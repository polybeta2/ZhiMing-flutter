import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/core/storage/blob_store.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
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
}
