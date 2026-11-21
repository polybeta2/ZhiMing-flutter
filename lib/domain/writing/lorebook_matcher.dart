import '../../core/database/app_database.dart' as db;
import '../models/novel_domain.dart';
import 'context_builder.dart';

/// 单章按需激活的 Lorebook 选择结果（保持 sortOrder 稳定以利 KV 前缀缓存）。
class LorebookSelection {
  const LorebookSelection({
    required this.characters,
    required this.worldEntries,
    this.triggeredCharacterIds = const {},
    this.triggeredWorldEntryIds = const {},
  });

  final List<db.Character> characters;
  final List<db.WorldEntry> worldEntries;
  final Set<String> triggeredCharacterIds;
  final Set<String> triggeredWorldEntryIds;
}

/// 关键词触发 + 常驻规则的 Lorebook 匹配器：
/// 扫描 [本章细纲 + 场景卡 + 上一章末尾 600 字 + 本章末尾 800 字]，
/// 自动激活相关角色与世界观条目；结果按 sortOrder 稳定排序，避免无谓破坏 KV 缓存前缀。
abstract final class LorebookMatcher {
  static const int defaultMaxCharacters = 16;
  static const int defaultMaxWorldEntries = 16;
  static const int defaultFallbackWorldEntries = 6;

  static LorebookSelection selectForChapter({
    required ChapterBundle chapter,
    required NovelBundle bundle,
    int maxCharacters = defaultMaxCharacters,
    int maxWorldEntries = defaultMaxWorldEntries,
    int fallbackWorldEntries = defaultFallbackWorldEntries,
  }) {
    final probe = buildProbeText(chapter: chapter, bundle: bundle);
    return selectByProbe(
      probeText: probe,
      characters: bundle.characters,
      worldEntries: bundle.worldEntries,
      maxCharacters: maxCharacters,
      maxWorldEntries: maxWorldEntries,
      fallbackWorldEntries: fallbackWorldEntries,
    );
  }

  /// 构造单章扫描探测文本：细纲 + 场景卡 + 上章尾 600 字 + 本章尾 800 字。
  static String buildProbeText({
    required ChapterBundle chapter,
    required NovelBundle bundle,
  }) {
    final buf = StringBuffer();
    buf.writeln(chapter.chapter.title);
    final outline = chapter.chapter.detailedOutline?.trim();
    if (outline != null && outline.isNotEmpty) {
      buf.writeln(outline);
    }
    final cards = chapter.sceneCards;
    if (cards.isNotEmpty) {
      buf.writeln(ContextBuilder.renderSceneCards(cards));
    }

    final all = bundle.allChaptersInOrder;
    final idx = all.indexWhere((c) => c.chapter.id == chapter.chapter.id);
    if (idx > 0) {
      var prevTail = all[idx - 1].chapter.content.trim();
      if (prevTail.length > ContextBuilder.neighborTailLength) {
        prevTail = prevTail.substring(
          prevTail.length - ContextBuilder.neighborTailLength,
        );
      }
      if (prevTail.isNotEmpty) buf.writeln(prevTail);
    }

    var curTail = chapter.chapter.content.trim();
    if (curTail.length > ContextBuilder.tailLength) {
      curTail = curTail.substring(curTail.length - ContextBuilder.tailLength);
    }
    if (curTail.isNotEmpty) buf.writeln(curTail);

    return buf.toString();
  }

  /// 纯函数匹配入口（便于单元测试与事实审稿复用）。
  static LorebookSelection selectByProbe({
    required String probeText,
    required List<db.Character> characters,
    required List<db.WorldEntry> worldEntries,
    int maxCharacters = defaultMaxCharacters,
    int maxWorldEntries = defaultMaxWorldEntries,
    int fallbackWorldEntries = defaultFallbackWorldEntries,
  }) {
    final probeLower = probeText.toLowerCase();

    // 1) 角色匹配：关键词/别名命中 + isSceneRelevant 常驻
    final triggeredChars = <db.Character>[];
    final alwaysOnChars = <db.Character>[];
    final triggeredCharIds = <String>{};

    final orderedChars = [...characters]
      ..sort(_compareCharacter);

    for (final c in orderedChars) {
      final terms = <String>[
        c.name,
        ...decodeStringList(c.aliasesJson),
      ];
      final hit = _matchesAny(probeLower, terms);
      if (hit) {
        triggeredChars.add(c);
        triggeredCharIds.add(c.id);
      } else if (c.isSceneRelevant) {
        alwaysOnChars.add(c);
      }
    }

    final pickedChars = <db.Character>[];
    for (final c in triggeredChars) {
      if (pickedChars.length >= maxCharacters) break;
      pickedChars.add(c);
    }
    for (final c in alwaysOnChars) {
      if (pickedChars.length >= maxCharacters) break;
      pickedChars.add(c);
    }
    // 最终按稳定 sortOrder 排序，保护 KV 前缀缓存
    pickedChars.sort(_compareCharacter);

    // 2) 世界观匹配：条目名/触发关键词命中 + isAlwaysOn 常驻，零命中则回退前 6 条
    final triggeredWorlds = <db.WorldEntry>[];
    final alwaysOnWorlds = <db.WorldEntry>[];
    final triggeredWorldIds = <String>{};

    final orderedWorlds = [...worldEntries]
      ..sort(_compareWorldEntry);

    for (final w in orderedWorlds) {
      final terms = <String>[
        w.name,
        ...decodeStringList(w.keywordsJson),
      ];
      final hit = _matchesAny(probeLower, terms);
      if (hit) {
        triggeredWorlds.add(w);
        triggeredWorldIds.add(w.id);
      } else if (w.isAlwaysOn) {
        alwaysOnWorlds.add(w);
      }
    }

    final pickedWorlds = <db.WorldEntry>[];
    for (final w in triggeredWorlds) {
      if (pickedWorlds.length >= maxWorldEntries) break;
      pickedWorlds.add(w);
    }
    for (final w in alwaysOnWorlds) {
      if (pickedWorlds.length >= maxWorldEntries) break;
      pickedWorlds.add(w);
    }
    if (pickedWorlds.isEmpty && orderedWorlds.isNotEmpty) {
      pickedWorlds.addAll(orderedWorlds.take(fallbackWorldEntries));
    }
    pickedWorlds.sort(_compareWorldEntry);

    return LorebookSelection(
      characters: pickedChars,
      worldEntries: pickedWorlds,
      triggeredCharacterIds: triggeredCharIds,
      triggeredWorldEntryIds: triggeredWorldIds,
    );
  }

  static bool _matchesAny(String probeLower, List<String> terms) {
    if (probeLower.isEmpty) return false;
    for (final raw in terms) {
      final term = raw.trim().toLowerCase();
      if (term.isEmpty) continue;
      if (probeLower.contains(term)) return true;
    }
    return false;
  }

  static int _compareCharacter(db.Character a, db.Character b) {
    final c = a.sortOrder.compareTo(b.sortOrder);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  static int _compareWorldEntry(db.WorldEntry a, db.WorldEntry b) {
    final c = a.sortOrder.compareTo(b.sortOrder);
    return c != 0 ? c : a.id.compareTo(b.id);
  }
}
