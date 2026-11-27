import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_templates.dart';
import '../models/novel_domain.dart';
import 'context_builder.dart';
import 'lorebook_matcher.dart';

/// 5 个客观审稿维度标准键与中文名。
const List<String> kFactReviewDimensions = [
  'setting',
  'timeline',
  'continuity',
  'character',
  'logic',
];

String factDimensionLabel(String dim) => switch (dim) {
  'setting' => '设定一致性',
  'timeline' => '时间与空间',
  'continuity' => '衔接与物品',
  'character' => '人设与信息壁垒',
  'logic' => '因果与逻辑',
  _ => dim,
};

/// 单个审稿维度的核查结论。
class FactDimensionResult {
  const FactDimensionResult({
    required this.dimension,
    required this.pass,
    required this.note,
  });

  final String dimension;
  final bool pass;
  final String note;

  String get label => factDimensionLabel(dimension);
}

/// 单条可验证的事实/连续性矛盾。
class FactReviewIssue {
  const FactReviewIssue({
    required this.severity,
    required this.category,
    required this.location,
    required this.description,
    required this.evidence,
    required this.fixHint,
    required this.blocking,
  });

  final String severity; // 'critical' | 'warning'
  final String category; // setting | timeline | continuity | character | logic
  final String location;
  final String description;
  final String evidence;
  final String fixHint;
  final bool blocking;

  bool get isBlocking => blocking || severity == 'critical';
  String get categoryLabel => factDimensionLabel(category);

  static FactReviewIssue? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final desc = raw['description']?.toString().trim() ?? '';
    if (desc.isEmpty) return null;
    final rawSev = (raw['severity']?.toString().trim().toLowerCase() ?? 'warning');
    final severity = rawSev == 'critical' || rawSev == 'high' || rawSev == 'error'
        ? 'critical'
        : 'warning';
    final rawCat = (raw['category']?.toString().trim().toLowerCase() ?? 'logic');
    final category = kFactReviewDimensions.contains(rawCat) ? rawCat : 'logic';
    final blockingRaw = raw['blocking'];
    final blocking = blockingRaw is bool
        ? blockingRaw
        : (blockingRaw?.toString().toLowerCase() == 'true' || severity == 'critical');
    return FactReviewIssue(
      severity: severity,
      category: category,
      location: raw['location']?.toString().trim() ?? '正文中',
      description: desc,
      evidence: raw['evidence']?.toString().trim() ?? '',
      fixHint: raw['fix_hint']?.toString().trim() ?? '',
      blocking: blocking,
    );
  }
}

/// 5 维事实审稿完整结果。
class FactReviewResult {
  const FactReviewResult({
    required this.overallPass,
    required this.summary,
    required this.dimensionResults,
    required this.issues,
    this.rawJsonReply,
  });

  final bool overallPass;
  final String summary;
  final List<FactDimensionResult> dimensionResults;
  final List<FactReviewIssue> issues;
  final String? rawJsonReply;

  FactReviewResult withRawReply(String raw) => FactReviewResult(
    overallPass: overallPass,
    summary: summary,
    dimensionResults: dimensionResults,
    issues: issues,
    rawJsonReply: raw,
  );

  bool get hasBlocking => issues.any((i) => i.isBlocking);
  List<FactReviewIssue> get blockingIssues =>
      issues.where((i) => i.isBlocking).toList();
  List<FactReviewIssue> get warningIssues =>
      issues.where((i) => !i.isBlocking).toList();

  static FactReviewResult? tryParse(String raw) {
    return LLMJSONParser.decodeObject(raw, (json) {
      final issuesRaw = json['issues'];
      final issues = issuesRaw is List
          ? issuesRaw
                .map(FactReviewIssue.fromJson)
                .whereType<FactReviewIssue>()
                .toList()
          : <FactReviewIssue>[];

      final parsedDims = <String, FactDimensionResult>{};
      final dimsRaw = json['dimension_results'];
      if (dimsRaw is List) {
        for (final item in dimsRaw) {
          if (item is! Map) continue;
          final dim = item['dimension']?.toString().trim().toLowerCase() ?? '';
          if (!kFactReviewDimensions.contains(dim)) continue;
          final passRaw = item['pass'];
          final pass = passRaw is bool
              ? passRaw
              : passRaw?.toString().toLowerCase() != 'false';
          final note = item['note']?.toString().trim() ?? '';
          parsedDims[dim] = FactDimensionResult(
            dimension: dim,
            pass: pass,
            note: note,
          );
        }
      }

      // 保证 5 个标准维度完整且顺序稳定
      final normalizedDims = <FactDimensionResult>[];
      for (final dim in kFactReviewDimensions) {
        final existing = parsedDims[dim];
        final dimHasBlocking = issues.any(
          (i) => i.category == dim && i.isBlocking,
        );
        if (existing != null) {
          normalizedDims.add(
            FactDimensionResult(
              dimension: dim,
              pass: existing.pass && !dimHasBlocking,
              note: existing.note.isEmpty
                  ? (existing.pass && !dimHasBlocking ? '未发现矛盾' : '存在事实冲突')
                  : existing.note,
            ),
          );
        } else {
          final dimIssues = issues.where((i) => i.category == dim).toList();
          normalizedDims.add(
            FactDimensionResult(
              dimension: dim,
              pass: !dimHasBlocking,
              note: dimIssues.isEmpty
                  ? '未发现明显矛盾'
                  : '发现 ${dimIssues.length} 处问题',
            ),
          );
        }
      }

      final hasBlocking = issues.any((i) => i.isBlocking);
      final overallRaw = json['overall_pass'];
      final overallParsed = overallRaw is bool
          ? overallRaw
          : overallRaw?.toString().toLowerCase() != 'false';
      final overallPass = !hasBlocking && overallParsed;

      final summary = (json['summary']?.toString().trim() ?? '').isNotEmpty
          ? json['summary'].toString().trim()
          : (overallPass
                ? '5 维事实核查通过，未发现硬性矛盾。'
                : '发现 ${issues.where((i) => i.isBlocking).length} 处阻断性事实矛盾，建议先修订。');

      return FactReviewResult(
        overallPass: overallPass,
        summary: summary,
        dimensionResults: normalizedDims,
        issues: issues,
      );
    });
  }
}

/// 5 维客观事实与连续性审稿服务（供手动审稿面板与自动撰写拦截门共用）。
class FactReviewService {
  FactReviewService({
    required this.client,
    required this.library,
    this.providerExtra,
  });

  final LLMClient client;
  final PromptLibraryState library;
  final String? providerExtra;

  /// 为审稿构建紧凑但全面的【真相档案】，自动用 LorebookMatcher 按草稿内容激活相关角色与世界观。
  static String buildTruthArchive({
    required ChapterBundle chapter,
    required NovelBundle bundle,
    required String draftContent,
    String? sourceWindow,
    int maxChars = 24000,
  }) {
    final sections = <String>[];

    // 1) 上一章末尾（衔接基准）
    final all = bundle.allChaptersInOrder;
    final idx = all.indexWhere((c) => c.chapter.id == chapter.chapter.id);
    if (idx > 0) {
      var prevTail = all[idx - 1].chapter.content.trim();
      if (prevTail.isNotEmpty) {
        if (prevTail.length > ContextBuilder.neighborTailLength) {
          prevTail = prevTail.substring(
            prevTail.length - ContextBuilder.neighborTailLength,
          );
        }
        sections.add('【上一章正文末尾（衔接基准）】\n……$prevTail');
      }
    }

    // 2) 本章细纲与场景卡
    final outline = chapter.chapter.detailedOutline?.trim();
    if (outline != null && outline.isNotEmpty) {
      sections.add('【本章细纲】\n$outline');
    }
    if (chapter.sceneCards.isNotEmpty) {
      sections.add('【本章场景卡】\n${ContextBuilder.renderSceneCards(chapter.sceneCards)}');
    }

    // 3) 角色状态档案（用草稿+细纲+上章尾联合探测，保证文中提及的冷门角色也被核查）
    final probe = [
      chapter.chapter.title,
      ?outline,
      draftContent,
    ].join('\n');
    final lore = LorebookMatcher.selectByProbe(
      probeText: probe,
      characters: bundle.characters,
      worldEntries: bundle.worldEntries,
      relations: bundle.relations,
      maxCharacters: 20,
      maxWorldEntries: 20,
      fallbackWorldEntries: 8,
    );

    if (lore.characters.isNotEmpty) {
      final charBlocks = lore.characters.map((c) {
        final aliases = decodeStringList(c.aliasesJson);
        final lines = <String>[
          '◆ ${c.name}${aliases.isEmpty ? '' : '（${aliases.join('/')}）'}',
        ];
        if ((c.personality ?? '').isNotEmpty) lines.add('性格：${c.personality}');
        if ((c.background ?? '').isNotEmpty) lines.add('背景：${c.background}');
        if ((c.currentLocation ?? '').isNotEmpty) {
          lines.add('当前位置：${c.currentLocation}');
        }
        if ((c.physicalState ?? '').isNotEmpty) {
          lines.add('身体状态：${c.physicalState}');
        }
        if ((c.mentalState ?? '').isNotEmpty) {
          lines.add('心理状态：${c.mentalState}');
        }
        if ((c.currentGoal ?? '').isNotEmpty) {
          lines.add('当前目标：${c.currentGoal}');
        }
        if ((c.lastSeenChapterTitle ?? '').isNotEmpty) {
          lines.add('最近出场：${c.lastSeenChapterTitle}');
        }
        return lines.join('\n');
      });
      sections.add('【角色档案与当前状态】\n${charBlocks.join('\n\n')}');
    }

    if (lore.relations.isNotEmpty) {
      final nameById = {for (final c in bundle.characters) c.id: c.name};
      final relLines = <String>[];
      for (final r in lore.relations) {
        final a = nameById[r.sourceCharacterId];
        final b = nameById[r.targetCharacterId];
        if (a == null || b == null) continue;
        final secretTag = r.line == '暗线' ? '【暗线/信息壁垒注意】' : '';
        final desc = r.description.trim().isNotEmpty ? '（${r.description.trim()}）' : '';
        relLines.add('- $a ↔ $b［${r.relationType}·${r.line}·强度${r.strength}］$secretTag：${r.label}$desc');
      }
      if (relLines.isNotEmpty) {
        sections.add('【人物关系网与明暗线边界】\n${relLines.join('\n')}');
      }
    }

    if (lore.worldEntries.isNotEmpty) {
      final worldLines = lore.worldEntries.map(
        (w) => '- [${w.category}] ${w.name}：${w.content}',
      );
      sections.add('【世界观与硬规则】\n${worldLines.join('\n')}');
    }

    // 4) 最近 5 章摘要与关键事实 + 显式时间线事件
    final positions = bundle.globalIndexMap();
    final currentGlobal = positions[chapter.chapter.id] ?? (all.length + 1);
    final priorTimeline = bundle.timelineEvents
        .where((e) => e.chapterOrder == null || e.chapterOrder! < currentGlobal)
        .toList();
    if (priorTimeline.isNotEmpty) {
      final recentTl = priorTimeline.length > 6
          ? priorTimeline.sublist(priorTimeline.length - 6)
          : priorTimeline;
      final tlLines = recentTl.map((e) {
        final chTag = e.chapterRange ??
            (e.chapterOrder != null ? '第${e.chapterOrder}章' : '前期');
        final timeTag =
            (e.inWorldTime ?? '').isNotEmpty ? ' | ${e.inWorldTime}' : '';
        final locTag =
            (e.location ?? '').isNotEmpty ? ' @${e.location}' : '';
        return '- [$chTag$timeTag$locTag] ${e.title}：${e.summary}';
      });
      sections.add('【显式故事时间线（用于核对先后与时空位置）】\n${tlLines.join('\n')}');
    }
    final prevWithSummary = all
        .where(
          (c) =>
              c.summary != null &&
              (positions[c.chapter.id] ?? 0) < currentGlobal,
        )
        .toList();
    final recent = prevWithSummary.length > 5
        ? prevWithSummary.sublist(prevWithSummary.length - 5)
        : prevWithSummary;
    if (recent.isNotEmpty) {
      final sumLines = recent.map(
        (c) => '第${positions[c.chapter.id]}章《${c.chapter.title}》：${c.summary!.summaryText}',
      );
      sections.add('【前文摘要（最近 ${recent.length} 章）】\n${sumLines.join('\n')}');
      final facts = [for (final c in recent) ...c.keyFacts];
      if (facts.isNotEmpty) {
        sections.add('【已确立关键事实】\n${facts.map((f) => '- $f').join('\n')}');
      }
    }

    // 5) 未回收伏笔（最多 15 条）
    final openFs = bundle.foreshadowings
        .where((f) => f.status == 'open')
        .take(15)
        .toList();
    if (openFs.isNotEmpty) {
      final fsLines = openFs.map((f) {
        final detail = (f.detail ?? '').trim();
        return detail.isEmpty ? '- ${f.title}' : '- ${f.title}（$detail）';
      });
      sections.add('【未回收伏笔】\n${fsLines.join('\n')}');
    }

    if (sourceWindow != null && sourceWindow.trim().isNotEmpty) {
      sections.add('【原作档案窗口】\n${sourceWindow.trim()}');
    }

    // 预算裁剪
    final buf = StringBuffer();
    for (final sec in sections) {
      if (buf.length + sec.length + 2 > maxChars) {
        final remaining = maxChars - buf.length - 2;
        if (remaining > 200) {
          if (buf.isNotEmpty) buf.write('\n\n');
          buf.write(sec.substring(0, remaining));
          buf.write('……');
        }
        break;
      }
      if (buf.isNotEmpty) buf.write('\n\n');
      buf.write(sec);
    }
    return buf.toString();
  }

  /// 执行 5 维客观事实审稿（推理模型友好：maxTokens 至少 12288）。
  Future<FactReviewResult> review({
    required String truthArchive,
    required String chapterTitle,
    required String draftContent,
    int maxTokens = 12288,
    void Function(StreamEvent)? onEvent,
    CancelToken? cancelToken,
  }) async {
    final msgs = PromptTemplates.applyingExtra(
      providerExtra,
      PromptTemplates.factReview(
        library: library,
        truthArchive: truthArchive,
        chapterTitle: chapterTitle,
        draftContent: draftContent,
      ),
    );
    final raw = StringBuffer();
    await for (final ev in client.streamChat(
      msgs,
      config: GenerationConfig(
        temperature: 0.15,
        maxTokens: math.max(maxTokens, 12288),
        jsonMode: true,
        reasoningEffort: ReasoningEffort.medium,
        enablePromptCacheControl: true,
      ),
      cancelToken: cancelToken,
    )) {
      onEvent?.call(ev);
      if (ev is ContentDelta) raw.write(ev.text);
    }
    final rawText = raw.toString();
    final parsed = FactReviewResult.tryParse(rawText);
    if (parsed == null) {
      throw const FormatException('事实审稿 JSON 解析失败，请重试或切换支持结构化输出的模型');
    }
    return parsed.withRawReply(rawText);
  }

  /// 按选中的事实问题清单执行单次定点最小化修订（优先接续首轮审稿 KV 缓存）。
  Future<String> applyFixes({
    required String truthArchive,
    required String chapterTitle,
    required String draftContent,
    required List<FactReviewIssue> issues,
    String? priorReviewReply,
    int maxTokens = 16384,
    void Function(StreamEvent)? onEvent,
    CancelToken? cancelToken,
  }) async {
    if (issues.isEmpty) return draftContent;
    final checklist = StringBuffer();
    for (var i = 0; i < issues.length; i++) {
      final item = issues[i];
      checklist.writeln(
        '${i + 1}. [${item.categoryLabel}${item.isBlocking ? ' · 阻断' : ''}] ${item.location}：${item.description}',
      );
      if (item.evidence.isNotEmpty) {
        checklist.writeln('   证据：${item.evidence}');
      }
      if (item.fixHint.isNotEmpty) {
        checklist.writeln('   修复方向：${item.fixHint}');
      }
    }

    final msgs =
        (priorReviewReply != null && priorReviewReply.trim().isNotEmpty)
        ? PromptTemplates.factReviewFixFollowUp(
            reviewMessages: PromptTemplates.applyingExtra(
              providerExtra,
              PromptTemplates.factReview(
                library: library,
                truthArchive: truthArchive,
                chapterTitle: chapterTitle,
                draftContent: draftContent,
              ),
            ),
            reviewAssistantReply: priorReviewReply,
            issuesChecklist: checklist.toString(),
          )
        : PromptTemplates.applyingExtra(
            providerExtra,
            PromptTemplates.factReviewFix(
              truthArchive: truthArchive,
              chapterTitle: chapterTitle,
              draftContent: draftContent,
              issuesChecklist: checklist.toString(),
            ),
          );
    final out = StringBuffer();
    await for (final ev in client.streamChat(
      msgs,
      config: GenerationConfig(
        temperature: 0.3,
        maxTokens: math.max(maxTokens, 12288),
        enablePromptCacheControl: true,
      ),
      cancelToken: cancelToken,
    )) {
      onEvent?.call(ev);
      if (ev is ContentDelta) out.write(ev.text);
    }
    return out.toString().trim();
  }
}
