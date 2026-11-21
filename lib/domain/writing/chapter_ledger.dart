import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/llm/llm_json_parser.dart';
import '../models/novel_domain.dart';

/// 单章提取出的已有角色状态增量（仅含本章发生变化的字段）。
class CharacterStateDelta {
  const CharacterStateDelta({
    required this.name,
    this.currentLocation,
    this.physicalState,
    this.mentalState,
    this.currentGoal,
  });

  final String name;
  final String? currentLocation;
  final String? physicalState;
  final String? mentalState;
  final String? currentGoal;

  bool get hasChanges =>
      currentLocation != null ||
      physicalState != null ||
      mentalState != null ||
      currentGoal != null;

  String describeChanges() {
    final parts = <String>[];
    if (currentLocation != null) parts.add('位置 → $currentLocation');
    if (physicalState != null) parts.add('身体 → $physicalState');
    if (mentalState != null) parts.add('心理 → $mentalState');
    if (currentGoal != null) parts.add('目标 → $currentGoal');
    return parts.join(' · ');
  }

  static CharacterStateDelta? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final name = _cleanText(raw['name']);
    if (name == null) return null;
    final delta = CharacterStateDelta(
      name: name,
      currentLocation: _cleanDeltaField(raw['current_location']),
      physicalState: _cleanDeltaField(raw['physical_state']),
      mentalState: _cleanDeltaField(raw['mental_state']),
      currentGoal: _cleanDeltaField(raw['current_goal']),
    );
    return delta.hasChanges ? delta : null;
  }
}

/// 单章提取出的新出场具名角色。
class NewCharacterEntry {
  const NewCharacterEntry({
    required this.name,
    this.aliases = const [],
    this.personality,
    this.appearance,
    this.currentLocation,
    this.currentGoal,
  });

  final String name;
  final List<String> aliases;
  final String? personality;
  final String? appearance;
  final String? currentLocation;
  final String? currentGoal;

  static NewCharacterEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final name = _cleanText(raw['name']);
    if (name == null) return null;
    final aliasesRaw = raw['aliases'];
    final aliases = aliasesRaw is List
        ? aliasesRaw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty && s != name)
              .toList()
        : <String>[];
    return NewCharacterEntry(
      name: name,
      aliases: aliases,
      personality: _cleanText(raw['personality']),
      appearance: _cleanText(raw['appearance']),
      currentLocation: _cleanText(raw['current_location']),
      currentGoal: _cleanText(raw['current_goal']),
    );
  }
}

/// 单章提取出的新世界观条目（附带 Lorebook 触发关键词）。
class NewWorldEntry {
  const NewWorldEntry({
    required this.category,
    required this.name,
    this.keywords = const [],
    required this.content,
  });

  final String category;
  final String name;
  final List<String> keywords;
  final String content;

  static NewWorldEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final name = _cleanText(raw['name']);
    final content = _cleanText(raw['content']);
    if (name == null || content == null) return null;
    final rawCat = _cleanText(raw['category']) ?? '其他';
    final category = WorldCategories.all.contains(rawCat) ? rawCat : '其他';
    final kwRaw = raw['keywords'];
    final keywords = kwRaw is List
        ? kwRaw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .take(8)
              .toList()
        : <String>[];
    return NewWorldEntry(
      category: category,
      name: name,
      keywords: keywords,
      content: content,
    );
  }
}

/// 活体账本单次提取完整结果（兼容旧 SummaryResult 结构并扩展实体增量）。
class ChapterLedgerExtraction {
  const ChapterLedgerExtraction({
    required this.summaryResult,
    this.characterDeltas = const [],
    this.newCharacters = const [],
    this.newWorldEntries = const [],
  });

  final SummaryResult summaryResult;
  final List<CharacterStateDelta> characterDeltas;
  final List<NewCharacterEntry> newCharacters;
  final List<NewWorldEntry> newWorldEntries;

  bool get hasWriteBackCandidates =>
      characterDeltas.isNotEmpty ||
      newCharacters.isNotEmpty ||
      newWorldEntries.isNotEmpty ||
      summaryResult.newForeshadowings.isNotEmpty ||
      summaryResult.resolvedForeshadowingTitles.isNotEmpty;

  static ChapterLedgerExtraction? tryParse(String raw) {
    return LLMJSONParser.decodeObject(raw, (json) {
      final summary = json['summary']?.toString() ?? '';
      if (summary.trim().isEmpty) {
        throw const FormatException('missing summary');
      }
      final factsRaw = json['key_facts'];
      final keyFacts = factsRaw is List
          ? factsRaw
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList()
          : <String>[];
      final newFsRaw = json['new_foreshadowings'];
      final newForeshadowings = newFsRaw is List
          ? newFsRaw.map(ForeshadowExtraction.fromJson).toList()
          : <ForeshadowExtraction>[];
      final resolvedRaw = json['resolved_foreshadowing_titles'];
      final resolvedTitles = resolvedRaw is List
          ? resolvedRaw
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList()
          : <String>[];

      final deltasRaw = json['character_deltas'];
      final deltas = deltasRaw is List
          ? deltasRaw
                .map(CharacterStateDelta.fromJson)
                .whereType<CharacterStateDelta>()
                .take(12)
                .toList()
          : <CharacterStateDelta>[];

      final newCharsRaw = json['new_characters'];
      final newChars = newCharsRaw is List
          ? newCharsRaw
                .map(NewCharacterEntry.fromJson)
                .whereType<NewCharacterEntry>()
                .take(8)
                .toList()
          : <NewCharacterEntry>[];

      final newWorldsRaw = json['new_world_entries'];
      final newWorlds = newWorldsRaw is List
          ? newWorldsRaw
                .map(NewWorldEntry.fromJson)
                .whereType<NewWorldEntry>()
                .take(8)
                .toList()
          : <NewWorldEntry>[];

      return ChapterLedgerExtraction(
        summaryResult: SummaryResult(
          summary: summary,
          keyFacts: keyFacts,
          newForeshadowings: newForeshadowings,
          resolvedForeshadowingTitles: resolvedTitles,
        ),
        characterDeltas: deltas,
        newCharacters: newChars,
        newWorldEntries: newWorlds,
      );
    });
  }
}

/// 活体账本写回统计结果。
class LedgerApplyReport {
  const LedgerApplyReport({
    this.updatedCharacters = 0,
    this.createdCharacters = 0,
    this.createdWorldEntries = 0,
    this.createdForeshadowings = 0,
    this.flaggedResolvedForeshadowings = 0,
  });

  final int updatedCharacters;
  final int createdCharacters;
  final int createdWorldEntries;
  final int createdForeshadowings;
  final int flaggedResolvedForeshadowings;

  int get totalEntityMutations =>
      updatedCharacters +
      createdCharacters +
      createdWorldEntries +
      createdForeshadowings +
      flaggedResolvedForeshadowings;

  String formatSummary() {
    final parts = <String>[];
    if (updatedCharacters > 0) parts.add('角色状态更新 $updatedCharacters');
    if (createdCharacters > 0) parts.add('新增角色 $createdCharacters');
    if (createdWorldEntries > 0) parts.add('新增设定 $createdWorldEntries');
    if (createdForeshadowings > 0) parts.add('新伏笔 $createdForeshadowings');
    if (flaggedResolvedForeshadowings > 0) {
      parts.add('待确认回收伏笔 $flaggedResolvedForeshadowings');
    }
    return parts.isEmpty ? '已更新摘要与关键事实' : parts.join(' · ');
  }
}

/// 活体账本事务写回器：
/// - 手动建档模式：传入勾选集合（selected*Indices），只应用作者确认的条目；
/// - 自动撰写流水线模式：省略勾选集合（默认全选），单章完成后自动推进角色状态与新实体。
abstract final class ChapterLedgerApplier {
  static const _uuid = Uuid();

  static Future<LedgerApplyReport> applyToDb({
    required AppDatabase db,
    required NovelRepository repo,
    required String novelId,
    required Chapter chapter,
    required ChapterLedgerExtraction extraction,
    bool applySummary = true,
    Set<int>? selectedDeltaIndices,
    Set<int>? selectedNewCharacterIndices,
    Set<int>? selectedNewWorldIndices,
    Set<int>? selectedNewForeshadowIndices,
    Set<int>? selectedResolvedForeshadowIndices,
  }) async {
    var createdFsCount = 0;
    var resolvedFsCount = 0;

    if (applySummary) {
      final filteredNewFs = [
        for (var i = 0; i < extraction.summaryResult.newForeshadowings.length; i++)
          if (selectedNewForeshadowIndices == null ||
              selectedNewForeshadowIndices.contains(i))
            extraction.summaryResult.newForeshadowings[i],
      ];
      final filteredResolvedFs = [
        for (var i = 0;
            i < extraction.summaryResult.resolvedForeshadowingTitles.length;
            i++)
          if (selectedResolvedForeshadowIndices == null ||
              selectedResolvedForeshadowIndices.contains(i))
            extraction.summaryResult.resolvedForeshadowingTitles[i],
      ];

      final beforeFs = await db.getForeshadowings(novelId);
      final beforeSuggestedIds = beforeFs
          .where((f) => f.suggestedResolved)
          .map((f) => f.id)
          .toSet();

      await repo.applySummaryResult(
        novelId: novelId,
        chapter: chapter,
        result: SummaryResult(
          summary: extraction.summaryResult.summary,
          keyFacts: extraction.summaryResult.keyFacts,
          newForeshadowings: filteredNewFs,
          resolvedForeshadowingTitles: filteredResolvedFs,
        ),
      );

      final afterFs = await db.getForeshadowings(novelId);
      createdFsCount = (afterFs.length - beforeFs.length).clamp(0, 100);
      resolvedFsCount = afterFs
          .where((f) => f.suggestedResolved && !beforeSuggestedIds.contains(f.id))
          .length;
    }

    var updatedChars = 0;
    var createdChars = 0;
    var createdWorlds = 0;

    final existingChars = await db.getCharacters(novelId);
    final knownCharKeys = <String, Character>{};
    for (final c in existingChars) {
      knownCharKeys[c.name.trim().toLowerCase()] = c;
      for (final a in decodeStringList(c.aliasesJson)) {
        final k = a.trim().toLowerCase();
        if (k.isNotEmpty) knownCharKeys.putIfAbsent(k, () => c);
      }
    }

    // 1) 应用已有角色状态增量（非破坏性局部更新）
    for (var i = 0; i < extraction.characterDeltas.length; i++) {
      if (selectedDeltaIndices != null && !selectedDeltaIndices.contains(i)) {
        continue;
      }
      final delta = extraction.characterDeltas[i];
      if (!delta.hasChanges) continue;
      final hit = knownCharKeys[delta.name.trim().toLowerCase()];
      if (hit == null) continue;
      await (db.update(db.characters)..where((t) => t.id.equals(hit.id))).write(
        CharactersCompanion(
          currentLocation: delta.currentLocation != null
              ? Value(delta.currentLocation)
              : const Value.absent(),
          physicalState: delta.physicalState != null
              ? Value(delta.physicalState)
              : const Value.absent(),
          mentalState: delta.mentalState != null
              ? Value(delta.mentalState)
              : const Value.absent(),
          currentGoal: delta.currentGoal != null
              ? Value(delta.currentGoal)
              : const Value.absent(),
          lastSeenChapterTitle: Value(chapter.title),
        ),
      );
      updatedChars++;
    }

    // 2) 创建新具名角色（按姓名与别名去重）
    var nextCharOrder = existingChars.isEmpty
        ? 0
        : existingChars
                  .map((c) => c.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    for (var i = 0; i < extraction.newCharacters.length; i++) {
      if (selectedNewCharacterIndices != null &&
          !selectedNewCharacterIndices.contains(i)) {
        continue;
      }
      final entry = extraction.newCharacters[i];
      final norm = entry.name.trim().toLowerCase();
      if (norm.isEmpty || knownCharKeys.containsKey(norm)) continue;
      final id = _uuid.v4();
      await db.upsertCharacter(
        CharactersCompanion.insert(
          id: id,
          novelId: novelId,
          name: entry.name.trim(),
          aliasesJson: Value(encodeStringList(entry.aliases)),
          personality: Value(entry.personality),
          appearance: Value(entry.appearance),
          currentLocation: Value(entry.currentLocation),
          currentGoal: Value(entry.currentGoal),
          lastSeenChapterTitle: Value(chapter.title),
          isSceneRelevant: const Value(true),
          sortOrder: Value(nextCharOrder++),
        ),
      );
      final inserted = (await db.getCharacters(
        novelId,
      )).where((c) => c.id == id).firstOrNull;
      if (inserted != null) {
        knownCharKeys[norm] = inserted;
      }
      createdChars++;
    }

    // 3) 创建新世界观条目（按名称去重）
    final existingWorlds = await db.getWorldEntries(novelId);
    final knownWorldNames = existingWorlds
        .map((w) => w.name.trim().toLowerCase())
        .toSet();
    var nextWorldOrder = existingWorlds.isEmpty
        ? 0
        : existingWorlds
                  .map((w) => w.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    for (var i = 0; i < extraction.newWorldEntries.length; i++) {
      if (selectedNewWorldIndices != null &&
          !selectedNewWorldIndices.contains(i)) {
        continue;
      }
      final entry = extraction.newWorldEntries[i];
      final norm = entry.name.trim().toLowerCase();
      if (norm.isEmpty || knownWorldNames.contains(norm)) continue;
      await db.upsertWorldEntry(
        WorldEntriesCompanion.insert(
          id: _uuid.v4(),
          novelId: novelId,
          category: entry.category,
          name: entry.name.trim(),
          content: Value(entry.content.trim()),
          keywordsJson: Value(encodeStringList(entry.keywords)),
          isAlwaysOn: const Value(false),
          sortOrder: Value(nextWorldOrder++),
        ),
      );
      knownWorldNames.add(norm);
      createdWorlds++;
    }

    if (updatedChars > 0 || createdChars > 0 || createdWorlds > 0) {
      await repo.touchNovel(novelId);
    }

    return LedgerApplyReport(
      updatedCharacters: updatedChars,
      createdCharacters: createdChars,
      createdWorldEntries: createdWorlds,
      createdForeshadowings: createdFsCount,
      flaggedResolvedForeshadowings: resolvedFsCount,
    );
  }
}

String? _cleanText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return null;
  return s;
}

const Set<String> _noChangeSentinels = {
  '无',
  '无变化',
  '未变化',
  '不变',
  '保持不变',
  '暂无',
  '未知',
  'none',
  'n/a',
  'unchanged',
  '-',
};

String? _cleanDeltaField(dynamic v) {
  final s = _cleanText(v);
  if (s == null) return null;
  if (_noChangeSentinels.contains(s.toLowerCase())) return null;
  return s;
}
