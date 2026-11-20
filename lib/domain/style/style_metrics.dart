import 'dart:convert';

import '../models/style_models.dart';

class StyleSampleSegment {
  const StyleSampleSegment({required this.text, required this.label});
  final String text;
  final String label;
}

/// 原文 8-gram 复用查重索引（64 位 FNV-1a 哈希，百万字样本仅占极小内存且一次构建多候选复用）
class NgramIndex {
  const NgramIndex._(this._hashes, this.n);
  final Set<int> _hashes;
  final int n;

  bool hasViolation(String candidate) => violations([candidate]).isNotEmpty;

  List<String> violations(List<String> candidates) {
    final hits = <String>[];
    for (final candidate in candidates) {
      final norm = StyleMetrics.normalize(candidate);
      final chars = norm.runes.toList();
      if (chars.length < n) continue;
      String? found;
      for (var i = 0; i <= chars.length - n; i++) {
        final window = String.fromCharCodes(chars.sublist(i, i + n));
        if (_hashes.contains(StyleMetrics._fnv1a(window))) {
          found = window;
          break;
        }
      }
      if (found != null && !hits.contains(found)) {
        hits.add(found);
      }
    }
    return hits;
  }
}

/// 本地文风计量与 n-gram 原创性查重
abstract final class StyleMetrics {
  static final RegExp _sepRe = RegExp(r'[。！？；!?;\n]+');
  static final RegExp _dropRe = RegExp(
    r'[，。！？；：、“”‘’「」『』（）《》【】…—\n\r\t ,.;:!?"' "'" r'()<>]',
  );

  static List<StyleSampleSegment> sampleSegments(String full, int maxChars) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length <= maxChars) {
      return [StyleSampleSegment(text: trimmed, label: '全文')];
    }
    final part = maxChars ~/ 3;
    final head = trimmed.substring(0, part);
    final midStart = (trimmed.length - part) ~/ 2;
    final middle = trimmed.substring(midStart, midStart + part);
    final tail = trimmed.substring(trimmed.length - part);
    return [
      StyleSampleSegment(text: head, label: '开头'),
      StyleSampleSegment(text: middle, label: '中段'),
      StyleSampleSegment(text: tail, label: '结尾'),
    ];
  }

  static StyleMetricsSnapshot compute(String text) {
    final trimmed = text.trim();
    final charCount = trimmed.length;
    if (charCount == 0) return const StyleMetricsSnapshot();

    final sentences = trimmed
        .split(_sepRe)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final rawLengths = [for (final s in sentences) s.length];
    final sorted = [...rawLengths]..sort();

    var short = 0;
    var long = 0;
    for (final len in rawLengths) {
      if (len <= 10) short++;
      if (len >= 25) long++;
    }
    final count = rawLengths.length;

    var alternation = 0;
    if (count >= 2) {
      int cat(int len) => len <= 10 ? 0 : (len >= 25 ? 2 : 1);
      for (var i = 1; i < count; i++) {
        if (cat(rawLengths[i]) != cat(rawLengths[i - 1])) alternation++;
      }
    }

    final lines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final quoted = lines
        .where(
          (l) =>
              l.contains('“') ||
              l.contains('「') ||
              l.contains('『') ||
              l.contains('"'),
        )
        .length;

    double per1k(int occ) => occ / charCount * 1000.0;

    return StyleMetricsSnapshot(
      sampleCharCount: charCount,
      sentenceCount: count,
      medianSentenceLength: _median(sorted),
      shortSentenceRatio: count == 0 ? 0 : short / count,
      longSentenceRatio: count == 0 ? 0 : long / count,
      alternationRate: count < 2 ? 0 : alternation / (count - 1),
      dialogueLineRatio: lines.isEmpty ? 0 : quoted / lines.length,
      dashPer1k: per1k(_countSub(trimmed, '——')),
      ellipsisPer1k: per1k(_countSub(trimmed, '……')),
      exclamationPer1k: per1k(
        _countSub(trimmed, '！') + _countSub(trimmed, '!'),
      ),
      questionPer1k: per1k(_countSub(trimmed, '？') + _countSub(trimmed, '?')),
    );
  }

  static NgramIndex ngramIndex(String original, {int n = 8}) {
    final norm = normalize(original);
    final chars = norm.runes.toList();
    if (chars.length < n) return NgramIndex._(const {}, n);
    final set = <int>{};
    for (var i = 0; i <= chars.length - n; i++) {
      final window = String.fromCharCodes(chars.sublist(i, i + n));
      set.add(_fnv1a(window));
    }
    return NgramIndex._(set, n);
  }

  static String normalize(String text) =>
      text.toLowerCase().replaceAll(_dropRe, '');

  /// 64 位 FNV-1a 哈希（Dart VM 原生 64 位整数）
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0x7FFFFFFFFFFFFFFF;
    }
    return hash;
  }

  static double _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid].toDouble();
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static int _countSub(String text, String needle) {
    var count = 0;
    var pos = 0;
    while (true) {
      final idx = text.indexOf(needle, pos);
      if (idx == -1) break;
      count++;
      pos = idx + needle.length;
    }
    return count;
  }
}
