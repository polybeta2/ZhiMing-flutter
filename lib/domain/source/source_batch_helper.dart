import 'dart:convert';

import '../../core/llm/llm_types.dart';
import 'source_micro_summarizer.dart';

class BatchChapterInput {
  const BatchChapterInput({
    required this.index,
    this.title,
    required this.body,
  });

  /// 1-based 真实章号
  final int index;
  final String? title;
  final String body;
}

/// 批量复制分析协议：把最烧 token 的 Map 阶段外包给免费外部 AI App，或用于 API 自动批量扫描。
class SourceBatchHelper {
  const SourceBatchHelper._();

  static const int perChapterEstimateChars = 600;

  static const String _jsonlInstruction =
      '请逐段输出「增量式微摘要」JSON：每段输出【一行】JSON 对象，行与行之间用换行分隔；除此之外不要输出任何内容（不要解释、不要代码块围栏、不要编号）。';
  static const String _schemaHeader =
      '每行 JSON 格式（chapter 必须严格填标题括号中给出的 chapter 整数；只记录本段新出现或发生变化的信息，无新增则给空数组）：';
  static const String _schemaJson =
      '{"chapter": <整数章号>, "characters": [{"name": "主名", "aliases": ["别名/形态"], "role_hint": "主角/反派/配角", "camp_hint": "阵营", "traits": "性格或能力", "state_change": "状态变化"}], "relations": [{"from": "角色A", "to": "角色B", "relation": "关系描述", "kind": "亲友|盟友|爱恋|敌对|从属|竞争|未知", "line": "明线|暗线", "evidence": "依据"}], "events": [{"summary": "核心事件", "in_world_time": "书内时间(可选)", "participants": ["角色A"], "importance": "major|normal|minor"}], "worldbuilding": [{"name": "词条", "category": "力量体系|地理|势力|规则|器物", "content": "说明"}], "foreshadowing": [{"summary": "新埋或回收的伏笔一句话", "planted": true, "characters": ["相关角色"], "target_hint": "回收时简述对应前期悬念"}]}';
  static const String _rulesLine =
      '规则：新埋伏笔记 planted=true；本段揭晓/回收的记 planted=false 并填写 target_hint；涉及秘密/单方不知情/幕后操控的关系 line 记为 "暗线"，公开关系记为 "明线"。';

  static String chapterBlock(BatchChapterInput chapter) {
    final cleanTitle = chapter.title?.trim() ?? '';
    final marker = cleanTitle.isEmpty
        ? '第${chapter.index}章'
        : (cleanTitle.contains('第${chapter.index}')
              ? cleanTitle
              : '第${chapter.index}章 $cleanTitle');
    return '【$marker（chapter=${chapter.index}）】\n${chapter.body}';
  }

  static String prompt({
    String? title,
    required List<BatchChapterInput> chapters,
  }) {
    if (chapters.isEmpty) return '';
    final book = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : '这部小说';
    final first = chapters.first.index;
    final last = chapters.last.index;

    final lines = <String>[
      '【任务】你是小说内容分析师。下面是《$book》第 $first-$last 章的正文（共 ${chapters.length} 段）。',
      _jsonlInstruction,
      _schemaHeader,
      _schemaJson,
      _rulesLine,
      '',
      for (final c in chapters) chapterBlock(c),
    ];
    return lines.join('\n\n');
  }

  /// 构建 KV 前缀缓存友好的批量 Map 消息：
  /// - `system`（`cacheControl: true`）在全书所有批次之间保持字节级完全一致，不含任何批内章号或段数；
  /// - `user` 仅承载当前批次章号区间与正文。
  static List<LLMMessage> buildCachedBatchMessages({
    required String title,
    required List<BatchChapterInput> chapters,
    List<String> knownCharacters = const [],
  }) {
    if (chapters.isEmpty) return const [];
    final book = title.trim().isNotEmpty ? title.trim() : '这部小说';
    final first = chapters.first.index;
    final last = chapters.last.index;

    final sysLines = <String>[
      '【任务】你是小说内容分析师，正在对《$book》进行全书分批微摘要抽取。',
      _jsonlInstruction,
      _schemaHeader,
      _schemaJson,
      _rulesLine,
    ];
    final priorChars = knownCharacters
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(40)
        .toList();
    if (priorChars.isNotEmpty) {
      sysLines.add(
        '【全书高频先验人物名录（请优先沿用此主名，减少别名碎片）】\n${priorChars.join("、")}',
      );
    }

    final userLines = <String>[
      '下面是《$book》第 $first-$last 章的正文（共 ${chapters.length} 段），请逐段输出对应 JSON 行：',
      for (final c in chapters) chapterBlock(c),
    ];

    return [
      LLMMessage(
        role: LLMRole.system,
        content: sysLines.join('\n\n'),
        cacheControl: true,
      ),
      LLMMessage(role: LLMRole.user, content: userLines.join('\n\n')),
    ];
  }

  /// 解析逐行输出为有序列表（支持超长章拆多段时共享同一 chapterNo）。
  static List<({int chapterNo, MicroSummary summary})> parseBatchEntries(
    String raw,
  ) {
    final entries = <({int chapterNo, MicroSummary summary})>[];
    for (final jsonStr in extractJsonObjects(raw, matchingKey: 'chapter')) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        final ch = map['chapter'];
        final idx = ch is num ? ch.toInt() : int.tryParse(ch?.toString() ?? '');
        if (idx == null || idx < 1) continue;
        final summary = MicroSummary.fromJson(map);
        entries.add((chapterNo: idx, summary: summary));
      } catch (_) {
        continue;
      }
    }
    if (entries.isEmpty) {
      throw const FormatException('未能解析出任何逐章微摘要 JSON');
    }
    return entries;
  }

  /// 解析外部 AI 输出为 0-based 章序 → MicroSummary（同章多段自动合并）。
  static Map<int, MicroSummary> parseBatchOutput(String raw) {
    final entries = parseBatchEntries(raw);
    final result = <int, MicroSummary>{};
    for (final entry in entries) {
      final key = entry.chapterNo - 1;
      final existing = result[key];
      result[key] = existing == null
          ? entry.summary
          : existing.mergeWith(entry.summary);
    }
    return result;
  }

  /// 字符串感知地提取所有以 `{"<matchingKey>"` 开头的配平 `{...}` JSON 对象。
  static List<String> extractJsonObjects(
    String text, {
    required String matchingKey,
  }) {
    final objects = <String>[];
    var i = 0;
    while (i < text.length) {
      final brace = text.indexOf('{', i);
      if (brace == -1) break;
      final probeEnd = (brace + matchingKey.length + 12).clamp(0, text.length);
      final probe = text
          .substring(brace, probeEnd)
          .replaceAll(RegExp(r'\s+'), '');
      if (!probe.startsWith('{"$matchingKey"')) {
        i = brace + 1;
        continue;
      }
      final end = _closingBrace(text, brace);
      if (end != null) {
        objects.add(text.substring(brace, end + 1));
        i = end + 1;
      } else {
        i = brace + 1;
      }
    }
    return objects;
  }

  static int? _closingBrace(String text, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
      } else if (inString && ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = !inString;
      } else if (!inString) {
        if (ch == '{') {
          depth += 1;
        } else if (ch == '}') {
          depth -= 1;
          if (depth == 0) return i;
        }
      }
    }
    return null;
  }
}
