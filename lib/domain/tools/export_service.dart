import '../models/novel_domain.dart';

enum ExportFormat { txt, markdown }

sealed class ExportScope {
  const ExportScope();
}

final class FullNovelScope extends ExportScope {
  const FullNovelScope();
}

final class SingleVolumeScope extends ExportScope {
  const SingleVolumeScope(this.volumeId);
  final String volumeId;
}

final class OutlineOnlyScope extends ExportScope {
  const OutlineOnlyScope();
}

abstract final class ExportService {
  static const _sep = '\n\n---\n\n';

  static String export({
    required NovelBundle bundle,
    required ExportScope scope,
    required ExportFormat format,
  }) {
    return switch (scope) {
      FullNovelScope() => _renderFullNovel(bundle, format),
      SingleVolumeScope(:final volumeId) => _renderSingleVolume(
        bundle,
        volumeId,
        format,
      ),
      OutlineOnlyScope() => _renderOutline(bundle, format),
    };
  }

  static String fileName({
    required NovelBundle bundle,
    required ExportScope scope,
    required ExportFormat format,
  }) {
    final ext = format == ExportFormat.txt ? 'txt' : 'md';
    final safeTitle = bundle.novel.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final base = '《$safeTitle》';
    return switch (scope) {
      FullNovelScope() => '$base-全书.$ext',
      SingleVolumeScope(:final volumeId) => () {
        final volName =
            bundle.volumes
                .where((v) => v.volume.id == volumeId)
                .firstOrNull
                ?.volume
                .name
                .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ??
            '卷';
        return '$base-$volName.$ext';
      }(),
      OutlineOnlyScope() => '$base-大纲.$ext',
    };
  }

  static String _renderFullNovel(NovelBundle bundle, ExportFormat format) {
    final parts = <String>[_header(bundle, format)];
    var globalIdx = 1;
    for (var v = 0; v < bundle.volumes.length; v++) {
      final vol = bundle.volumes[v];
      parts.add(_volumeTitle(vol, v + 1, format));
      for (final ch in vol.chapters) {
        parts.add(_chapterText(ch, globalIdx++, format));
      }
    }
    return parts.join(_sep);
  }

  static String _renderSingleVolume(
    NovelBundle bundle,
    String volumeId,
    ExportFormat format,
  ) {
    final idx = bundle.volumes.indexWhere((v) => v.volume.id == volumeId);
    if (idx < 0) return '';
    final vol = bundle.volumes[idx];
    final parts = <String>[
      _header(bundle, format),
      _volumeTitle(vol, idx + 1, format),
      for (var i = 0; i < vol.chapters.length; i++)
        _chapterText(vol.chapters[i], i + 1, format),
    ];
    return parts.join(_sep);
  }

  static String _header(NovelBundle bundle, ExportFormat format) {
    final md = format == ExportFormat.markdown;
    final lines = <String>[
      md ? '# 《${bundle.novel.title}》' : '《${bundle.novel.title}》',
    ];
    final syn = bundle.novel.synopsis.trim();
    if (syn.isNotEmpty) {
      lines.add(md ? '**梗概**：$syn' : '[梗概：\n$syn\n]');
    }
    return lines.join('\n\n');
  }

  static String _volumeTitle(
    VolumeBundle vol,
    int order,
    ExportFormat format,
  ) {
    final label = '第$order卷：${vol.volume.name}';
    return format == ExportFormat.markdown ? '## $label' : label;
  }

  static String _chapterText(
    ChapterBundle ch,
    int number,
    ExportFormat format,
  ) {
    final title = ch.chapter.title.trim();
    final heading = title.isEmpty
        ? (format == ExportFormat.markdown ? '### 第$number章' : '第$number章')
        : (format == ExportFormat.markdown
              ? '### 第$number章 $title'
              : '第$number章 $title');
    final body = ch.chapter.content.trim();
    return '$heading\n\n${body.isEmpty ? '（本章暂无正文）' : body}';
  }

  static String _renderOutline(NovelBundle bundle, ExportFormat format) {
    final md = format == ExportFormat.markdown;
    final parts = <String>[
      md ? '# 《${bundle.novel.title}》大纲' : '《${bundle.novel.title}》大纲',
    ];
    if (bundle.novel.synopsis.trim().isNotEmpty) {
      parts.add(
        md
            ? '**梗概**：${bundle.novel.synopsis}'
            : '梗概：${bundle.novel.synopsis}',
      );
    }
    if ((bundle.novel.genre ?? '').trim().isNotEmpty) {
      parts.add(md ? '**类型**：${bundle.novel.genre}' : '类型：${bundle.novel.genre}');
    }
    if ((bundle.novel.perspective ?? '').trim().isNotEmpty) {
      parts.add(
        md
            ? '**视角**：${bundle.novel.perspective}'
            : '视角：${bundle.novel.perspective}',
      );
    }

    for (var v = 0; v < bundle.volumes.length; v++) {
      final vol = bundle.volumes[v];
      parts.add(_volumeTitle(vol, v + 1, format));
      final outline = vol.volume.outline?.trim() ?? '';
      if (outline.isNotEmpty) {
        parts.add(md ? '- **卷纲**：$outline' : '卷纲：$outline');
      }
      final arc = vol.emotionArc;
      if (arc.isNotEmpty) {
        parts.add(
          md ? '- **情绪走向**：${arc.join(' → ')}' : '情绪走向：${arc.join(' → ')}',
        );
      }
      for (final rung in vol.conflictLadder) {
        final tp = rung.turningPoint;
        if (tp != null && tp.isNotEmpty) {
          parts.add(
            md
                ? '- **L${rung.level} ${rung.obstacle}（转折：$tp）**'
                : '  L${rung.level} ${rung.obstacle}（转折：$tp）',
          );
        } else {
          parts.add(
            md
                ? '- **L${rung.level}** ${rung.obstacle}'
                : '  L${rung.level} ${rung.obstacle}',
          );
        }
      }
      final gap = vol.infoGap;
      if (gap != null && !gap.isEmpty) {
        parts.add(
          md
              ? '- **信息差**：起点「${gap.start}」→ 终点「${gap.end}」'
              : '信息差：起点「${gap.start}」→ 终点「${gap.end}」',
        );
      }
      for (var c = 0; c < vol.chapters.length; c++) {
        final ch = vol.chapters[c];
        parts.add(
          md
              ? '### 第${c + 1}章：${ch.chapter.title}'
              : '第${c + 1}章：${ch.chapter.title}',
        );
        final detail = ch.chapter.detailedOutline?.trim() ?? '';
        if (detail.isNotEmpty) {
          parts.add(md ? '- **细纲**：$detail' : '  细纲：$detail');
        }
        final cards = ch.sceneCards;
        for (var i = 0; i < cards.length; i++) {
          final card = cards[i];
          parts.add(
            md
                ? '- **场景卡${i + 1}**：目标「${card.goal}」｜阻力「${card.obstacle}」｜钩子「${card.hook}」'
                : '  场景卡${i + 1}：目标「${card.goal}」｜阻力「${card.obstacle}」｜钩子「${card.hook}」',
          );
        }
      }
    }
    return parts.join(_sep);
  }
}
