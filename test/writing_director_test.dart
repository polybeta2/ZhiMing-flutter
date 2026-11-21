import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/core/prompts/prompt_library.dart';
import 'package:zhiming/core/prompts/prompt_limits.dart';
import 'package:zhiming/core/widgets/character_graph_canvas.dart';
import 'package:zhiming/domain/writing/chapter_ledger.dart';
import 'package:zhiming/domain/writing/context_builder.dart';
import 'package:zhiming/domain/writing/prose_checker.dart';
import 'package:zhiming/domain/writing/writing_director_composer.dart';
import 'package:zhiming/domain/writing/writing_director_config.dart';

void main() {
  group('WritingDirectorConfig & WritingDirectorComposer', () {
    test('strictly produces 0 tokens when all switches are default off and R18 is disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await WritingDirectorStore.load('novel_empty');
      expect(loaded, const WritingDirectorConfig());
      expect(loaded.hasActiveRules(r18Enabled: false), isFalse);
      expect(
        WritingDirectorComposer.composeStaticBlock(loaded, r18Enabled: false),
        isEmpty,
      );
      expect(
        WritingDirectorComposer.composeThinkingSteps(loaded, r18Enabled: false),
        isEmpty,
      );
    });

    test('dynamically inserts step 20 when strictAntiOmniscience is enabled and sorts ascending', () {
      const baseCfg = WritingDirectorConfig(deepPreWriteThinking: true);
      final baseSteps = WritingDirectorComposer.composeThinkingSteps(
        baseCfg,
        r18Enabled: false,
      );
      expect(baseSteps.map((s) => s.order).toList(), [10, 30, 40, 50, 60]);

      final withAntiOmni = baseCfg.copyWith(strictAntiOmniscience: true);
      final mergedSteps = WritingDirectorComposer.composeThinkingSteps(
        withAntiOmni,
        r18Enabled: false,
      );
      expect(
        mergedSteps.map((s) => s.order).toList(),
        [10, 20, 30, 40, 50, 60],
      );
      expect(mergedSteps[1].instruction, contains('知识盲区'));

      final onlyAntiOmni = WritingDirectorComposer.composeThinkingSteps(
        const WritingDirectorConfig(strictAntiOmniscience: true),
        r18Enabled: false,
      );
      expect(onlyAntiOmni.map((s) => s.order).toList(), [20]);
    });

    test('renders R18 presets and anti-daily-horny gate only when r18Enabled is true', () {
      const cfg = WritingDirectorConfig(
        cameraMode: ProseCameraMode.cinematic,
        livingHumanFeel: true,
        r18StylePreset: R18StylePreset.soothingRestrained,
        r18StrictOutlineGate: true,
        r18IntimateDialogue: true,
      );

      final withoutR18 = WritingDirectorComposer.composeStaticBlock(
        cfg,
        r18Enabled: false,
      );
      expect(withoutR18, contains('电影运镜'));
      expect(withoutR18, contains('活人感加强'));
      expect(withoutR18, isNot(contains('R18 细分尺度与门控')));

      final withR18 = WritingDirectorComposer.composeStaticBlock(
        cfg,
        r18Enabled: true,
      );
      expect(withR18, contains('R18 细分尺度与门控'));
      expect(withR18, contains('舒缓克制'));
      expect(withR18, contains('防日常发情门控'));
      expect(withR18, contains('亲密台词声感'));

      // 开发者工坊覆写 PromptID.directorCinematic 后立即生效
      const customLib = PromptLibraryState(
        overrides: {
          PromptID.directorCinematic: '【自定义电影运镜覆写】长镜头慢推不切镜。',
        },
      );
      final overridden = WritingDirectorComposer.composeStaticBlock(
        cfg,
        r18Enabled: false,
        library: customLib,
      );
      expect(overridden, contains('【自定义电影运镜覆写】长镜头慢推不切镜。'));
    });

    test('persists per-novel config and cleans up on delete', () async {
      SharedPreferences.setMockInitialValues({});
      const cfg = WritingDirectorConfig(
        cameraMode: ProseCameraMode.pureSensory,
        calmDailyPacing: true,
        antiClicheOpenClose: true,
        trackOffscreenBeats: true,
        r18StylePreset: R18StylePreset.explicitIntense,
        r18StrictOutlineGate: false,
      );
      await WritingDirectorStore.save('n_42', cfg);
      expect(await WritingDirectorStore.load('n_42'), cfg);

      await WritingDirectorStore.delete('n_42');
      expect(
        await WritingDirectorStore.load('n_42'),
        const WritingDirectorConfig(),
      );
    });
  });

  group('ProseChecker Meowssiah anti-slop rules', () {
    test('catches stone-ripple opening, emotion tag tails, and imperceptible slop', () {
      const sample =
          '她的话像一颗石子投入平静的湖面，瞬间激起层层涟漪。'
          '他转过身，声音中带着一丝不容置疑的意味，眼底闪过一抹不易察觉的冷意。'
          '屋檐下的雨水顺着铜铃滑落，远处巷口传来清脆的马蹄声。';
      final rules = ProseChecker.check(sample).map((e) => e.rule).toSet();
      expect(
        rules,
        containsAll(['公式化投石开头', '动作后情绪解读尾巴', '空洞抽象修饰']),
      );
    });
  });

  group('High-density scene_freeze & offscreen_beats in Ledger & ContextBuilder', () {
    test('persists scene_freeze & offscreen_beats without schema change and separates them in ContextBuilder', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NovelRepository(db);
      addTearDown(db.close);

      final novelId = await repo.createBlankNovel(title: '场记测试');
      final volId = (await db.getVolumes(novelId)).single.id;
      final ch1Id = (await db.getChaptersByVolume(volId)).single.id;
      final ch1 = (await db.getChapter(ch1Id))!;
      await db.upsertChapter(
        ch1
            .copyWith(
              title: '第1章 钟楼交锋',
              content: '陆深按住桌上发烫的怀表，抬眼望向门口。',
              wordCount: 20,
            )
            .toCompanion(true),
      );
      await db.upsertChapter(
        ChaptersCompanion.insert(
          id: 'ch_2',
          volumeId: volId,
          sortOrder: 1,
          title: '第2章 雾港追踪',
          detailedOutline: const Value('承接钟楼对峙，决定追查老码头。'),
          updatedAt: DateTime.now(),
        ),
      );

      const rawLedger = '''
{
  "summary": "陆深在钟楼拿到铜钥匙并与老周约定子夜去老码头。",
  "key_facts": ["陆深拿到钟楼三号铜钥匙"],
  "new_foreshadowings": [],
  "resolved_foreshadowing_titles": [],
  "character_deltas": [],
  "new_characters": [],
  "new_world_entries": [],
  "relationship_deltas": [],
  "timeline_events": [],
  "scene_freeze": "陆深风衣敞开、左手压着桌面怀表，右手攥着三号铜钥匙，正与门口老周对视。",
  "offscreen_beats": ["海关巡逻队已在东码头封锁渡口并调集探照灯"]
}
''';
      final ext = ChapterLedgerExtraction.tryParse(rawLedger);
      expect(ext, isNotNull);
      expect(ext!.sceneFreeze, contains('三号铜钥匙'));
      expect(ext.offscreenBeats.single, contains('海关巡逻队'));

      await ChapterLedgerApplier.applyToDb(
        db: db,
        repo: repo,
        novelId: novelId,
        chapter: (await db.getChapter(ch1Id))!,
        extraction: ext,
      );

      final bundle = (await repo.loadBundle(novelId))!;
      final ch2 = bundle.allChaptersInOrder[1];
      final ctx = ContextBuilder.buildContinueContext(
        chapter: ch2,
        bundle: bundle,
        budgetChars: 30000,
        directorConfig: const WritingDirectorConfig(
          cameraMode: ProseCameraMode.cinematic,
          strictAntiOmniscience: true,
          deepPreWriteThinking: true,
          trackOffscreenBeats: true,
        ),
      );

      // Director rules + thinking steps sit in staticPrefix (KV Cache friendly)
      expect(ctx.staticPrefix, contains('【写作导演微调】'));
      expect(ctx.staticPrefix, contains('【写前静默导演推演清单'));
      expect(ctx.staticPrefix, contains('知识盲区'));

      // Scene freeze sits right next to previous prose tail in dynamicSuffix
      expect(ctx.dynamicSuffix, contains('【上一章结尾定格快照（衣着/持物/姿态锚点）】'));
      expect(ctx.dynamicSuffix, contains('陆深风衣敞开'));

      // Offscreen beat is separated from 【关键事实】 into its own block
      expect(ctx.dynamicSuffix, contains('【场外暗线演化（供后续自然收束，勿硬塞本章）】'));
      expect(ctx.dynamicSuffix, contains('海关巡逻队'));

      // Normal 【关键事实】 retains only genuine key facts without duplicate tagged prefixes
      final keyFactsIdx = ctx.dynamicSuffix.indexOf('【关键事实】');
      expect(keyFactsIdx, greaterThanOrEqualTo(0));
      final afterKeyFacts = ctx.dynamicSuffix.substring(keyFactsIdx);
      final keyFactsSection = afterKeyFacts.split('\n\n').first;
      expect(keyFactsSection, contains('陆深拿到钟楼三号铜钥匙'));
      expect(keyFactsSection, isNot(contains(ChapterLedgerExtraction.sceneFreezePrefix)));
      expect(keyFactsSection, isNot(contains(ChapterLedgerExtraction.offscreenBeatPrefix)));
    });

    test('CharacterGraphLayout.compute handles null and blank camp without throwing', () {
      const nodes = [
        GraphNode(id: 'c1', name: '陆深', camp: null),
        GraphNode(id: 'c2', name: '老周', camp: '  '),
        GraphNode(id: 'c3', name: '沈默', camp: '暗桩'),
      ];
      const edges = [
        GraphEdge(id: 'e1', fromId: 'c1', toId: 'c2', label: '合作', relationType: '盟友'),
      ];
      final pos = CharacterGraphLayout.compute(nodes, edges);
      expect(pos.keys, containsAll(['c1', 'c2', 'c3']));
    });
  });
}
