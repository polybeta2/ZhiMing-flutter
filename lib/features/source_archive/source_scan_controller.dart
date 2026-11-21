import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/database/app_database.dart' hide ScanMeta;
import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/storage/blob_store.dart';
import '../../domain/models/source_profile_models.dart';
import '../../domain/source/novel_local_indexer.dart';
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
/// - 默认模式 [ScanMode.evidence]：零耗时本地索引 + 两轮证据驱动建档 + Static Prefix KV 缓存（80%+ 命中，~1-2 分钟完成）
/// - 深度模式 [ScanMode.fast] / [ScanMode.full]：滚动并发 Map + Reduce + Drift 断点续跑 + 推理模型安全预算（maxTokens >= 12288）
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
    statusDetail = null;
    resultProfile = null;
    cachedTokens = 0;
    _mapTimes.clear();
    final generation = ++_runGeneration;
    final pid = presetProfileId ?? const Uuid().v4();
    final clampedBatch = batchSize.clamp(1, 10);

    try {
      await WakelockPlus.enable();
    } catch (_) {}

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

      phase = ScanPhase.mapping;
      statusDetail = '正在后台切章与净化正文…';
      notifyListeners();

      // 原文大文本在 Isolate 中切块，避免 UI 掉帧（静态方法避免捕获 this/CancelToken）
      final chunks = await _chunkInIsolate(sourceText, mode);
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
      statusDetail = '正在逐批分析并滚动归并（${mode.label} · 每批 $clampedBatch 块）';
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

      // 推理模型安全预算：防止 reasoning_tokens 吃干 maxTokens 导致空正文（实测 P0 修复）
      const mapConfig = GenerationConfig(temperature: 0.2, maxTokens: 12288);
      const reduceConfig = GenerationConfig(temperature: 0.25, maxTokens: 12288);
      const finalConfig = GenerationConfig(temperature: 0.3, maxTokens: 16384);

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
            cachedTokens += res.usage!.cachedTokens;
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
          cachedTokens += usage.cachedTokens;
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
      statusDetail = '正在收尾滚动归并阶段摘要…';
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
      statusDetail = isContinuation
          ? '正在深度归并人物现状、未回收伏笔与剧情弧…'
          : '正在终归并全书人物、时间线与世界观…';
      notifyListeners();

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
        cachedTokens += finalRes.usage!.cachedTokens;
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

      // 始终保存原文到 BlobStore，便于写作助手 zm-search 随时按需查书
      await blobs.saveText(BlobKinds.continuation, profile.id, sourceText);

      profile = profile.copyWith(
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
      statusDetail = '分析完成！档案已入库';
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

    const round1Config = GenerationConfig(temperature: 0.2, maxTokens: 12288);
    const round2Config = GenerationConfig(temperature: 0.25, maxTokens: 16384);

    final round1User =
        '请快速审阅以上全书实体热力图、目录、开篇与近期正文，列出你为了彻底搞清「人物真实身份/形态/关系」「核心道具/势力规则」「开篇及中期尚未回收的关键伏笔」而需要在全书 $totalChapters 章中精确检索的 6~10 个关键词。'
        '只输出合法 JSON 对象，不要代码块或多余文字：\n'
        '{"queries": ["关键词1", "关键词2"], "focus": "一句话说明当前主线与重点核查方向"}';

    final res1 = await _fetchWithRetry(
      [
        LLMMessage(role: LLMRole.system, content: staticPrefix),
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
    const evidenceBudget = 11000;
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
      LLMMessage(role: LLMRole.system, content: staticPrefix),
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
    final localVoiceMap = {
      for (final e in indexer.topEntities)
        if (e.voiceSamples.isNotEmpty) e.name: e.voiceSamples,
    };
    final enrichedChars = profile.characters.map((c) {
      if (c.voiceSamples.isNotEmpty) return c;
      final localSamples = localVoiceMap[c.name];
      return localSamples == null
          ? c
          : c.copyWith(voiceSamples: localSamples);
    }).toList();

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

  static Future<List<SourceScanChunk>> _chunkInIsolate(
    String sourceText,
    ScanMode mode,
  ) => Isolate.run(() => SourceScanChunker.chunks(sourceText, mode: mode));

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
