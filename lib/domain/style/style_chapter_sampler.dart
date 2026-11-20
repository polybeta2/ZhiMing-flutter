import 'dart:math' as math;

class SampleChapter {
  const SampleChapter({
    required this.marker,
    required this.number,
    required this.symbol,
    required this.body,
  });

  final String marker;
  final int? number;
  final String? symbol;
  final String body;
}

/// 长篇切章与自适应抽样（与原版 v2.5.1/v2.9.0 算法 1:1 对齐：含中文数字解析与回落型尖刺裁决）
abstract final class StyleChapterSampler {
  static const int initialCount = 6;
  static const int expandStep = 2;
  static const int maxChapters = 10;
  static const Set<String> _adjudicatableSymbols = {'章', '节', '回'};

  static List<SampleChapter> split(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final raw = <({String marker, int? number, String? symbol, String body})>[];
    final pending = <String>[];
    var preamble = '';
    ({String marker, int? number, String? symbol})? lastMarker;

    for (final line in lines) {
      final number = markerNumber(line);
      if (number != null) {
        final symbol = markerSymbol(line);
        final body = pending.join('\n').trim();
        if (lastMarker != null) {
          raw.add((
            marker: lastMarker.marker,
            number: lastMarker.number,
            symbol: lastMarker.symbol,
            body: body,
          ));
        } else if (body.isNotEmpty) {
          preamble = body;
        }
        pending.clear();
        lastMarker = (marker: line.trim(), number: number, symbol: symbol);
      } else {
        pending.add(line);
      }
    }
    if (lastMarker != null) {
      raw.add((
        marker: lastMarker.marker,
        number: lastMarker.number,
        symbol: lastMarker.symbol,
        body: pending.join('\n').trim(),
      ));
    }
    if (raw.isEmpty) return const [];

    final survivors = _adjudicate(raw);
    final result = <SampleChapter>[];
    final pendingDrop = <String>[];

    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (survivors.contains(i)) {
        var body = ch.body;
        if (result.isEmpty && preamble.isNotEmpty) {
          body = '$preamble\n$body'.trim();
        }
        if (pendingDrop.isNotEmpty) {
          body = '${pendingDrop.join('\n')}\n$body'.trim();
          pendingDrop.clear();
        }
        result.add(
          SampleChapter(
            marker: ch.marker,
            number: ch.number,
            symbol: ch.symbol,
            body: body,
          ),
        );
      } else {
        pendingDrop.add('${ch.marker}\n${ch.body}');
      }
    }
    if (pendingDrop.isNotEmpty && result.isNotEmpty) {
      final last = result.removeLast();
      result.add(
        SampleChapter(
          marker: last.marker,
          number: last.number,
          symbol: last.symbol,
          body: '${last.body}\n${pendingDrop.join('\n')}'.trim(),
        ),
      );
    }
    return result;
  }

  static Set<int> _adjudicate(
    List<({String marker, int? number, String? symbol, String body})> raw,
  ) {
    final numbered = <({int offset, int number})>[];
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch.number == null) continue;
      if (ch.symbol != null && !_adjudicatableSymbols.contains(ch.symbol)) {
        continue; // 卷/集不参与尖刺裁决
      }
      numbered.add((offset: i, number: ch.number!));
    }
    if (numbered.length < 3) return {for (var i = 0; i < raw.length; i++) i};

    final forwardGaps = <int>[];
    for (var i = 1; i < numbered.length; i++) {
      final gap = numbered[i].number - numbered[i - 1].number;
      if (gap > 0) forwardGaps.add(gap);
    }
    if (forwardGaps.isEmpty) return {for (var i = 0; i < raw.length; i++) i};
    final minGap = forwardGaps.reduce(math.min);
    final tolerance = math.max(3, 5 * minGap);

    final keep = {for (var i = 0; i < raw.length; i++) i};
    int? lastKept;
    for (var pos = 0; pos < numbered.length; pos++) {
      final item = numbered[pos];
      if (lastKept != null) {
        if (item.number == lastKept) {
          keep.remove(item.offset);
          continue;
        }
        if (item.number > lastKept + tolerance) {
          var returnsLater = false;
          for (var j = pos + 1; j < numbered.length; j++) {
            if ((numbered[j].number - lastKept).abs() <= tolerance) {
              returnsLater = true;
              break;
            }
          }
          if (returnsLater) {
            keep.remove(item.offset);
            continue;
          }
        }
      }
      lastKept = item.number;
    }
    return keep;
  }

  static List<int> selectInitial(
    int total, {
    int Function(int maxExclusive)? pickRandom,
  }) {
    if (total <= 0) return const [];
    if (total <= initialCount) return [for (var i = 0; i < total; i++) i];
    final rng = math.Random();
    final pick = pickRandom ?? rng.nextInt;
    final picked = <int>{0, 1, total - 2, total - 1};
    var pool = [for (var i = 2; i < total - 2; i++) i];
    if (total >= 12) {
      final mid = pool.where((i) => i >= total ~/ 4 && i < (total * 3) ~/ 4).toList();
      if (mid.length >= 2) pool = mid;
    }
    for (var k = 0; k < 2 && pool.isNotEmpty; k++) {
      final idx = pick(pool.length);
      picked.add(pool.removeAt(idx));
    }
    return picked.toList()..sort();
  }

  static List<int> expand(
    List<int> selected,
    int total, {
    int Function(int maxExclusive)? pickRandom,
  }) {
    final rng = math.Random();
    final pick = pickRandom ?? rng.nextInt;
    final res = selected.toSet();
    final pool = [for (var i = 0; i < total; i++) if (!res.contains(i)) i];
    for (var k = 0; k < expandStep; k++) {
      if (pool.isEmpty || res.length >= maxChapters) break;
      res.add(pool.removeAt(pick(pool.length)));
    }
    return res.toList()..sort();
  }

  static String _toHalfWidth(String s) {
    final buf = StringBuffer();
    for (final code in s.codeUnits) {
      if (code == 0x3000) {
        buf.writeCharCode(0x20);
      } else if (code >= 0xFF01 && code <= 0xFF5E) {
        buf.writeCharCode(code - 0xFEE0);
      } else {
        buf.writeCharCode(code);
      }
    }
    return buf.toString();
  }

  static int? markerNumber(String line) {
    final trimmed = _toHalfWidth(line).trim();
    if (trimmed.isEmpty || trimmed.length > 40) return null;

    // 纯数字行：001 / 28
    if (trimmed.length <= 4 && RegExp(r'^\d+$').hasMatch(trimmed)) {
      final n = int.tryParse(trimmed);
      if (n != null && n >= 1) return n;
    }

    // 第X章/节/回/卷/集
    if (trimmed.startsWith('第')) {
      final m = RegExp(
        r'^第\s*([0-9零〇一二三四五六七八九十百千万两]+)\s*([章节回卷集])',
      ).firstMatch(trimmed);
      if (m != null) {
        return parseChineseNumeral(m.group(1)!);
      }
      return null;
    }

    // Chapter 12
    final chMatch = RegExp(
      r'^chapter\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (chMatch != null) return int.tryParse(chMatch.group(1)!);
    return null;
  }

  static String? markerSymbol(String line) {
    final trimmed = _toHalfWidth(line).trim();
    final m = RegExp(
      r'^第\s*[0-9零〇一二三四五六七八九十百千万两]+\s*([章节回卷集])',
    ).firstMatch(trimmed);
    return m?.group(1);
  }

  static int? parseChineseNumeral(String raw) {
    final direct = int.tryParse(raw);
    if (direct != null) return direct > 0 ? direct : null;
    const digits = {
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '两': 2,
    };
    const units = {'十': 10, '百': 100, '千': 1000};
    var total = 0;
    var section = 0;
    var digit = 0;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (digits.containsKey(ch)) {
        digit = digits[ch]!;
      } else if (units.containsKey(ch)) {
        section += (digit == 0 ? 1 : digit) * units[ch]!;
        digit = 0;
      } else if (ch == '万') {
        total = (total + section + digit) * 10000;
        section = 0;
        digit = 0;
      } else {
        return null;
      }
    }
    final result = total + section + digit;
    return result > 0 ? result : null;
  }
}
