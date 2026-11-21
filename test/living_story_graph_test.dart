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
