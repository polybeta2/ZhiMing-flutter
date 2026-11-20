import 'dart:convert';

/// 从模型输出中宽容提取 JSON：支持对象/数组双顶层、字符串感知括号配平、
/// 剥 ```json 围栏、清理尾逗号，以及多候选回退（最多尝试 8 个起始括号）。
abstract final class LLMJSONParser {
  static final RegExp _trailingArrayComma = RegExp(r',\s*]');
  static final RegExp _trailingObjectComma = RegExp(r',\s*}');

  /// 提取首个完整配平的 JSON 对象或数组
  static String? extractJson(String text) {
    final start = _nextOpenBracket(text, 0);
    if (start == -1) return null;
    final end = _balancedEnd(text, start);
    if (end == -1) return null;
    return text.substring(start, end + 1);
  }

  /// 解码任意顶层 JSON（对象或数组）
  static dynamic decodeAny(String text) {
    final first = extractJson(text);
    if (first != null) {
      try {
        return jsonDecode(first);
      } catch (_) {
        // fallback to lenient
      }
    }
    return _decodeLenient(text);
  }

  /// 解码并映射为强类型对象；失败返回 null
  static T? decodeObject<T>(
    String text,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final first = extractJson(text);
    if (first != null) {
      try {
        final raw = jsonDecode(first);
        if (raw is Map<String, dynamic>) return fromJson(raw);
      } catch (_) {}
    }
    return _decodeLenientTyped<T>(text, (raw) {
      if (raw is Map<String, dynamic>) return fromJson(raw);
      return null;
    });
  }

  /// 解码 JSON 数组并映射
  static List<T>? decodeList<T>(
    String text,
    T Function(dynamic item) mapper,
  ) {
    final first = extractJson(text);
    if (first != null) {
      try {
        final raw = jsonDecode(first);
        if (raw is List) return raw.map(mapper).toList();
      } catch (_) {}
    }
    return _decodeLenientTyped<List<T>>(text, (raw) {
      if (raw is List) return raw.map(mapper).toList();
      return null;
    });
  }

  static dynamic _decodeLenient(String text) {
    return _decodeLenientTyped<dynamic>(text, (raw) => raw);
  }

  static T? _decodeLenientTyped<T>(
    String text,
    T? Function(dynamic raw) converter,
  ) {
    final candidate = _stripFence(text);
    var searchFrom = 0;
    var attempts = 0;
    while (attempts < 8 && searchFrom < candidate.length) {
      final start = _nextOpenBracket(candidate, searchFrom);
      if (start == -1) break;
      attempts += 1;
      final end = _balancedEnd(candidate, start);
      if (end == -1) {
        searchFrom = start + 1;
        continue;
      }
      final jsonStr = candidate.substring(start, end + 1);
      final cleaned = jsonStr
          .replaceAll(_trailingArrayComma, ']')
          .replaceAll(_trailingObjectComma, '}');
      for (final variant in [jsonStr, cleaned]) {
        try {
          final parsed = jsonDecode(variant);
          final converted = converter(parsed);
          if (converted != null) return converted;
        } catch (_) {}
      }
      searchFrom = end + 1;
    }
    return null;
  }

  static String _stripFence(String text) {
    final fenceStart = text.indexOf('```');
    if (fenceStart == -1) return text;
    final nl = text.indexOf('\n', fenceStart);
    if (nl == -1) return text;
    final inner = text.substring(nl + 1);
    final fenceEnd = inner.indexOf('```');
    return fenceEnd == -1 ? inner : inner.substring(0, fenceEnd);
  }

  static int _nextOpenBracket(String text, int from) {
    for (var i = from; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x7B || c == 0x5B) return i; // '{' or '['
    }
    return -1;
  }

  static int _balancedEnd(String text, int start) {
    final open = text.codeUnitAt(start);
    final close = open == 0x7B ? 0x7D : 0x5D; // '}' or ']'
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (escaped) {
        escaped = false;
      } else if (inString && c == 0x5C) {
        escaped = true;
      } else if (c == 0x22) {
        inString = !inString;
      } else if (!inString) {
        if (c == open) {
          depth += 1;
        } else if (c == close) {
          depth -= 1;
          if (depth == 0) return i;
        }
      }
    }
    return -1;
  }
}

/// 摘要中提取出的单条新伏笔
class ForeshadowExtraction {
  const ForeshadowExtraction({
    this.title,
    this.detail,
    this.plannedResolve,
  });

  final String? title;
  final String? detail;
  final String? plannedResolve;

  factory ForeshadowExtraction.fromJson(dynamic raw) {
    if (raw is String) {
      return ForeshadowExtraction(title: raw);
    }
    if (raw is Map) {
      return ForeshadowExtraction(
        title: raw['title']?.toString(),
        detail: raw['detail']?.toString(),
        plannedResolve: raw['planned_resolve']?.toString(),
      );
    }
    return const ForeshadowExtraction();
  }
}

/// 章节摘要解析结果
class SummaryResult {
  const SummaryResult({
    required this.summary,
    this.keyFacts = const [],
    this.newForeshadowings = const [],
    this.resolvedForeshadowingTitles = const [],
  });

  final String summary;
  final List<String> keyFacts;
  final List<ForeshadowExtraction> newForeshadowings;
  final List<String> resolvedForeshadowingTitles;

  static SummaryResult? tryParse(String raw) {
    return LLMJSONParser.decodeObject(raw, (json) {
      final summary = json['summary']?.toString() ?? '';
      if (summary.trim().isEmpty) {
        throw const FormatException('missing summary');
      }
      final factsRaw = json['key_facts'];
      final keyFacts = factsRaw is List
          ? factsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : <String>[];
      final newRaw = json['new_foreshadowings'];
      final newForeshadowings = newRaw is List
          ? newRaw.map(ForeshadowExtraction.fromJson).toList()
          : <ForeshadowExtraction>[];
      final resolvedRaw = json['resolved_foreshadowing_titles'];
      final resolvedTitles = resolvedRaw is List
          ? resolvedRaw
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];
      return SummaryResult(
        summary: summary,
        keyFacts: keyFacts,
        newForeshadowings: newForeshadowings,
        resolvedForeshadowingTitles: resolvedTitles,
      );
    });
  }
}
