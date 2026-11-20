import '../models/novel_domain.dart';

class NovelStatistics {
  const NovelStatistics({
    required this.totalWordCount,
    required this.todayWordCount,
    required this.completedChapters,
    required this.draftChapters,
    required this.emptyChapters,
    required this.averageChapterWords,
    required this.chapterWordCounts,
  });

  final int totalWordCount;
  final int todayWordCount;
  final int completedChapters;
  final int draftChapters;
  final int emptyChapters;
  final int averageChapterWords;
  final List<({String title, int wordCount})> chapterWordCounts;

  int get totalChapters => chapterWordCounts.length;
}

abstract final class StatisticsService {
  static const int completedThreshold = 1000;

  static NovelStatistics calculate(NovelBundle bundle, {DateTime? now}) {
    final current = now ?? DateTime.now();
    var total = 0;
    var completed = 0;
    var draft = 0;
    var empty = 0;
    final counts = <({String title, int wordCount})>[];

    for (final ch in bundle.allChaptersInOrder) {
      final words = ch.chapter.content.length;
      total += words;
      if (words == 0) {
        empty += 1;
      } else if (words >= completedThreshold) {
        completed += 1;
      } else {
        draft += 1;
      }
      counts.add((title: ch.chapter.title, wordCount: words));
    }

    final avg = counts.isEmpty ? 0 : total ~/ counts.length;
    final lastDate = bundle.novel.lastStatsDate;
    final isToday = lastDate != null && _isSameDay(lastDate, current);
    final today = isToday
        ? (total - bundle.novel.lastTotalWordCount).clamp(0, total)
        : 0;

    return NovelStatistics(
      totalWordCount: total,
      todayWordCount: today,
      completedChapters: completed,
      draftChapters: draft,
      emptyChapters: empty,
      averageChapterWords: avg,
      chapterWordCounts: counts,
    );
  }

  static bool needsBaselineUpdate(DateTime? lastStatsDate, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return lastStatsDate == null || !_isSameDay(lastStatsDate, current);
  }

  static DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
