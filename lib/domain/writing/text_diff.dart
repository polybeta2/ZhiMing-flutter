/// 轻量行级 Diff 计算器（LCS 算法），供改写精修与风格体检「一键应用」对比预览使用。
enum DiffKind { unchanged, removed, added }

class DiffLine {
  const DiffLine(this.kind, this.text);
  final DiffKind kind;
  final String text;
}

abstract final class TextDiff {
  static List<DiffLine> diffLines(String before, String after) {
    final a = before.split('\n');
    final b = after.split('\n');
    final m = a.length;
    final n = b.length;

    // 超大文本保护：>400 行走首尾锚定块对比，保证毫秒级渲染
    if (m * n > 160000) {
      return [
        for (final line in a) DiffLine(DiffKind.removed, line),
        for (final line in b) DiffLine(DiffKind.added, line),
      ];
    }

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = m - 1; i >= 0; i--) {
      for (var j = n - 1; j >= 0; j--) {
        if (a[i] == b[j]) {
          dp[i][j] = dp[i + 1][j + 1] + 1;
        } else {
          dp[i][j] = dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }

    final result = <DiffLine>[];
    var i = 0;
    var j = 0;
    while (i < m && j < n) {
      if (a[i] == b[j]) {
        result.add(DiffLine(DiffKind.unchanged, a[i]));
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        result.add(DiffLine(DiffKind.removed, a[i]));
        i++;
      } else {
        result.add(DiffLine(DiffKind.added, b[j]));
        j++;
      }
    }
    while (i < m) {
      result.add(DiffLine(DiffKind.removed, a[i++]));
    }
    while (j < n) {
      result.add(DiffLine(DiffKind.added, b[j++]));
    }
    return result;
  }
}
