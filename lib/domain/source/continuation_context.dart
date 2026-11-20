import '../models/source_profile_models.dart';
import 'novel_text_cleaner.dart';

/// 续写上下文装配器：把「截至 X 章」的深度档案（人物快照 + 口癖声音样本 + 未回收伏笔 + 活跃剧情弧 + 设定）
/// 与「已净化的近期原文末尾」按预算装成统一上下文块。
class ContinuationContext {
  const ContinuationContext._();

  static String rendered({
    required SourceNovelProfileData profile,
    String? recentText,
    int maxChars = 4000,
  }) {
    if (maxChars <= 0) return '';
    final sections = <String>[];
    var used = 0;

    final upTo = profile.continuationFromChapter;
    if (upTo != null) {
      final header = '【续写锚点】已读至原作第 $upTo 章，将从第 ${upTo + 1} 章续写';
      sections.add(header);
      used += header.length + 2;
    }

    // 预留给近期原文的预算（如果存在近期原文，保留 ~35%-45% 给文风与场景无缝衔接，先剥离《完》作者感言）
    final cleanRecent = recentText == null
        ? ''
        : NovelTextCleaner.cleanChapterBody(recentText);
    final recentReserve = cleanRecent.isEmpty
        ? 0
        : (maxChars * 0.4).round().clamp(600, 3600);
    final archiveBudget = (maxChars - recentReserve).clamp(400, maxChars);

    void appendBlock(String title, List<String> lines) {
      if (lines.isEmpty || used >= archiveBudget) return;
      final buf = StringBuffer('【$title】');
      var count = 0;
      for (final line in lines) {
        if (used + buf.length + line.length + 2 > archiveBudget) break;
        buf.write('\n- $line');
        count += 1;
      }
      if (count > 0) {
        final text = buf.toString();
        sections.add(text);
        used += text.length + 2;
      }
    }

    appendBlock(
      '人物现状快照',
      profile.characters.map((c) {
        final state = c.currentState ?? c.oneLine ?? '';
        final rel = c.relationships.isEmpty
            ? ''
            : '；关系:${c.relationships.take(3).map((r) => "${r.target}(${r.relation})").join("、")}';
        final voice = c.voiceSamples.isEmpty
            ? ''
            : '；原话口癖:${c.voiceSamples.take(2).join("/")}';
        return '${c.name}：$state$rel$voice';
      }).toList(),
    );

    appendBlock(
      '未回收伏笔',
      profile.openThreads.map((t) {
        final ch = t.plantedChapter != null ? '[第${t.plantedChapter}章]' : '';
        return '$ch${t.title}：${t.detail}';
      }).toList(),
    );

    appendBlock('进行中剧情弧', profile.activeArcs);

    appendBlock(
      '核心设定',
      profile.worldbuilding
          .map((w) => '[${w.category}] ${w.name}：${w.content}')
          .toList(),
    );

    if (cleanRecent.isNotEmpty) {
      final remaining = maxChars - used - 24;
      if (remaining > 200) {
        final snippet = cleanRecent.length <= remaining
            ? cleanRecent
            : cleanRecent.substring(cleanRecent.length - remaining);
        sections.add('【原作近期原文（用于文风与情节衔接）】\n$snippet');
      }
    }

    return sections.join('\n\n');
  }
}
