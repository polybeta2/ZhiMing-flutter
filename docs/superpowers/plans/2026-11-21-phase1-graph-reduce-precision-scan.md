# Phase 1: 续写精扫零损建图管线（Graph-Reduce）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用「并发 Map（真实章号锚定）+ 本地零损程序化聚合 + 4 阶段专职归并（Canon 实体消歧 / 角色分批建档 / 关系与世界观 / 伏笔埋收对账与时间线）」替代现行有损散文 Reduce 漏斗，并修复极速模式 `NovelLocalIndexer` 的动词/副词粘连噪音。

**Architecture:** 保留现有 `ScanChunks` / `ScanReduces` 表结构，不引入任何新第三方依赖或外部向量库。Map 阶段以真实 `chapterNo` 并发抽取增强版 `MicroSummary`；归并阶段先由纯 Dart `SourceGraphAggregator` 0-Token 零损汇总全书候选池，再由 `SourceGraphReducer` 执行 4 个职责单一、每步独立落盘 `ScanReduces`（`seq >= 1000`）的轻量 LLM Pass，并在 Pass 1 后由代码用 `aliasMap` 确定性归一化全书角色引用。

**Tech Stack:** Flutter / Dart 3, Drift SQLite, Riverpod, Dio, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-11-21-graph-reduce-scan-and-living-story-graph-design.md`

## Global Constraints

- 不引入外部 Embedding / 向量库或新 pub 依赖。
- 所有 `SourceNovelProfileData` 与 `MicroSummary` 的 JSON 扩展必须 100% 向后兼容旧缓存与旧存档（新字段全可选并有合理默认值）。
- 全部结构化 JSON LLM 调用必须使用 `maxTokens >= 12288`（适配思考模型 `reasoning_tokens`）。
- 保留 `SourceScanController` 中的 `WakelockPlus` 与 `BackgroundKeepAliveService.instance.acquire()/release()` 钩子，避免破坏 iOS 后台保活。
- Isolate 调用必须是静态顶层/静态方法，不得捕获 `this` 或 `CancelToken`。
- 完成后运行 `flutter analyze`（0 问题）与 `flutter test`（全绿）。

---

## File Structure

- Modify: `lib/domain/models/source_profile_models.dart` — 兼容扩展 `CanonCamp`、`CanonRelationEvolution`、`CanonRelationEdge`、`CanonCharacter`、`CanonEvent`、`CanonWorldEntry`、`CanonThread`、`SourceNovelProfileData`
- Modify: `lib/domain/source/source_scan_chunker.dart` — `SourceScanChunk` 增补 `chapterTitle`、`partIndex`、`partCount`
- Modify: `lib/domain/source/source_micro_summarizer.dart` — 兼容扩展 `MicroCharacter`、`MicroRelation`、`MicroEvent`、`MicroWorld`、`MicroForeshadow`、`MicroSummary`
- Modify: `lib/domain/source/source_batch_helper.dart` — 批量 Map 协议支持真实章号与增强字段，`parseBatchOutput` 支持同章多段返回
- Modify: `lib/domain/source/novel_local_indexer.dart` — 剥离高频真名+副词/动词粘连噪音，补全动作停用词，Top 25
- Create: `lib/domain/source/source_graph_aggregator.dart` — 纯 Dart 0-Token 零损聚合器、显式别名预合并、共现计算与 `aliasMap` 确定性重写
- Create: `lib/domain/source/source_graph_reducer.dart` — 4 阶段专职归并 Prompt 构造、宽容解析与结果装配
- Modify: `lib/core/database/app_database.dart` — 新增 `loadScanReduceMap(profileId)` 读取 `seq -> summaryText`（零 Schema 改动）
- Modify: `lib/features/source_archive/source_scan_controller.dart` — 并发 Map 工作池 + 4 阶段 Graph-Reduce 断点续跑
- Modify: `lib/features/source_archive/source_scan_dialogs.dart` & `lib/features/source_archive/source_library_page.dart` — 扫描配置支持可选并发度 `concurrency`（默认 3，范围 1..4）
- Create: `test/source_graph_pipeline_test.dart` — Phase 1 全链路单元测试套件

---

### Task 1: 扩展 `SourceNovelProfileData` 统一图谱数据契约

**Files:**
- Modify: `lib/domain/models/source_profile_models.dart`
- Test: `test/source_graph_pipeline_test.dart`

**Interfaces:**
- Consumes: 现有 `lib/domain/models/source_profile_models.dart`
- Produces:
  - `CanonCamp({required String name, String? stance, String? brief})`
  - `CanonRelationEvolution({required String chapterLabel, required String state})`
  - `CanonRelationEdge({required String from, required String to, String relationType, required String label, String description, int strength, String line, int? firstChapter, int? lastChapter, List<CanonRelationEvolution> evolution, String? evidence})`
  - `CanonCharacter` 新增可选字段 `camp`, `stance`, `importance`
  - `CanonEvent` 新增可选字段 `id`, `chapterStart`, `chapterEnd`, `inWorldTime`, `linkedClueTitles`
  - `CanonWorldEntry` 新增可选字段 `keywords`
  - `CanonThread` 新增可选字段 `status`（`'open' | 'partial' | 'resolved'`）, `resolvedChapter`, `involvedCharacters`, `relatedEventSummary`, `payoffDetail`
  - `SourceNovelProfileData` 新增可选字段 `camps`, `relations`

- [ ] **Step 1: Write the failing test**

Create `test/source_graph_pipeline_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';

void main() {
  group('SourceNovelProfileData v2 additive contract', () {
    test('round-trips camps, relations, enriched threads and timeline', () {
      final profile = SourceNovelProfileData(
        id: 'p1',
        title: '诡异降临',
        camps: const [
          CanonCamp(name: '星光之城', stance: '中立', brief: '城主庇佑之地'),
        ],
        characters: const [
          CanonCharacter(
            name: '莫烬',
            aliases: ['末路灰烬', '狼人行商'],
            camp: '独立',
            stance: '主角方',
            importance: CanonImportance.major,
            currentState: '在群星之城接住力竭的月莲',
          ),
        ],
        relations: const [
          CanonRelationEdge(
            from: '莫烬',
            to: '爱丽丝',
            relationType: '敌对',
            label: '执念追杀',
            description: '爱丽丝执着于永远占有莫烬并反复追杀他',
            strength: 5,
            line: '暗线',
            firstChapter: 1,
            lastChapter: 250,
            evolution: [
              CanonRelationEvolution(chapterLabel: '第1章', state: '追杀至钟表屋'),
            ],
            evidence: '第1章爱丽丝称莫烬为哥哥/小偷',
          ),
        ],
        timeline: const [
          CanonEvent(
            id: 'ev_1',
            phase: '降临前夕',
            chapterRange: '第1-3章',
            chapterStart: 1,
            chapterEnd: 3,
            inWorldTime: '2029年7月8日',
            summary: '莫烬借银色怀表回到现实公寓并失忆',
            participants: ['莫烬', '薇拉', '爱丽丝'],
            linkedClueTitles: ['银色怀表来历'],
            importance: CanonImportance.major,
          ),
        ],
        worldbuilding: const [
          CanonWorldEntry(
            category: '地点',
            name: '星光之城',
            content: '受城主庇佑可减少低语侵蚀',
            keywords: ['星光之城', '群星城', '石门'],
          ),
        ],
        openThreads: const [
          CanonThread(
            title: '银色怀表来历',
            detail: '薇拉赠予莫烬的破碎怀表可扭曲时间',
            plantedChapter: 1,
            status: 'partial',
            resolvedChapter: null,
            involvedCharacters: ['莫烬', '薇拉'],
            relatedEventSummary: '钟表屋离别',
            payoffDetail: '中期揭示与轮回有关但未完全解开',
          ),
        ],
      );

      final decoded = SourceNovelProfileData.fromJsonString(
        profile.toJsonString(),
      );
      expect(decoded.camps.single.name, '星光之城');
      expect(decoded.characters.single.camp, '独立');
      expect(decoded.characters.single.importance, CanonImportance.major);
      expect(decoded.relations.single.line, '暗线');
      expect(decoded.relations.single.evolution.single.chapterLabel, '第1章');
      expect(decoded.timeline.single.chapterStart, 1);
      expect(decoded.timeline.single.inWorldTime, '2029年7月8日');
      expect(decoded.timeline.single.linkedClueTitles, ['银色怀表来历']);
      expect(decoded.worldbuilding.single.keywords, contains('群星城'));
      expect(decoded.openThreads.single.status, 'partial');
      expect(decoded.openThreads.single.involvedCharacters, ['莫烬', '薇拉']);
    });

    test('loads legacy v1 profile JSON with safe defaults', () {
      final legacyJson = jsonEncode({
        'id': 'old-1',
        'title': '旧书',
        'characters': [
          {'name': '林深', 'aliases': ['阿深']},
        ],
        'timeline': [
          {'summary': '初入雾港', 'participants': ['林深']},
        ],
        'worldbuilding': [
          {'category': '规则', 'name': '低语', 'content': '侵蚀理智'},
        ],
        'openThreads': [
          {'title': '钟楼秘密', 'detail': '午夜停摆', 'plantedChapter': 3},
        ],
      });

      final decoded = SourceNovelProfileData.fromJsonString(legacyJson);
      expect(decoded.camps, isEmpty);
      expect(decoded.relations, isEmpty);
      expect(decoded.characters.single.importance, CanonImportance.normal);
      expect(decoded.worldbuilding.single.keywords, isEmpty);
      expect(decoded.openThreads.single.status, 'open');
      expect(decoded.openThreads.single.involvedCharacters, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: FAIL with compile errors (`CanonCamp`, `CanonRelationEdge`, `CanonRelationEvolution`, missing named parameters).

- [ ] **Step 3: Implement additive model extensions in `lib/domain/models/source_profile_models.dart`**

Add `CanonCamp`, `CanonRelationEvolution`, `CanonRelationEdge`, and extend `CanonCharacter`, `CanonEvent`, `CanonWorldEntry`, `CanonThread`, and `SourceNovelProfileData` in `lib/domain/models/source_profile_models.dart`:

```dart
class CanonCamp {
  const CanonCamp({required this.name, this.stance, this.brief});

  final String name;
  final String? stance;
  final String? brief;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (stance != null) 'stance': stance,
    if (brief != null) 'brief': brief,
  };

  factory CanonCamp.fromJson(Map<String, dynamic> json) => CanonCamp(
    name: json['name']?.toString().trim() ?? '',
    stance: _optString(json['stance']),
    brief: _optString(json['brief']),
  );
}

class CanonRelationEvolution {
  const CanonRelationEvolution({
    required this.chapterLabel,
    required this.state,
  });

  final String chapterLabel;
  final String state;

  Map<String, dynamic> toJson() => {
    'chapterLabel': chapterLabel,
    'state': state,
  };

  factory CanonRelationEvolution.fromJson(Map<String, dynamic> json) =>
      CanonRelationEvolution(
        chapterLabel:
            (json['chapterLabel'] ?? json['chapter_label'] ?? json['chapter'])
                ?.toString()
                .trim() ??
            '',
        state: (json['state'] ?? json['desc'])?.toString().trim() ?? '',
      );
}

class CanonRelationEdge {
  const CanonRelationEdge({
    required this.from,
    required this.to,
    this.relationType = '未知',
    required this.label,
    this.description = '',
    this.strength = 3,
    this.line = '明线',
    this.firstChapter,
    this.lastChapter,
    this.evolution = const [],
    this.evidence,
  });

  final String from;
  final String to;
  final String relationType;
  final String label;
  final String description;
  final int strength;
  final String line;
  final int? firstChapter;
  final int? lastChapter;
  final List<CanonRelationEvolution> evolution;
  final String? evidence;

  CanonRelationEdge copyWith({
    String? from,
    String? to,
    String? relationType,
    String? label,
    String? description,
    int? strength,
    String? line,
    int? firstChapter,
    int? lastChapter,
    List<CanonRelationEvolution>? evolution,
    String? evidence,
  }) => CanonRelationEdge(
    from: from ?? this.from,
    to: to ?? this.to,
    relationType: relationType ?? this.relationType,
    label: label ?? this.label,
    description: description ?? this.description,
    strength: strength ?? this.strength,
    line: line ?? this.line,
    firstChapter: firstChapter ?? this.firstChapter,
    lastChapter: lastChapter ?? this.lastChapter,
    evolution: evolution ?? this.evolution,
    evidence: evidence ?? this.evidence,
  );

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'relationType': relationType,
    'label': label,
    if (description.isNotEmpty) 'description': description,
    'strength': strength,
    'line': line,
    if (firstChapter != null) 'firstChapter': firstChapter,
    if (lastChapter != null) 'lastChapter': lastChapter,
    if (evolution.isNotEmpty)
      'evolution': evolution.map((e) => e.toJson()).toList(),
    if (evidence != null) 'evidence': evidence,
  };

  factory CanonRelationEdge.fromJson(Map<String, dynamic> json) {
    final rawLine = (json['line'] ?? '明线').toString().trim();
    final line = rawLine.contains('暗') ? '暗线' : '明线';
    final rawStrength = (json['strength'] as num?)?.toInt() ?? 3;
    return CanonRelationEdge(
      from: (json['from'] ?? json['a'] ?? json['source'])?.toString().trim() ?? '',
      to: (json['to'] ?? json['b'] ?? json['target'])?.toString().trim() ?? '',
      relationType: _normalizeRelationType(
        (json['relationType'] ?? json['relation_type'] ?? json['kind'])
            ?.toString(),
      ),
      label: (json['label'] ?? json['relation'])?.toString().trim() ?? '',
      description:
          (json['description'] ?? json['desc'])?.toString().trim() ?? '',
      strength: rawStrength.clamp(1, 5),
      line: line,
      firstChapter: _optInt(json['firstChapter'] ?? json['first_chapter']),
      lastChapter: _optInt(json['lastChapter'] ?? json['last_chapter']),
      evolution: (json['evolution'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonRelationEvolution.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.state.isNotEmpty)
          .toList(),
      evidence: _optString(json['evidence']),
    );
  }
}

String _normalizeRelationType(String? raw) {
  final t = (raw ?? '').trim();
  const allowed = {'亲友', '盟友', '爱恋', '敌对', '从属', '竞争', '未知'};
  if (allowed.contains(t)) return t;
  if (t.contains('敌') || t.contains('仇') || t.contains('杀') || t.contains('反')) {
    return '敌对';
  }
  if (t.contains('爱') || t.contains('恋') || t.contains('情') || t.contains('妻') || t.contains('夫')) {
    return '爱恋';
  }
  if (t.contains('亲') || t.contains('友') || t.contains('兄') || t.contains('妹') || t.contains('父') || t.contains('母') || t.contains('师')) {
    return '亲友';
  }
  if (t.contains('盟') || t.contains('合') || t.contains('同') || t.contains('搭档')) {
    return '盟友';
  }
  if (t.contains('属') || t.contains('主') || t.contains('仆') || t.contains('契约') || t.contains('下级')) {
    return '从属';
  }
  if (t.contains('竞') || t.contains('对手')) return '竞争';
  return '未知';
}

int? _optInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
```

Update existing classes in the same file:
- `CanonCharacter`: add optional `this.camp`, `this.stance`, `this.importance = CanonImportance.normal` to constructor, `copyWith`, `toJson`, and `fromJson`.
- `CanonEvent`: add optional `this.id`, `this.chapterStart`, `this.chapterEnd`, `this.inWorldTime`, `this.linkedClueTitles = const []` to constructor, `copyWith`, `toJson`, and `fromJson` (supporting both camelCase and snake_case keys).
- `CanonWorldEntry`: add `this.keywords = const []` to constructor, `copyWith`, `toJson`, and `fromJson`.
- `CanonThread`: add `this.status = 'open'`, `this.resolvedChapter`, `this.involvedCharacters = const []`, `this.relatedEventSummary`, `this.payoffDetail` to constructor, `toJson`, and `fromJson` (normalizing `status` to `'open' | 'partial' | 'resolved'`).
- `SourceNovelProfileData`: add `this.camps = const []`, `this.relations = const []` to constructor, `copyWith`, `toJson`, and `fromJson`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/source_graph_pipeline_test.dart test/source_domain_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/source_profile_models.dart test/source_graph_pipeline_test.dart
git commit -m "feat(source): extend SourceNovelProfileData with camps, relations, timeline and thread lifecycle fields"
```

---

### Task 2: 升级 `SourceScanChunker`、`SourceMicroSummarizer` 与 `SourceBatchHelper`（真实章号锚定 + 增强微摘要）

**Files:**
- Modify: `lib/domain/source/source_scan_chunker.dart`
- Modify: `lib/domain/source/source_micro_summarizer.dart`
- Modify: `lib/domain/source/source_batch_helper.dart`
- Test: `test/source_graph_pipeline_test.dart`

**Interfaces:**
- Consumes: `StyleChapterSampler.split`
- Produces:
  - `SourceScanChunk({required int chapterIndex, String chapterTitle = '', int partIndex = 0, int partCount = 1, required String kind, required String text})` with `int get chapterNo => chapterIndex + 1`
  - `MicroCharacter({required String name, List<String> aliases = const [], String? roleHint, String? campHint, String? traits, String? stateChange})`
  - `MicroRelation({required String from, required String to, required String relation, String kind = '未知', String line = '明线', String? evidence})`
  - `MicroEvent({required String summary, String? inWorldTime, List<String> participants = const [], String importance = 'normal'})`
  - `MicroWorld({required String name, String? category, required String content})`
  - `MicroForeshadow({required String summary, bool planted = true, List<String> characters = const [], String? targetHint})`
  - `MicroSummary({int? chapterNo, ... , List<MicroRelation> relations = const []})`
  - `SourceBatchHelper.parseBatchEntries(String raw)` → `List<({int chapterNo, MicroSummary summary})>` (handles multi-part chapters sharing the same `chapterNo`, while preserving `parseBatchOutput` for existing callers).

- [ ] **Step 1: Write the failing test**

Append to `test/source_graph_pipeline_test.dart`:

```dart
import 'package:zhiming/domain/source/source_batch_helper.dart';
import 'package:zhiming/domain/source/source_micro_summarizer.dart';
import 'package:zhiming/domain/source/source_scan_chunker.dart';
```

And add test group:

```dart
  group('SourceScanChunker & MicroSummary & SourceBatchHelper', () {
    test('long chapter split preserves real chapterNo and part metadata', () {
      final longBody = '钟声响起，迷雾涌动。' * 500; // 5000 chars -> 2 parts
      final book = '第1章 雾起\n$longBody\n\n第2章 交易\n莫烬来到下城区。';
      final chunks = SourceScanChunker.chunks(book, mode: ScanMode.full);
      expect(chunks.length, 3);
      expect(chunks[0].chapterNo, 1);
      expect(chunks[0].partIndex, 0);
      expect(chunks[0].partCount, 2);
      expect(chunks[0].chapterTitle, contains('第1章'));
      expect(chunks[1].chapterNo, 1);
      expect(chunks[1].partIndex, 1);
      expect(chunks[1].partCount, 2);
      expect(chunks[2].chapterNo, 2);
      expect(chunks[2].partCount, 1);
    });

    test('MicroSummary parses aliases, relations, inWorldTime and targetHint', () {
      const raw = '''
{
  "chapter": 50,
  "characters": [{"name": "林医生", "aliases": ["老林"], "role_hint": "配角", "camp_hint": "星光之城", "traits": "炼金术师", "state_change": "重逢莫烬"}],
  "relations": [{"from": "莫烬", "to": "林医生", "relation": "欠债2000魂", "kind": "盟友", "line": "明线", "evidence": "妃莉娅代付"}],
  "events": [{"summary": "进入星光之城", "in_world_time": "次日黄昏", "participants": ["莫烬", "妃莉娅"], "importance": "major"}],
  "worldbuilding": [{"name": "星光之城", "category": "地点", "content": "城主庇佑"}],
  "foreshadowing": [{"summary": "莫烬对林医生有莫名熟悉感", "planted": true, "characters": ["莫烬", "林医生"], "target_hint": ""}]
}
''';
      final parsed = SourceMicroSummarizer.parse(raw);
      expect(parsed.chapterNo, 50);
      expect(parsed.characters.single.aliases, ['老林']);
      expect(parsed.characters.single.campHint, '星光之城');
      expect(parsed.relations.single.from, '莫烬');
      expect(parsed.relations.single.to, '林医生');
      expect(parsed.events.single.inWorldTime, '次日黄昏');
      expect(parsed.events.single.importance, 'major');
      expect(parsed.worldbuilding.single.category, '地点');
      expect(parsed.foreshadowing.single.characters, ['莫烬', '林医生']);
    });

    test('SourceBatchHelper merges duplicate chapterNo rows from multi-part chapter', () {
      const raw = '''
{"chapter": 1, "characters": [{"name": "莫烬", "traits": "冷静"}], "relations": [{"from": "莫烬", "to": "薇拉", "relation": "同伴", "kind": "亲友", "line": "明线"}], "events": [{"summary": "上半段事件", "participants": ["莫烬"]}], "worldbuilding": [], "foreshadowing": [{"summary": "伏笔A", "planted": true, "characters": ["莫烬"]}]}
{"chapter": 1, "characters": [{"name": "爱丽丝", "aliases": ["人偶女孩"]}], "relations": [], "events": [{"summary": "下半段事件", "participants": ["爱丽丝"]}], "worldbuilding": [], "foreshadowing": []}
''';
      final entries = SourceBatchHelper.parseBatchEntries(raw);
      expect(entries.length, 2);
      expect(entries[0].chapterNo, 1);
      expect(entries[1].chapterNo, 1);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: FAIL (`chapterNo`, `partIndex`, `relations`, `parseBatchEntries` undefined).

- [ ] **Step 3: Implement updates in `source_scan_chunker.dart`, `source_micro_summarizer.dart`, and `source_batch_helper.dart`**

1. In `lib/domain/source/source_scan_chunker.dart`:
   - Extend `SourceScanChunk`:
     ```dart
     class SourceScanChunk {
       const SourceScanChunk({
         required this.chapterIndex,
         this.chapterTitle = '',
         this.partIndex = 0,
         this.partCount = 1,
         required this.kind,
         required this.text,
       });

       final int chapterIndex;
       final String chapterTitle;
       final int partIndex;
       final int partCount;
       final String kind; // 'fast_abridged' | 'full' | 'part'
       final String text;

       int get chapterNo => chapterIndex + 1;
     }
     ```
   - Populate `chapterTitle: chapters[i].marker.trim()`, and in `ScanMode.full` when `body.length > fullMaxChunk`, compute `partCount = (body.length + fullMaxChunk - 1) ~/ fullMaxChunk` and pass `partIndex` (`0..partCount-1`).

2. In `lib/domain/source/source_micro_summarizer.dart`:
   - Add `MicroRelation`:
     ```dart
     class MicroRelation {
       const MicroRelation({
         required this.from,
         required this.to,
         required this.relation,
         this.kind = '未知',
         this.line = '明线',
         this.evidence,
       });

       final String from;
       final String to;
       final String relation;
       final String kind;
       final String line;
       final String? evidence;

       Map<String, dynamic> toJson() => {
         'from': from,
         'to': to,
         'relation': relation,
         'kind': kind,
         'line': line,
         if (evidence != null) 'evidence': evidence,
       };

       factory MicroRelation.fromJson(Map<String, dynamic> json) => MicroRelation(
         from: (json['from'] ?? json['a'])?.toString().trim() ?? '',
         to: (json['to'] ?? json['b'])?.toString().trim() ?? '',
         relation: (json['relation'] ?? json['label'] ?? json['desc'])
             ?.toString()
             .trim() ?? '',
         kind: _opt(json['kind'] ?? json['relation_type']) ?? '未知',
         line: (json['line']?.toString().contains('暗') ?? false) ? '暗线' : '明线',
         evidence: _opt(json['evidence']),
       );
     }
     ```
   - Extend `MicroCharacter`, `MicroEvent`, `MicroWorld`, `MicroForeshadow`, `MicroSummary` with all fields above and backward-compatible `fromJson` / `toJson`.
   - Update `SourceMicroSummarizer.systemPrompt` to request the extended schema (including `aliases`, `role_hint`, `camp_hint`, `relations`, `in_world_time`, `importance`, `category`, `characters`, `target_hint`).

3. In `lib/domain/source/source_batch_helper.dart`:
   - Update `SourceBatchHelper.prompt` to describe the enriched JSON line schema and instruct:
     - `chapter` 填正文中标注的真实章号（如 `50`）；
     - `relations` 记录本章明确展现或变化的人物关系（`line` 标 `明线` 或 `暗线`）；
     - `foreshadowing` 回收时记 `planted=false` 并在 `target_hint` 简述呼应的前期悬念。
   - Add `parseBatchEntries(String raw)` returning `List<({int chapterNo, MicroSummary summary})>` and implement `parseBatchOutput` by indexing `entries` by `chapterNo - 1` (merging when two entries share the same `chapterNo`).

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/source_graph_pipeline_test.dart test/source_domain_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/source/source_scan_chunker.dart lib/domain/source/source_micro_summarizer.dart lib/domain/source/source_batch_helper.dart test/source_graph_pipeline_test.dart
git commit -m "feat(source): anchor true chapter numbers and enrich map micro-summary schema"
```

---

### Task 3: 修复 `NovelLocalIndexer` 动词/粘连噪音过滤

**Files:**
- Modify: `lib/domain/source/novel_local_indexer.dart`
- Test: `test/source_graph_pipeline_test.dart`

**Interfaces:**
- Consumes: `NovelLocalIndexer.fromRawText` / `fromChapters`
- Produces: 清洗后的 `NovelLocalIndexer.topEntities`（最多 25 项，不含动作词及「真名+副词/动词」脏词）

- [ ] **Step 1: Write the failing test**

Add to `test/source_graph_pipeline_test.dart`:

```dart
import 'package:zhiming/domain/source/novel_local_indexer.dart';
```

```dart
  group('NovelLocalIndexer noise filtering', () {
    test('strips protagonist+adverb glued noise and action verbs', () {
      const chapter = '''
第1章 测试
莫烬说道：“走吧。”莫烬问道：“谁在那里？”莫烬笑道：“有意思。”
莫烬急忙说道：“快躲开！”莫烬急忙转身。莫烬急忙开口。
莫烬继续说道：“接着聊。”莫烬继续看着前方。莫烬继续沉默。
转过头来问道：“你是谁？”转过头来看向门口。转过头来皱眉。
开口说道：“别吵。”开口问道：“懂了吗？”开口笑道：“行。”
佩洛冷笑道：“蠢货。”佩洛问道：“准备好了吗？”佩洛转身离开。
''';
      final indexer = NovelLocalIndexer.fromRawText(chapter);
      final names = indexer.topEntities.map((e) => e.name).toList();
      expect(names, containsAll(['莫烬', '佩洛']));
      expect(names, isNot(contains('莫烬急忙')));
      expect(names, isNot(contains('莫烬继续')));
      expect(names, isNot(contains('转过头来')));
      expect(names, isNot(contains('开口')));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: FAIL (`莫烬急忙`, `莫烬继续`, `转过头来`, `开口` present in `names`).

- [ ] **Step 3: Implement noise stripping in `lib/domain/source/novel_local_indexer.dart`**

1. Expand `_stopWords` with action/posture verbs: `'开口'`, `'转头'`, `'转过头来'`, `'回头'`, `'抬头'`, `'低头'`, `'点头'`, `'摇头'`, `'默默'`, `'眯着眼睛'`, `'眯起眼睛'`, `'眨了眨眼'`, `'深吸'`, `'冷哼'`, `'轻叹'`, `'叹气'`, `'沉默'`, `'闭嘴'`, `'咬牙'`, `'皱眉'`.
2. Add `_trailingModifiers` list (`['急忙', '继续', '再次', '连忙', '赶紧', '微微', '轻轻', '缓缓', '冷冷', '顿时', '随即', '立刻', '直接', '突然', '慢慢', '悄悄', '猛地', '默默', '一愣', '一笑', '一叹']`).
3. After counting `speakerHits`, collect strong base names (`speakerHits.entries.where((e) => e.key.length <= 3 && e.value >= 2).map((e) => e.key).toSet()`). For every 4-char (or longer) candidate in `speakerHits`, if it starts with a strong base name and the remainder is in `_trailingModifiers` (or is a 1-char adverb/verb like `'忙'/'又'/'再'/'却'/'便'`), merge its `speakerHits` count into the base name and remove the glued candidate.
4. Raise `stats.take(20)` to `stats.take(25)`.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/source_graph_pipeline_test.dart test/source_domain_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/source/novel_local_indexer.dart test/source_graph_pipeline_test.dart
git commit -m "fix(source): filter action verbs and glued adverb noise in NovelLocalIndexer"
```

---

### Task 4: 实现 `SourceGraphAggregator`（0-Token 零损程序化聚合器与 `aliasMap` 确定性重写）

**Files:**
- Create: `lib/domain/source/source_graph_aggregator.dart`
- Test: `test/source_graph_pipeline_test.dart`

**Interfaces:**
- Consumes: `MicroSummary`, `MicroCharacter`, `MicroRelation`, `MicroEvent`, `MicroWorld`, `MicroForeshadow`
- Produces:
  - `class CharacterCandidate` (`name`, `aliases`, `mentions`, `chapterNos`, `recentHits`, `roleHints`, `campHints`, `traits`, `stateChanges: List<({int chapterNo, String change})>`)
  - `class IndexedRawEvent` (`id`, `chapterNo`, `inWorldTime`, `summary`, `participants`, `importance`)
  - `class RawRelationEvidence` (`chapterNo`, `from`, `to`, `relation`, `kind`, `line`, `evidence`)
  - `class RawClueRecord` (`chapterNo`, `planted`, `summary`, `characters`, `targetHint`)
  - `class RawWorldCandidate` (`name`, `category`, `contents`, `chapterNos`)
  - `class AggregatedSourceGraph`:
    - `static AggregatedSourceGraph build(List<({int chapterNo, MicroSummary summary})> records, {required int totalChapters})`
    - `AggregatedSourceGraph applyAliasMap(Map<String, String> aliasMap, {Set<String> dropNames = const {}})`
    - `Map<String, List<RawRelationEvidence>> groupedRelationsByPair({Set<String>? allowedNames})`

- [ ] **Step 1: Write the failing test**

Add to `test/source_graph_pipeline_test.dart`:

```dart
import 'package:zhiming/domain/source/source_graph_aggregator.dart';
```

```dart
  group('SourceGraphAggregator', () {
    test('aggregates all chapters losslessly and rewrites names via aliasMap', () {
      final records = <({int chapterNo, MicroSummary summary})>[
        (
          chapterNo: 1,
          summary: const MicroSummary(
            chapterNo: 1,
            characters: [
              MicroCharacter(name: '莫烬', aliases: ['末路灰烬'], traits: '冷静'),
              MicroCharacter(name: '罗娜', traits: '群星城主', campHint: '群星之城'),
            ],
            relations: [
              MicroRelation(
                from: '莫烬',
                to: '罗娜',
                relation: '初识',
                kind: '盟友',
                line: '明线',
              ),
            ],
            events: [
              MicroEvent(
                summary: '莫烬遇见罗娜',
                inWorldTime: '第1天',
                participants: ['莫烬', '罗娜'],
                importance: 'major',
              ),
            ],
            foreshadowing: [
              MicroForeshadow(
                summary: '罗娜的铃铛来源不明',
                planted: true,
                characters: ['罗娜'],
              ),
            ],
          ),
        ),
        (
          chapterNo: 248,
          summary: const MicroSummary(
            chapterNo: 248,
            characters: [
              MicroCharacter(name: '小黑猫', stateChange: '昏迷被帕梅拉带走'),
              MicroCharacter(name: '路人甲', traits: '背景板'),
            ],
            relations: [
              MicroRelation(
                from: '末路灰烬',
                to: '小黑猫',
                relation: '托付群星之城',
                kind: '盟友',
                line: '暗线',
              ),
            ],
            events: [
              MicroEvent(
                summary: '小黑猫交出铃铛',
                participants: ['小黑猫', '末路灰烬'],
                importance: 'major',
              ),
            ],
            foreshadowing: [
              MicroForeshadow(
                summary: '铃铛是城主权柄核心',
                planted: false,
                characters: ['小黑猫'],
                targetHint: '罗娜的铃铛来源不明',
              ),
            ],
          ),
        ),
      ];

      final raw = SourceGraphAggregator.build(records, totalChapters: 250);
      expect(raw.rawEvents.length, 2);
      expect(raw.rawEvents[0].chapterNo, 1);
      expect(raw.rawEvents[1].chapterNo, 248);
      expect(raw.rawClues.length, 2);

      final normalized = raw.applyAliasMap(
        const {'莫烬': '莫烬', '末路灰烬': '莫烬', '罗娜': '罗娜', '小黑猫': '罗娜'},
        dropNames: const {'路人甲'},
      );
      expect(normalized.characterCandidates.containsKey('路人甲'), isFalse);
      expect(normalized.characterCandidates['罗娜']!.chapterNos, [1, 248]);
      expect(normalized.characterCandidates['罗娜']!.stateChanges.single.chapterNo, 248);
      expect(normalized.rawEvents[1].participants, containsAll(['莫烬', '罗娜']));
      expect(normalized.rawClues[1].characters, ['罗娜']);

      final pairs = normalized.groupedRelationsByPair(allowedNames: {'莫烬', '罗娜'});
      expect(pairs.length, 1);
      expect(pairs.values.single.length, 2);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: FAIL (`source_graph_aggregator.dart` does not exist).

- [ ] **Step 3: Implement `lib/domain/source/source_graph_aggregator.dart`**

```dart
import 'dart:math' as math;

import 'source_micro_summarizer.dart';

class CharacterCandidate {
  CharacterCandidate({
    required this.name,
    Set<String>? aliases,
    this.mentions = 0,
    Set<int>? chapterNos,
    this.recentHits = 0,
    Set<String>? roleHints,
    Set<String>? campHints,
    List<String>? traits,
    List<({int chapterNo, String change})>? stateChanges,
  }) : aliases = aliases ?? <String>{},
       chapterNos = chapterNos ?? <int>{},
       roleHints = roleHints ?? <String>{},
       campHints = campHints ?? <String>{},
       traits = traits ?? <String>[],
       stateChanges = stateChanges ?? <({int chapterNo, String change})>[];

  final String name;
  final Set<String> aliases;
  int mentions;
  final Set<int> chapterNos;
  int recentHits;
  final Set<String> roleHints;
  final Set<String> campHints;
  final List<String> traits;
  final List<({int chapterNo, String change})> stateChanges;

  int get firstChapter =>
      chapterNos.isEmpty ? 0 : chapterNos.reduce(math.min);
  int get lastChapter =>
      chapterNos.isEmpty ? 0 : chapterNos.reduce(math.max);
  int get chapterCount => chapterNos.length;

  void mergeFrom(CharacterCandidate other, {required int recentStart}) {
    if (other.name != name) aliases.add(other.name);
    aliases.addAll(other.aliases);
    aliases.remove(name);
    mentions += other.mentions;
    chapterNos.addAll(other.chapterNos);
    recentHits = chapterNos.where((c) => c >= recentStart).length;
    roleHints.addAll(other.roleHints);
    campHints.addAll(other.campHints);
    for (final t in other.traits) {
      if (!traits.contains(t)) traits.add(t);
    }
    stateChanges.addAll(other.stateChanges);
    stateChanges.sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
  }
}

class IndexedRawEvent {
  const IndexedRawEvent({
    required this.id,
    required this.chapterNo,
    this.inWorldTime,
    required this.summary,
    this.participants = const [],
    this.importance = 'normal',
  });

  final String id;
  final int chapterNo;
  final String? inWorldTime;
  final String summary;
  final List<String> participants;
  final String importance;
}

class RawRelationEvidence {
  const RawRelationEvidence({
    required this.chapterNo,
    required this.from,
    required this.to,
    required this.relation,
    this.kind = '未知',
    this.line = '明线',
    this.evidence,
  });

  final int chapterNo;
  final String from;
  final String to;
  final String relation;
  final String kind;
  final String line;
  final String? evidence;
}

class RawClueRecord {
  const RawClueRecord({
    required this.chapterNo,
    required this.planted,
    required this.summary,
    this.characters = const [],
    this.targetHint,
  });

  final int chapterNo;
  final bool planted;
  final String summary;
  final List<String> characters;
  final String? targetHint;
}

class RawWorldCandidate {
  RawWorldCandidate({
    required this.name,
    this.category,
    List<String>? contents,
    Set<int>? chapterNos,
  }) : contents = contents ?? <String>[],
       chapterNos = chapterNos ?? <int>{};

  final String name;
  String? category;
  final List<String> contents;
  final Set<int> chapterNos;
}

class AggregatedSourceGraph {
  const AggregatedSourceGraph({
    required this.totalChapters,
    required this.characterCandidates,
    required this.rawEvents,
    required this.rawRelations,
    required this.rawClues,
    required this.rawWorldEntries,
    required this.cooccurrence,
  });

  final int totalChapters;
  final Map<String, CharacterCandidate> characterCandidates;
  final List<IndexedRawEvent> rawEvents;
  final List<RawRelationEvidence> rawRelations;
  final List<RawClueRecord> rawClues;
  final Map<String, RawWorldCandidate> rawWorldEntries;
  final Map<String, int> cooccurrence;

  List<CharacterCandidate> get orderedCandidates {
    final list = characterCandidates.values.toList()
      ..sort((a, b) {
        final scoreA = a.chapterCount * 10 + a.mentions + a.recentHits * 6;
        final scoreB = b.chapterCount * 10 + b.mentions + b.recentHits * 6;
        return scoreB.compareTo(scoreA);
      });
    return list;
  }

  /// Pass 1 完成后由代码确定性重写全书事件、关系边、伏笔和角色候选池。
  AggregatedSourceGraph applyAliasMap(
    Map<String, String> aliasMap, {
    Set<String> dropNames = const {},
  }) {
    final recentStart = math.max(1, totalChapters - 14);
    String? resolve(String raw) {
      final clean = raw.trim();
      if (clean.isEmpty || dropNames.contains(clean)) return null;
      final mapped = aliasMap[clean] ?? clean;
      if (dropNames.contains(mapped)) return null;
      return mapped;
    }

    final mergedChars = <String, CharacterCandidate>{};
    for (final cand in characterCandidates.values) {
      final canon = resolve(cand.name);
      if (canon == null) continue;
      final dst = mergedChars.putIfAbsent(
        canon,
        () => CharacterCandidate(name: canon),
      );
      dst.mergeFrom(cand, recentStart: recentStart);
    }

    final normEvents = <IndexedRawEvent>[];
    for (final ev in rawEvents) {
      final parts = <String>[];
      final seen = <String>{};
      for (final p in ev.participants) {
        final r = resolve(p);
        if (r != null && seen.add(r)) parts.add(r);
      }
      normEvents.add(
        IndexedRawEvent(
          id: ev.id,
          chapterNo: ev.chapterNo,
          inWorldTime: ev.inWorldTime,
          summary: ev.summary,
          participants: parts,
          importance: ev.importance,
        ),
      );
    }

    final normRelations = <RawRelationEvidence>[];
    for (final rel in rawRelations) {
      final a = resolve(rel.from);
      final b = resolve(rel.to);
      if (a == null || b == null || a == b) continue;
      normRelations.add(
        RawRelationEvidence(
          chapterNo: rel.chapterNo,
          from: a,
          to: b,
          relation: rel.relation,
          kind: rel.kind,
          line: rel.line,
          evidence: rel.evidence,
        ),
      );
    }

    final normClues = <RawClueRecord>[];
    for (final clue in rawClues) {
      final chars = <String>[];
      final seen = <String>{};
      for (final c in clue.characters) {
        final r = resolve(c);
        if (r != null && seen.add(r)) chars.add(r);
      }
      normClues.add(
        RawClueRecord(
          chapterNo: clue.chapterNo,
          planted: clue.planted,
          summary: clue.summary,
          characters: chars,
          targetHint: clue.targetHint,
        ),
      );
    }

    return AggregatedSourceGraph(
      totalChapters: totalChapters,
      characterCandidates: mergedChars,
      rawEvents: normEvents,
      rawRelations: normRelations,
      rawClues: normClues,
      rawWorldEntries: rawWorldEntries,
      cooccurrence: _computeCooccurrence(normEvents),
    );
  }

  /// 按无序角色对聚合关系证据（保留时间顺序）。
  Map<String, List<RawRelationEvidence>> groupedRelationsByPair({
    Set<String>? allowedNames,
  }) {
    final map = <String, List<RawRelationEvidence>>{};
    for (final rel in rawRelations) {
      if (allowedNames != null &&
          (!allowedNames.contains(rel.from) || !allowedNames.contains(rel.to))) {
        continue;
      }
      final key = _pairKey(rel.from, rel.to);
      map.putIfAbsent(key, () => []).add(rel);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
    }
    return map;
  }

  static String _pairKey(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a||$b' : '$b||$a';

  static Map<String, int> _computeCooccurrence(List<IndexedRawEvent> events) {
    final counts = <String, int>{};
    for (final ev in events) {
      final ps = ev.participants;
      for (var i = 0; i < ps.length; i++) {
        for (var j = i + 1; j < ps.length; j++) {
          final key = _pairKey(ps[i], ps[j]);
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    return counts;
  }
}

abstract final class SourceGraphAggregator {
  static AggregatedSourceGraph build(
    List<({int chapterNo, MicroSummary summary})> records, {
    required int totalChapters,
  }) {
    final sorted = [...records]
      ..sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
    final recentStart = math.max(1, totalChapters - 14);
    final chars = <String, CharacterCandidate>{};
    final events = <IndexedRawEvent>[];
    final relations = <RawRelationEvidence>[];
    final clues = <RawClueRecord>[];
    final worlds = <String, RawWorldCandidate>{};
    final perChapterSeq = <int, int>{};

    for (final rec in sorted) {
      final chNo = rec.chapterNo;
      final m = rec.summary;

      for (final c in m.characters) {
        final name = c.name.trim();
        if (name.isEmpty) continue;
        final cand = chars.putIfAbsent(name, () => CharacterCandidate(name: name));
        cand.mentions += 1;
        cand.chapterNos.add(chNo);
        cand.recentHits = cand.chapterNos.where((n) => n >= recentStart).length;
        for (final a in c.aliases) {
          final cleanA = a.trim();
          if (cleanA.isNotEmpty && cleanA != name) cand.aliases.add(cleanA);
        }
        if (c.roleHint != null && c.roleHint!.isNotEmpty) {
          cand.roleHints.add(c.roleHint!);
        }
        if (c.campHint != null && c.campHint!.isNotEmpty) {
          cand.campHints.add(c.campHint!);
        }
        if (c.traits != null &&
            c.traits!.isNotEmpty &&
            !cand.traits.contains(c.traits!)) {
          cand.traits.add(c.traits!);
        }
        if (c.stateChange != null && c.stateChange!.isNotEmpty) {
          cand.stateChanges.add((chapterNo: chNo, change: c.stateChange!));
        }
      }

      for (final r in m.relations) {
        final from = r.from.trim();
        final to = r.to.trim();
        if (from.isEmpty || to.isEmpty || from == to) continue;
        relations.add(
          RawRelationEvidence(
            chapterNo: chNo,
            from: from,
            to: to,
            relation: r.relation,
            kind: r.kind,
            line: r.line,
            evidence: r.evidence,
          ),
        );
      }

      for (final e in m.events) {
        final sum = e.summary.trim();
        if (sum.isEmpty) continue;
        final seq = (perChapterSeq[chNo] ?? 0) + 1;
        perChapterSeq[chNo] = seq;
        events.add(
          IndexedRawEvent(
            id: 'ev_c${chNo}_$seq',
            chapterNo: chNo,
            inWorldTime: e.inWorldTime,
            summary: sum,
            participants: e.participants,
            importance: e.importance,
          ),
        );
      }

      for (final f in m.foreshadowing) {
        final sum = f.summary.trim();
        if (sum.isEmpty) continue;
        clues.add(
          RawClueRecord(
            chapterNo: chNo,
            planted: f.planted,
            summary: sum,
            characters: f.characters,
            targetHint: f.targetHint,
          ),
        );
      }

      for (final w in m.worldbuilding) {
        final name = w.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        final cand = worlds.putIfAbsent(
          key,
          () => RawWorldCandidate(name: name, category: w.category),
        );
        cand.category ??= w.category;
        cand.chapterNos.add(chNo);
        final content = w.content.trim();
        if (content.isNotEmpty && !cand.contents.contains(content)) {
          cand.contents.add(content);
        }
      }
    }

    // 预合并：若候选 B 明确出现在高频候选 A 的 aliases 中，无损归并
    final aliasOwner = <String, String>{};
    final orderedNames = chars.values.toList()
      ..sort((a, b) => b.mentions.compareTo(a.mentions));
    for (final c in orderedNames) {
      for (final a in c.aliases) {
        aliasOwner.putIfAbsent(a, () => c.name);
      }
    }
    for (final entry in aliasOwner.entries) {
      final alias = entry.key;
      final owner = entry.value;
      if (alias != owner &&
          chars.containsKey(alias) &&
          chars.containsKey(owner) &&
          chars[owner]!.mentions >= chars[alias]!.mentions) {
        chars[owner]!.mergeFrom(chars[alias]!, recentStart: recentStart);
        chars.remove(alias);
      }
    }

    return AggregatedSourceGraph(
      totalChapters: totalChapters,
      characterCandidates: chars,
      rawEvents: events,
      rawRelations: relations,
      rawClues: clues,
      rawWorldEntries: worlds,
      cooccurrence: AggregatedSourceGraph._computeCooccurrence(events),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/source/source_graph_aggregator.dart test/source_graph_pipeline_test.dart
git commit -m "feat(source): add zero-loss SourceGraphAggregator with deterministic alias rewriting"
```

---

### Task 5: 实现 `SourceGraphReducer`（4 阶段专职归并 Prompt & 解析器）

**Files:**
- Create: `lib/domain/source/source_graph_reducer.dart`
- Test: `test/source_graph_pipeline_test.dart`

**Interfaces:**
- Consumes: `AggregatedSourceGraph`, `SourceNovelProfileData`, `CanonCamp`, `CanonCharacter`, `CanonRelationEdge`, `CanonEvent`, `CanonWorldEntry`, `CanonThread`, `LLMJSONParser`
- Produces:
  - `class GraphReduceSeq` constants (`pass1Canon = 1000`, `pass2CharBase = 2000`, `pass3RelBase = 3000`, `pass3World = 3500`, `pass4Clues = 4000`, `pass4Timeline = 4500`)
  - `class CanonPassResult` (`camps`, `skeletons`, `aliasMap`, `dropNames`)
  - `SourceGraphReducer.pass1CanonPrompt(AggregatedSourceGraph graph, {required String title})` & `parsePass1Canon(String raw)`
  - `SourceGraphReducer.selectProfileTargets(CanonPassResult canon, AggregatedSourceGraph normalized, {int maxCharacters = 48})`
  - `SourceGraphReducer.pass2CharBatchPrompt(...)` & `parsePass2CharBatch(String raw)`
  - `SourceGraphReducer.pass3RelationsPrompt(...)` & `parsePass3Relations(String raw)`
  - `SourceGraphReducer.pass3WorldPrompt(...)` & `parsePass3World(String raw)`
  - `SourceGraphReducer.pass4CluesPrompt(...)` & `parsePass4Clues(String raw)`
  - `SourceGraphReducer.pass4TimelinePrompt(...)` & `parsePass4Timeline(String raw)`

- [ ] **Step 1: Write the failing test**

Add to `test/source_graph_pipeline_test.dart`:

```dart
import 'package:zhiming/domain/source/source_graph_reducer.dart';
```

```dart
  group('SourceGraphReducer 4-pass parsers & builders', () {
    test('parses Pass 1 canon entity resolution and builds aliasMap', () {
      const raw = '''
{
  "camps": [{"name": "群星之城", "stance": "中立", "brief": "庇护所"}],
  "characters": [
    {"name": "罗娜", "aliases": ["小黑猫", "群星城主"], "role": "核心配角", "camp": "群星之城", "stance": "主角方", "importance": "major"},
    {"name": "莫烬", "aliases": ["末路灰烬"], "role": "主角", "camp": "独立", "stance": "主角方", "importance": "major"}
  ],
  "not_characters": ["路人甲", "无头战友"]
}
''';
      final res = SourceGraphReducer.parsePass1Canon(raw);
      expect(res.camps.single.name, '群星之城');
      expect(res.aliasMap['小黑猫'], '罗娜');
      expect(res.aliasMap['末路灰烬'], '莫烬');
      expect(res.dropNames, containsAll(['路人甲', '无头战友']));
    });

    test('parses Pass 3 relations and Pass 4 reconciled clues & timeline', () {
      const relRaw = '''
{
  "relations": [
    {
      "from": "莫烬",
      "to": "罗娜",
      "relationType": "盟友",
      "label": "托付群星之城",
      "description": "罗娜力竭变回黑猫前将城主权柄托付",
      "strength": 4,
      "line": "暗线",
      "firstChapter": 50,
      "lastChapter": 250,
      "evolution": [{"chapterLabel": "第248章", "state": "舍弃力量化为小黑猫"}]
    }
  ]
}
''';
      final rels = SourceGraphReducer.parsePass3Relations(relRaw);
      expect(rels.single.from, '莫烬');
      expect(rels.single.line, '暗线');
      expect(rels.single.lastChapter, 250);

      const clueRaw = '''
{
  "threads": [
    {
      "title": "罗娜的铃铛权柄",
      "detail": "第1章起提及的铃铛实为群星之城权柄载体",
      "status": "resolved",
      "plantedChapter": 1,
      "resolvedChapter": 248,
      "involvedCharacters": ["罗娜", "月莲"],
      "relatedEventSummary": "罗娜交出铃铛",
      "payoffDetail": "第248章移交月莲"
    },
    {
      "title": "主的真实意图",
      "detail": "3号载体临死宣称主的力量必须归还",
      "status": "open",
      "plantedChapter": 249,
      "involvedCharacters": ["月莲", "莫烬"]
    }
  ]
}
''';
      final clues = SourceGraphReducer.parsePass4Clues(clueRaw);
      expect(clues.length, 2);
      expect(clues[0].status, 'resolved');
      expect(clues[0].resolvedChapter, 248);
      expect(clues[1].status, 'open');
      expect(clues[1].plantedChapter, 249);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: FAIL (`source_graph_reducer.dart` does not exist).

- [ ] **Step 3: Implement `lib/domain/source/source_graph_reducer.dart`**

Implement:
- `GraphReduceSeq` constants (`1000`, `2000`, `3000`, `3500`, `4000`, `4500`).
- `CanonSkeleton` & `CanonPassResult` (`camps`, `skeletons`, `aliasMap`, `dropNames`, `toJsonString()` / `fromJsonString()` for `ScanReduces` checkpoint reload).
- `pass1CanonPrompt`: formats Top 120 `graph.orderedCandidates` into compact lines `- 名称｜别称:…｜跨章N章(第A-B章)｜身份:…｜势力:…`, asks for `{camps, characters, not_characters}` JSON only.
- `selectProfileTargets`: selects all `major` + `normal` characters and any `minor` appearing in `>= 2` chapters (sorted by importance then `chapterCount` + `recentHits * 3`), capped at `maxCharacters = 48` (ensuring 25–48 quality characters without one-off extras).
- `pass2CharBatchPrompt`: accepts a batch of 10–12 targets, renders each character's `aliases`, `camp`, `stance`, `role`, `traits` (up to 6), key `stateChanges` (first 2 + last 6), and for continuation mode appends the tail snippet (last ~2500 chars of the novel) as latest-state anchor; outputs `{"characters": [...]}`.
- `pass3RelationsPrompt`: accepts up to 50 normalized `(A, B)` pairs with their chronological `RawRelationEvidence` lines + co-occurrence count; outputs `{"relations": [...]}`.
- `pass3WorldPrompt`: renders Top 45 `rawWorldEntries` (sorted by `chapterNos.length` desc) capped at 14,000 chars; outputs `{"worldbuilding": [{"category", "name", "content", "keywords": []}]}`.
- `pass4CluesPrompt`: renders the full normalized `[埋]` pool and `[收]` pool with exact `[第X章][涉及角色]` + `targetHint` (capped gracefully at 18,000 chars favoring earliest opening seeds + recurring character clues + recent unresolved clues); instructs model to reconcile every planted clue against resolved clues and output `{"threads": [...]}` preserving `open`, `partial`, and key `resolved` threads.
- `pass4TimelinePrompt`: groups normalized `rawEvents` into chapter phases (prioritizing `major`/`normal`, capped at 18,000 chars) + list of Pass 4A clue titles; outputs `{"timeline": [...], "activeArcs": [...]}` with `chapterStart`, `chapterEnd`, `inWorldTime`, `linkedClueTitles`.
- Strict `LLMJSONParser.decodeTopLevelObject` / `decodeObject` parsing on every pass with clear `FormatException` messages.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/source/source_graph_reducer.dart test/source_graph_pipeline_test.dart
git commit -m "feat(source): implement 4-pass SourceGraphReducer for canon, profiles, relations, clues and timeline"
```

---

### Task 6: 升级 `AppDatabase`、`SourceScanController` 与扫描弹窗（并发 Map + Graph-Reduce 4 阶段断点续跑）

**Files:**
- Modify: `lib/core/database/app_database.dart` (add `loadScanReduceMap`)
- Modify: `lib/features/source_archive/source_scan_controller.dart`
- Modify: `lib/features/source_archive/source_scan_dialogs.dart`
- Modify: `lib/features/source_archive/source_library_page.dart`
- Test: `test/source_graph_pipeline_test.dart`

**Interfaces:**
- Consumes: `SourceGraphAggregator`, `SourceGraphReducer`, `GraphReduceSeq`, `NovelLocalIndexer`, `BackgroundKeepAliveService`
- Produces:
  - `AppDatabase.loadScanReduceMap(String profileId)` → `Future<Map<int, String>>`
  - `SourceScanController.start({..., int concurrency = 3})` running concurrent Map + 4-Pass Graph-Reduce with full checkpoint resume on both `ScanChunks` and `ScanReduces`

- [ ] **Step 1: Write the failing test**

Add an end-to-end controller test (in-memory Drift DB + Stub `LLMClient`) to `test/source_graph_pipeline_test.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/storage/blob_store.dart';
import 'package:zhiming/features/source_archive/source_scan_controller.dart';
```

```dart
  group('SourceScanController Graph-Reduce E2E', () {
    test('runs concurrent map + 4-pass graph reduce with zero chapter loss and checkpoints', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final tmp = await Directory.systemTemp.createTemp('zm_graph_scan_');
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final stub = _GraphScanStubClient();
      final ctrl = SourceScanController(
        db: db,
        blobs: BlobStore(baseDirOverride: tmp),
        client: stub,
        provider: ProviderRecord(
          id: 'prov-1',
          name: 'Test',
          baseUrl: 'https://example.com/v1',
          apiKeyId: 'k1',
          modelName: 'test-model',
          temperature: 0.2,
          maxTokens: 16384,
          contextBudgetChars: 60000,
          isDefault: true,
          createdAt: DateTime(2026),
        ),
      );

      final book = List.generate(
        6,
        (i) => '第${i + 1}章 章节${i + 1}\n莫烬与罗娜在群星之城探索银色怀表的秘密。',
      ).join('\n\n');

      await ctrl.start(
        sourceText: book,
        title: '测试长篇',
        mode: ScanMode.full,
        batchSize: 3,
        concurrency: 2,
        isContinuation: true,
      );

      expect(ctrl.phase, ScanPhase.done, reason: ctrl.errorMessage);
      final profile = ctrl.resultProfile!;
      expect(profile.meta.totalChapters, 6);
      expect(profile.characters.map((c) => c.name), containsAll(['莫烬', '罗娜']));
      expect(profile.relations, isNotEmpty);
      expect(profile.relations.first.from, '莫烬');
      expect(profile.openThreads.length, 2);
      expect(profile.openThreads.any((t) => t.status == 'resolved' && t.resolvedChapter == 6), isTrue);
      expect(profile.timeline, isNotEmpty);
      expect(profile.timeline.first.chapterStart, 1);
      ctrl.dispose();
    });
  });
}

class _GraphScanStubClient implements LLMClient {
  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    final joined = messages.map((m) => m.content).join('\n');
    if (joined.contains('增量式微摘要')) {
      final matches = RegExp(r'第(\d+)章').allMatches(joined);
      final chNos = matches.map((m) => int.parse(m.group(1)!)).toSet().toList()..sort();
      final lines = [
        for (final n in chNos)
          jsonEncode({
            'chapter': n,
            'characters': [
              {'name': '莫烬', 'aliases': ['末路灰烬'], 'traits': '冷静', 'state_change': '第$n章行动'},
              {'name': n == 6 ? '小黑猫' : '罗娜', 'camp_hint': '群星之城', 'traits': '城主'},
            ],
            'relations': [
              {'from': '莫烬', 'to': n == 6 ? '小黑猫' : '罗娜', 'relation': '托付群星之城', 'kind': '盟友', 'line': '暗线'},
            ],
            'events': [
              {'summary': '第$n章探索银色怀表', 'in_world_time': '第$n天', 'participants': ['莫烬', n == 6 ? '小黑猫' : '罗娜'], 'importance': 'major'},
            ],
            'worldbuilding': [
              {'name': '群星之城', 'category': '地点', 'content': '庇护所'},
            ],
            'foreshadowing': [
              if (n == 1) {'summary': '银色怀表的真实来历', 'planted': true, 'characters': ['莫烬']},
              if (n == 1) {'summary': '罗娜铃铛的秘密', 'planted': true, 'characters': ['罗娜']},
              if (n == 6) {'summary': '铃铛权柄移交揭晓', 'planted': false, 'characters': ['小黑猫'], 'target_hint': '罗娜铃铛的秘密'},
            ],
          }),
      ];
      yield ContentDelta(lines.join('\n'));
      return;
    }
    if (joined.contains('not_characters')) {
      yield const ContentDelta(
        '{"camps":[{"name":"群星之城","stance":"中立","brief":"庇护所"}],'
        '"characters":[{"name":"莫烬","aliases":["末路灰烬"],"role":"主角","camp":"独立","stance":"主角方","importance":"major"},'
        '{"name":"罗娜","aliases":["小黑猫"],"role":"核心配角","camp":"群星之城","stance":"主角方","importance":"major"}],'
        '"not_characters":[]}',
      );
      return;
    }
    if (joined.contains('"relations"')) {
      yield const ContentDelta(
        '{"relations":[{"from":"莫烬","to":"罗娜","relationType":"盟友","label":"托付群星之城","strength":4,"line":"暗线","firstChapter":1,"lastChapter":6}]}',
      );
      return;
    }
    if (joined.contains('"worldbuilding"')) {
      yield const ContentDelta(
        '{"worldbuilding":[{"category":"地点","name":"群星之城","content":"庇护所","keywords":["群星之城"]}]}',
      );
      return;
    }
    if (joined.contains('"threads"')) {
      yield const ContentDelta(
        '{"threads":[{"title":"银色怀表的真实来历","detail":"第1章埋下","status":"open","plantedChapter":1,"involvedCharacters":["莫烬"]},'
        '{"title":"罗娜铃铛的秘密","detail":"权柄载体","status":"resolved","plantedChapter":1,"resolvedChapter":6,"involvedCharacters":["罗娜"],"payoffDetail":"第6章移交"}]}',
      );
      return;
    }
    if (joined.contains('"timeline"')) {
      yield const ContentDelta(
        '{"timeline":[{"phase":"开局","chapterRange":"第1-6章","chapterStart":1,"chapterEnd":6,"inWorldTime":"第1-6天","summary":"莫烬与罗娜探索怀表与铃铛","participants":["莫烬","罗娜"],"linkedClueTitles":["罗娜铃铛的秘密"],"importance":"major"}],"activeArcs":["探索银色怀表"]}',
      );
      return;
    }
    yield const ContentDelta(
      '{"characters":[{"name":"莫烬","aliases":["末路灰烬"],"oneLine":"末日行商","role":"主角","camp":"独立","stance":"主角方","importance":"major","currentState":"在群星之城"},'
      '{"name":"罗娜","aliases":["小黑猫"],"oneLine":"群星城主","role":"核心配角","camp":"群星之城","stance":"主角方","importance":"major","currentState":"化为小黑猫"}]}',
    );
  }

  @override
  Future<String> testConnection({CancelToken? cancelToken}) async => 'ok';

  @override
  Future<List<String>> fetchModelIds({CancelToken? cancelToken}) async => const [];
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/source_graph_pipeline_test.dart`
Expected: FAIL (`concurrency` parameter not defined on `SourceScanController.start`).

- [ ] **Step 3: Implement changes**

1. In `lib/core/database/app_database.dart`: add `loadScanReduceMap(String profileId)` returning `{for (final r in rows) r.seq: r.summaryText}`.
2. In `lib/features/source_archive/source_scan_controller.dart`:
   - Add `int concurrency = 3` parameter to `start(...)`, clamped to `1..4`.
   - Build Map batch tasks grouped by consecutive undone chunks (using true `chunk.chapterNo` and `chunk.chapterTitle` in `BatchChapterInput`; when a single chapter has `partCount > 1`, label `title: '${chunk.chapterTitle}（第${chunk.partIndex + 1}/${chunk.partCount}段）'`).
   - Execute Map batches via a bounded async worker pool (`List.generate(clampedConcurrency, (_) => worker())`), storing each completed chunk in `ScanChunks` with `chapterNo` inside `MicroSummary`.
   - After Map completes (all `chunks.length` done):
     - Load all `ScanChunks` rows, pair each with `chunks[row.idx].chapterNo`, and run `SourceGraphAggregator.build(...)`.
     - Load existing `savedReduces = await db.loadScanReduceMap(pid)` so every Pass skips already-completed `seq` slots on resume!
     - **Pass 1 (`seq = 1000`)**: Canon entity resolution → `normalized = aggregated.applyAliasMap(canon.aliasMap, dropNames: canon.dropNames)`.
     - **Pass 2 (`seq = 2000 + i`)**: Batched character profiling (10–12 chars/batch, max 2 concurrent) + enrich `voiceSamples` from `NovelLocalIndexer` (run in `Isolate.run`).
     - **Pass 3A (`seq = 3000 + i`) & Pass 3B (`seq = 3500`)**: Relations (chunked by <=50 pairs) & Worldbuilding (can run concurrently!).
     - **Pass 4A (`seq = 4000`) & Pass 4B (`seq = 4500`)**: Clues reconciliation then Timeline & ActiveArcs (receiving Pass 4A titles).
     - Sync `CanonCharacter.relationships` from `relations` for backward compatibility, assemble final `SourceNovelProfileData`, persist to `SourceProfiles` + `BlobStore`, and clear checkpoints.
   - Keep `WakelockPlus` and `BackgroundKeepAliveService.instance.acquire()/release()` intact in `try/finally`.
3. In `lib/features/source_archive/source_library_page.dart` & `source_scan_dialogs.dart`:
   - Add an optional `并发数` selector (`1 / 2 / 3 / 4`, default `3`) for `ScanMode.fast` / `ScanMode.full`, passing `concurrency` into `SourceScanProgressDialog` and `SourceScanController.start`.

- [ ] **Step 4: Run full analysis & test suite**

Run: `flutter analyze && flutter test test/source_graph_pipeline_test.dart test/source_domain_test.dart`
Expected: `No issues found!` and all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/app_database.dart lib/features/source_archive/source_scan_controller.dart lib/features/source_archive/source_scan_dialogs.dart lib/features/source_archive/source_library_page.dart test/source_graph_pipeline_test.dart
git commit -m "feat(source): upgrade SourceScanController to concurrent Map and 4-pass Graph-Reduce"
```
