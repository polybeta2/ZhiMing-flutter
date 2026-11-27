import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/database/app_database.dart' hide ScanMeta;
import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/platform/background_keep_alive.dart';
import '../../core/storage/blob_store.dart';
import '../../domain/models/source_profile_models.dart';
import '../../domain/source/novel_local_indexer.dart';
import '../../domain/source/source_batch_helper.dart';
import '../../domain/source/source_graph_aggregator.dart';
import '../../domain/source/source_graph_reducer.dart';
import '../../domain/source/source_micro_summarizer.dart';
import '../../domain/source/source_reducer.dart';
import '../../domain/source/source_scan_chunker.dart';
import '../../domain/style/style_chapter_sampler.dart';

enum ScanPhase { idle, mapping, reducing, paused, done, failed }

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
/// - 默认模式 [ScanMode.evidence]：零耗时本地索引 + 两轮证据驱动建档 + Static Prefix KV 缓存（80%+ 命中，~1-2 分钟完成）
/// - 深度模式 [ScanMode.fast] / [ScanMode.full]：≤8 万字直读快车道 + 大窗分批并发 Map（AIMD 限流自适应 + 强弱模型分流）+ 4-Pass Graph-Reduce + Drift 断点续跑
class SourceScanController extends ChangeNotifier {
  SourceScanController({
    required this.db,
    required this.blobs,
    required this.client,
    required this.provider,
    this.fastClient,
    this.fastProvider,
  });

  final AppDatabase db;
  final BlobStore blobs;
  LLMClient client;
  ProviderRecord provider;
  LLMClient? fastClient;
  ProviderRecord? fastProvider;

  LLMClient get _mapClient => fastClient ?? client;
  ProviderRecord get _mapProvider => fastProvider ?? provider;

  final StreamProgressTracker progress = StreamProgressTracker();

  ScanPhase phase = ScanPhase.idle;
  String? statusDetail;
  String? errorMessage;
  int totalChunks = 0;
  int doneChunks = 0;
  int tokensIn = 0;
  int tokensOut = 0;
  int cachedTokens = 0;
  int? estimatedRemainingSeconds;
  SourceNovelProfileData? resultProfile;

  bool _cancelled = false;
  CancelToken? _activeCancel;
  int _runGeneration = 0;
  int _activeStreams = 0;
  final List<double> _mapTimes = [];

  static bool isRateLimitError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('429') || lower.contains('rate limit');
  }

  /// 计算 AIMD 自适应并发步进状态：限流减半（下限 1），每连续 6 次成功探测 +1（上限 [maxConcurrency]）。
  @visibleForTesting
  static ({int activeLimit, int consecutiveOk}) nextAimdState({
    required int currentLimit,
    required int maxConcurrency,
    required int consecutiveOk,
    required bool isRateLimited,
  }) {
    final cap = math.max(1, maxConcurrency);
    if (isRateLimited) {
      return (activeLimit: math.max(1, currentLimit ~/ 2), consecutiveOk: 0);
    }
    final nextOk = consecutiveOk + 1;
    if (nextOk >= 6) {
      return (
        activeLimit: math.min(cap, currentLimit + 1),
        consecutiveOk: 0,
      );
    }
    return (activeLimit: currentLimit.clamp(1, cap), consecutiveOk: nextOk);
  }

  @visibleForTesting
  static int nextAimdLimit({
    required int currentLimit,
    required int maxConcurrency,
    required int consecutiveOk,
    required bool isRateLimited,
  }) => nextAimdState(
    currentLimit: currentLimit,
    maxConcurrency: maxConcurrency,
    consecutiveOk: consecutiveOk,
    isRateLimited: isRateLimited,
  ).activeLimit;

  void updateProvider(
    ProviderRecord nextProvider,
    LLMClient nextClient, {
    ProviderRecord? nextFastProvider,
    LLMClient? nextFastClient,
  }) {
    provider = nextProvider;
    client = nextClient;
    if (nextFastProvider != null) fastProvider = nextFastProvider;
    if (nextFastClient != null) fastClient = nextFastClient;
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
    int batchSize = 10,
    int concurrency = 6,
    int? batchCharBudget,
    bool isContinuation = false,
    String? presetProfileId,
  }) async {
    _cancelled = false;
    _activeCancel = CancelToken();
    errorMessage = null;
    statusDetail = null;
    resultProfile = null;
    cachedTokens = 0;
    tokensIn = 0;
    tokensOut = 0;
    _mapTimes.clear();
    final generation = ++_runGeneration;
    final pid = presetProfileId ?? const Uuid().v4();
    final clampedBatch = batchSize.clamp(1, 20);
    final clampedConcurrency = concurrency.clamp(1, 12);

    try {
      await WakelockPlus.enable();
    } catch (_) {}
    await BackgroundKeepAliveService.instance.acquire();

    try {
      if (mode == ScanMode.evidence) {
        await _runEvidenceScan(
          sourceText: sourceText,
          title: title,
          isContinuation: isContinuation,
          pid: pid,
          generation: generation,
        );
        return;
      }

      NovelLocalIndexer? upfrontIndexer;

      // ---- 0. Direct-Read 快车道（≤ 80,000 字且未开始分块缓存且主力模型窗口 ≥ 60,000） ----
      if (mode == ScanMode.full &&
          sourceText.length <= 80000 &&
          provider.contextBudgetChars >= 60000 &&
          (await db.getDoneScanChunkIndexes(pid)).isEmpty) {
        phase = ScanPhase.reducing;
        totalChunks = 1;
        doneChunks = 0;
        statusDetail =
            '体量适中（${sourceText.length} 字），正在使用长窗口直读通道一次性建档…';
        notifyListeners();

        upfrontIndexer = await _indexInIsolate(sourceText);
        if (_cancelled || generation != _runGeneration) return;

        final direct = await _tryDirectReadProfile(
          sourceText: sourceText,
          title: title,
          mode: mode,
          isContinuation: isContinuation,
          pid: pid,
          indexer: upfrontIndexer,
          generation: generation,
        );
        if (_cancelled || generation != _runGeneration) return;
        if (direct.profile != null) {
          final saved = direct.profile!;
          await blobs.saveText(BlobKinds.continuation, saved.id, sourceText);
          await db.upsertSourceProfile(
            SourceProfilesCompanion.insert(
              id: saved.id,
              title: saved.title,
              author: Value(saved.author),
              payloadJson: saved.toJsonString(),
              createdAt: saved.createdAt,
            ),
          );
          await db.clearScanCheckpoints(pid);
          await blobs.delete(BlobKinds.scanTask, pid);

          resultProfile = saved;
          doneChunks = 1;
          totalChunks = 1;
          phase = ScanPhase.done;
          statusDetail =
              '直读建图完成！${saved.characters.length} 角色 · ${saved.relations.length} 关系 · ${saved.openThreads.length} 伏笔 · ${saved.timeline.length} 时间线';
          estimatedRemainingSeconds = 0;
          notifyListeners();
          return;
        }
        totalChunks = 0;
        doneChunks = 0;
        statusDetail =
            '长窗口直读未完成（${direct.failureReason ?? "结构回退"}），正在切换分块精扫流程…';
        notifyListeners();
      }

      phase = ScanPhase.mapping;
      statusDetail = '正在后台索引人物并切章净化正文…';
      notifyListeners();

      upfrontIndexer ??= await _indexInIsolate(sourceText);
      if (_cancelled || generation != _runGeneration) return;

      final knownCharacters = upfrontIndexer.topEntities
          .take(40)
          .map((e) => e.name)
          .toList();
      final maxChunkChars = _mapProvider.contextBudgetChars >= 50000
          ? SourceScanChunker.modernFullMaxChunk
          : SourceScanChunker.fullMaxChunk;

      // 原文大文本在 Isolate 中切块，避免 UI 掉帧（静态方法避免捕获 this/CancelToken）
      final chunks = await _chunkInIsolate(
        sourceText,
        mode,
        maxChunkChars: maxChunkChars,
      );
      if (_cancelled || generation != _runGeneration) return;
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
      var inTotal = tokensIn;
      var outTotal = tokensOut;
      for (final row in doneChunkRows) {
        if (row.tokensIn > inTotal) inTotal = row.tokensIn;
        if (row.tokensOut > outTotal) outTotal = row.tokensOut;
      }

      totalChunks = chunks.length;
      doneChunks = doneIndexes.length;
      tokensIn = inTotal;
      tokensOut = outTotal;
      final usingSeparateFast =
          fastProvider != null && fastProvider!.id != provider.id;
      statusDetail =
          '步骤 1/5：并发抽取逐章事实（${mode.label} · 每批最多 $clampedBatch 块 · $clampedConcurrency 并发'
          '${usingSeparateFast ? " · Map:${_mapProvider.name}" : ""}）';
      notifyListeners();

      // 推理模型安全预算 + 结构化 JSON / 提示词缓存控制
      const mapSingleConfig = GenerationConfig(
        temperature: 0.2,
        maxTokens: 12288,
        jsonMode: true,
        reasoningEffort: ReasoningEffort.low,
        enablePromptCacheControl: true,
      );
      const mapBatchConfig = GenerationConfig(
        temperature: 0.2,
        maxTokens: 12288,
        jsonMode: false,
        reasoningEffort: ReasoningEffort.low,
        enablePromptCacheControl: true,
      );
      const reduceConfig = GenerationConfig(
        temperature: 0.2,
        maxTokens: 12288,
        jsonMode: true,
        reasoningEffort: ReasoningEffort.medium,
        enablePromptCacheControl: true,
      );
      const heavyReduceConfig = GenerationConfig(
        temperature: 0.25,
        maxTokens: 16384,
        jsonMode: true,
        reasoningEffort: ReasoningEffort.medium,
        enablePromptCacheControl: true,
      );

      // ---- 1. 并发 Map 阶段（按字符预算打包 + KV Cache + AIMD 限流自适应） ----
      final effectiveBatchCharBudget = clampedBatch == 1
          ? 1
          : (batchCharBudget ??
                (_mapProvider.contextBudgetChars >= 80000 ? 48000 : 32000));
      final pendingGroups = SourceScanChunker.packByCharBudget(
        chunks,
        doneIndexes,
        targetBatchChars: effectiveBatchCharBudget,
        maxChunksPerBatch: clampedBatch,
      );

      final workQueue =
          Queue<
            ({List<({int pos, SourceScanChunk chunk})> group, int retries})
          >.from(pendingGroups.map((g) => (group: g, retries: 0)));

      var activeLimit = clampedConcurrency;
      var consecutiveOk = 0;
      var inFlight = 0;
      final waiters = <Completer<void>>[];
      String? mapFatalError;

      void wakeWaiters() {
        while (waiters.isNotEmpty && inFlight < activeLimit) {
          final w = waiters.removeAt(0);
          if (!w.isCompleted) w.complete();
        }
      }

      void wakeAllWaiters() {
        while (waiters.isNotEmpty) {
          final w = waiters.removeAt(0);
          if (!w.isCompleted) w.complete();
        }
      }

      Future<bool> acquireSlot() async {
        while (workQueue.isEmpty || inFlight >= activeLimit) {
          if (_cancelled ||
              generation != _runGeneration ||
              mapFatalError != null ||
              (workQueue.isEmpty && inFlight == 0)) {
            return false;
          }
          final c = Completer<void>();
          waiters.add(c);
          await c.future;
        }
        if (_cancelled ||
            generation != _runGeneration ||
            mapFatalError != null ||
            workQueue.isEmpty) {
          return false;
        }
        inFlight += 1;
        return true;
      }

      void releaseSlot() {
        inFlight = math.max(0, inFlight - 1);
        if (_cancelled ||
            generation != _runGeneration ||
            mapFatalError != null ||
            (workQueue.isEmpty && inFlight == 0)) {
          wakeAllWaiters();
        } else if (workQueue.isNotEmpty) {
          wakeWaiters();
        }
      }

      Future<void> mapWorker() async {
        while (true) {
          if (_cancelled ||
              generation != _runGeneration ||
              mapFatalError != null) {
            wakeAllWaiters();
            return;
          }
          if (workQueue.isEmpty && inFlight == 0) {
            wakeAllWaiters();
            return;
          }
          final gotSlot = await acquireSlot();
          if (!gotSlot) {
            if (inFlight == 0) wakeAllWaiters();
            return;
          }

          try {
            if (_cancelled ||
                generation != _runGeneration ||
                mapFatalError != null ||
                workQueue.isEmpty) {
              continue;
            }
            final task = workQueue.removeFirst();
            final group = task.group;
            final t0 = DateTime.now();
            final groupSummary = <int, MicroSummary>{};
            UsageReport? usage;
            String? itemError;

            if (group.length == 1) {
              final single = group.first;
              final marker = single.chunk.partCount > 1
                  ? '${single.chunk.chapterTitle.isNotEmpty ? single.chunk.chapterTitle : "第${single.chunk.chapterNo}章"}（第${single.chunk.partIndex + 1}/${single.chunk.partCount}段，chapter=${single.chunk.chapterNo}）'
                  : (single.chunk.chapterTitle.isNotEmpty
                        ? '${single.chunk.chapterTitle}（chapter=${single.chunk.chapterNo}）'
                        : '第${single.chunk.chapterNo}章');
              final rawMsgs = SourceMicroSummarizer.messages(
                chunk: single.chunk.text,
                chapterMarker: marker,
              );
              final msgs = [
                for (final m in rawMsgs)
                  m.role == LLMRole.system && !m.cacheControl
                      ? LLMMessage(
                          role: m.role,
                          content: m.content,
                          cacheControl: true,
                        )
                      : m,
              ];
              final parsed = await _fetchSingleParsed(
                msgs,
                config: mapSingleConfig,
                targetClient: _mapClient,
              );
              if (_cancelled || generation != _runGeneration) return;
              if (parsed.summary == null) {
                itemError = parsed.error ?? '网络错误';
              } else {
                groupSummary[single.pos] = MicroSummary(
                  chapterNo: single.chunk.chapterNo,
                  characters: parsed.summary!.characters,
                  relations: parsed.summary!.relations,
                  events: parsed.summary!.events,
                  worldbuilding: parsed.summary!.worldbuilding,
                  foreshadowing: parsed.summary!.foreshadowing,
                );
                usage = parsed.usage;
              }
            } else {
              final batchInputs = group.map((item) {
                final ch = item.chunk;
                final rawTitle = ch.chapterTitle.isNotEmpty
                    ? ch.chapterTitle
                    : '第${ch.chapterNo}章';
                final titled = ch.partCount > 1
                    ? '$rawTitle（第${ch.partIndex + 1}/${ch.partCount}段）'
                    : rawTitle;
                return BatchChapterInput(
                  index: ch.chapterNo,
                  title: titled,
                  body: ch.text,
                );
              }).toList();
              final msgs = SourceBatchHelper.buildCachedBatchMessages(
                title: title,
                chapters: batchInputs,
                knownCharacters: knownCharacters,
              );
              final parsed = await _fetchBatchEntriesParsed(
                msgs,
                config: mapBatchConfig,
                targetClient: _mapClient,
              );
              if (_cancelled || generation != _runGeneration) return;
              if (parsed.entries == null) {
                itemError = parsed.error ?? '批量微摘要解析失败';
              } else {
                // 按真实 chapterNo 分配（同章多段依次对应，避免重复或错位）
                final byCh = <int, List<MicroSummary>>{};
                for (final entry in parsed.entries!) {
                  byCh
                      .putIfAbsent(entry.chapterNo, () => [])
                      .add(entry.summary);
                }
                for (final item in group) {
                  final list = byCh[item.chunk.chapterNo];
                  if (list != null && list.isNotEmpty) {
                    final m = list.removeAt(0);
                    groupSummary[item.pos] = MicroSummary(
                      chapterNo: item.chunk.chapterNo,
                      characters: m.characters,
                      relations: m.relations,
                      events: m.events,
                      worldbuilding: m.worldbuilding,
                      foreshadowing: m.foreshadowing,
                    );
                  } else {
                    groupSummary[item.pos] = MicroSummary(
                      chapterNo: item.chunk.chapterNo,
                    );
                  }
                }
                // 若还有未消费的同章额外条目，合并到本组同章首块
                for (final rem in byCh.entries) {
                  if (rem.value.isEmpty) continue;
                  final target = group
                      .where((g) => g.chunk.chapterNo == rem.key)
                      .firstOrNull;
                  if (target == null) continue;
                  var acc =
                      groupSummary[target.pos] ??
                      MicroSummary(chapterNo: rem.key);
                  for (final extra in rem.value) {
                    acc = acc.mergeWith(extra);
                  }
                  groupSummary[target.pos] = acc;
                }
                usage = parsed.usage;
              }
            }

            if (itemError != null) {
              if (isRateLimitError(itemError) && task.retries < 3) {
                final next = nextAimdState(
                  currentLimit: activeLimit,
                  maxConcurrency: clampedConcurrency,
                  consecutiveOk: consecutiveOk,
                  isRateLimited: true,
                );
                activeLimit = next.activeLimit;
                consecutiveOk = next.consecutiveOk;
                workQueue.addLast((group: group, retries: task.retries + 1));
                wakeWaiters();
                statusDetail =
                    '触发限流，已自动降速至 $activeLimit 路并发并重新排队（$doneChunks/$totalChunks）…';
                notifyListeners();
                await _backoff(task.retries);
                continue;
              }
              mapFatalError ??= itemError;
              wakeAllWaiters();
              return;
            }

            final next = nextAimdState(
              currentLimit: activeLimit,
              maxConcurrency: clampedConcurrency,
              consecutiveOk: consecutiveOk,
              isRateLimited: false,
            );
            activeLimit = next.activeLimit;
            consecutiveOk = next.consecutiveOk;

            final elapsedSec =
                DateTime.now().difference(t0).inMilliseconds / 1000.0;
            _mapTimes.add(elapsedSec / group.length);

            if (usage != null) {
              inTotal += usage.promptTokens;
              outTotal += usage.completionTokens;
              cachedTokens += usage.cachedTokens;
            }

            for (final item in group) {
              if (_cancelled || generation != _runGeneration) return;
              final micro =
                  groupSummary[item.pos] ??
                  MicroSummary(chapterNo: item.chunk.chapterNo);
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
              doneChunks = doneIndexes.length;
              tokensIn = inTotal;
              tokensOut = outTotal;
            }

            _updateEstimate(concurrency: activeLimit);
            notifyListeners();
          } finally {
            releaseSlot();
          }
        }
      }

      if (pendingGroups.isNotEmpty) {
        final workerCount = math.min(clampedConcurrency, pendingGroups.length);
        await Future.wait(List.generate(workerCount, (_) => mapWorker()));
      }

      if (_cancelled || generation != _runGeneration) return;
      if (mapFatalError != null) {
        _fail(mapFatalError!);
        return;
      }

      // ---- 2. 本地零损程序化聚合（0 Token，彻底消除 12000 字截断与 1500 字漏斗） ----
      phase = ScanPhase.reducing;
      statusDetail = '正在零损聚合全书人物、关系、事件与伏笔证据池…';
      notifyListeners();

      final allDoneRows = await db.getDoneScanChunks(pid);
      final analyzedChapters = chunks
          .map((c) => c.chapterNo)
          .reduce((a, b) => a > b ? a : b);
      final microRecords = <({int chapterNo, MicroSummary summary})>[];
      for (final row in allDoneRows) {
        if (row.payloadJson == null || row.idx < 0 || row.idx >= chunks.length) {
          continue;
        }
        try {
          final m = MicroSummary.fromJsonString(row.payloadJson!);
          final realCh = chunks[row.idx].chapterNo;
          microRecords.add((chapterNo: realCh, summary: m));
        } catch (_) {}
      }

      final aggregated = SourceGraphAggregator.build(
        microRecords,
        totalChapters: analyzedChapters,
      );
      final savedReduces = await db.loadScanReduceMap(pid);

      void recordUsage(UsageReport? u, int estInChars, int estOutChars) {
        if (u != null) {
          inTotal += u.promptTokens;
          outTotal += u.completionTokens;
          cachedTokens += u.cachedTokens;
        } else {
          inTotal += estInChars ~/ 2;
          outTotal += estOutChars ~/ 2;
        }
        tokensIn = inTotal;
        tokensOut = outTotal;
        notifyListeners();
      }

      // ---- 3. Pass 1: Canon 实体消歧与阵营名录 ----
      statusDetail =
          '步骤 2/5：实体消歧与别名统一（共汇总 ${aggregated.characterCandidates.length} 个候选角色、${aggregated.rawClues.length} 条伏笔线索）…';
      notifyListeners();

      CanonPassResult canon;
      final cachedPass1 = savedReduces[GraphReduceSeq.pass1Canon];
      if (cachedPass1 != null && cachedPass1.trim().isNotEmpty) {
        try {
          canon = SourceGraphReducer.parsePass1Canon(cachedPass1);
        } catch (_) {
          canon = await _runPass1Canon(
            pid: pid,
            title: title,
            aggregated: aggregated,
            config: heavyReduceConfig,
            recordUsage: recordUsage,
          );
        }
      } else {
        canon = await _runPass1Canon(
          pid: pid,
          title: title,
          aggregated: aggregated,
          config: heavyReduceConfig,
          recordUsage: recordUsage,
        );
      }
      if (_cancelled || generation != _runGeneration) return;

      // 代码确定性重写全书所有角色名
      final normalized = aggregated.applyAliasMap(
        canon.aliasMap,
        dropNames: canon.dropNames,
      );
      final targets = SourceGraphReducer.selectProfileTargets(canon, normalized);
      final targetNames = targets.map((t) => t.name).toSet();

      // ---- 4. Pass 2: 角色分批建档（10-12人/批，最多 6 并发） ----
      final charBatches = <List<CanonSkeleton>>[];
      for (var i = 0; i < targets.length; i += SourceGraphReducer.charBatchSize) {
        final end = (i + SourceGraphReducer.charBatchSize).clamp(0, targets.length);
        charBatches.add(targets.sublist(i, end));
      }

      final tailSnippet = isContinuation
          ? chunks
                .sublist((chunks.length - 3).clamp(0, chunks.length))
                .map((c) => '〔第${c.chapterNo}章 ${c.chapterTitle}〕\n${c.text}')
                .join('\n\n')
          : null;

      statusDetail =
          '步骤 3/5：分批深度建档 ${targets.length} 名核心与重要角色（共 ${charBatches.length} 批）…';
      notifyListeners();

      final profiledMap = <String, CanonCharacter>{};
      var nextCharBatch = 0;
      String? pass2Error;

      Future<void> charBatchWorker() async {
        while (true) {
          if (_cancelled || generation != _runGeneration || pass2Error != null) {
            return;
          }
          if (nextCharBatch >= charBatches.length) return;
          final bIdx = nextCharBatch++;
          final batch = charBatches[bIdx];
          final seq = GraphReduceSeq.pass2CharBase + bIdx;
          final cached = savedReduces[seq];
          List<CanonCharacter>? chars;
          if (cached != null && cached.trim().isNotEmpty) {
            try {
              chars = SourceGraphReducer.parsePass2CharBatch(cached);
            } catch (_) {}
          }
          if (chars == null) {
            final msgs = SourceGraphReducer.pass2CharBatchPrompt(
              title: title,
              batch: batch,
              normalized: normalized,
              isContinuation: isContinuation,
              tailContextSnippet: tailSnippet,
            );
            final res = await _fetchWithRetry(msgs, config: heavyReduceConfig);
            if (_cancelled || generation != _runGeneration) return;
            if (!res.drained) {
              pass2Error ??= res.errorText ?? '角色建档第 ${bIdx + 1} 批请求失败';
              return;
            }
            recordUsage(res.usage, msgs.last.content.length, res.reply.length);
            try {
              chars = SourceGraphReducer.parsePass2CharBatch(res.reply);
              await db.saveScanReduce(pid, seq, res.reply.trim());
            } catch (e) {
              pass2Error ??= '角色建档第 ${bIdx + 1} 批解析失败：$e';
              return;
            }
          }
          for (final c in chars) {
            profiledMap[c.name] = c;
          }
        }
      }

      if (charBatches.isNotEmpty) {
        final workers = math.min(
          charBatches.length,
          clampedConcurrency.clamp(1, 6),
        );
        await Future.wait(List.generate(workers, (_) => charBatchWorker()));
      }
      if (_cancelled || generation != _runGeneration) return;
      if (pass2Error != null) {
        _fail(pass2Error!);
        return;
      }

      // ---- 5. Pass 3A（关系图谱）、Pass 3B（世界观）& Pass 4A（伏笔生命周期对账）并发归并 ----
      statusDetail = '步骤 4/5：并发归并人物关系图谱、世界观词条与全书伏笔对账…';
      notifyListeners();

      final relPairs = SourceGraphReducer.selectRelationPairs(
        normalized,
        allowedNames: targetNames,
      );
      final relBatches = <List<MapEntry<String, List<RawRelationEvidence>>>>[];
      for (var i = 0; i < relPairs.length; i += SourceGraphReducer.relPairBatchSize) {
        final end = (i + SourceGraphReducer.relPairBatchSize).clamp(0, relPairs.length);
        relBatches.add(relPairs.sublist(i, end));
      }

      final relations = <CanonRelationEdge>[];
      final worldbuilding = <CanonWorldEntry>[];
      final threads = <CanonThread>[];

      await Future.wait([
        () async {
          if (relBatches.isEmpty) return;
          final batchResults = List<List<CanonRelationEdge>>.filled(
            relBatches.length,
            const [],
          );
          var nextRel = 0;
          Future<void> relWorker() async {
            while (true) {
              if (_cancelled || generation != _runGeneration) return;
              if (nextRel >= relBatches.length) return;
              final i = nextRel++;
              final seq = GraphReduceSeq.pass3RelBase + i;
              final cached = savedReduces[seq];
              if (cached != null && cached.trim().isNotEmpty) {
                try {
                  batchResults[i] = SourceGraphReducer.parsePass3Relations(
                    cached,
                  );
                  continue;
                } catch (_) {}
              }
              final msgs = SourceGraphReducer.pass3RelationsPrompt(
                title: title,
                pairBatch: relBatches[i],
                cooccurrence: normalized.cooccurrence,
              );
              final res = await _fetchWithRetry(msgs, config: reduceConfig);
              if (_cancelled || generation != _runGeneration) return;
              if (res.drained && res.reply.trim().isNotEmpty) {
                recordUsage(
                  res.usage,
                  msgs.last.content.length,
                  res.reply.length,
                );
                try {
                  final parsedRels = SourceGraphReducer.parsePass3Relations(
                    res.reply,
                  );
                  batchResults[i] = parsedRels;
                  await db.saveScanReduce(pid, seq, res.reply.trim());
                } catch (_) {}
              }
            }
          }

          final relWorkers = math.min(relBatches.length, 4);
          await Future.wait(List.generate(relWorkers, (_) => relWorker()));
          for (final list in batchResults) {
            relations.addAll(list);
          }
        }(),
        () async {
          if (normalized.rawWorldEntries.isEmpty) return;
          final cached = savedReduces[GraphReduceSeq.pass3World];
          if (cached != null && cached.trim().isNotEmpty) {
            try {
              worldbuilding.addAll(SourceGraphReducer.parsePass3World(cached));
              return;
            } catch (_) {}
          }
          final msgs = SourceGraphReducer.pass3WorldPrompt(
            normalized,
            title: title,
            contextBudgetChars: provider.contextBudgetChars,
          );
          final res = await _fetchWithRetry(msgs, config: reduceConfig);
          if (_cancelled || generation != _runGeneration) return;
          if (res.drained && res.reply.trim().isNotEmpty) {
            recordUsage(res.usage, msgs.last.content.length, res.reply.length);
            try {
              worldbuilding.addAll(SourceGraphReducer.parsePass3World(res.reply));
              await db.saveScanReduce(
                pid,
                GraphReduceSeq.pass3World,
                res.reply.trim(),
              );
            } catch (_) {}
          }
        }(),
        () async {
          if (normalized.rawClues.isEmpty) return;
          final cached = savedReduces[GraphReduceSeq.pass4Clues];
          if (cached != null && cached.trim().isNotEmpty) {
            try {
              threads.addAll(SourceGraphReducer.parsePass4Clues(cached));
              return;
            } catch (_) {}
          }
          final msgs = SourceGraphReducer.pass4CluesPrompt(
            normalized,
            title: title,
            isContinuation: isContinuation,
            contextBudgetChars: provider.contextBudgetChars,
          );
          final res = await _fetchWithRetry(msgs, config: heavyReduceConfig);
          if (_cancelled || generation != _runGeneration) return;
          if (res.drained && res.reply.trim().isNotEmpty) {
            recordUsage(res.usage, msgs.last.content.length, res.reply.length);
            try {
              threads.addAll(SourceGraphReducer.parsePass4Clues(res.reply));
              await db.saveScanReduce(
                pid,
                GraphReduceSeq.pass4Clues,
                res.reply.trim(),
              );
            } catch (_) {}
          }
        }(),
      ]);
      if (_cancelled || generation != _runGeneration) return;

      // ---- 6. Pass 4B（时间线里程碑与主线，关联已对账伏笔标题） ----
      statusDetail = '步骤 5/5：归并剧情时间线里程碑与主线弧（已对账 ${threads.length} 条伏笔）…';
      notifyListeners();

      var timelineResult = const TimelinePassResult(
        timeline: [],
        activeArcs: [],
      );
      if (normalized.rawEvents.isNotEmpty) {
        final cached = savedReduces[GraphReduceSeq.pass4Timeline];
        var loaded = false;
        if (cached != null && cached.trim().isNotEmpty) {
          try {
            timelineResult = SourceGraphReducer.parsePass4Timeline(cached);
            loaded = true;
          } catch (_) {}
        }
        if (!loaded) {
          final msgs = SourceGraphReducer.pass4TimelinePrompt(
            normalized,
            title: title,
            reconciledThreads: threads,
            isContinuation: isContinuation,
            contextBudgetChars: provider.contextBudgetChars,
          );
          final res = await _fetchWithRetry(msgs, config: heavyReduceConfig);
          if (_cancelled || generation != _runGeneration) return;
          if (res.drained && res.reply.trim().isNotEmpty) {
            recordUsage(res.usage, msgs.last.content.length, res.reply.length);
            try {
              timelineResult = SourceGraphReducer.parsePass4Timeline(res.reply);
              await db.saveScanReduce(
                pid,
                GraphReduceSeq.pass4Timeline,
                res.reply.trim(),
              );
            } catch (_) {}
          }
        }
      }

      // ---- 7. 组装统一档案并补全声音样本与双向关系兼容字段 ----
      final baseCharacters = <CanonCharacter>[];
      for (final sk in targets) {
        final base =
            profiledMap[sk.name] ??
            CanonCharacter(
              name: sk.name,
              aliases: sk.aliases,
              role: sk.role,
              camp: sk.camp,
              stance: sk.stance,
              importance: sk.importance,
            );
        final mergedAliases = {...base.aliases, ...sk.aliases}..remove(base.name);
        baseCharacters.add(
          base.copyWith(
            aliases: mergedAliases.toList(),
            role: base.role ?? sk.role,
            camp: base.camp ?? sk.camp,
            stance: base.stance ?? sk.stance,
            importance: sk.importance,
          ),
        );
      }
      final finalCharacters = _enrichCharacters(
        baseCharacters,
        indexer: upfrontIndexer,
        relations: relations,
      );

      // 始终保存原文到 BlobStore，便于写作助手 zm-search 随时按需查书
      await blobs.saveText(BlobKinds.continuation, pid, sourceText);

      final profile = SourceNovelProfileData(
        id: pid,
        title: title,
        camps: canon.camps,
        characters: finalCharacters,
        relations: relations,
        timeline: timelineResult.timeline,
        worldbuilding: worldbuilding,
        openThreads: threads,
        activeArcs: timelineResult.activeArcs,
        continuationFromChapter: isContinuation ? analyzedChapters : null,
        hasSourceText: true,
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
      statusDetail =
          '建图完成！${finalCharacters.length} 角色 · ${relations.length} 关系 · ${threads.length} 伏笔 · ${timelineResult.timeline.length} 时间线';
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
      await BackgroundKeepAliveService.instance.release();
    }
  }

  /// 长窗口直读快车道（≤ 80,000 字）：在主力模型一次结构化请求内直接产出完整原作/续写档案。
  Future<({SourceNovelProfileData? profile, String? failureReason})>
  _tryDirectReadProfile({
    required String sourceText,
    required String title,
    required ScanMode mode,
    required bool isContinuation,
    required String pid,
    required NovelLocalIndexer indexer,
    required int generation,
  }) async {
    final analyzedChapters = StyleChapterSampler.split(
      sourceText,
    ).length.clamp(1, 99999);
    final cleanedBody = indexer.chapters.isNotEmpty
        ? indexer.chapters
              .map((c) => '〔第${c.chapterNo}章 ${c.title}〕\n${c.body}')
              .join('\n\n')
        : sourceText.trim();
    if (cleanedBody.isEmpty) {
      return (profile: null, failureReason: '正文为空');
    }

    final sysPrompt = '''你是长篇小说档案与续写架构师。请直接阅读提供的全书完整正文与本地实体检索线索，一次性输出准确、结构化、闭合的全书档案 JSON（只输出合法 JSON 对象，不要代码块或说明）。
Schema:
{
  "title": "$title",
  "author": "作者（未知省略）",
  "camps": [{"name": "阵营/势力名", "stance": "主角方|对立|中立|摇摆", "brief": "一句话说明"}],
  "characters": [{
    "name": "权威主名",
    "aliases": ["别名/形态"],
    "oneLine": "一句话定位（注明性别/种族/身份，≤35字）",
    "role": "主角|核心配角|反派|配角",
    "camp": "阵营",
    "stance": "主角方|对立|中立|摇摆",
    "importance": "major|normal|minor",
    "appearance": "外貌特征（≤45字）",
    "personality": "性格与行为倾向（≤60字）",
    "abilities": "核心能力/道具（≤60字）",
    ${isContinuation ? '"currentState": "截至第$analyzedChapters章末尾的精确现状（位置、形态、伤势、心境，≤80字）",' : '"currentState": "全书后期的最新状态（≤60字）",'}
    "voiceSamples": ["真实原话口癖"],
    "relationships": [{"target": "对象主名", "relation": "关系描述"}],
    "arc": [{"phase": "阶段名", "state": "该阶段关键变化"}]
  }],
  "relations": [{
    "from": "角色A",
    "to": "角色B",
    "relationType": "亲友|盟友|爱恋|敌对|从属|竞争|未知",
    "label": "简短标签（2-8字）",
    "description": "关系全貌与核心张力（≤70字）",
    "strength": 4,
    "line": "明线|暗线",
    "firstChapter": 1,
    "lastChapter": $analyzedChapters,
    "evolution": [{"chapterLabel": "第1章", "state": "关系演变"}],
    "evidence": "关键原文依据"
  }],
  "timeline": [{
    "id": "tl_1",
    "phase": "剧情阶段/篇名",
    "chapterRange": "第1-3章",
    "chapterStart": 1,
    "chapterEnd": 3,
    "inWorldTime": "书内时间锚点（可选）",
    "summary": "该节点核心事件（≤80字）",
    "participants": ["权威角色名"],
    "linkedClueTitles": ["关联伏笔标题"],
    "importance": "major|normal|minor"
  }],
  "worldbuilding": [{
    "category": "力量体系|地理|势力|规则|器物",
    "name": "规范词条名",
    "content": "设定说明（≤100字）",
    "keywords": ["触发词1", "别称2"]
  }],
  "openThreads": [{
    "title": "伏笔简明标题",
    "detail": "已埋线索与悬念（≤80字）",
    "status": "open|partial|resolved",
    "plantedChapter": 1,
    "resolvedChapter": null,
    "involvedCharacters": ["权威角色名"],
    "relatedEventSummary": "关联关键事件",
    "payoffDetail": "若已部分或全部回收，写明揭晓内容"
  }],
  "activeArcs": ["截至第$analyzedChapters章仍在推进中的核心主线/冲突弧"]
}
规则：
1. 同一角色的绰号、变身或不同称呼合并到 aliases 中，所有字段统一使用权威主名；
2. ${isContinuation ? '精准还原截至第$analyzedChapters章末尾的人物现状、未回收(open/partial)伏笔与进行中主线；' : '完整梳理核心角色、关系明暗线、世界观规则、关键里程碑时间线与核心伏笔闭环；'}
3. 严禁编造原文未给出的设定，确保输出完整闭合的单个 JSON 对象。''';

    final userBuf = StringBuffer()
      ..writeln('《$title》（共 $analyzedChapters 章，约 ${sourceText.length} 字）');
    if (indexer.headerSynopsis != null && indexer.headerSynopsis!.isNotEmpty) {
      userBuf
        ..writeln('\n【原书简介】')
        ..writeln(indexer.headerSynopsis);
    }
    if (indexer.topEntities.isNotEmpty) {
      userBuf
        ..writeln('\n【本地先验高频实体提示】')
        ..writeln(
          indexer.topEntities
              .take(25)
              .map(
                (e) =>
                    '${e.name}(${e.mentions}次/第${e.firstChapter}-${e.lastChapter}章)',
              )
              .join('、'),
        );
    }
    userBuf
      ..writeln('\n【完整清洗正文】')
      ..write(cleanedBody);

    const directConfig = GenerationConfig(
      temperature: 0.2,
      maxTokens: 16384,
      jsonMode: true,
      reasoningEffort: ReasoningEffort.medium,
      enablePromptCacheControl: true,
    );

    final res = await _fetch(
      [
        LLMMessage(role: LLMRole.system, content: sysPrompt, cacheControl: true),
        LLMMessage(role: LLMRole.user, content: userBuf.toString()),
      ],
      config: directConfig,
      targetClient: client,
    );
    if (_cancelled || generation != _runGeneration) {
      return (profile: null, failureReason: '已取消');
    }

    if (res.usage != null) {
      tokensIn += res.usage!.promptTokens;
      tokensOut += res.usage!.completionTokens;
      cachedTokens += res.usage!.cachedTokens;
    } else if (res.drained) {
      tokensIn += (sysPrompt.length + userBuf.length) ~/ 2;
      tokensOut += res.reply.length ~/ 2;
    }

    if (!res.drained || res.reply.trim().isEmpty) {
      return (profile: null, failureReason: res.errorText ?? '直读请求失败');
    }

    try {
      final parsed = isContinuation
          ? SourceReducer.parseContinuation(
              res.reply,
              fallbackTitle: title,
              upToChapter: analyzedChapters,
              profileId: pid,
            )
          : SourceReducer.parseFinal(
              res.reply,
              fallbackTitle: title,
              profileId: pid,
            );
      final rawMap = LLMJSONParser.decodeTopLevelObject(res.reply, (m) => m);
      final camps = (rawMap?['camps'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonCamp.fromJson(e.cast<String, dynamic>()))
          .where((c) => c.name.isNotEmpty)
          .toList();
      final relations =
          ((rawMap?['relations'] ?? rawMap?['edges']) as List? ?? const [])
              .whereType<Map>()
              .map((e) => CanonRelationEdge.fromJson(e.cast<String, dynamic>()))
              .where(
                (r) => r.from.isNotEmpty && r.to.isNotEmpty && r.from != r.to,
              )
              .toList();

      if (parsed.characters.isEmpty ||
          (parsed.timeline.isEmpty &&
              parsed.worldbuilding.isEmpty &&
              relations.isEmpty)) {
        return (profile: null, failureReason: '直读输出缺少时间线与世界观结构');
      }

      final enrichedChars = _enrichCharacters(
        parsed.characters,
        indexer: indexer,
        relations: relations,
      );

      final profile = parsed.copyWith(
        camps: camps,
        characters: enrichedChars,
        relations: relations,
        hasSourceText: true,
        meta: ScanMeta(
          totalChapters: analyzedChapters,
          totalChars: sourceText.length,
          scanMode: mode,
        ),
        scanState: ScanState(
          stage: ScanStage.done,
          totalChunks: 1,
          doneChunks: 1,
          tokensIn: tokensIn,
          tokensOut: tokensOut,
          startedAt: DateTime.now(),
        ),
      );
      return (profile: profile, failureReason: null);
    } catch (e) {
      return (profile: null, failureReason: '直读 JSON 解析回退：$e');
    }
  }

  static List<CanonCharacter> _enrichCharacters(
    List<CanonCharacter> characters, {
    required NovelLocalIndexer indexer,
    required List<CanonRelationEdge> relations,
  }) {
    final localVoiceMap = {
      for (final e in indexer.topEntities)
        if (e.voiceSamples.isNotEmpty) e.name: e.voiceSamples,
    };
    final relsByChar = <String, List<CanonRelationship>>{};
    for (final edge in relations) {
      relsByChar
          .putIfAbsent(edge.from, () => [])
          .add(CanonRelationship(target: edge.to, relation: edge.label));
      relsByChar
          .putIfAbsent(edge.to, () => [])
          .add(CanonRelationship(target: edge.from, relation: edge.label));
    }
    return characters.map((c) {
      final samples = c.voiceSamples.isNotEmpty
          ? c.voiceSamples
          : (localVoiceMap[c.name] ?? const <String>[]);
      final relList = c.relationships.isNotEmpty
          ? c.relationships
          : (relsByChar[c.name] ?? const <CanonRelationship>[]);
      return c.copyWith(voiceSamples: samples, relationships: relList);
    }).toList();
  }

  Future<CanonPassResult> _runPass1Canon({
    required String pid,
    required String title,
    required AggregatedSourceGraph aggregated,
    required GenerationConfig config,
    required void Function(UsageReport?, int, int) recordUsage,
  }) async {
    final msgs = SourceGraphReducer.pass1CanonPrompt(aggregated, title: title);
    final res = await _fetchWithRetry(msgs, config: config);
    if (!res.drained) {
      throw Exception(res.errorText ?? 'Pass 1 实体消歧请求失败');
    }
    recordUsage(res.usage, msgs.last.content.length, res.reply.length);
    final canon = SourceGraphReducer.parsePass1Canon(res.reply);
    await db.saveScanReduce(pid, GraphReduceSeq.pass1Canon, res.reply.trim());
    return canon;
  }

  /// 极速证据建档（Search-First + KV Prefix Cache）：
  /// Step 1: Isolate 零 Token 索引全书（实体热力图 + 共现 + 声音样本 + 净化正文）
  /// Step 2: Round 1 定位待查证关键词/历史谜团（填充静态前缀缓存）
  /// Step 3: 本地毫秒级 grepSpan 抓取全书首现+末现原文证据
  /// Step 4: Round 2 复用同一静态前缀（命中 80%+ KV Cache）直出零幻觉结构化档案！
  Future<void> _runEvidenceScan({
    required String sourceText,
    required String title,
    required bool isContinuation,
    required String pid,
    required int generation,
  }) async {
    phase = ScanPhase.mapping;
    totalChunks = 3;
    doneChunks = 0;
    statusDetail = '步骤 1/3：本地零耗时索引全书实体、共现关系与角色口癖…';
    notifyListeners();

    final indexer = await _indexInIsolate(sourceText);
    if (_cancelled || generation != _runGeneration) return;
    if (indexer.chapters.isEmpty) {
      _fail('原文内容为空，无法建档');
      return;
    }

    final totalChapters = indexer.chapters.length;
    final staticPrefix = indexer.buildEvidenceStaticPrefix(
      title: title,
      isContinuation: isContinuation,
    );

    doneChunks = 1;
    statusDetail =
        '步骤 2/3：全书 ${indexer.chapters.length} 章已索引（发现 ${indexer.topEntities.length} 个核心实体），AI 正在定位需查证的伏笔与人物线索…';
    notifyListeners();

    const round1Config = GenerationConfig(
      temperature: 0.2,
      maxTokens: 12288,
      jsonMode: true,
      reasoningEffort: ReasoningEffort.low,
      enablePromptCacheControl: true,
    );
    const round2Config = GenerationConfig(
      temperature: 0.25,
      maxTokens: 16384,
      jsonMode: true,
      reasoningEffort: ReasoningEffort.medium,
      enablePromptCacheControl: true,
    );

    final round1User =
        '请快速审阅以上全书实体热力图、目录、开篇与近期正文，列出你为了彻底搞清「人物真实身份/形态/关系」「核心道具/势力规则」「开篇及中期尚未回收的关键伏笔」而需要在全书 $totalChapters 章中精确检索的 6~10 个关键词。'
        '只输出合法 JSON 对象，不要代码块或多余文字：\n'
        '{"queries": ["关键词1", "关键词2"], "focus": "一句话说明当前主线与重点核查方向"}';

    final res1 = await _fetchWithRetry(
      [
        LLMMessage(role: LLMRole.system, content: staticPrefix, cacheControl: true),
        LLMMessage(role: LLMRole.user, content: round1User),
      ],
      config: round1Config,
    );
    if (_cancelled || generation != _runGeneration) return;
    if (!res1.drained) {
      _fail(res1.errorText ?? '线索定位请求失败');
      return;
    }

    if (res1.usage != null) {
      tokensIn += res1.usage!.promptTokens;
      tokensOut += res1.usage!.completionTokens;
      cachedTokens += res1.usage!.cachedTokens;
    } else {
      tokensIn += (staticPrefix.length + round1User.length) ~/ 2;
      tokensOut += res1.reply.length ~/ 2;
    }

    // 解析 AI 提出的检索词，并兜底补入 Top 高频实体
    final queries = <String>[];
    final parsed1 = LLMJSONParser.decodeObject(res1.reply, (m) => m);
    if (parsed1 != null && parsed1['queries'] is List) {
      for (final q in parsed1['queries'] as List) {
        final s = q.toString().trim();
        if (s.isNotEmpty && !queries.contains(s)) queries.add(s);
      }
    }
    for (final e in indexer.topEntities.take(8)) {
      if (queries.length >= 10) break;
      if (!queries.contains(e.name)) queries.add(e.name);
    }

    // 本地零耗时 grep 全书原文证据
    final evidenceBuf = StringBuffer('以下是本地检索引擎在全书 $totalChapters 章中为你查回的原文证据：\n');
    var evidenceUsed = 0;
    final evidenceBudget = provider.contextBudgetChars >= 80000 ? 30000 : 18000;
    for (final q in queries.take(10)) {
      final hits = indexer.grepSpan(q, earliestHits: 1, latestHits: 2);
      if (hits.isEmpty) continue;
      final block = '【检索：$q】\n${hits.map((h) => h.format()).join('\n')}\n';
      if (evidenceUsed + block.length > evidenceBudget) break;
      evidenceBuf.writeln(block);
      evidenceUsed += block.length;
    }

    phase = ScanPhase.reducing;
    doneChunks = 2;
    statusDetail = '步骤 3/3：已回填 ${queries.length} 组全书原文证据，复用前缀缓存生成结构化原作档案…';
    notifyListeners();

    final schemaInstruction = isContinuation
        ? '''请结合【System 中的全书基线】与上面【查回的原文证据】，输出完整、精炼、闭合的【续写档案】JSON（只输出合法 JSON 对象，不要代码块或说明）：
{
  "title": "$title",
  "author": "作者（未知省略）",
  "characters": [{
    "name": "主名",
    "aliases": ["别名/形态名"],
    "oneLine": "一句话定位（注明真实性别/种族/形态）",
    "role": "主角/反派/配角",
    "appearance": "外貌特征（≤40字）",
    "personality": "性格与行为倾向（≤50字）",
    "abilities": "能力与武器/道具（≤50字）",
    "currentState": "截至第$totalChapters章末尾的精确现状（位置、形态、伤势、心境，≤70字）",
    "voiceSamples": ["原话口癖1", "原话口癖2"],
    "relationships": [{"target": "对象", "relation": "当前关系"}],
    "arc": [{"phase": "阶段", "state": "状态"}]
  }],
  "timeline": [{"phase": "阶段名", "chapterRange": "约第X-Y章", "summary": "核心事件（≤70字）", "participants": ["角色"], "importance": "major|normal|minor"}],
  "worldbuilding": [{"category": "力量体系|地理|势力|规则|器物", "name": "词条", "content": "说明（≤80字）"}],
  "openThreads": [{"title": "未回收伏笔标题", "detail": "已埋线索与悬念（≤70字）", "plantedChapter": 1}],
  "activeArcs": ["截至第$totalChapters章正在推进中的剧情弧线"]
}
数量与防截断硬约束：
1. characters 精选 8~14 名核心角色（每名角色 arc 至多 2~3 条），严禁违背查回的原文证据或混淆真实形态/性别；
2. timeline 精选 8~14 个关键剧情里程碑；worldbuilding 精选 8~14 条核心规则/势力/道具；openThreads 精选 5~10 条最重要未回收伏笔；activeArcs 3~5 条；
3. 请保持字段凝练紧凑，务必输出完整闭合的单个 JSON 对象，避免超长被截断。'''
        : '''请结合【System 中的全书基线】与上面【查回的原文证据】，输出完整、精炼、闭合的【原作同人档案】JSON（只输出合法 JSON 对象，不要代码块或说明）：
{
  "title": "$title",
  "author": "作者（未知省略）",
  "characters": [{
    "name": "主名",
    "aliases": ["别名"],
    "oneLine": "一句话定位（注明性别/形态/阵营）",
    "role": "主角/反派/配角",
    "appearance": "外貌（≤40字）",
    "personality": "性格（≤50字）",
    "abilities": "能力（≤50字）",
    "voiceSamples": ["原话口癖1", "原话口癖2"],
    "relationships": [{"target": "对象", "relation": "关系"}],
    "arc": [{"phase": "阶段", "state": "状态"}]
  }],
  "timeline": [{"phase": "阶段名", "chapterRange": "约第X-Y章", "summary": "核心事件（≤70字）", "participants": ["角色"], "importance": "major|normal|minor"}],
  "worldbuilding": [{"category": "力量体系|地理|势力|规则|器物", "name": "词条", "content": "说明（≤80字）"}]
}
数量与防截断硬约束：characters 8~14 人、timeline 8~14 项、worldbuilding 8~14 项，字段精炼，确保完整闭合单个 JSON 对象。''';

    // Round 2 严格保持 system -> user(R1) -> assistant(R1) -> user(R2) 轮次，最大化命中 KV Prefix Cache！
    final round2Messages = [
      LLMMessage(role: LLMRole.system, content: staticPrefix, cacheControl: true),
      LLMMessage(role: LLMRole.user, content: round1User),
      LLMMessage(role: LLMRole.assistant, content: res1.reply),
      LLMMessage(
        role: LLMRole.user,
        content: '${evidenceBuf.toString()}\n$schemaInstruction',
      ),
    ];

    SourceNovelProfileData? parsedProfile;
    String? lastParseError;

    for (var attempt = 0; attempt < 2; attempt++) {
      final msgs = attempt == 0
          ? round2Messages
          : [
              ...round2Messages.sublist(0, 3),
              LLMMessage(
                role: LLMRole.user,
                content:
                    '${evidenceBuf.toString()}\n$schemaInstruction\n\n'
                    '【重要】上次输出因过长被截断或格式不合法，本次请进一步精简每条字数（仅输出 Top 8 核心人物、Top 8 世界观、Top 8 时间线、Top 6 未回收伏笔），确保 JSON 100% 完整闭合！',
              ),
            ];
      if (attempt == 1) {
        statusDetail = '步骤 3/3：上次输出疑似截断，正在自动切换紧凑模式重试一次…';
        notifyListeners();
      }
      final res2 = await _fetchWithRetry(msgs, config: round2Config);
      if (_cancelled || generation != _runGeneration) return;
      if (!res2.drained) {
        _fail(res2.errorText ?? '档案生成请求失败');
        return;
      }
      if (res2.usage != null) {
        tokensIn += res2.usage!.promptTokens;
        tokensOut += res2.usage!.completionTokens;
        cachedTokens += res2.usage!.cachedTokens;
      } else {
        tokensOut += res2.reply.length ~/ 2;
      }

      try {
        parsedProfile = isContinuation
            ? SourceReducer.parseContinuation(
                res2.reply,
                fallbackTitle: title,
                upToChapter: totalChapters,
                profileId: pid,
              )
            : SourceReducer.parseFinal(
                res2.reply,
                fallbackTitle: title,
                profileId: pid,
              );
        break;
      } catch (e) {
        lastParseError = e.toString();
      }
    }

    if (parsedProfile == null) {
      _fail(
        '证据建档解析失败（${lastParseError ?? "未输出有效人物/设定 JSON"}），请点击「继续分析」重试或更换模型',
      );
      return;
    }
    var profile = parsedProfile;

    // 把本地检出的真实原话声音样本补充合并到对应角色（若模型漏填）
    final enrichedChars = _enrichCharacters(
      profile.characters,
      indexer: indexer,
      relations: const [],
    );

    // 保存原文到 BlobStore（同人/续写均落盘，支持后续写作助手 zm-search 实时查书）
    await blobs.saveText(BlobKinds.continuation, profile.id, sourceText);

    profile = profile.copyWith(
      characters: enrichedChars,
      hasSourceText: true,
      meta: ScanMeta(
        totalChapters: totalChapters,
        totalChars: sourceText.length,
        scanMode: ScanMode.evidence,
      ),
      scanState: ScanState(
        stage: ScanStage.done,
        totalChunks: 3,
        doneChunks: 3,
        tokensIn: tokensIn,
        tokensOut: tokensOut,
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

    doneChunks = 3;
    resultProfile = profile;
    phase = ScanPhase.done;
    statusDetail = cachedTokens > 0
        ? '极速证据建档完成（缓存命中 ${(cachedTokens / 1000).toStringAsFixed(1)}k tokens）'
        : '极速证据建档完成！';
    estimatedRemainingSeconds = 0;
    notifyListeners();
  }

  void _fail(String reason) {
    errorMessage = '分析中断：$reason。检查网络或模型配置后可点「继续分析」续跑。';
    phase = ScanPhase.failed;
    notifyListeners();
  }

  void _updateEstimate({int concurrency = 1}) {
    if (_mapTimes.isEmpty) return;
    final avg = _mapTimes.reduce((a, b) => a + b) / _mapTimes.length;
    final remaining = (totalChunks - doneChunks).clamp(0, totalChunks);
    final divisor = concurrency.clamp(1, 12);
    estimatedRemainingSeconds = (avg * remaining / divisor).round();
  }

  Future<_FetchResult> _fetch(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    LLMClient? targetClient,
  }) async {
    _activeStreams += 1;
    if (_activeStreams == 1) {
      progress.begin();
    }
    final buf = StringBuffer();
    UsageReport? usage;
    final activeClient = targetClient ?? client;
    try {
      await for (final ev in activeClient.streamChat(
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
      return _FetchResult(reply: buf.toString(), drained: true, usage: usage);
    } catch (e) {
      return _FetchResult(
        reply: buf.toString(),
        drained: false,
        errorText: e.toString(),
      );
    } finally {
      _activeStreams = (_activeStreams - 1).clamp(0, 999);
      if (_activeStreams == 0) {
        progress.finish();
      }
    }
  }

  Future<({MicroSummary? summary, String? error, UsageReport? usage})>
  _fetchSingleParsed(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    LLMClient? targetClient,
    int attempts = 3,
  }) async {
    String? lastError;
    for (var i = 0; i < attempts; i++) {
      if (_cancelled) return (summary: null, error: null, usage: null);
      final res = await _fetch(
        messages,
        config: config,
        targetClient: targetClient,
      );
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
        if (isRateLimitError(lastError)) {
          return (summary: null, error: lastError, usage: null);
        }
      }
      if (i + 1 < attempts) await _backoff(i);
    }
    return (summary: null, error: lastError, usage: null);
  }

  Future<
    ({
      List<({int chapterNo, MicroSummary summary})>? entries,
      String? error,
      UsageReport? usage,
    })
  >
  _fetchBatchEntriesParsed(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    LLMClient? targetClient,
    int attempts = 3,
  }) async {
    String? lastError;
    for (var i = 0; i < attempts; i++) {
      if (_cancelled) return (entries: null, error: null, usage: null);
      final res = await _fetch(
        messages,
        config: config,
        targetClient: targetClient,
      );
      if (res.drained) {
        try {
          return (
            entries: SourceBatchHelper.parseBatchEntries(res.reply),
            error: null,
            usage: res.usage,
          );
        } catch (_) {
          lastError = '批量返回无法解析为逐块微摘要';
        }
      } else {
        lastError = res.errorText ?? '网络错误';
        if (isRateLimitError(lastError)) {
          return (entries: null, error: lastError, usage: null);
        }
      }
      if (i + 1 < attempts) await _backoff(i);
    }
    return (entries: null, error: lastError, usage: null);
  }

  Future<_FetchResult> _fetchWithRetry(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    LLMClient? targetClient,
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
      final res = await _fetch(
        messages,
        config: config,
        targetClient: targetClient,
      );
      if (res.drained) return res;
      last = res;
      if (i + 1 < attempts) await _backoff(i);
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

  static Future<List<SourceScanChunk>> _chunkInIsolate(
    String sourceText,
    ScanMode mode, {
    int? maxChunkChars,
  }) => Isolate.run(
    () => SourceScanChunker.chunks(
      sourceText,
      mode: mode,
      maxChunkChars: maxChunkChars,
    ),
  );

  static Future<NovelLocalIndexer> _indexInIsolate(String sourceText) =>
      Isolate.run(() => NovelLocalIndexer.fromRawText(sourceText));

  @override
  void dispose() {
    _cancelled = true;
    _activeCancel?.cancel('disposed');
    progress.dispose();
    super.dispose();
  }
}
