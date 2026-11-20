import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/domain/creation/creation_session_engine.dart';
import 'package:zhiming/domain/models/blueprint_models.dart';
import 'package:zhiming/domain/writing/assistant_patch.dart';

void main() {
  group('CreationSessionEngine & Blueprint tolerant decoding', () {
    test('handles string-array conflict_ladder & full 5-phase replay into DB', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NovelRepository(db);
      final novelId = await repo.createCreationNovel(
        title: '临时',
        brief: '雾港邮差发现三年前的自己寄来的密信',
      );

      final engine = CreationSessionEngine(
        CreationSessionState(brief: '雾港邮差发现三年前的自己寄来的密信'),
      );

      // 1) Clarify enough=true -> auto requestStructure
      final c1 = engine.settle(
        kind: CreationStreamKind.clarify,
        raw: '{"enough": true, "reason": "ok", "questions": []}',
      );
      expect(c1.nextStep, CreationNextStep.requestStructure);

      // 2) Structure proposal
      final s1 = engine.settle(
        kind: CreationStreamKind.structure,
        raw: '{"concept":"悬疑长篇","volumes":[{"name":"第一卷：雾起","chapter_count":2}]}',
      );
      expect(s1.error, isNull);
      expect(engine.state.phase, CreationPhase.proposing);

      // 3) Foundation with string-array conflict_ladder (v2.1.2 regression)
      final f1 = engine.settle(
        kind: CreationStreamKind.foundation,
        raw: '''{
          "title_suggestion": "雾港来信",
          "theme": "悬疑推理",
          "synopsis": "雾港邮差追查密信",
          "perspective": "第三人称限知",
          "style_guide": "冷峻白描",
          "characters": [{"name":"沈屿","role":"主角","personality":"克制","goal":"找回记忆"}],
          "worldbuilding": [{"category":"地点","name":"雾港","content":"常年浓雾"}],
          "volumes": [{
            "name": "第一卷：雾起",
            "conflict_ladder": ["港口封锁", "真凶冒充"],
            "chapters": [{"title":"番外"},{"title":"番外"}]
          }]
        }''',
      );
      expect(f1.error, isNull);
      expect(engine.state.phase, CreationPhase.blueprintReady);
      expect(engine.state.blueprint!.volumes.first.conflictLadder!.length, 2);

      // 4) Volume batch with decorated name variation (v2.6.1 fuzzy match)
      final v1 = engine.settle(
        kind: CreationStreamKind.volumeBatch,
        raw: '[{"name":"第一卷 雾起","outline":"主角在浓雾中拆开第一封信","emotion_arc":["压抑","反转"]}]',
      );
      expect(v1.error, isNull);
      expect(engine.outlineProgress.volumeDone, 1);

      // 5) Chapter batch with duplicate chapter titles consumes sequentially
      final ch1 = engine.settle(
        kind: CreationStreamKind.chapterBatch,
        raw: '''[
          {"title":"「番外」","detailed_outline":"第一段番外细纲","scene_cards":[{"goal":"拆信","obstacle":"封蜡","hook":"指纹"}]},
          {"title":"番外","detailed_outline":"第二段番外细纲"}
        ]''',
      );
      expect(ch1.error, isNull);
      expect(engine.outlineProgress.outlineDone, 2);

      // 6) Persist to Drift DB
      await CreationSessionEngine.persistBlueprintToDb(
        db: db,
        novelId: novelId,
        blueprint: engine.state.blueprint!,
      );
      final bundle = (await repo.loadBundle(novelId))!;
      expect(bundle.novel.title, '雾港来信');
      expect(bundle.characters.single.name, '沈屿');
      expect(bundle.volumes.single.chapters.length, 2);
      expect(bundle.volumes.single.chapters[0].chapter.detailedOutline, '第一段番外细纲');
      expect(bundle.volumes.single.chapters[1].chapter.detailedOutline, '第二段番外细纲');
    });

    test('fuzzyMatchIndex skips ambiguous substring matches', () {
      expect(
        CreationSessionEngine.fuzzyMatchIndex(['第1章 雾起', '第2章 雾起再临'], '雾起'),
        isNull,
      );
      expect(
        CreationSessionEngine.fuzzyMatchIndex(['第一卷：雾起', '第二卷：海沉'], '雾起'),
        0,
      );
    });
  });

  group('AssistantPatch extract & apply', () {
    test('extracts fenced zm-patch and applies character, world, rename & scene cards', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NovelRepository(db);
      final novelId = await repo.createBlankNovel(title: '原名');
      final vol = (await db.getVolumes(novelId)).first;
      final ch = (await db.getChaptersByVolume(vol.id)).first;
      await db.upsertCharacter(
        CharactersCompanion.insert(id: 'c1', novelId: novelId, name: '沈屿'),
      );

      const reply = '''好的，我建议调整沈屿的目标并新增场景卡。
```zm-patch
{
  "summary": "更新沈屿状态并重命名章节",
  "character_updates": [{"find":"沈屿","set":{"currentGoal":"查清灯塔真相","isSceneRelevant":"true"}}],
  "character_adds": [{"name":"林澈","personality":"机警"}],
  "world_upserts": [{"category":"地点","name":"老纸坊","content":"城南废弃作坊"}],
  "chapter_renames": [{"find":"第一卷/第一章","to":"雾港来信"}],
  "scene_cards": [{"chapter":"第一章","add":[{"goal":"取信","obstacle":"暴雨","hook":"署名"}]}]
}
```''';

      final extracted = AssistantPatch.extract(reply);
      expect(extracted.patch, isNotNull);
      expect(extracted.cleanedText, '好的，我建议调整沈屿的目标并新增场景卡。');

      final bundle = (await repo.loadBundle(novelId))!;
      final desc = extracted.patch!.describe(bundle);
      expect(desc.length, 5);

      final res = await extracted.patch!.applyToDb(db: db, bundle: bundle);
      expect(res.every((l) => l.startsWith('✅')), isTrue);

      final updated = (await repo.loadBundle(novelId))!;
      expect(
        updated.characters.firstWhere((c) => c.name == '沈屿').currentGoal,
        '查清灯塔真相',
      );
      expect(updated.characters.any((c) => c.name == '林澈'), isTrue);
      expect(updated.worldEntries.single.name, '老纸坊');
      expect((await db.getChapter(ch.id))!.title, '雾港来信');
      expect(updated.allChaptersInOrder.single.sceneCards.single.hook, '署名');
    });
  });
}
