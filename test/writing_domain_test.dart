import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/core/llm/llm_json_parser.dart';
import 'package:zhiming/domain/models/novel_domain.dart';
import 'package:zhiming/domain/tools/export_service.dart';
import 'package:zhiming/domain/tools/statistics_service.dart';
import 'package:zhiming/domain/writing/context_builder.dart';
import 'package:zhiming/domain/writing/text_diff.dart';

void main() {
  group('ContextBuilder, Neighbor Seam, Export & Statistics', () {
    late AppDatabase db;
    late NovelRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NovelRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('buildContinueContext injects neighbor prose tail, next outline head & respects budget', () async {
      final novelId = await repo.createBlankNovel(
        title: '雾港来信',
        synopsis: '一个关于雾港与旧灯塔的故事',
        styleGuide: '冷峻白描',
      );
      final vols = await db.getVolumes(novelId);
      final volId = vols.first.id;
      final ch1 = (await db.getChaptersByVolume(volId)).first;
      await repo.saveChapterContent(
        novelId: novelId,
        chapterId: ch1.id,
        content: '雨点砸在窗棂上。电话铃忽然响了起来。',
      );
      await repo.applySummaryResult(
        novelId: novelId,
        chapter: (await db.getChapter(ch1.id))!,
        result: const SummaryResult(
          summary: '沈屿在雾港收到匿名电话。',
          keyFacts: ['电话来自老灯塔'],
          newForeshadowings: [
            ForeshadowExtraction(
              title: '旧灯塔钥匙',
              plannedResolve: '第一卷末',
            ),
          ],
        ),
      );

      await repo.addChapter(
        novelId,
        volId,
        title: '第二章 接听',
        detailedOutline: '沈屿接起电话，得知老纸坊线索。',
        sceneCards: const [
          SceneCard(goal: '确认来电者', obstacle: '信号断续', hook: '纸坊地址'),
        ],
      );
      await repo.addChapter(
        novelId,
        volId,
        title: '第三章 老纸坊',
        detailedOutline: '沈屿夜探城南老纸坊，发现账本残页。',
      );

      await db.upsertCharacter(
        CharactersCompanion.insert(
          id: 'char1',
          novelId: novelId,
          name: '沈屿',
          personality: const Value('冷静克制'),
        ),
      );
      await db.upsertWorldEntry(
        WorldEntriesCompanion.insert(
          id: 'w1',
          novelId: novelId,
          category: '地点',
          name: '雾港',
          content: const Value('常年浓雾的港口小城'),
        ),
      );

      final bundle = (await repo.loadBundle(novelId))!;
      final ch2Bundle = bundle.allChaptersInOrder[1];

      final ctx = ContextBuilder.buildContinueContext(
        chapter: ch2Bundle,
        bundle: bundle,
        budgetChars: 20000,
      );
      expect(ctx.rendered, contains('【上一章正文末尾】'));
      expect(ctx.rendered, contains('电话铃忽然响了起来'));
      expect(ctx.rendered, contains('【下一章细纲（开头走向）】'));
      expect(ctx.rendered, contains('老纸坊'));
      expect(ctx.rendered, contains('【前文摘要'));
      expect(ctx.rendered, contains('【关键事实】'));
      expect(ctx.rendered, contains('【未回收伏笔提醒】'));
      expect(ctx.truncatedSections, isEmpty);

      // 极小预算下保留必需层，裁剪高优先/可选层并上报
      final tight = ContextBuilder.buildContinueContext(
        chapter: ch2Bundle,
        bundle: bundle,
        budgetChars: 10,
      );
      expect(tight.rendered, contains('【风格约束】'));
      expect(tight.rendered, contains('【本章细纲】'));
      expect(tight.truncatedSections, contains('前文摘要'));
      expect(tight.truncatedSections, contains('角色状态'));
    });

    test('snapshot rolling cap & non-destructive restore', () async {
      final novelId = await repo.createBlankNovel(title: '测试书');
      final vol = (await db.getVolumes(novelId)).first;
      final ch = (await db.getChaptersByVolume(vol.id)).first;

      for (var i = 1; i <= 55; i++) {
        await repo.takeSnapshot(
          chapterId: ch.id,
          content: '版本$i',
          triggerType: 'manual_save',
        );
      }
      final snaps = await db.getSnapshots(ch.id);
      expect(snaps.length, NovelRepository.maxSnapshotsPerChapter);
      expect(snaps.first.versionNumber, 55);
      expect(snaps.last.versionNumber, 6);

      await repo.saveChapterContent(
        novelId: novelId,
        chapterId: ch.id,
        content: '最新未保存正文',
      );
      await repo.restoreSnapshot(
        novelId: novelId,
        chapterId: ch.id,
        snapshot: snaps.last,
      );
      final restoredCh = (await db.getChapter(ch.id))!;
      expect(restoredCh.content, '版本6');
      final afterSnaps = await db.getSnapshots(ch.id);
      expect(afterSnaps.first.triggerType, 'restore');
      expect(afterSnaps.first.content, '最新未保存正文');
    });

    test('StatisticsService & ExportService cover all modes', () async {
      final novelId = await repo.createBlankNovel(title: '归港', synopsis: '简介');
      final vol = (await db.getVolumes(novelId)).first;
      final ch1 = (await db.getChaptersByVolume(vol.id)).first;
      await repo.saveChapterContent(
        novelId: novelId,
        chapterId: ch1.id,
        content: '字' * 1200,
      );
      await repo.addChapter(novelId, vol.id, title: '草稿章', content: '字' * 300);
      await repo.addChapter(novelId, vol.id, title: '空白章');

      final bundle = (await repo.loadBundle(novelId))!;
      final stats = StatisticsService.calculate(bundle);
      expect(stats.totalWordCount, 1500);
      expect(stats.completedChapters, 1);
      expect(stats.draftChapters, 1);
      expect(stats.emptyChapters, 1);
      expect(stats.averageChapterWords, 500);

      final md = ExportService.export(
        bundle: bundle,
        scope: const FullNovelScope(),
        format: ExportFormat.markdown,
      );
      expect(md, contains('# 《归港》'));
      expect(md, contains('### 第1章 第一章'));
      expect(
        ExportService.fileName(
          bundle: bundle,
          scope: const OutlineOnlyScope(),
          format: ExportFormat.txt,
        ),
        '《归港》-大纲.txt',
      );
    });

    test('TextDiff produces accurate added/removed/unchanged lines', () {
      final diff = TextDiff.diffLines('第一行\n旧句\n第三行', '第一行\n新句\n第三行');
      expect(diff.where((d) => d.kind == DiffKind.removed).single.text, '旧句');
      expect(diff.where((d) => d.kind == DiffKind.added).single.text, '新句');
      expect(diff.where((d) => d.kind == DiffKind.unchanged).length, 2);
    });
  });
}
