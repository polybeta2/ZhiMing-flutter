import '../models/source_profile_models.dart';
import '../style/style_chapter_sampler.dart';

class SourceScanChunk {
  const SourceScanChunk({
    required this.chapterIndex,
    required this.kind,
    required this.text,
  });

  final int chapterIndex;
  final String kind; // 'head' | 'tail' | 'full' | 'part'
  final String text;
}

/// 原作分析切块器：复用 StyleChapterSampler 切章，区分快扫/精扫两档。
class SourceScanChunker {
  const SourceScanChunker._();

  static const int fastHeadChars = 1500;
  static const int fastTailChars = 500;
  static const int fastMinSplit = 2500;
  static const int fullMaxChunk = 4000;
  static const int fallbackWindow = 4000;

  static List<SourceScanChunk> chunks(String text, {required ScanMode mode}) {
    final chapters = StyleChapterSampler.split(text);
    if (chapters.isEmpty) return _fallbackChunks(text);
    final result = <SourceScanChunk>[];
    for (var i = 0; i < chapters.length; i++) {
      final body = chapters[i].body;
      switch (mode) {
        case ScanMode.fast:
          if (body.length < fastMinSplit) {
            result.add(
              SourceScanChunk(chapterIndex: i, kind: 'full', text: body),
            );
          } else {
            result.add(
              SourceScanChunk(
                chapterIndex: i,
                kind: 'head',
                text: body.substring(0, fastHeadChars.clamp(0, body.length)),
              ),
            );
            result.add(
              SourceScanChunk(
                chapterIndex: i,
                kind: 'tail',
                text: body.substring(
                  (body.length - fastTailChars).clamp(0, body.length),
                ),
              ),
            );
          }
        case ScanMode.full:
          if (body.length <= fullMaxChunk) {
            result.add(
              SourceScanChunk(chapterIndex: i, kind: 'full', text: body),
            );
          } else {
            var offset = 0;
            while (offset < body.length) {
              final end = (offset + fullMaxChunk).clamp(0, body.length);
              result.add(
                SourceScanChunk(
                  chapterIndex: i,
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
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    final out = <SourceScanChunk>[];
    var offset = 0;
    var index = 0;
    while (offset < trimmed.length) {
      final end = (offset + fallbackWindow).clamp(0, trimmed.length);
      out.add(
        SourceScanChunk(
          chapterIndex: index,
          kind: 'part',
          text: trimmed.substring(offset, end),
        ),
      );
      offset = end;
      index += 1;
    }
    return out;
  }
}
