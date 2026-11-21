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
  static const int fallbackWindow = 4000;

  static List<SourceScanChunk> chunks(String text, {required ScanMode mode}) {
    final chapters = StyleChapterSampler.split(text);
    if (chapters.isEmpty) return _fallbackChunks(text);
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
          if (body.length <= fullMaxChunk) {
            result.add(
              SourceScanChunk(
                chapterIndex: chIdx,
                chapterTitle: marker,
                kind: 'full',
                text: body,
              ),
            );
          } else {
            final partCount = (body.length + fullMaxChunk - 1) ~/ fullMaxChunk;
            var offset = 0;
            var partIdx = 0;
            while (offset < body.length) {
              final end = (offset + fullMaxChunk).clamp(0, body.length);
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

  static List<SourceScanChunk> _fallbackChunks(String text) {
    final cleaned = NovelTextCleaner.cleanChapterBody(
      NovelTextCleaner.stripLeadingMetadata(text),
    );
    if (cleaned.isEmpty) return const [];
    final out = <SourceScanChunk>[];
    var offset = 0;
    var index = 0;
    while (offset < cleaned.length) {
      final end = (offset + fallbackWindow).clamp(0, cleaned.length);
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
