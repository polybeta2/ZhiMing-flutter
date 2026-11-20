import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/database/app_database.dart' hide ScanMeta;
import '../../core/llm/llm_types.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/storage/blob_store.dart';
import '../../domain/models/source_profile_models.dart';
import '../../domain/source/source_batch_helper.dart';
import '../../domain/source/source_micro_summarizer.dart';
import '../../domain/source/source_reduce_watermark.dart';
import '../../domain/source/source_reducer.dart';
import '../../domain/source/source_scan_chunker.dart';

enum ScanPhase { idle, mapping, reducing, paused, done, failed }

class _PendingMicro {
  const _PendingMicro(this.pos, this.micro);
  final int pos;
  final MicroSummary micro;
}

class _RetryReduceBatch {
  const _RetryReduceBatch(this.seq, this.items);
  final int seq;
  final List<_PendingMicro> items;
}

class _FetchResult {
  const _FetchResult({
    required this.reply,
    required this.drained,
    this.errorText,
    this.usage,
  });

  final String reply;
  final bool drained;
  final String? errorText;
  final UsageReport? usage;
}

/// 原作分析扫描控制器：
/// - 滚动并发 Map + Reduce（每攒满 40 块并发归并）
/// - Drift SQLite 检查点（ScanTasks / ScanChunks / ScanReduces / ScanMetas）
/// - 单调连续前缀水位（SourceReduceWatermark）防止断点续跑丢块
/// - 真实 UsageReport 统计 + 估算兜底 + 3 次指数退避重试 + 暂停/换商续跑
class SourceScanController extends ChangeNotifier {
  SourceScanController({
    required this.db,
    required this.blobs,
    required this.client,
    required this.provider,
  });

  final AppDatabase db;
  final BlobStore blobs;
  LLMClient client;
  ProviderRecord provider;

  final StreamProgressTracker progress = StreamProgressTracker();

  ScanPhase phase = ScanPhase.idle;
  String? errorMessage;
  int totalChunks = 0;
  int doneChunks = 0;
  int tokensIn = 0;
  int tokensOut = 0;
  int? estimatedRemainingSeconds;
  SourceNovelProfileData? resultProfile;

  bool _cancelled = false;
  CancelToken? _activeCancel;
  int _runGeneration = 0;
  final List<double> _mapTimes = [];

  static const int _reduceBatchSize = 40;

  void updateProvider(ProviderRecord nextProvider, LLMClient nextClient) {
    provider = nextProvider;
    client = nextClient;
    notifyListeners();
  }

  void pause() {
    _cancelled = true;
    _activeCancel?.cancel('paused');
    progress.finish();
    if (phase == ScanPhase.mapping || phase == ScanPhase.reducing) {
      phase = ScanPhase.paused;
      notifyListeners();
    }
  }

  /// 开启新任务或从 presetProfileId 恢复扫描/归并。
  Future<void> start({
    required String sourceText,
    required String title,
    required ScanMode mode,
    int batchSize = 3,
    bool isContinuation = false,
    String? presetProfileId,
  }) async {
    _cancelled = false;
    _activeCancel = CancelToken();
    errorMessage = null;
    resultProfile = null;
    _mapTimes.clear();
    final generation = ++_runGeneration;
    final pid = presetProfileId ?? const Uuid().v4();
    final clampedBatch = batchSize.clamp(1, 10);

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    try {
      phase = ScanPhase.mapping;
      notifyListeners();

      // 原文大文本在 Isolate 中切块，避免 UI 掉帧
      final chunks = await Isolate.run(
        () => SourceScanChunker.chunks(sourceText, mode: mode),
      );
      if (chunks.isEmpty) {
        phase = ScanPhase.failed;
        errorMessage = '原文内容为空，无法分析';
        notifyListeners();
        return;
      }

      // 保存原文到 BlobStore 与断点书签，支持杀进程后恢复
      await blobs.saveText(BlobKinds.scanTask, pid, sourceText);
      await db.upsertScanTask(
        ScanTasksCompanion.insert(
          profileId: pid,
          title: title,
          mode: mode.raw,
          batchSize: clampedBatch,
          isContinuation: Value(isContinuation),
          totalChunks: chunks.length,
          providerName: provider.name,
          providerBaseUrl: provider.baseUrl,
          providerModel: provider.modelName,
          providerKeyId: provider.apiKeyId,
          startedAt: DateTime.now(),
        ),
      );

      final doneIndexes = await db.getDoneScanChunkIndexes(pid);
      final doneChunkRows = await db.getDoneScanChunks(pid);
      var inTotal = 0;
      var outTotal = 0;
      for (final row in doneChunkRows) {
        if (row.tokensIn > inTotal) inTotal = row.tokensIn;
        if (row.tokensOut > outTotal) outTotal = row.tokensOut;
      }

      totalChunks = chunks.length;
      doneChunks = doneIndexes.length;
      tokensIn = inTotal;
      tokensOut = outTotal;
      notifyListeners();

      // 恢复滚动归并状态
      final reducedUpto = await db.getReducedUpto(pid);
      final reducePending = <_PendingMicro>[];
      for (final row in doneChunkRows) {
        if (row.idx > reducedUpto && row.payloadJson != null) {
          try {
            reducePending.add(
              _PendingMicro(
                row.idx,
                MicroSummary.fromJsonString(row.payloadJson!),
              ),
            );
          } catch (_) {}
        }
      }
      final reduceRetries = <_RetryReduceBatch>[];
      final reduceFutures = <Future<void>>[];
      var nextReduceSeq = (await db.getMaxReduceSeq(pid)) + 1;
      final watermark = SourceReduceWatermark(
        nextSeq: nextReduceSeq,
        watermark: reducedUpto,
      );

      const mapConfig = GenerationConfig(temperature: 0.2, maxTokens: 2048);
      const reduceConfig = GenerationConfig(temperature: 0.25, maxTokens: 4096);
      const finalConfig = GenerationConfig(temperature: 0.3, maxTokens: 8192);

      void spawnReduce() {
        int seq;
        List<_PendingMicro> batch;
        if (reduceRetries.isNotEmpty) {
          final retry = reduceRetries.removeAt(0);
          seq = retry.seq;
          batch = retry.items;
        } else {
          if (reducePending.isEmpty) return;
          seq = nextReduceSeq++;
          batch = List<_PendingMicro>.from(reducePending);
          reducePending.clear();
        }
        final hiPos = batch.map((e) => e.pos).reduce((a, b) => a > b ? a : b);
        reduceFutures.add(() async {
          final prompt = SourceReducer.batchPrompt(
            batch.map((e) => e.micro).toList(),
            batchChars: 12000,
          );
          final res = await _fetchWithRetry(
            [LLMMessage(role: LLMRole.user, content: prompt)],
            config: reduceConfig,
          );
          if (_cancelled || generation != _runGeneration) return;
          if (!res.drained || res.reply.trim().isEmpty) {
            reduceRetries.add(_RetryReduceBatch(seq, batch));
            return;
          }
          await db.saveScanReduce(pid, seq, res.reply.trim());
          final adv = watermark.complete(seq: seq, hiPos: hiPos);
          if (adv != null) {
            await db.advanceReducedUpto(pid, adv);
          }
          if (res.usage != null) {
            inTotal += res.usage!.promptTokens;
            outTotal += res.usage!.completionTokens;
          } else {
            inTotal += prompt.length ~/ 2;
            outTotal += res.reply.length ~/ 2;
          }
          tokensIn = inTotal;
          tokensOut = outTotal;
          notifyListeners();
        }());
      }

      // ---- 1. Map 阶段（连续未完成块成组） ----
      var pos = 0;
      while (pos < chunks.length) {
        if (_cancelled || generation != _runGeneration) break;
        if (doneIndexes.contains(pos)) {
          pos += 1;
          continue;
        }
        final group = <({int pos, SourceScanChunk chunk})>[];
        var g = pos;
        while (g < chunks.length && group.length < clampedBatch) {
          if (doneIndexes.contains(g)) break;
          group.add((pos: g, chunk: chunks[g]));
          g += 1;
        }
        if (group.isEmpty) {
          pos += 1;
          continue;
        }

        final t0 = DateTime.now();
        final groupSummary = <int, MicroSummary>{};
        UsageReport? usage;

        if (group.length == 1) {
          final single = group.first;
          final msgs = SourceMicroSummarizer.messages(chunk: single.chunk.text);
          final parsed = await _fetchSingleParsed(msgs, config: mapConfig);
          if (_cancelled) break;
          if (parsed.summary == null) {
            _fail(parsed.error ?? '网络错误');
            return;
          }
          groupSummary[single.pos] = parsed.summary!;
          usage = parsed.usage;
        } else {
          final batchInputs = group
              .map(
                (item) => BatchChapterInput(
                  index: item.pos + 1,
                  body: item.chunk.text,
                ),
              )
              .toList();
          final prompt = SourceBatchHelper.prompt(
            title: title,
            chapters: batchInputs,
          );
          final parsed = await _fetchBatchParsed(
            [LLMMessage(role: LLMRole.user, content: prompt)],
            config: mapConfig,
          );
          if (_cancelled) break;
          if (parsed.summaries == null) {
            _fail(parsed.error ?? '批量微摘要解析失败');
            return;
          }
          groupSummary.addAll(parsed.summaries!);
          usage = parsed.usage;
        }

        final elapsedSec =
            DateTime.now().difference(t0).inMilliseconds / 1000.0;
        _mapTimes.add(elapsedSec / group.length);

        if (usage != null) {
          inTotal += usage.promptTokens;
          outTotal += usage.completionTokens;
        }

        for (final item in group) {
          if (_cancelled) break;
          final micro = groupSummary[item.pos] ?? const MicroSummary();
          final payload = micro.toJsonString();
          if (usage == null) {
            inTotal += item.chunk.text.length ~/ 2;
            outTotal += payload.length ~/ 2;
          }
          await db.markScanChunk(
            ScanChunksCompanion.insert(
              profileId: pid,
              idx: item.pos,
              status: 'done',
              payloadJson: Value(payload),
              tokensIn: Value(inTotal),
              tokensOut: Value(outTotal),
              updatedAt: DateTime.now(),
            ),
          );
          doneIndexes.add(item.pos);
          reducePending.add(_PendingMicro(item.pos, micro));
          doneChunks = doneIndexes.length;
          tokensIn = inTotal;
          tokensOut = outTotal;
        }

        _updateEstimate();
        notifyListeners();

        if (reducePending.length >= _reduceBatchSize) {
          spawnReduce();
        }
        pos = g;
      }

      if (_cancelled || generation != _runGeneration) {
        return;
      }

      // ---- 2. 收尾滚动归并 ----
      phase = ScanPhase.reducing;
      notifyListeners();

      var rounds = 0;
      while (rounds < 3) {
        while (reduceRetries.isNotEmpty || reducePending.isNotEmpty) {
          spawnReduce();
        }
        if (reduceFutures.isNotEmpty) {
          await Future.wait(List<Future<void>>.from(reduceFutures));
          reduceFutures.clear();
        }
        if (_cancelled) return;
        if (reduceRetries.isEmpty) break;
        rounds += 1;
      }

      if (reduceRetries.isNotEmpty) {
        _fail('部分归并批次多次失败（阶段摘要不完整），请检查网络后点「继续分析」续跑');
        return;
      }

      final stageSummaries = await db.loadScanReduces(pid);
      if (_cancelled) return;

      // ---- 3. 终归并 / 续写深度归并 ----
      final analyzedChapters =
          chunks.map((c) => c.chapterIndex).reduce((a, b) => a > b ? a : b) + 1;
      final finalMsgs = isContinuation
          ? SourceReducer.continuationPrompt(
              stageSummaries: stageSummaries,
              upToChapter: analyzedChapters,
            )
          : SourceReducer.finalPrompt(stageSummaries: stageSummaries);

      final finalRes = await _fetchWithRetry(finalMsgs, config: finalConfig);
      if (_cancelled) return;
      if (!finalRes.drained) {
        _fail(finalRes.errorText ?? '终归并网络失败');
        return;
      }
      if (finalRes.usage != null) {
        inTotal += finalRes.usage!.promptTokens;
        outTotal += finalRes.usage!.completionTokens;
      } else {
        outTotal += finalRes.reply.length ~/ 2;
      }

      SourceNovelProfileData profile;
      try {
        profile = isContinuation
            ? SourceReducer.parseContinuation(
                finalRes.reply,
                fallbackTitle: title,
                upToChapter: analyzedChapters,
                profileId: pid,
              )
            : SourceReducer.parseFinal(
                finalRes.reply,
                fallbackTitle: title,
                profileId: pid,
              );
      } catch (_) {
        _fail(
          isContinuation
              ? '深度归并产物解析失败，可稍后点「继续分析」重试（阶段摘要已缓存）'
              : '终归并产物解析失败，可稍后点「继续分析」重试（阶段摘要已缓存）',
        );
        return;
      }

      var hasSourceText = false;
      if (isContinuation) {
        await blobs.saveText(BlobKinds.continuation, profile.id, sourceText);
        hasSourceText = true;
      }

      profile = profile.copyWith(
        hasSourceText: hasSourceText,
        meta: ScanMeta(
          totalChapters: analyzedChapters,
          totalChars: sourceText.length,
          scanMode: mode,
        ),
        scanState: ScanState(
          stage: ScanStage.done,
          totalChunks: chunks.length,
          doneChunks: chunks.length,
          tokensIn: inTotal,
          tokensOut: outTotal,
          startedAt: DateTime.now(),
        ),
      );

      await db.upsertSourceProfile(
        SourceProfilesCompanion.insert(
          id: profile.id,
          title: profile.title,
          author: Value(profile.author),
          payloadJson: profile.toJsonString(),
          createdAt: profile.createdAt,
        ),
      );
      await db.clearScanCheckpoints(pid);
      await blobs.delete(BlobKinds.scanTask, pid);

      resultProfile = profile;
      tokensIn = inTotal;
      tokensOut = outTotal;
      phase = ScanPhase.done;
      estimatedRemainingSeconds = 0;
      notifyListeners();
    } catch (e) {
      if (!_cancelled) {
        _fail('分析异常：$e');
      }
    } finally {
      progress.finish();
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  void _fail(String reason) {
    errorMessage = '分析中断：$reason。检查网络或模型配置后可点「继续分析」续跑。';
    phase = ScanPhase.failed;
    notifyListeners();
  }

  void _updateEstimate() {
    if (_mapTimes.isEmpty) return;
    final avg = _mapTimes.reduce((a, b) => a + b) / _mapTimes.length;
    final remaining = (totalChunks - doneChunks).clamp(0, totalChunks);
    estimatedRemainingSeconds = (avg * remaining).round();
  }

  Future<_FetchResult> _fetch(
    List<LLMMessage> messages, {
    required GenerationConfig config,
  }) async {
    progress.begin();
    final buf = StringBuffer();
    UsageReport? usage;
    try {
      await for (final ev in client.streamChat(
        messages,
        config: config,
        cancelToken: _activeCancel,
      )) {
        if (_cancelled) {
          return const _FetchResult(
            reply: '',
            drained: false,
            errorText: '已暂停',
          );
        }
        progress.handle(ev);
        switch (ev) {
          case ReasoningDelta():
            break;
          case ContentDelta(:final text):
            buf.write(text);
          case UsageReport():
            usage = ev;
        }
      }
      progress.finish();
      return _FetchResult(reply: buf.toString(), drained: true, usage: usage);
    } catch (e) {
      progress.finish();
      return _FetchResult(
        reply: buf.toString(),
        drained: false,
        errorText: e.toString(),
      );
    }
  }

  Future<({MicroSummary? summary, String? error, UsageReport? usage})>
  _fetchSingleParsed(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    int attempts = 3,
  }) async {
    String? lastError;
    for (var i = 0; i < attempts; i++) {
      if (_cancelled) return (summary: null, error: null, usage: null);
      final res = await _fetch(messages, config: config);
      if (res.drained) {
        try {
          return (
            summary: SourceMicroSummarizer.parse(res.reply),
            error: null,
            usage: res.usage,
          );
        } catch (_) {
          lastError = '返回内容无法解析为微摘要 JSON';
        }
      } else {
        lastError = res.errorText ?? '网络错误';
      }
      await _backoff(i);
    }
    return (summary: null, error: lastError, usage: null);
  }

  Future<({Map<int, MicroSummary>? summaries, String? error, UsageReport? usage})>
  _fetchBatchParsed(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    int attempts = 3,
  }) async {
    String? lastError;
    for (var i = 0; i < attempts; i++) {
      if (_cancelled) return (summaries: null, error: null, usage: null);
      final res = await _fetch(messages, config: config);
      if (res.drained) {
        try {
          return (
            summaries: SourceBatchHelper.parseBatchOutput(res.reply),
            error: null,
            usage: res.usage,
          );
        } catch (_) {
          lastError = '批量返回无法解析为逐块微摘要';
        }
      } else {
        lastError = res.errorText ?? '网络错误';
      }
      await _backoff(i);
    }
    return (summaries: null, error: lastError, usage: null);
  }

  Future<_FetchResult> _fetchWithRetry(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    int attempts = 3,
  }) async {
    var last = const _FetchResult(
      reply: '',
      drained: false,
      errorText: '未知错误',
    );
    for (var i = 0; i < attempts; i++) {
      if (_cancelled) {
        return const _FetchResult(reply: '', drained: false, errorText: '已暂停');
      }
      final res = await _fetch(messages, config: config);
      if (res.drained) return res;
      last = res;
      await _backoff(i);
    }
    return last;
  }

  Future<void> _backoff(int attempt) async {
    final seconds = (1 << attempt).clamp(1, 8);
    for (var s = 0; s < seconds * 5; s++) {
      if (_cancelled) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _activeCancel?.cancel('disposed');
    progress.dispose();
    super.dispose();
  }
}
