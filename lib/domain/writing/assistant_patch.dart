import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../models/novel_domain.dart';

enum AssistantAccessMode {
  readOnly('只读'),
  readWrite('读写');

  const AssistantAccessMode(this.label);
  final String label;
}

class PatchCharUpdate {
  const PatchCharUpdate({required this.find, required this.setFields});
  final String find;
  final Map<String, String> setFields;
}

class PatchCharAdd {
  const PatchCharAdd({
    required this.name,
    this.aliases = const [],
    this.appearance,
    this.personality,
    this.background,
    this.currentGoal,
    this.currentLocation,
    this.physicalState,
    this.mentalState,
  });

  final String name;
  final List<String> aliases;
  final String? appearance;
  final String? personality;
  final String? background;
  final String? currentGoal;
  final String? currentLocation;
  final String? physicalState;
  final String? mentalState;
}

class PatchWorldUpsert {
  const PatchWorldUpsert({
    this.category,
    required this.name,
    required this.content,
  });

  final String? category;
  final String name;
  final String content;
}

class PatchNameRename {
  const PatchNameRename({required this.find, required this.to});
  final String find;
  final String to;
}

class PatchSceneCardDto {
  const PatchSceneCardDto({this.index, this.goal, this.obstacle, this.hook});
  final int? index;
  final String? goal;
  final String? obstacle;
  final String? hook;

  SceneCard? get asCard {
    final g = (goal ?? '').trim();
    final o = (obstacle ?? '').trim();
    final h = (hook ?? '').trim();
    if (g.isEmpty && o.isEmpty && h.isEmpty) return null;
    return SceneCard(goal: g, obstacle: o, hook: h);
  }
}

class PatchSceneCardsOp {
  const PatchSceneCardsOp({
    required this.chapter,
    this.replace = const [],
    this.update = const [],
    this.add = const [],
    this.remove = const [],
  });

  final String chapter;
  final List<PatchSceneCardDto> replace;
  final List<PatchSceneCardDto> update;
  final List<PatchSceneCardDto> add;
  final List<int> remove;
}

class PatchNovelUpdates {
  const PatchNovelUpdates({this.synopsis, this.perspective, this.styleGuide});
  final String? synopsis;
  final String? perspective;
  final String? styleGuide;
}

/// 写作助手 `zm-patch` 补丁协议：提取、逐项预览描述与事务落库。
class AssistantPatch {
  const AssistantPatch({
    this.summary,
    this.characterUpdates = const [],
    this.characterAdds = const [],
    this.worldUpserts = const [],
    this.novelUpdates,
    this.volumeRenames = const [],
    this.chapterRenames = const [],
    this.sceneCards = const [],
  });

  final String? summary;
  final List<PatchCharUpdate> characterUpdates;
  final List<PatchCharAdd> characterAdds;
  final List<PatchWorldUpsert> worldUpserts;
  final PatchNovelUpdates? novelUpdates;
  final List<PatchNameRename> volumeRenames;
  final List<PatchNameRename> chapterRenames;
  final List<PatchSceneCardsOp> sceneCards;

  bool get isEmpty =>
      characterUpdates.isEmpty &&
      characterAdds.isEmpty &&
      worldUpserts.isEmpty &&
      novelUpdates == null &&
      volumeRenames.isEmpty &&
      chapterRenames.isEmpty &&
      sceneCards.isEmpty;

  static ({AssistantPatch? patch, String cleanedText}) extract(String text) {
    final fenceRe = RegExp(r'```[^\n]*\n([\s\S]*?)```');
    for (final m in fenceRe.allMatches(text)) {
      final payload = m.group(1) ?? '';
      final patch = _decode(payload);
      if (patch != null && !patch.isEmpty) {
        final cleaned = text.replaceRange(m.start, m.end, '').trim();
        return (patch: patch, cleanedText: cleaned);
      }
    }
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      final raw = text.substring(firstBrace, lastBrace + 1);
      final patch = _decode(raw);
      if (patch != null && !patch.isEmpty) {
        final cleaned = text.replaceRange(firstBrace, lastBrace + 1, '').trim();
        return (patch: patch, cleanedText: cleaned);
      }
    }
    return (patch: null, cleanedText: text);
  }

  static AssistantPatch? _decode(String source) {
    dynamic raw;
    try {
      raw = jsonDecode(source.trim());
    } catch (_) {
      return null;
    }
    if (raw is! Map<String, dynamic>) return null;

    final charUpdates = <PatchCharUpdate>[];
    if (raw['character_updates'] is List) {
      for (final item in raw['character_updates'] as List) {
        if (item is Map && item['find'] is String && item['set'] is Map) {
          final map = <String, String>{};
          (item['set'] as Map).forEach(
            (k, v) => map[k.toString()] = v.toString(),
          );
          charUpdates.add(
            PatchCharUpdate(find: item['find'] as String, setFields: map),
          );
        }
      }
    }

    final charAdds = <PatchCharAdd>[];
    if (raw['character_adds'] is List) {
      for (final item in raw['character_adds'] as List) {
        if (item is Map && item['name'] is String) {
          final aliases = item['aliases'] is List
              ? (item['aliases'] as List).map((e) => e.toString()).toList()
              : <String>[];
          charAdds.add(
            PatchCharAdd(
              name: item['name'] as String,
              aliases: aliases,
              appearance: item['appearance']?.toString(),
              personality: item['personality']?.toString(),
              background: item['background']?.toString(),
              currentGoal: item['currentGoal']?.toString(),
              currentLocation: item['currentLocation']?.toString(),
              physicalState: item['physicalState']?.toString(),
              mentalState: item['mentalState']?.toString(),
            ),
          );
        }
      }
    }

    final worlds = <PatchWorldUpsert>[];
    if (raw['world_upserts'] is List) {
      for (final item in raw['world_upserts'] as List) {
        if (item is Map && item['name'] is String) {
          worlds.add(
            PatchWorldUpsert(
              category: item['category']?.toString(),
              name: item['name'] as String,
              content: item['content']?.toString() ?? '',
            ),
          );
        }
      }
    }

    PatchNovelUpdates? novelUpd;
    if (raw['novel_updates'] is Map) {
      final m = raw['novel_updates'] as Map;
      final syn = m['synopsis']?.toString();
      final per = m['perspective']?.toString();
      final sg = m['styleGuide']?.toString();
      if ((syn ?? '').trim().isNotEmpty ||
          (per ?? '').trim().isNotEmpty ||
          (sg ?? '').trim().isNotEmpty) {
        novelUpd = PatchNovelUpdates(
          synopsis: syn,
          perspective: per,
          styleGuide: sg,
        );
      }
    }

    List<PatchNameRename> parseRenames(dynamic list) {
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map && item['find'] is String && item['to'] is String)
            PatchNameRename(
              find: item['find'] as String,
              to: item['to'] as String,
            ),
      ];
    }

    PatchSceneCardDto parseCardDto(dynamic item) {
      if (item is! Map) return const PatchSceneCardDto();
      return PatchSceneCardDto(
        index: (item['index'] as num?)?.toInt(),
        goal: item['goal']?.toString(),
        obstacle: item['obstacle']?.toString(),
        hook: item['hook']?.toString(),
      );
    }

    final sceneOps = <PatchSceneCardsOp>[];
    if (raw['scene_cards'] is List) {
      for (final item in raw['scene_cards'] as List) {
        if (item is Map && item['chapter'] is String) {
          sceneOps.add(
            PatchSceneCardsOp(
              chapter: item['chapter'] as String,
              replace: item['replace'] is List
                  ? (item['replace'] as List).map(parseCardDto).toList()
                  : const [],
              update: item['update'] is List
                  ? (item['update'] as List).map(parseCardDto).toList()
                  : const [],
              add: item['add'] is List
                  ? (item['add'] as List).map(parseCardDto).toList()
                  : const [],
              remove: item['remove'] is List
                  ? (item['remove'] as List)
                        .map((e) => (e as num?)?.toInt())
                        .whereType<int>()
                        .toList()
                  : const [],
            ),
          );
        }
      }
    }

    return AssistantPatch(
      summary: raw['summary']?.toString(),
      characterUpdates: charUpdates,
      characterAdds: charAdds,
      worldUpserts: worlds,
      novelUpdates: novelUpd,
      volumeRenames: parseRenames(raw['volume_renames']),
      chapterRenames: parseRenames(raw['chapter_renames']),
      sceneCards: sceneOps,
    );
  }

  // ---- 目标匹配 ----

  static Character? matchCharacter(String query, NovelBundle bundle) {
    final kw = query.trim();
    if (kw.isEmpty) return null;
    for (final c in bundle.characters) {
      if (c.name == kw || decodeStringList(c.aliasesJson).contains(kw)) {
        return c;
      }
    }
    for (final c in bundle.characters) {
      if (c.name.contains(kw) || kw.contains(c.name)) return c;
    }
    return null;
  }

  static VolumeBundle? matchVolume(String query, NovelBundle bundle) {
    final kw = query.trim();
    if (kw.isEmpty) return null;
    for (final v in bundle.volumes) {
      if (v.volume.name == kw) return v;
    }
    final numMatch = RegExp(r'第\s*(\d+)\s*卷').firstMatch(kw);
    if (numMatch != null) {
      final order = int.tryParse(numMatch.group(1)!);
      for (final v in bundle.volumes) {
        if (v.volume.sortOrder == order) return v;
      }
    }
    for (final v in bundle.volumes) {
      if (v.volume.name.contains(kw) || kw.contains(v.volume.name)) return v;
    }
    return null;
  }

  static ChapterBundle? matchChapter(String query, NovelBundle bundle) {
    final kw = query.trim();
    if (kw.isEmpty) return null;
    List<ChapterBundle> candidates;
    var titleKey = kw;
    if (kw.contains('/')) {
      final idx = kw.indexOf('/');
      final volKey = kw.substring(0, idx).trim();
      titleKey = kw.substring(idx + 1).trim();
      candidates =
          matchVolume(volKey, bundle)?.chapters ?? bundle.allChaptersInOrder;
    } else {
      candidates = bundle.allChaptersInOrder;
    }
    for (final c in candidates) {
      if (c.chapter.title == titleKey) return c;
    }
    for (final c in candidates) {
      if (c.chapter.title.contains(titleKey) ||
          titleKey.contains(c.chapter.title)) {
        return c;
      }
    }
    return null;
  }

  /// 人可读拟议变更清单（用于确认卡逐项展示）
  List<String> describe(NovelBundle bundle) {
    final lines = <String>[];
    for (final u in characterUpdates) {
      final target = matchCharacter(u.find, bundle);
      if (target != null) {
        final keys = (u.setFields.keys.toList()..sort()).join('、');
        lines.add('角色「${target.name}」更新：$keys');
      } else {
        lines.add('⚠️ 未找到角色「${u.find}」（应用时将跳过）');
      }
    }
    for (final a in characterAdds) {
      if (a.name.trim().isNotEmpty) lines.add('新增角色「${a.name.trim()}」');
    }
    for (final w in worldUpserts) {
      final name = w.name.trim();
      if (name.isEmpty) continue;
      final exists = bundle.worldEntries.any((e) => e.name == name);
      lines.add('${exists ? '更新' : '新增'}世界观「$name」');
    }
    for (final r in volumeRenames) {
      final target = matchVolume(r.find, bundle);
      if (target != null) {
        lines.add('卷「${target.volume.name}」重命名为「${r.to.trim()}」');
      } else {
        lines.add('⚠️ 未找到卷「${r.find}」（将跳过）');
      }
    }
    for (final r in chapterRenames) {
      final target = matchChapter(r.find, bundle);
      if (target != null) {
        lines.add('章节「${target.chapter.title}」重命名为「${r.to.trim()}」');
      } else {
        lines.add('⚠️ 未找到章节「${r.find}」（将跳过）');
      }
    }
    for (final op in sceneCards) {
      final ch = matchChapter(op.chapter, bundle);
      if (ch == null) {
        lines.add('⚠️ 未找到章节「${op.chapter}」（场景卡变更将跳过）');
        continue;
      }
      final parts = <String>[];
      if (op.replace.isNotEmpty) parts.add('整组替换 ${op.replace.length} 张');
      if (op.update.isNotEmpty) parts.add('更新 ${op.update.length} 处');
      if (op.add.isNotEmpty) parts.add('新增 ${op.add.length} 张');
      if (op.remove.isNotEmpty) parts.add('删除 ${op.remove.length} 张');
      if (parts.isNotEmpty) {
        lines.add('《${ch.chapter.title}》场景卡：${parts.join('、')}');
      }
    }
    if (novelUpdates != null) {
      if ((novelUpdates!.synopsis ?? '').trim().isNotEmpty) {
        lines.add('更新作品梗概');
      }
      if ((novelUpdates!.perspective ?? '').trim().isNotEmpty) {
        lines.add('更新叙事视角');
      }
      if ((novelUpdates!.styleGuide ?? '').trim().isNotEmpty) {
        lines.add('更新风格约束');
      }
    }
    return lines;
  }

  /// 事务应用到 SQLite，返回逐条执行回执
  Future<List<String>> applyToDb({
    required AppDatabase db,
    required NovelBundle bundle,
  }) async {
    const uuid = Uuid();
    final results = <String>[];
    final novelId = bundle.novel.id;

    await db.transaction(() async {
      for (final u in characterUpdates) {
        final target = matchCharacter(u.find, bundle);
        if (target == null) {
          results.add('⚠️ 未找到角色「${u.find}」，已跳过');
          continue;
        }
        var comp = const CharactersCompanion();
        final changed = <String>[];
        u.setFields.forEach((field, rawVal) {
          final v = rawVal.trim();
          if (v.isEmpty) return;
          switch (field) {
            case 'name':
              comp = comp.copyWith(name: Value(v));
              changed.add(field);
            case 'aliases':
              final list = v
                  .split(RegExp(r'[,，、]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              comp = comp.copyWith(aliasesJson: Value(encodeStringList(list)));
              changed.add(field);
            case 'appearance':
              comp = comp.copyWith(appearance: Value(v));
              changed.add(field);
            case 'personality':
              comp = comp.copyWith(personality: Value(v));
              changed.add(field);
            case 'background':
              comp = comp.copyWith(background: Value(v));
              changed.add(field);
            case 'currentGoal':
              comp = comp.copyWith(currentGoal: Value(v));
              changed.add(field);
            case 'currentLocation':
              comp = comp.copyWith(currentLocation: Value(v));
              changed.add(field);
            case 'physicalState':
              comp = comp.copyWith(physicalState: Value(v));
              changed.add(field);
            case 'mentalState':
              comp = comp.copyWith(mentalState: Value(v));
              changed.add(field);
            case 'isSceneRelevant':
              final b = v.toLowerCase() == 'true' || v == '1';
              comp = comp.copyWith(isSceneRelevant: Value(b));
              changed.add(field);
          }
        });
        if (changed.isNotEmpty) {
          await (db.update(
            db.characters,
          )..where((t) => t.id.equals(target.id))).write(comp);
          changed.sort();
          results.add('✅ 角色「${target.name}」：${changed.join('、')}');
        }
      }

      for (final a in characterAdds) {
        final name = a.name.trim();
        if (name.isEmpty) continue;
        await db.upsertCharacter(
          CharactersCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            name: name,
            aliasesJson: Value(encodeStringList(a.aliases)),
            appearance: Value(a.appearance),
            personality: Value(a.personality),
            background: Value(a.background),
            currentGoal: Value(a.currentGoal),
            currentLocation: Value(a.currentLocation),
            physicalState: Value(a.physicalState),
            mentalState: Value(a.mentalState),
          ),
        );
        results.add('✅ 新增角色「$name」');
      }

      for (final w in worldUpserts) {
        final name = w.name.trim();
        if (name.isEmpty) continue;
        final existing = bundle.worldEntries
            .where((e) => e.name == name)
            .firstOrNull;
        if (existing != null) {
          await (db.update(db.worldEntries)
                ..where((t) => t.id.equals(existing.id)))
              .write(WorldEntriesCompanion(content: Value(w.content)));
          results.add('✅ 更新世界观「$name」');
        } else {
          final cat = WorldCategories.all.contains(w.category)
              ? w.category!
              : '其他';
          await db.upsertWorldEntry(
            WorldEntriesCompanion.insert(
              id: uuid.v4(),
              novelId: novelId,
              category: cat,
              name: name,
              content: Value(w.content),
            ),
          );
          results.add('✅ 新增世界观「$name」');
        }
      }

      for (final r in volumeRenames) {
        final to = r.to.trim();
        if (to.isEmpty) continue;
        final target = matchVolume(r.find, bundle);
        if (target == null) {
          results.add('⚠️ 未找到卷「${r.find}」，已跳过');
          continue;
        }
        await (db.update(db.volumes)
              ..where((t) => t.id.equals(target.volume.id)))
            .write(VolumesCompanion(name: Value(to)));
        results.add('✅ 卷「${target.volume.name}」→「$to」');
      }

      for (final r in chapterRenames) {
        final to = r.to.trim();
        if (to.isEmpty) continue;
        final target = matchChapter(r.find, bundle);
        if (target == null) {
          results.add('⚠️ 未找到章节「${r.find}」，已跳过');
          continue;
        }
        await (db.update(db.chapters)
              ..where((t) => t.id.equals(target.chapter.id)))
            .write(ChaptersCompanion(title: Value(to)));
        results.add('✅ 章节「${target.chapter.title}」→「$to」');
      }

      for (final op in sceneCards) {
        final target = matchChapter(op.chapter, bundle);
        if (target == null) {
          results.add('⚠️ 未找到章节「${op.chapter}」，场景卡变更已跳过');
          continue;
        }
        var cards = List<SceneCard>.from(target.sceneCards);
        final actions = <String>[];
        if (op.replace.isNotEmpty) {
          cards = op.replace.map((d) => d.asCard).whereType<SceneCard>().toList();
          actions.add('整组替换为 ${cards.length} 张');
        } else {
          var touched = 0;
          for (final dto in op.update) {
            final idx = (dto.index ?? 0) - 1;
            if (idx < 0 || idx >= cards.length) continue;
            final cur = cards[idx];
            cards[idx] = SceneCard(
              goal: (dto.goal ?? '').trim().isNotEmpty
                  ? dto.goal!.trim()
                  : cur.goal,
              obstacle: (dto.obstacle ?? '').trim().isNotEmpty
                  ? dto.obstacle!.trim()
                  : cur.obstacle,
              hook: (dto.hook ?? '').trim().isNotEmpty
                  ? dto.hook!.trim()
                  : cur.hook,
            );
            touched++;
          }
          if (touched > 0) actions.add('更新 $touched 处');

          final validRem = op.remove
              .where((i) => i >= 1 && i <= cards.length)
              .toList()
            ..sort((a, b) => b.compareTo(a));
          for (final idx in validRem) {
            cards.removeAt(idx - 1);
          }
          if (validRem.isNotEmpty) actions.add('删除 ${validRem.length} 张');

          final added = op.add.map((d) => d.asCard).whereType<SceneCard>().toList();
          cards.addAll(added);
          if (added.isNotEmpty) actions.add('新增 ${added.length} 张');
        }
        await (db.update(db.chapters)
              ..where((t) => t.id.equals(target.chapter.id)))
            .write(
              ChaptersCompanion(
                sceneCardsJson: Value(SceneCard.encodeList(cards)),
              ),
            );
        results.add('✅ 《${target.chapter.title}》场景卡：${actions.join('、')}');
      }

      if (novelUpdates != null) {
        var comp = const NovelsCompanion();
        if ((novelUpdates!.synopsis ?? '').trim().isNotEmpty) {
          comp = comp.copyWith(synopsis: Value(novelUpdates!.synopsis!.trim()));
          results.add('✅ 更新作品梗概');
        }
        if ((novelUpdates!.perspective ?? '').trim().isNotEmpty) {
          comp = comp.copyWith(
            perspective: Value(novelUpdates!.perspective!.trim()),
          );
          results.add('✅ 更新叙事视角');
        }
        if ((novelUpdates!.styleGuide ?? '').trim().isNotEmpty) {
          comp = comp.copyWith(
            styleGuide: Value(novelUpdates!.styleGuide!.trim()),
          );
          results.add('✅ 更新风格约束');
        }
        await (db.update(
          db.novels,
        )..where((t) => t.id.equals(novelId))).write(comp);
      }

      await (db.update(db.novels)..where((t) => t.id.equals(novelId))).write(
        NovelsCompanion(updatedAt: Value(DateTime.now())),
      );
    });
    return results;
  }
}
