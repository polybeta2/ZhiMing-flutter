import 'dart:convert';

import 'source_micro_summarizer.dart';

class BatchChapterInput {
  const BatchChapterInput({
    required this.index,
    this.title,
    required this.body,
  });

  /// 1-based 序号（全书块序或章序）
  final int index;
  final String? title;
  final String body;
}

/// 批量复制分析协议：把最烧 token 的 Map 阶段外包给免费外部 AI App，或用于 API 自动批量扫描。
class SourceBatchHelper {
  const SourceBatchHelper._();

  static const int perChapterEstimateChars = 600;

  static String chapterBlock(BatchChapterInput chapter) {
    final marker = (chapter.title != null && chapter.title!.trim().isNotEmpty)
        ? chapter.title!.trim()
        : '第${chapter.index}章';
    return '【$marker】\n${chapter.body}';
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
      '【任务】你是小说内容分析师。下面是《$book》第 $first-$last 章的正文（共 ${chapters.length} 章）。',
      '请逐章输出「增量式微摘要」JSON：每章输出【一行】JSON 对象，章与章之间用换行分隔；除此之外不要输出任何内容（不要解释、不要代码块围栏、不要编号）。',
      '每章 JSON 格式（只记录本章「新增或变化」的信息：新角色、性格/能力表现、状态变化、发生的事件、新确立的设定、新埋或回收的伏笔；不要复述前文已知内容；本章无新增则对应字段给空数组）：',
      '{"chapter": <本章序号>, "characters": [{"name": "", "traits": "", "state_change": ""}], "events": [{"summary": "", "participants": []}], "worldbuilding": [{"name": "", "content": ""}], "foreshadowing": [{"summary": "本章新埋或回收的伏笔一句话", "planted": true}]}',
      '伏笔规则：本章新埋的记 planted=true（含线索）；本章回收（悬念解除）的记 planted=false；无则空数组。',
      '',
      for (final c in chapters) chapterBlock(c),
    ];
    return lines.join('\n\n');
  }

  /// 解析外部 AI 输出为 0-based 序号 → MicroSummary。
  static Map<int, MicroSummary> parseBatchOutput(String raw) {
    final result = <int, MicroSummary>{};
    for (final jsonStr in extractJsonObjects(raw, matchingKey: 'chapter')) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        final ch = map['chapter'];
        final idx = ch is num ? ch.toInt() : int.tryParse(ch?.toString() ?? '');
        if (idx == null || idx < 1) continue;
        result[idx - 1] = MicroSummary.fromJson(map);
      } catch (_) {
        continue;
      }
    }
    if (result.isEmpty) {
      throw const FormatException('未能解析出任何逐章微摘要 JSON');
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
