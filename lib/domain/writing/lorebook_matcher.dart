import '../../core/database/app_database.dart' as db;
import '../models/novel_domain.dart';
import 'context_builder.dart';

/// 单章按需激活的 Lorebook 选择结果（保持 sortOrder 稳定以利 KV 前缀缓存）。
class LorebookSelection {
  const LorebookSelection({
    required this.characters,
    required this.worldEntries,
    this.relations = const [],
    this.triggeredCharacterIds = const {},
    this.triggeredWorldEntryIds = const {},
  });

  final List<db.Character> characters;
  final List<db.WorldEntry> worldEntries;
  final List<db.CharacterRelation> relations;
  final Set<String> triggeredCharacterIds;
  final Set<String> triggeredWorldEntryIds;
}

/// 关键词触发 + 常驻规则的 Lorebook 匹配器：
/// 扫描 [本章细纲 + 场景卡 + 上一章末尾 600 字 + 本章末尾 800 字]，
/// 自动激活相关角色、1-hop 高强/暗线关联角色、结构化关系边与世界观条目；
/// 结果按 sortOrder/id 稳定排序，避免无谓破坏 KV 缓存前缀。
abstract final class LorebookMatcher {
  static const int defaultMaxCharacters = 16;
  static const int defaultMaxWorldEntries = 16;
  static const int defaultFallbackWorldEntries = 6;
  static const int defaultMaxRelations = 12;

  static LorebookSelection selectForChapter({
    required ChapterBundle chapter,
    required NovelBundle bundle,
    int maxCharacters = defaultMaxCharacters,
    int maxWorldEntries = defaultMaxWorldEntries,
    int fallbackWorldEntries = defaultFallbackWorldEntries,
    int maxRelations = defaultMaxRelations,
  }) {
    final probe = buildProbeText(chapter: chapter, bundle: bundle);
    return selectByProbe(
      probeText: probe,
      characters: bundle.characters,
      worldEntries: bundle.worldEntries,
      relations: bundle.relations,
      maxCharacters: maxCharacters,
      maxWorldEntries: maxWorldEntries,
      fallbackWorldEntries: fallbackWorldEntries,
      maxRelations: maxRelations,
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
    List<db.CharacterRelation> relations = const [],
    int maxCharacters = defaultMaxCharacters,
    int maxWorldEntries = defaultMaxWorldEntries,
    int fallbackWorldEntries = defaultFallbackWorldEntries,
    int maxRelations = defaultMaxRelations,
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
    final pickedCharIds = <String>{};
    for (final c in triggeredChars) {
      if (pickedChars.length >= maxCharacters) break;
      if (pickedCharIds.add(c.id)) pickedChars.add(c);
    }

    // 1.5) 1-hop 关系联带召回：若触发角色存在高强度(>=4)或暗线关系，补入对手方角色
    if (relations.isNotEmpty &&
        triggeredCharIds.isNotEmpty &&
        pickedChars.length < maxCharacters) {
      final charById = {for (final c in orderedChars) c.id: c};
      final sortedRels = [...relations]..sort((a, b) => a.id.compareTo(b.id));
      for (final r in sortedRels) {
        if (pickedChars.length >= maxCharacters) break;
        if (r.status == 'broken') continue;
        final isPriority = r.strength >= 4 || r.line == '暗线';
        if (!isPriority) continue;
        String? partnerId;
        if (triggeredCharIds.contains(r.sourceCharacterId)) {
          partnerId = r.targetCharacterId;
        } else if (triggeredCharIds.contains(r.targetCharacterId)) {
          partnerId = r.sourceCharacterId;
        }
        if (partnerId != null && !pickedCharIds.contains(partnerId)) {
          final partner = charById[partnerId];
          if (partner != null && pickedCharIds.add(partner.id)) {
            pickedChars.add(partner);
          }
        }
      }
    }

    for (final c in alwaysOnChars) {
      if (pickedChars.length >= maxCharacters) break;
      if (pickedCharIds.add(c.id)) pickedChars.add(c);
    }
    // 最终按稳定 sortOrder 排序，保护 KV 前缀缓存
    pickedChars.sort(_compareCharacter);

    // 1.8) 筛选与入选角色相关的结构化关系边（稳定排序保护 KV 前缀）
    final pickedRelations = <db.CharacterRelation>[];
    if (relations.isNotEmpty && pickedCharIds.isNotEmpty) {
      final candidates = relations.where((r) {
        if (r.status == 'broken') return false;
        final bothIn =
            pickedCharIds.contains(r.sourceCharacterId) &&
            pickedCharIds.contains(r.targetCharacterId);
        if (bothIn) return true;
        final touchTriggered =
            triggeredCharIds.contains(r.sourceCharacterId) ||
            triggeredCharIds.contains(r.targetCharacterId);
        return touchTriggered && (r.strength >= 4 || r.line == '暗线');
      }).toList()
        ..sort((a, b) {
          final darkA = a.line == '暗线' ? 1 : 0;
          final darkB = b.line == '暗线' ? 1 : 0;
          final cmp = (b.strength + darkB * 2).compareTo(a.strength + darkA * 2);
          return cmp != 0 ? cmp : a.id.compareTo(b.id);
        });
      pickedRelations.addAll(candidates.take(maxRelations));
      pickedRelations.sort((a, b) => a.id.compareTo(b.id));
    }

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
      relations: pickedRelations,
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
