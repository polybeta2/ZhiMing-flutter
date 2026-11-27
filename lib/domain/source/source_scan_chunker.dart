import '../models/source_profile_models.dart';
import '../style/style_chapter_sampler.dart';
import 'novel_text_cleaner.dart';

class SourceScanChunk {
  const SourceScanChunk({
    required this.chapterIndex,
    this.chapterTitle = '',
    this.partIndex = 0,
    this.partCount = 1,
    required this.kind,
    required this.text,
  });

  /// 0-based 章序
  final int chapterIndex;
  final String chapterTitle;
  final int partIndex;
  final int partCount;
  final String kind; // 'fast_abridged' | 'full' | 'part'
  final String text;

  /// 1-based 真实章号
  int get chapterNo => chapterIndex + 1;
}

/// 原作分析切块器：复用 StyleChapterSampler 切章，先经 NovelTextCleaner 净化正文。
/// 修复快扫模式块数倒挂 Bug：超过 fastMinSplit 的章节首尾拼接为单块，保证快扫块数恒 <= 精扫块数。
class SourceScanChunker {
  const SourceScanChunker._();

  static const int fastHeadChars = 1500;
  static const int fastTailChars = 600;
  static const int fastMinSplit = 2500;
  static const int fullMaxChunk = 4000;
  static const int modernFullMaxChunk = 14000;
  static const int fallbackWindow = 4000;

  static List<SourceScanChunk> chunks(
    String text, {
    required ScanMode mode,
    int? maxChunkChars,
  }) {
    final fullCap = (maxChunkChars ?? fullMaxChunk).clamp(500, 100000);
    final chapters = StyleChapterSampler.split(text);
    if (chapters.isEmpty) {
      return _fallbackChunks(
        text,
        windowSize: mode == ScanMode.full ? fullCap : fallbackWindow,
      );
    }
    final result = <SourceScanChunk>[];
    var validChapterIdx = 0;
    for (var i = 0; i < chapters.length; i++) {
      final body = NovelTextCleaner.cleanChapterBody(chapters[i].body);
      if (body.isEmpty) continue;
      final marker = chapters[i].marker.trim();
      final chIdx = validChapterIdx++;
      switch (mode) {
        case ScanMode.evidence:
        case ScanMode.fast:
          if (body.length < fastMinSplit) {
            result.add(
              SourceScanChunk(
                chapterIndex: chIdx,
                chapterTitle: marker,
                kind: 'full',
                text: body,
              ),
            );
          } else {
            final head = body.substring(0, fastHeadChars.clamp(0, body.length));
            final tail = body.substring(
              (body.length - fastTailChars).clamp(0, body.length),
            );
            result.add(
              SourceScanChunk(
                chapterIndex: chIdx,
                chapterTitle: marker,
                kind: 'fast_abridged',
                text: '$head\n…（本章中段已略）…\n$tail',
              ),
            );
          }
        case ScanMode.full:
          if (body.length <= fullCap) {
            result.add(
              SourceScanChunk(
                chapterIndex: chIdx,
                chapterTitle: marker,
                kind: 'full',
                text: body,
              ),
            );
          } else {
            final partCount = (body.length + fullCap - 1) ~/ fullCap;
            var offset = 0;
            var partIdx = 0;
            while (offset < body.length) {
              final end = (offset + fullCap).clamp(0, body.length);
              result.add(
                SourceScanChunk(
                  chapterIndex: chIdx,
                  chapterTitle: marker,
                  partIndex: partIdx++,
                  partCount: partCount,
                  kind: 'part',
                  text: body.substring(offset, end),
                ),
              );
              offset = end;
            }
          }
      }
    }
    return result;
  }

  /// 按字符预算与最大块数将连续未完成分块打包成批次；遇已完成下标即断开，
  /// 每组至少包含 1 块（即使单块正文已超过 [targetBatchChars]）。
  static List<List<({int pos, SourceScanChunk chunk})>> packByCharBudget(
    List<SourceScanChunk> chunks,
    Set<int> doneIndexes, {
    int targetBatchChars = 42000,
    int maxChunksPerBatch = 12,
  }) {
    if (chunks.isEmpty) return const [];
    final maxPerBatch = maxChunksPerBatch < 1 ? 1 : maxChunksPerBatch;
    final budget = targetBatchChars < 0 ? 0 : targetBatchChars;
    final groups = <List<({int pos, SourceScanChunk chunk})>>[];

    var pos = 0;
    while (pos < chunks.length) {
      if (doneIndexes.contains(pos)) {
        pos += 1;
        continue;
      }
      final first = chunks[pos];
      final group = <({int pos, SourceScanChunk chunk})>[(pos: pos, chunk: first)];
      var groupChars = first.text.length;
      var nextPos = pos + 1;
      while (nextPos < chunks.length && group.length < maxPerBatch) {
        if (doneIndexes.contains(nextPos)) break;
        final candidate = chunks[nextPos];
        if (groupChars + candidate.text.length > budget) break;
        group.add((pos: nextPos, chunk: candidate));
        groupChars += candidate.text.length;
        nextPos += 1;
      }
      groups.add(group);
      pos = nextPos;
    }
    return groups;
  }

  static List<SourceScanChunk> _fallbackChunks(
    String text, {
    int windowSize = fallbackWindow,
  }) {
    final cleaned = NovelTextCleaner.cleanChapterBody(
      NovelTextCleaner.stripLeadingMetadata(text),
    );
    if (cleaned.isEmpty) return const [];
    final out = <SourceScanChunk>[];
    var offset = 0;
    var index = 0;
    while (offset < cleaned.length) {
      final end = (offset + windowSize).clamp(0, cleaned.length);
      out.add(
        SourceScanChunk(
          chapterIndex: index,
          chapterTitle: '第${index + 1}段',
          kind: 'part',
          text: cleaned.substring(offset, end),
        ),
      );
      offset = end;
      index += 1;
    }
    return out;
  }
}
