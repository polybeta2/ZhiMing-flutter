# Phase 2: 作品内活体人物关系图谱、故事时间线引擎与交互可视化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Drift SQLite v3 中落地结构化「人物关系表」与「故事时间线表」，打通续写无损入库、写作期零额外调用活账本演进、Lorebook/ContextBuilder/5 维事实审稿深度联动，并交付纯 Flutter 原生交互式人物关系图谱与故事时间轴 UI。

**Architecture:** 在 Phase 1 产出的统一 `SourceNovelProfileData` 之上，将 `AppDatabase.schemaVersion` 从 `2` 无损升级至 `3`（新增 `CharacterRelations` 与 `TimelineEvents` 两张表及增量列）；扩展现有 `PromptID.summarize` 单次调用实现关系与时间线的增量回写（零额外 API 轮次）；纯 Flutter `InteractiveViewer` + 阵营扇区力导向 `CustomPainter` 打造通用 `CharacterGraphCanvas` 与 `StoryTimelineView`，同时复用于作品工作台与原作档案详情。

**Tech Stack:** Flutter / Dart 3, Drift SQLite + `build_runner`, Riverpod, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-11-21-graph-reduce-scan-and-living-story-graph-design.md`

**Prerequisite:** Phase 1 Plan (`docs/superpowers/plans/2026-11-21-phase1-graph-reduce-precision-scan.md`) completed and green.

## Global Constraints

- 必须采用 Drift `schemaVersion = 3` 增量无损迁移（`createTable` + `addColumn`），不破坏现有 v1/v2 本地书库。
- 写作期关系变动与时间线提取必须复用现有 `PromptID.summarize` 单次请求，不增加额外 API 轮次，且 `maxTokens >= 12288`。
- `LorebookMatcher` 与 `ContextBuilder` 新增的关系网/时间线块必须保持排序确定性，不破坏 Static-First KV 缓存前缀。
- 关系图谱与时间轴组件零第三方图表/WebView 依赖，Windows 桌面端（>=1024dp）与 iOS 移动端均流畅可用。
- 不实现存量旧书批量回溯补扫入口（遵循 Spec 非目标）。
- 每次修改 Drift 表结构后必须运行 `dart run build_runner build --delete-conflicting-outputs`。
- 完成后运行 `flutter analyze`（0 问题）与 `flutter test`（全绿）。

---

## File Structure

- Modify: `lib/core/database/tables.dart` — 新增 `CharacterRelations`、`TimelineEvents` 表；`Characters` 新增 `camp`, `role`, `arcJson`；`Foreshadowings` 新增 `involvedCharactersJson`, `resolvedChapterOrder`, `payoffDetail`
- Modify: `lib/core/database/app_database.dart` + regenerate `app_database.g.dart` — `schemaVersion = 3`、`onUpgrade` 迁移与两张新表 CRUD/Stream 方法
- Modify: `lib/domain/models/novel_domain.dart` — 新增 `RelationEvolutionPoint`、`CharacterArcPoint` 编解码模型；`NovelBundle` 增加 `relations` 与 `timelineEvents`
- Modify: `lib/core/database/novel_repository.dart` — `loadBundle` 同步加载 `relations` 与 `timelineEvents`
- Modify: `lib/features/source_archive/source_injection_helper.dart` & `lib/domain/source/continuation_context.dart` — 续写建书无损写入全量角色、关系边、时间线事件与带状态伏笔
- Modify: `lib/core/prompts/prompt_defaults.dart` & `lib/core/prompts/prompt_templates.dart` — `PromptID.summarize` 增补 `relationship_deltas` & `timeline_events`
- Modify: `lib/domain/writing/chapter_ledger.dart` — `RelationshipDelta`、`NewTimelineEvent` 解析与 `ChapterLedgerApplier` 写回（关系演变追加不覆盖历史）
- Modify: `lib/features/editor/chapter_editor_widget.dart` & `lib/features/editor/auto_write_sheet.dart` — 手动摘要勾选卡与自动撰写日志展示关系/时间线更新
- Modify: `lib/domain/writing/lorebook_matcher.dart` & `lib/domain/writing/context_builder.dart` & `lib/domain/writing/fact_review_service.dart` — 关系网 1-hop 联带召回、时间线锚点注入、5 维审稿增强
- Create: `lib/core/widgets/character_graph_canvas.dart` — 纯 Flutter 原生交互式人物关系图谱（阵营扇区 + 确定性力导向布局 + 星图/列表双视图 + 1-hop 聚焦与 CRUD 回调）
- Create: `lib/core/widgets/story_timeline_view.dart` — 故事时间线视图（阶段分节 + 筛选 + 伏笔徽章 + 跳章与 CRUD 回调）
- Modify: `lib/features/settings_book/book_settings_view.dart` — 设定集 3→4 段新增「关系图谱」页（含新增/编辑/删除关系弹窗）
- Modify: `lib/features/outline/outline_and_foreshadow_view.dart` & `lib/features/workspace/novel_workspace_page.dart` — 大纲伏笔 2→3 段新增「故事时间线」页、升级伏笔台账状态展示并接线 `onJumpToChapter`
- Modify: `lib/features/source_archive/source_profile_detail_dialog.dart` — 原作档案详情 4→5 Tab 复用 `CharacterGraphCanvas` 与 `StoryTimelineView`
- Create: `test/living_story_graph_test.dart` — Phase 2 数据层、写作闭环与 UI 回归测试

---

### Task 1: Drift SQLite Schema v2 → v3 迁移与 `NovelBundle` 扩展

**Files:**
- Modify: `lib/core/database/tables.dart`
- Modify: `lib/core/database/app_database.dart` (regenerate `lib/core/database/app_database.g.dart`)
- Modify: `lib/domain/models/novel_domain.dart`
- Modify: `lib/core/database/novel_repository.dart`
- Test: `test/living_story_graph_test.dart`

**Interfaces:**
- Consumes: 现有 `AppDatabase` v2、`NovelBundle`
- Produces:
  - Drift 表 `CharacterRelations` (`CharacterRelation`, `CharacterRelationsCompanion`) 与 `TimelineEvents` (`TimelineEvent`, `TimelineEventsCompanion`)
  - `AppDatabase` 方法：`watchCharacterRelations`, `getCharacterRelations`, `upsertCharacterRelation`, `deleteCharacterRelation`, `watchTimelineEvents`, `getTimelineEvents`, `upsertTimelineEvent`, `deleteTimelineEvent`
  - `NovelBundle({..., List<db.CharacterRelation> relations = const [], List<db.TimelineEvent> timelineEvents = const []})`
  - `RelationEvolutionPoint` 与 `CharacterArcPoint` 编解码工具

- [ ] **Step 1: Write the failing test**

Create `test/living_story_graph_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';

void main() {
  group('Drift Schema v3 CharacterRelations & TimelineEvents', () {
    test('supports CRUD, cascade delete and NovelRepository.loadBundle', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NovelRepository(db);
      final now = DateTime(2026, 11, 21);

      await db.upsertNovel(
        NovelsCompanion.insert(
          id: 'n1',
          title: '测试长篇',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.upsertCharacter(
        CharactersCompanion.insert(
          id: 'c1',
          novelId: 'n1',
          name: '莫烬',
          camp: const Value('独立'),
          role: const Value('主角'),
        ),
      );
      await db.upsertCharacter(
        CharactersCompanion.insert(
          id: 'c2',
          novelId: 'n1',
          name: '罗娜',
          camp: const Value('群星之城'),
          role: const Value('核心配角'),
        ),
      );
      await db.upsertCharacterRelation(
        CharacterRelationsCompanion.insert(
          id: 'r1',
          novelId: 'n1',
          sourceCharacterId: 'c1',
          targetCharacterId: 'c2',
          relationType: const Value('盟友'),
          label: '托付群星之城',
          strength: const Value(4),
          line: const Value('暗线'),
          updatedAt: now,
        ),
      );
      await db.upsertTimelineEvent(
        TimelineEventsCompanion.insert(
          id: 't1',
          novelId: 'n1',
          chapterOrder: const Value(248),
          inWorldTime: const Value('血月之夜'),
          phase: const Value('群星事变'),
          title: '罗娜移交铃铛',
          summary: const Value('罗娜舍弃群星力量化为黑猫'),
          participantsJson: const Value('["莫烬","罗娜"]'),
          importance: const Value('major'),
          createdAt: now,
        ),
      );

      final bundle = await repo.loadBundle('n1');
      expect(bundle, isNotNull);
      expect(bundle!.relations.length, 1);
      expect(bundle.relations.single.line, '暗线');
      expect(bundle.timelineEvents.length, 1);
      expect(bundle.timelineEvents.single.inWorldTime, '血月之夜');

      // 删除角色 c2 级联删除关系 r1
      await db.deleteCharacter('c2');
      expect(await db.getCharacterRelations('n1'), isEmpty);

      // 删除作品 n1 级联删除时间线 t1
      await db.deleteNovelCascade('n1');
      expect(await db.getTimelineEvents('n1'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Implement Schema v3 tables, DAOs, codegen, and `NovelBundle` update**

1. In `lib/core/database/tables.dart`:
   - On `Characters`, add:
     ```dart
     TextColumn get camp => text().nullable()();
     TextColumn get role => text().nullable()();
     TextColumn get arcJson => text().withDefault(const Constant('[]'))();
     ```
   - On `Foreshadowings`, add:
     ```dart
     TextColumn get involvedCharactersJson =>
         text().withDefault(const Constant('[]'))();
     IntColumn get resolvedChapterOrder => integer().nullable()();
     TextColumn get payoffDetail => text().nullable()();
     ```
   - Add `CharacterRelations` and `TimelineEvents` tables matching Spec §3.2 exactly.
2. In `lib/core/database/app_database.dart`:
   - Register `CharacterRelations` and `TimelineEvents` in `@DriftDatabase(tables: [...])`.
   - Set `schemaVersion => 3`.
   - In `onUpgrade`:
     ```dart
     if (from < 3) {
       await m.createTable(characterRelations);
       await m.createTable(timelineEvents);
       await m.addColumn(characters, characters.camp);
       await m.addColumn(characters, characters.role);
       await m.addColumn(characters, characters.arcJson);
       await m.addColumn(foreshadowings, foreshadowings.involvedCharactersJson);
       await m.addColumn(foreshadowings, foreshadowings.resolvedChapterOrder);
       await m.addColumn(foreshadowings, foreshadowings.payoffDetail);
     }
     ```
   - Add `watchCharacterRelations`, `getCharacterRelations`, `upsertCharacterRelation`, `deleteCharacterRelation`, `watchTimelineEvents`, `getTimelineEvents`, `upsertTimelineEvent`, `deleteTimelineEvent`.
3. Run Drift codegen:
   Run: `dart run build_runner build --delete-conflicting-outputs`
4. In `lib/domain/models/novel_domain.dart`:
   - Add `RelationEvolutionPoint` and `CharacterArcPoint` with `decodeList`/`encodeList`.
   - Add `this.relations = const []` and `this.timelineEvents = const []` to `NovelBundle`.
5. In `lib/core/database/novel_repository.dart`:
   - In `loadBundle`, load `relations = await db.getCharacterRelations(novelId)` and `timelineEvents = await db.getTimelineEvents(novelId)` and pass to `NovelBundle`.

- [ ] **Step 3: Run tests to verify pass**

Run: `flutter test test/living_story_graph_test.dart test/database_and_blob_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/core/database/tables.dart lib/core/database/app_database.dart lib/core/database/app_database.g.dart lib/domain/models/novel_domain.dart lib/core/database/novel_repository.dart test/living_story_graph_test.dart
git commit -m "feat(db): migrate Drift schema to v3 with CharacterRelations and TimelineEvents"
```

---

### Task 2: 续写建书无损入库与 `ContinuationContext` 升级

**Files:**
- Modify: `lib/features/source_archive/source_injection_helper.dart`
- Modify: `lib/domain/source/continuation_context.dart`
- Test: `test/living_story_graph_test.dart`

**Interfaces:**
- Consumes: `SourceNovelProfileData` (Phase 1), Drift v3 `CharacterRelations` & `TimelineEvents`
- Produces: 无损导入全量角色、关系边、时间线事件（自动映射已导入原作章 ID）、带状态伏笔及关键词世界观的 `createContinuationNovel`

- [ ] **Step 1: Write the failing test**

Add to `test/living_story_graph_test.dart`:

```dart
import 'dart:io';
import 'package:zhiming/core/storage/blob_store.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
import 'package:zhiming/features/source_archive/source_injection_helper.dart';
```

```dart
  group('Lossless continuation novel injection', () {
    test('imports all characters, relations, timeline chapter links and clue statuses', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final tmp = await Directory.systemTemp.createTemp('zm_inject_');
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final blobs = BlobStore(baseDirOverride: tmp);
      final bridge = SourceAndStyleBridge(db: db, blobs: blobs);

      const sourceText = '第1章 开局\n莫烬在钟表屋醒来。\n\n第2章 交易\n罗娜交付铃铛。';
      final profile = SourceNovelProfileData(
        id: 'sp-1',
        title: '诡异降临',
        continuationFromChapter: 2,
        hasSourceText: true,
        characters: const [
          CanonCharacter(
            name: '莫烬',
            aliases: ['末路灰烬'],
            camp: '独立',
            role: '主角',
            importance: CanonImportance.major,
            arc: [CanonArc(phase: '开局', state: '失忆')],
            currentState: '在群星之城',
          ),
          CanonCharacter(
            name: '罗娜',
            camp: '群星之城',
            role: '核心配角',
            importance: CanonImportance.major,
          ),
        ],
        relations: const [
          CanonRelationEdge(
            from: '莫烬',
            to: '罗娜',
            relationType: '盟友',
            label: '城主托付',
            strength: 4,
            line: '暗线',
            firstChapter: 2,
          ),
        ],
        timeline: const [
          CanonEvent(
            phase: '开局',
            chapterRange: '第2章',
            chapterStart: 2,
            inWorldTime: '次日夜',
            summary: '罗娜交付铃铛',
            participants: ['莫烬', '罗娜'],
            linkedClueTitles: ['银色铃铛'],
            importance: CanonImportance.major,
          ),
        ],
        openThreads: const [
          CanonThread(
            title: '银色铃铛',
            detail: '承载群星权柄',
            plantedChapter: 1,
            resolvedChapter: 2,
            status: 'resolved',
            involvedCharacters: ['罗娜', '莫烬'],
            payoffDetail: '第2章揭晓为城主权柄',
          ),
        ],
        worldbuilding: const [
          CanonWorldEntry(
            category: '地点',
            name: '群星之城',
            content: '庇护所',
            keywords: ['群星之城', '星光之城'],
          ),
        ],
      );
      await blobs.saveText(BlobKinds.continuation, profile.id, sourceText);

      final novelId = await bridge.createContinuationNovel(profile: profile);
      final bundle = (await NovelRepository(db).loadBundle(novelId))!;

      expect(bundle.characters.length, 2);
      expect(bundle.characters.first.camp, '独立');
      expect(bundle.characters.first.arcJson, contains('开局'));
      expect(bundle.relations.length, 1);
      expect(bundle.relations.single.line, '暗线');
      expect(bundle.timelineEvents.length, 1);
      expect(bundle.timelineEvents.single.chapterId, isNotNull);
      expect(bundle.timelineEvents.single.linkedForeshadowingIdsJson, isNot('[]'));
      expect(bundle.foreshadowings.single.status, 'resolved');
      expect(bundle.foreshadowings.single.resolvedChapterOrder, 2);
      expect(bundle.worldEntries.single.keywordsJson, contains('星光之城'));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/living_story_graph_test.dart`
Expected: FAIL (`relations` and `timelineEvents` empty after `createContinuationNovel`).

- [ ] **Step 3: Implement lossless injection in `source_injection_helper.dart` & update `continuation_context.dart`**

1. In `lib/features/source_archive/source_injection_helper.dart`:
   - Track `Map<int, String> origChapterIdByOrder = {}` and `String? origVolId` when inserting original chapters.
   - Insert all `profile.characters` with `camp`, `role`, `arcJson` (`jsonEncode(c.arc.map((a) => a.toJson()).toList())`), setting `isSceneRelevant: c.importance == CanonImportance.major || i < 12`, and record `nameToCharId` (including lowercase/trimmed aliases).
   - Insert `profile.relations` (plus fallback from `c.relationships` for edges not yet in `profile.relations`), deduplicating by undirected pair + label, persisting `evolutionJson`, `firstChapterOrder`, `lastChapterOrder`, `line`, `strength`.
   - Insert `profile.openThreads` preserving `status`, `plantedChapterOrder`, `resolvedChapterOrder`, `involvedCharactersJson`, `payoffDetail`, and record `clueTitleToId`.
   - Insert `profile.timeline` into `TimelineEvents`, mapping `chapterNo = ev.chapterStart ?? firstIntIn(ev.chapterRange)` to `origChapterIdByOrder[chapterNo]`, and mapping `ev.linkedClueTitles` to `linkedForeshadowingIdsJson`.
   - Insert `profile.worldbuilding` using `w.keywords.isNotEmpty ? w.keywords : _extractWorldKeywords(w.name)`.
2. In `lib/domain/source/continuation_context.dart`:
   - Add a `核心人物关系网` block (rendering high-strength / dark-line edges from `profile.relations`) and show `status` badge on `partial` threads in `未回收伏笔`.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/living_story_graph_test.dart test/source_domain_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/source_archive/source_injection_helper.dart lib/domain/source/continuation_context.dart test/living_story_graph_test.dart
git commit -m "feat(source): losslessly inject characters, relations, timeline and clue statuses into continuation novels"
```

---

### Task 3: 写作期活账本零额外调用扩展（`PromptID.summarize` + `ChapterLedger` + 编辑器/自动撰写）

**Files:**
- Modify: `lib/core/prompts/prompt_defaults.dart`
- Modify: `lib/core/prompts/prompt_templates.dart`
- Modify: `lib/domain/writing/chapter_ledger.dart`
- Modify: `lib/features/editor/chapter_editor_widget.dart`
- Modify: `lib/features/editor/auto_write_sheet.dart`
- Test: `test/living_story_graph_test.dart`

**Interfaces:**
- Consumes: Drift v3 `CharacterRelations` & `TimelineEvents`
- Produces:
  - `RelationshipDelta`, `NewTimelineEvent` in `lib/domain/writing/chapter_ledger.dart`
  - `ChapterLedgerExtraction` extended with `relationshipDeltas` & `timelineEvents`
  - `ChapterLedgerApplier.applyToDb(...)` extended with optional `selectedRelationDeltaIndexes`, `selectedTimelineEventIndexes`, `volumeId`, `chapterId`, `chapterOrder`
  - `ChapterLedgerApplyReport` extended with `updatedRelations`, `addedTimelineEvents`

- [ ] **Step 1: Write the failing test**

Add to `test/living_story_graph_test.dart`:

```dart
import 'package:zhiming/domain/writing/chapter_ledger.dart';
```

```dart
  group('ChapterLedger relation & timeline incremental writeback', () {
    test('parses and applies relationship_deltas (appending evolution) and timeline_events', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NovelRepository(db);
      final now = DateTime(2026, 11, 21);

      await db.upsertNovel(NovelsCompanion.insert(id: 'n1', title: '测试', createdAt: now, updatedAt: now));
      await db.upsertCharacter(CharactersCompanion.insert(id: 'c1', novelId: 'n1', name: '莫烬'));
      await db.upsertCharacter(CharactersCompanion.insert(id: 'c2', novelId: 'n1', name: '月莲'));
      await db.upsertCharacterRelation(
        CharacterRelationsCompanion.insert(
          id: 'r1',
          novelId: 'n1',
          sourceCharacterId: 'c1',
          targetCharacterId: 'c2',
          relationType: const Value('盟友'),
          label: '短暂同行',
          evolutionJson: const Value('[{"chapterLabel":"第92章","state":"初遇合作"}]'),
          updatedAt: now,
        ),
      );

      const llmJson = '''
{
  "summary": "莫烬三发炼金子弹击落3号载体并接住力竭的月莲。",
  "key_facts": ["3号载体被击杀"],
  "new_foreshadowings": [],
  "resolved_foreshadowing_titles": [],
  "character_deltas": [],
  "new_characters": [],
  "new_world_entries": [],
  "relationship_deltas": [
    {
      "from": "莫烬",
      "to": "月莲",
      "relation_type": "盟友",
      "label": "生死并肩",
      "strength": 5,
      "line": "明线",
      "change_note": "莫烬赶到战场救下力竭的月莲"
    }
  ],
  "timeline_events": [
    {
      "in_world_time": "血月战后",
      "title": "击杀3号载体",
      "summary": "莫烬与月莲联手斩杀3号载体",
      "location": "群星之城外",
      "participants": ["莫烬", "月莲"],
      "importance": "major"
    }
  ]
}
''';
      final extraction = ChapterLedgerExtraction.tryParse(llmJson)!;
      expect(extraction.relationshipDeltas.length, 1);
      expect(extraction.timelineEvents.length, 1);

      final report = await ChapterLedgerApplier.applyToDb(
        db: db,
        repo: repo,
        novelId: 'n1',
        chapterTitle: '第249章 不要跟女人比心机',
        chapterId: 'ch-249',
        chapterOrder: 249,
        extraction: extraction,
      );
      expect(report.updatedRelations, 1);
      expect(report.addedTimelineEvents, 1);

      final rels = await db.getCharacterRelations('n1');
      expect(rels.single.label, '生死并肩');
      expect(rels.single.strength, 5);
      expect(rels.single.evolutionJson, contains('初遇合作'));
      expect(rels.single.evolutionJson, contains('第249章'));

      final events = await db.getTimelineEvents('n1');
      expect(events.single.title, '击杀3号载体');
      expect(events.single.chapterOrder, 249);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/living_story_graph_test.dart`
Expected: FAIL (`relationshipDeltas`, `timelineEvents`, `updatedRelations` undefined).

- [ ] **Step 3: Implement zero-extra-call ledger extension**

1. Update `PromptDefaults.builtInPrompts` (`PromptID.summarize`) in `lib/core/prompts/prompt_defaults.dart` to document optional `relationship_deltas` & `timeline_events` arrays.
2. Update `PromptTemplates.summarize` in `lib/core/prompts/prompt_templates.dart` to accept optional `List<String> existingRelations = const []` (passing up to 20 active relation hints).
3. Update `lib/domain/writing/chapter_ledger.dart`:
   - Add `RelationshipDelta` and `NewTimelineEvent` classes.
   - Extend `ChapterLedgerExtraction` (`relationshipDeltas`, `timelineEvents`, update `hasWriteBackCandidates` and `tryParse`).
   - Extend `ChapterLedgerApplyReport` (`updatedRelations`, `addedTimelineEvents`, update `describe()`).
   - In `ChapterLedgerApplier.applyToDb`: after applying `newCharacters` (so newly created characters are immediately resolvable!), resolve `from`/`to` by name/alias, upsert `CharacterRelations` while **appending** a new `RelationEvolutionPoint(chapterLabel: chapterTitle, state: delta.changeNote)` to `evolutionJson`, and upsert deduplicated `TimelineEvents` anchored to `volumeId` / `chapterId` / `chapterOrder`.
4. Update `lib/features/editor/chapter_editor_widget.dart` (summary sheet checkbox groups for relations & timeline events + passing `existingRelations` and `chapterId`/`chapterOrder`) and `lib/features/editor/auto_write_sheet.dart` (passing `existingRelations`, `chapterId`, `chapterOrder` and logging `report.describe()`).

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/living_story_graph_test.dart test/living_ledger_and_review_test.dart test/llm_and_prompts_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/prompts/prompt_defaults.dart lib/core/prompts/prompt_templates.dart lib/domain/writing/chapter_ledger.dart lib/features/editor/chapter_editor_widget.dart lib/features/editor/auto_write_sheet.dart test/living_story_graph_test.dart
git commit -m "feat(writing): extend Living Ledger with zero-extra-call relation and timeline writeback"
```

---

### Task 4: `LorebookMatcher`、`ContextBuilder` 与 `FactReviewService` 关系网与时间线联动

**Files:**
- Modify: `lib/domain/writing/lorebook_matcher.dart`
- Modify: `lib/domain/writing/context_builder.dart`
- Modify: `lib/domain/writing/fact_review_service.dart`
- Test: `test/living_story_graph_test.dart`

**Interfaces:**
- Consumes: `NovelBundle.relations`, `NovelBundle.timelineEvents`
- Produces:
  - `LorebookSelection.relations` (up to 12 stably ordered `CharacterRelation` edges, plus 1-hop expansion for triggered characters' `strength >= 4` or `暗线` partners)
  - `ContextBuilder` rendering `【人物关系网（含明暗线）】` in `staticOptional` & `【故事时间线锚点】` in `dynamicHigh`
  - `FactReviewService` injecting active relations (explicitly highlighting `暗线`) and recent timeline events into `review(...)`

- [ ] **Step 1: Write the failing test**

Add to `test/living_story_graph_test.dart`:

```dart
import 'package:zhiming/domain/models/novel_domain.dart';
import 'package:zhiming/domain/writing/context_builder.dart';
import 'package:zhiming/domain/writing/lorebook_matcher.dart';
```

```dart
  group('LorebookMatcher & ContextBuilder relation/timeline integration', () {
    test('1-hop recalls secret relation partner and injects relation & timeline blocks', () {
      final now = DateTime(2026, 11, 21);
      final c1 = Character(id: 'c1', novelId: 'n1', name: '莫烬', isSceneRelevant: true, sortOrder: 0);
      final c2 = Character(id: 'c2', novelId: 'n1', name: '爱丽丝', isSceneRelevant: false, sortOrder: 1);
      final rel = CharacterRelation(
        id: 'r1',
        novelId: 'n1',
        sourceCharacterId: 'c1',
        targetCharacterId: 'c2',
        relationType: '敌对',
        label: '执念追杀',
        description: '暗中监视莫烬',
        strength: 5,
        line: '暗线',
        status: 'active',
        evolutionJson: '[]',
        updatedAt: now,
      );
      final ev = TimelineEvent(
        id: 't1',
        novelId: 'n1',
        chapterOrder: 1,
        inWorldTime: '2029年7月8日',
        phase: '开局',
        title: '钟表屋逃亡',
        summary: '薇拉用银色怀表送走莫烬',
        participantsJson: '["莫烬","薇拉"]',
        linkedForeshadowingIdsJson: '[]',
        importance: 'major',
        sortOrder: 0,
        createdAt: now,
      );
      final ch2 = ChapterBundle(
        chapter: Chapter(
          id: 'ch2',
          volumeId: 'v1',
          title: '第2章',
          detailedOutline: '莫烬囤积食物应对第一波侵蚀',
          content: '',
          sortOrder: 2,
          wordCount: 0,
          isOriginal: false,
          updatedAt: now,
        ),
        volumeId: 'v1',
        volumeName: '第一卷',
      );
      final bundle = NovelBundle(
        novel: Novel(id: 'n1', title: '测试', synopsis: '', r18Enabled: false, lastTotalWordCount: 0, createdAt: now, updatedAt: now),
        volumes: [VolumeBundle(volume: Volume(id: 'v1', novelId: 'n1', name: '第一卷', sortOrder: 1), chapters: [ch2])],
        characters: [c1, c2],
        worldEntries: const [],
        foreshadowings: const [],
        relations: [rel],
        timelineEvents: [ev],
      );

      final sel = LorebookMatcher.selectForChapter(chapter: ch2, bundle: bundle);
      expect(sel.characters.map((c) => c.id), contains('c2'));
      expect(sel.relations.length, 1);

      final ctx = ContextBuilder.buildContinueContext(
        chapter: ch2,
        bundle: bundle,
        budgetChars: 20000,
      );
      expect(ctx.staticPrefix, contains('【人物关系网'));
      expect(ctx.staticPrefix, contains('爱丽丝'));
      expect(ctx.staticPrefix, contains('暗线'));
      expect(ctx.dynamicSuffix, contains('【故事时间线锚点】'));
      expect(ctx.dynamicSuffix, contains('钟表屋逃亡'));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/living_story_graph_test.dart`
Expected: FAIL (`sel.relations` undefined).

- [ ] **Step 3: Implement integration in `lorebook_matcher.dart`, `context_builder.dart`, and `fact_review_service.dart`**

1. In `lib/domain/writing/lorebook_matcher.dart`:
   - Add `this.relations = const []` to `LorebookSelection`.
   - Accept optional `List<db.CharacterRelation> relations = const []` in `selectByProbe` and pass `bundle.relations` in `selectForChapter`.
   - When a triggered character (`triggeredCharIds`) has an active relation with `strength >= 4 || line == '暗线'`, add the partner character to `pickedChars` (if under `maxCharacters`), re-sort `pickedChars` by `_compareCharacter` for KV stability, and collect up to 12 stably sorted edges where both endpoints are in `pickedChars` (or one endpoint is triggered and `strength >= 4 || line == '暗线'`).
2. In `lib/domain/writing/context_builder.dart`:
   - Render `lorebook.relations` into `staticOptional` as `【人物关系网（含明暗线）】` (resolving character names by ID, including latest evolution point if present).
   - Select timeline events with `chapterOrder == null || chapterOrder < currentGlobal` (last 4 recent + up to 4 `major` milestones, deduplicated and ordered chronologically) and insert into `dynamicHigh` as `【故事时间线锚点】`.
3. In `lib/domain/writing/fact_review_service.dart`:
   - Include `lorebook.relations` (explicitly tagging `【暗线/秘密】`) and the last 6 `TimelineEvents` prior to the current chapter in `_buildReviewContext`.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/living_story_graph_test.dart test/living_ledger_and_review_test.dart test/writing_domain_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/writing/lorebook_matcher.dart lib/domain/writing/context_builder.dart lib/domain/writing/fact_review_service.dart test/living_story_graph_test.dart
git commit -m "feat(writing): wire character relations and timeline anchors into Lorebook, ContextBuilder and FactReview"
```

---

### Task 5: 纯 Flutter 原生交互式人物关系图谱组件（`CharacterGraphCanvas`）

**Files:**
- Create: `lib/core/widgets/character_graph_canvas.dart`
- Test: `test/living_story_graph_test.dart`

**Interfaces:**
- Consumes: Flutter Material, `InteractiveViewer`, `CustomPainter`
- Produces:
  - `GraphNode({required String id, required String name, String? camp, String? role, String importance, String? subtitle})`
  - `GraphEdge({required String id, required String fromId, required String toId, required String relationType, required String label, String description, int strength, String line, List<({String chapterLabel, String state})> evolution})`
  - `CharacterGraphLayout.compute(List<GraphNode> nodes, List<GraphEdge> edges, {Size canvasSize})` — deterministic camp-sector + Fruchterman-Reingold force-directed layout (pure Dart, zero randomness drift)
  - `CharacterGraphCanvas({required List<GraphNode> nodes, required List<GraphEdge> edges, VoidCallback? onAddRelation, ValueChanged<GraphEdge>? onEditRelation, ValueChanged<GraphEdge>? onDeleteRelation})` — 星图画布 / 关系列表双视图 + 阵营/类型/暗线/搜索筛选 + 1-hop 节点高亮与详情面板

- [ ] **Step 1: Write the failing widget & layout test**

Add to `test/living_story_graph_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:zhiming/core/widgets/character_graph_canvas.dart';
```

```dart
  group('CharacterGraphCanvas layout & widget', () {
    test('deterministic force layout places nodes within bounds without NaN', () {
      const nodes = [
        GraphNode(id: 'a', name: '莫烬', camp: '独立', importance: 'major'),
        GraphNode(id: 'b', name: '罗娜', camp: '群星之城', importance: 'major'),
        GraphNode(id: 'c', name: '月莲', camp: '独立', importance: 'normal'),
      ];
      const edges = [
        GraphEdge(id: 'e1', fromId: 'a', toId: 'b', relationType: '盟友', label: '托付', strength: 4, line: '暗线'),
        GraphEdge(id: 'e2', fromId: 'a', toId: 'c', relationType: '盟友', label: '并肩', strength: 5, line: '明线'),
      ];
      final pos1 = CharacterGraphLayout.compute(nodes, edges, canvasSize: const Size(800, 600));
      final pos2 = CharacterGraphLayout.compute(nodes, edges, canvasSize: const Size(800, 600));
      expect(pos1.length, 3);
      for (final id in ['a', 'b', 'c']) {
        expect(pos1[id]!.dx.isFinite && pos1[id]!.dy.isFinite, isTrue);
        expect(pos1[id], pos2[id]); // deterministic
      }
    });

    testWidgets('switches between graph canvas and list view cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterGraphCanvas(
              nodes: [
                GraphNode(id: 'a', name: '莫烬', camp: '独立', importance: 'major'),
                GraphNode(id: 'b', name: '爱丽丝', camp: '灾祸', importance: 'major'),
              ],
              edges: [
                GraphEdge(id: 'e1', fromId: 'a', toId: 'b', relationType: '敌对', label: '执念追杀', strength: 5, line: '暗线'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.text('列表'));
      await tester.pumpAndSettle();
      expect(find.text('执念追杀'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/living_story_graph_test.dart`
Expected: FAIL (`character_graph_canvas.dart` does not exist).

- [ ] **Step 3: Implement `lib/core/widgets/character_graph_canvas.dart`**

Implement:
- `GraphNode` & `GraphEdge` immutable view models + color helper `relationTypeColor(String type)` + camp palette assignment.
- `CharacterGraphLayout.compute`: initializes `major` hub nodes near center, other nodes on camp-grouped radial sectors, runs 80 iterations of damped Fruchterman-Reingold repulsive + spring-attractive forces, clamps inside canvas padding.
- `CharacterGraphCanvas` stateful widget:
  - Top bar: camp filter dropdown, relationType filter dropdown, `仅暗线` FilterChip, search field, `SegmentedButton` (`星图` / `列表`), and optional `+ 新增关系` button.
  - Graph mode: `InteractiveViewer(minScale: 0.4, maxScale: 3.0)` wrapping a `Stack` with `CustomPaint` for edges (solid for `明线`, dashed for `暗线`, strokeWidth scaled by `strength`, midpoint relation label) and positioned interactive node chips/circles (supporting tap to highlight 1-hop ego network & drag to reposition).
  - Node inspector: when a node is selected, desktop (`>= 840dp`) shows a right-hand 280px detail card; mobile shows a compact bottom detail bar listing all connected edges + evolution timeline + edit/delete actions.
  - List mode: filterable `ListView` of relation cards showing `A ↔ B`, relationType badge, `明线/暗线` tag, strength stars, evolution milestones, and edit/delete icon buttons.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/living_story_graph_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/character_graph_canvas.dart test/living_story_graph_test.dart
git commit -m "feat(ui): add native Flutter interactive CharacterGraphCanvas with force layout and list view"
```

---

### Task 6: 故事时间线视图（`StoryTimelineView`）与工作台 / 原作档案全量接线

**Files:**
- Create: `lib/core/widgets/story_timeline_view.dart`
- Modify: `lib/features/settings_book/book_settings_view.dart`
- Modify: `lib/features/outline/outline_and_foreshadow_view.dart`
- Modify: `lib/features/workspace/novel_workspace_page.dart`
- Modify: `lib/features/source_archive/source_profile_detail_dialog.dart`
- Modify: `test/ui_regression_test.dart`

**Interfaces:**
- Consumes: `CharacterGraphCanvas`, `AppDatabase.watchCharacterRelations`, `AppDatabase.watchTimelineEvents`, `SourceNovelProfileData`
- Produces:
  - `TimelineEventItem` & `StoryTimelineView({required List<TimelineEventItem> events, VoidCallback? onAddEvent, ValueChanged<TimelineEventItem>? onEditEvent, ValueChanged<TimelineEventItem>? onDeleteEvent, ValueChanged<String>? onJumpToChapter})`
  - `BookSettingsView`: 4-segment switcher (`作品信息 | 角色卡 | 关系图谱 | 世界观`) + full relation CRUD dialog
  - `OutlineAndForeshadowView({required String novelId, ValueChanged<String>? onJumpToChapter})`: 3-segment switcher (`卷章大纲 | 伏笔台账 | 故事时间线`) + enriched foreshadowing status/span/character badges + event CRUD dialog
  - `NovelWorkspacePage`: wires `onJumpToChapter` to switch to `_section = 0` and open/select that chapter
  - `SourceProfileDetailDialog`: 5-tab view (`人物 | 关系图谱 | 时间线 | 世界观 | 伏笔与弧线`) reusing both widgets

- [ ] **Step 1: Write the failing widget tests**

Add widget tests to `test/living_story_graph_test.dart` covering:
1. `StoryTimelineView` renders phase groups, filters by participant chip tap, and fires `onJumpToChapter`.
2. `BookSettingsView` exposes `关系图谱` tab and `OutlineAndForeshadowView` exposes `故事时间线` tab cleanly on both `1280x800` and `390x844` surfaces without overflow.

```dart
import 'package:zhiming/core/widgets/story_timeline_view.dart';
```

```dart
  group('StoryTimelineView widget', () {
    testWidgets('filters by participant and invokes onJumpToChapter', (tester) async {
      String? jumpedId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoryTimelineView(
              events: const [
                TimelineEventItem(
                  id: 't1',
                  chapterId: 'ch-1',
                  chapterLabel: '第1章',
                  inWorldTime: '2029年7月8日',
                  phase: '开局',
                  title: '钟表屋逃亡',
                  summary: '薇拉送出银色怀表',
                  participants: ['莫烬', '薇拉'],
                  linkedClueBadges: ['[埋] 银色怀表'],
                  importance: 'major',
                ),
                TimelineEventItem(
                  id: 't2',
                  chapterId: 'ch-50',
                  chapterLabel: '第50章',
                  phase: '星光之城',
                  title: '重逢林医生',
                  summary: '娼馆门外偶遇',
                  participants: ['莫烬', '林医生'],
                  importance: 'normal',
                ),
              ],
              onJumpToChapter: (id) => jumpedId = id,
            ),
          ),
        ),
      );

      expect(find.text('钟表屋逃亡'), findsOneWidget);
      expect(find.text('重逢林医生'), findsOneWidget);
      await tester.tap(find.text('第1章'));
      await tester.pump();
      expect(jumpedId, 'ch-1');

      await tester.tap(find.text('林医生').first);
      await tester.pumpAndSettle();
      expect(find.text('重逢林医生'), findsOneWidget);
      expect(find.text('钟表屋逃亡'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/living_story_graph_test.dart`
Expected: FAIL (`story_timeline_view.dart` does not exist).

- [ ] **Step 3: Implement `StoryTimelineView` and wire all 4 host screens**

1. Create `lib/core/widgets/story_timeline_view.dart` with `TimelineEventItem` and `StoryTimelineView` (filter bar: character chip clearable, `仅核心` FilterChip, keyword search, `+ 新增事件`; vertical phase-grouped timeline track with major/normal/minor dots, clickable chapter badge calling `onJumpToChapter`, `inWorldTime` chip, clickable participant chips, linked foreshadowing badges, and edit/delete actions).
2. Update `lib/features/settings_book/book_settings_view.dart`:
   - Add 4th segment `关系图谱` (`_tab == 2`, shifting 世界观 to `3`).
   - Add `_RelationGraphPane` streaming `db.watchCharacters(novelId)` & `db.watchCharacterRelations(novelId)` into `CharacterGraphCanvas`, plus `_editRelationDialog` for adding/editing relations (picking source/target characters, relationType, label, strength 1–5, 明线/暗线, description, evolution notes).
   - Also show `camp` / `role` fields in `_EditCharacterDialog`.
3. Update `lib/features/outline/outline_and_foreshadow_view.dart`:
   - Add optional `final ValueChanged<String>? onJumpToChapter;` parameter.
   - Add 3rd segment `故事时间线` (`_tab == 2`) rendering `_TimelinePane` (streaming `db.watchTimelineEvents(novelId)` + `db.watchForeshadowings(novelId)` into `StoryTimelineView`, plus `_editTimelineEventDialog`).
   - Enhance `_ForeshadowListPane` cards to show `status` badge (`未回收` / `部分推进` / `已回收`), `第X章埋 → 第Y章收` span, `involvedCharacters` chips, and `payoffDetail`.
4. Update `lib/features/workspace/novel_workspace_page.dart`:
   - Pass `onJumpToChapter` to `OutlineAndForeshadowView` to switch to `_section = 0`, set `_selectedChapterId = chapterId` on desktop, or push `ChapterEditorWidget` on mobile.
5. Update `lib/features/source_archive/source_profile_detail_dialog.dart`:
   - Expand `TabController(length: 5)` to `人物 | 关系图谱 | 时间线 | 世界观 | 伏笔与弧线`, embedding `CharacterGraphCanvas` (fed from `_profile.characters` & `_profile.relations`) and `StoryTimelineView` (fed from `_profile.timeline`).

- [ ] **Step 4: Run full verification suite**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and 100% of unit & UI regression tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/story_timeline_view.dart lib/features/settings_book/book_settings_view.dart lib/features/outline/outline_and_foreshadow_view.dart lib/features/workspace/novel_workspace_page.dart lib/features/source_archive/source_profile_detail_dialog.dart test/living_story_graph_test.dart test/ui_regression_test.dart
git commit -m "feat(ui): integrate StoryTimelineView and CharacterGraphCanvas across workspace and source archive"
```
