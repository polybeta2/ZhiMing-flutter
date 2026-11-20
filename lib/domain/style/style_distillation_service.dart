import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';

import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/prompts/prompt_templates.dart';
import '../models/style_models.dart';
import '../writing/prose_checker.dart';
import 'style_card_renderer.dart';
import 'style_chapter_sampler.dart';
import 'style_metrics.dart';

sealed class StyleDistillEvent {
  const StyleDistillEvent();
}

final class StyleDistillStage extends StyleDistillEvent {
  const StyleDistillStage(this.label);
  final String label;
}

final class StyleDistillStreamDelta extends StyleDistillEvent {
  const StyleDistillStreamDelta(this.event);
  final StreamEvent event;
}

final class StyleDistillAnalysisReady extends StyleDistillEvent {
  const StyleDistillAnalysisReady(this.rawAnalysisJson);
  final String rawAnalysisJson;
}

final class StyleDistillCompleted extends StyleDistillEvent {
  const StyleDistillCompleted(this.profile);
  final StyleProfileData profile;
}

/// 文风蒸馏四阶段流水线（S1 计量抽样 → S2 自适应机制分析 → S3 风格卡汇总 → S4 8-gram 查重回炉）
class StyleDistillationService {
  const StyleDistillationService({
    required this.client,
    required this.library,
    this.providerExtra,
    this.temperature = 0.4,
    this.maxTokens = 12288,
  });

  final LLMClient client;
  final PromptLibraryState library;
  final String? providerExtra;
  final double temperature;
  final int maxTokens;

  Stream<StyleDistillEvent> distill({
    required String sourceText,
    required String sourceNote,
    String? cachedAnalysisRaw,
    StyleProfileData? augmentTarget,
    CancelToken? cancelToken,
    int Function(int maxExclusive)? pickRandom,
  }) async* {
    // S1: 后台 Isolate 执行切章与本地计量（百万字不卡主线程）
    yield const StyleDistillStage('S1/4：切章抽样与本地文风计量…');
    final s1 = await Isolate.run(() {
      final metrics = StyleMetrics.compute(sourceText);
      final chapters = StyleChapterSampler.split(sourceText);
      return (metrics: metrics, chapters: chapters);
    });

    final metricsText = s1.metrics.toPromptText();

    // S2: 机制分析（支持断点跳过 + 自适应补样最多 3 轮）
    String analysisRaw;
    Map<String, dynamic>? analysisJson;

    if (cachedAnalysisRaw != null && cachedAnalysisRaw.trim().isNotEmpty) {
      final parsed = LLMJSONParser.decodeAny(cachedAnalysisRaw);
      if (parsed is Map<String, dynamic>) {
        analysisRaw = cachedAnalysisRaw;
        analysisJson = parsed;
        yield const StyleDistillStage('S2/4：命中断点缓存，跳过机制分析…');
      } else {
        analysisRaw = '';
      }
    } else {
      analysisRaw = '';
    }

    if (analysisJson == null) {
      var selectedIdx = StyleChapterSampler.selectInitial(
        s1.chapters.length,
        pickRandom: pickRandom,
      );
      for (var round = 1; round <= 3; round++) {
        yield StyleDistillStage(
          round == 1
              ? 'S2/4：分析七层语言机制…'
              : 'S2/4：样本不足，自动补样第 $round 轮（共 ${selectedIdx.length} 章）…',
        );
        final sampleBlock = _renderSample(
          sourceText,
          s1.chapters,
          selectedIdx,
        );
        final msgs = PromptTemplates.applyingExtra(providerExtra, [
          LLMMessage(
            role: LLMRole.system,
            content: library.resolvedText(PromptID.styleDistillAnalyze),
          ),
          LLMMessage(
            role: LLMRole.user,
            content: '【计量数据】\n$metricsText\n\n【样本文本】\n$sampleBlock',
          ),
        ]);
        final buf = StringBuffer();
        await for (final ev in client.streamChat(
          msgs,
          config: GenerationConfig(
            temperature: temperature,
            maxTokens: maxTokens,
          ),
          cancelToken: cancelToken,
        )) {
          yield StyleDistillStreamDelta(ev);
          if (ev is ContentDelta) buf.write(ev.text);
        }
        analysisRaw = buf.toString();
        final decoded = LLMJSONParser.decodeAny(analysisRaw);
        if (decoded is! Map<String, dynamic>) {
          throw const LLMException('文风机制分析 JSON 解析失败，请重试');
        }
        final enough = decoded['enough'];
        if (enough == false &&
            round < 3 &&
            s1.chapters.length > selectedIdx.length &&
            selectedIdx.length < StyleChapterSampler.maxChapters) {
          selectedIdx = StyleChapterSampler.expand(
            selectedIdx,
            s1.chapters.length,
            pickRandom: pickRandom,
          );
          continue;
        }
        analysisJson = decoded;
        break;
      }
      if (analysisJson == null) {
        throw const LLMException('机制分析未能完成，请重试');
      }
      if (augmentTarget == null) {
        yield StyleDistillAnalysisReady(jsonEncode(analysisJson));
      }
    }

    // S3: 汇总可执行风格卡
    yield const StyleDistillStage('S3/4：汇总可执行风格卡与改写示范…');
    final cardMsgs = PromptTemplates.applyingExtra(providerExtra, [
      LLMMessage(
        role: LLMRole.system,
        content: library.resolvedText(PromptID.styleDistillCard),
      ),
      LLMMessage(
        role: LLMRole.user,
        content: '【机制分析】\n${jsonEncode(analysisJson)}',
      ),
    ]);
    final cardBuf = StringBuffer();
    await for (final ev in client.streamChat(
      cardMsgs,
      config: GenerationConfig(temperature: temperature, maxTokens: maxTokens),
      cancelToken: cancelToken,
    )) {
      yield StyleDistillStreamDelta(ev);
      if (ev is ContentDelta) cardBuf.write(ev.text);
    }
    final cardDecoded = LLMJSONParser.decodeAny(cardBuf.toString());
    if (cardDecoded is! Map<String, dynamic>) {
      throw const LLMException('风格卡汇总 JSON 解析失败（S2 机制分析已缓存，重进可秒续）');
    }

    final fresh = _assembleProfile(
      analysis: analysisJson,
      card: cardDecoded,
      sourceNote: sourceNote,
      metrics: s1.metrics,
    );

    // S4: 后台构建 8-gram 复用索引 + 查重回炉修正
    yield const StyleDistillStage('S4/4：8-gram 原创性查重与示范校验…');
    final index = await Isolate.run(
      () => StyleMetrics.ngramIndex(sourceText, n: 8),
    );
    final violatedIndices = <int>[];
    for (var i = 0; i < fresh.examples.length; i++) {
      if (index.hasViolation(fresh.examples[i].styled)) {
        violatedIndices.add(i);
      }
    }

    if (violatedIndices.isNotEmpty) {
      yield StyleDistillStage(
        'S4/4：检测到 ${violatedIndices.length} 条示范与原文重合，正在重写…',
      );
      final listBuf = StringBuffer();
      for (final idx in violatedIndices) {
        final ex = fresh.examples[idx];
        listBuf.writeln(
          '- index=$idx | plain=${ex.plain} | styled=${ex.styled} | principle=${ex.principle}',
        );
      }
      final fixMsgs = PromptTemplates.applyingExtra(providerExtra, [
        LLMMessage(
          role: LLMRole.system,
          content: library.resolvedText(PromptID.styleDistillFix),
        ),
        LLMMessage(
          role: LLMRole.user,
          content: '【违规示范】\n${listBuf.toString()}',
        ),
      ]);
      final fixBuf = StringBuffer();
      await for (final ev in client.streamChat(
        fixMsgs,
        config: const GenerationConfig(temperature: 0.5, maxTokens: 12288),
        cancelToken: cancelToken,
      )) {
        yield StyleDistillStreamDelta(ev);
        if (ev is ContentDelta) fixBuf.write(ev.text);
      }
      final fixed = LLMJSONParser.decodeList<Map<String, dynamic>>(
        fixBuf.toString(),
        (e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
      );
      final toDrop = <int>{};
      for (final idx in violatedIndices) {
        final hit = fixed
            ?.where((m) => (m['index'] as num?)?.toInt() == idx)
            .firstOrNull;
        final rewritten = hit?['styled']?.toString().trim() ?? '';
        if (rewritten.isNotEmpty && !index.hasViolation(rewritten)) {
          fresh.examples[idx].styled = rewritten;
          final p = hit?['principle']?.toString().trim() ?? '';
          if (p.isNotEmpty) fresh.examples[idx].principle = p;
        } else {
          toDrop.add(idx);
        }
      }
      if (toDrop.isNotEmpty) {
        final kept = <StyleExample>[];
        for (var i = 0; i < fresh.examples.length; i++) {
          if (!toDrop.contains(i)) kept.add(fresh.examples[i]);
        }
        fresh.examples = kept;
        fresh.confidence = 'low';
      }
    }

    // 若为追加样本增量蒸馏，则合并入目标档案深拷贝（原档案 ID 不变）
    if (augmentTarget != null) {
      final merged = augmentTarget.deepCopy();
      StyleProfileAugment.merge(
        existing: merged,
        fresh: fresh,
        reason: sourceNote.trim().isEmpty ? '追加样本增量蒸馏' : sourceNote.trim(),
      );
      yield StyleDistillCompleted(merged);
    } else {
      yield StyleDistillCompleted(fresh);
    }
  }

  static String _renderSample(
    String sourceText,
    List<SampleChapter> chapters,
    List<int> selectedIndices,
  ) {
    final buf = StringBuffer();
    if (chapters.isEmpty || selectedIndices.isEmpty) {
      for (final seg in StyleMetrics.sampleSegments(
        sourceText,
        PromptLimits.styleSampleCap,
      )) {
        buf.writeln('=== ${seg.label} ===\n${seg.text}\n');
      }
    } else {
      for (final i in selectedIndices) {
        final ch = chapters[i];
        final body = ch.body.length > PromptLimits.styleChapterCap
            ? ch.body.substring(0, PromptLimits.styleChapterCap)
            : ch.body;
        buf.writeln('=== ${ch.marker} ===\n$body\n');
        if (buf.length >= PromptLimits.styleSampleCap) break;
      }
    }
    final out = buf.toString();
    return out.length > PromptLimits.styleSampleCap
        ? out.substring(0, PromptLimits.styleSampleCap)
        : out;
  }

  static StyleProfileData _assembleProfile({
    required Map<String, dynamic> analysis,
    required Map<String, dynamic> card,
    required String sourceNote,
    required StyleMetricsSnapshot metrics,
  }) {
    final evidenceRaw = analysis['evidence'];
    final evidence = evidenceRaw is List
        ? evidenceRaw.map(StyleEvidence.fromJson).map((e) {
            final clipped = e.snippet.length > PromptLimits.styleEvidenceCap
                ? e.snippet.substring(0, PromptLimits.styleEvidenceCap)
                : e.snippet;
            return StyleEvidence(
              trait: e.trait,
              snippet: clipped,
              confidence: e.confidence,
            );
          }).toList()
        : <StyleEvidence>[];

    final examplesRaw = card['examples'];
    final examples = examplesRaw is List
        ? examplesRaw
              .map(StyleExample.fromJson)
              .where((e) => e.plain.isNotEmpty && e.styled.isNotEmpty)
              .toList()
        : <StyleExample>[];

    return StyleProfileData(
      name: (card['name']?.toString().trim().isNotEmpty ?? false)
          ? card['name'].toString().trim()
          : '新文风档案',
      sourceNote: sourceNote,
      sampleCharCount: metrics.sampleCharCount,
      confidence: metrics.sampleCharCount >= 8000 ? 'high' : 'medium',
      fingerprintSummary:
          (card['fingerprint_summary'] ?? card['fingerprintSummary'])
              ?.toString() ??
          '',
      tags: flexStringList(card['tags']),
      mustRules: flexStringList(card['must_rules'] ?? card['mustRules']),
      avoidRules: flexStringList(card['avoid_rules'] ?? card['avoidRules']),
      examples: examples,
      evidence: evidence,
      narrativeVoice: StyleNarrativeVoice.fromJson(analysis['narrative_voice']),
      sentenceSyntax: StyleSentenceSyntax.fromJson(analysis['sentence_syntax']),
      diction: StyleDiction.fromJson(analysis['diction']),
      sceneRhythm: StyleSceneRhythm.fromJson(analysis['scene_rhythm']),
      dialogue: StyleDialogue.fromJson(analysis['dialogue']),
      emotion: StyleEmotion.fromJson(analysis['emotion']),
      antiAI: StyleAntiAI.fromJson(analysis['anti_ai']),
      localMetrics: metrics,
    );
  }
}

/// 风格体检评估器（7 维打分 + 按体检报告一键改写全文）
class StyleEvaluator {
  const StyleEvaluator({
    required this.client,
    required this.library,
    this.providerExtra,
  });

  final LLMClient client;
  final PromptLibraryState library;
  final String? providerExtra;

  Future<StyleEvalResult> evaluate({
    required String draft,
    required String evalCard,
    required String localReport,
    void Function(StreamEvent)? onEvent,
    CancelToken? cancelToken,
  }) async {
    final user = StringBuffer()
      ..writeln('【体检基准】\n$evalCard')
      ..writeln(
        '\n【本地体检结果】\n${localReport.isEmpty ? '本地快检未发现明显问题。' : localReport}',
      )
      ..writeln('\n【待检草稿】\n$draft');

    final msgs = PromptTemplates.applyingExtra(providerExtra, [
      LLMMessage(
        role: LLMRole.system,
        content: library.resolvedText(PromptID.styleEval),
      ),
      LLMMessage(role: LLMRole.user, content: user.toString()),
    ]);

    final raw = StringBuffer();
    await for (final ev in client.streamChat(
      msgs,
      config: const GenerationConfig(temperature: 0.2, maxTokens: 12288),
      cancelToken: cancelToken,
    )) {
      onEvent?.call(ev);
      if (ev is ContentDelta) raw.write(ev.text);
    }

    final parsed = LLMJSONParser.decodeObject(
      raw.toString(),
      StyleEvalResult.fromJson,
    );
    if (parsed == null) {
      throw const LLMException('风格体检结果 JSON 解析失败，请重试');
    }
    return parsed;
  }

  /// 一键按体检清单改写全文（对应原版 v2.12.4 fb5d589）
  Future<String> applyFixes({
    required String draft,
    required StyleEvalResult evalResult,
    required String evalCard,
    required int maxTokens,
    void Function(StreamEvent)? onEvent,
    CancelToken? cancelToken,
  }) async {
    final issuesBuf = StringBuffer();
    if (evalResult.drifts.isNotEmpty) {
      issuesBuf.writeln('【风格漂移】\n${evalResult.drifts.map((e) => '- $e').join('\n')}');
    }
    if (evalResult.aiFlavor.isNotEmpty) {
      issuesBuf.writeln('【AI 腔问题】\n${evalResult.aiFlavor.map((e) => '- $e').join('\n')}');
    }
    if (evalResult.moves.isNotEmpty) {
      issuesBuf.writeln('【修改动作】\n${evalResult.moves.map((e) => '- $e').join('\n')}');
    }
    final local = ProseChecker.reportLines(draft);
    if (local.isNotEmpty) {
      issuesBuf.writeln('【本地快检】\n${local.join('\n')}');
    }

    var msgs = PromptTemplates.rewrite(
      library: library,
      mode: '去AI味',
      selection: draft,
      instruction:
          '请严格依据以下风格体检报告与基准逐项改写全文，保留剧情、人物、对话语义与设定不变，只输出修改后的完整正文：\n\n$issuesBuf',
      styleCard: evalCard,
    );
    msgs = PromptTemplates.applyingExtra(providerExtra, msgs);

    final out = StringBuffer();
    await for (final ev in client.streamChat(
      msgs,
      config: GenerationConfig(temperature: 0.45, maxTokens: maxTokens),
      cancelToken: cancelToken,
    )) {
      onEvent?.call(ev);
      if (ev is ContentDelta) out.write(ev.text);
    }
    return out.toString().trim();
  }
}
