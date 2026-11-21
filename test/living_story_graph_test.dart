import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/core/storage/blob_store.dart';
import 'package:zhiming/domain/models/novel_domain.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
import 'package:zhiming/domain/writing/chapter_ledger.dart';
import 'package:zhiming/domain/writing/context_builder.dart';
import 'package:zhiming/domain/writing/fact_review_service.dart';
import 'package:zhiming/domain/writing/lorebook_matcher.dart';
import 'package:zhiming/features/source_archive/source_injection_helper.dart';

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
      expect(
        bundle.timelineEvents.single.linkedForeshadowingIdsJson,
        isNot('[]'),
      );
      expect(bundle.foreshadowings.single.status, 'resolved');
      expect(bundle.foreshadowings.single.resolvedChapterOrder, 2);
      expect(bundle.worldEntries.single.keywordsJson, contains('星光之城'));
    });
  });

  group('ChapterLedger relation & timeline incremental writeback', () {
    test('parses and applies relationship_deltas (appending evolution) and timeline_events', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NovelRepository(db);
      final now = DateTime(2026, 11, 21);

      await db.upsertNovel(
        NovelsCompanion.insert(
          id: 'n1',
          title: '测试',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.upsertVolume(
        VolumesCompanion.insert(
          id: 'v1',
          novelId: 'n1',
          name: '第一卷',
          sortOrder: 1,
        ),
      );
      await db.upsertChapter(
        ChaptersCompanion.insert(
          id: 'ch-249',
          volumeId: 'v1',
          title: '第249章 不要跟女人比心机',
          sortOrder: 249,
          updatedAt: now,
        ),
      );
      final chapter = (await db.getChapter('ch-249'))!;
      await db.upsertCharacter(
        CharactersCompanion.insert(id: 'c1', novelId: 'n1', name: '莫烬'),
      );
      await db.upsertCharacter(
        CharactersCompanion.insert(id: 'c2', novelId: 'n1', name: '月莲'),
      );
      await db.upsertCharacterRelation(
        CharacterRelationsCompanion.insert(
          id: 'r1',
          novelId: 'n1',
          sourceCharacterId: 'c1',
          targetCharacterId: 'c2',
          relationType: const Value('盟友'),
          label: '短暂同行',
          evolutionJson: const Value(
            '[{"chapterLabel":"第92章","state":"初遇合作"}]',
          ),
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
        chapter: chapter,
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

  group('LorebookMatcher, ContextBuilder & FactReview relation/timeline integration', () {
    test('1-hop recalls secret relation partner and injects relation & timeline blocks', () {
      final now = DateTime(2026, 11, 21);
      final c1 = Character(
        id: 'c1',
        novelId: 'n1',
        name: '莫烬',
        aliasesJson: '[]',
        arcJson: '[]',
        isSceneRelevant: true,
        sortOrder: 0,
      );
      final c2 = Character(
        id: 'c2',
        novelId: 'n1',
        name: '爱丽丝',
        aliasesJson: '[]',
        arcJson: '[]',
        isSceneRelevant: false,
        sortOrder: 1,
      );
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
      final ch1 = ChapterBundle(
        chapter: Chapter(
          id: 'ch1',
          volumeId: 'v1',
          title: '第1章',
          content: '钟表屋逃亡。',
          sortOrder: 1,
          wordCount: 6,
          isOriginal: false,
          updatedAt: now,
        ),
        volumeId: 'v1',
        volumeName: '第一卷',
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
        novel: Novel(
          id: 'n1',
          title: '测试',
          synopsis: '',
          enabledTagIdsJson: '[]',
          r18Enabled: false,
          lastTotalWordCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
        volumes: [
          VolumeBundle(
            volume: Volume(
              id: 'v1',
              novelId: 'n1',
              name: '第一卷',
              sortOrder: 1,
            ),
            chapters: [ch1, ch2],
          ),
        ],
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

      final truthArchive = FactReviewService.buildTruthArchive(
        chapter: ch2,
        bundle: bundle,
        draftContent: '莫烬在公寓中等待天黑。',
      );
      expect(truthArchive, contains('【人物关系网与明暗线边界】'));
      expect(truthArchive, contains('暗线/信息壁垒注意'));
      expect(truthArchive, contains('【显式故事时间线'));
    });
  });
}
