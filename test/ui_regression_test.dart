import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiming/app.dart';
import 'package:zhiming/core/database/app_database.dart' hide ScanMeta;
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/core/security/api_key_vault.dart';
import 'package:zhiming/core/storage/blob_store.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
import 'package:zhiming/features/editor/auto_write_sheet.dart';
import 'package:zhiming/features/workspace/novel_workspace_page.dart';
import 'package:zhiming/features/workspace/stats_and_export_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 让 Drift 查询流与 File I/O Future 在真实异步区完成一轮后再刷新渲染树
  Future<void> flushAsyncAndPump(
    WidgetTester tester, {
    int rounds = 4,
  }) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// 在测试结束前主动卸载组件树，让 Drift StreamQueryStore 的 0ms 清理定时器排空
  Future<void> unmountAndDrain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Widget buildApp(AppDatabase db, BlobStore blobs, ApiKeyVault vault) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        blobStoreProvider.overrideWithValue(blobs),
        apiKeyVaultProvider.overrideWithValue(vault),
      ],
      child: const ZhiMingApp(),
    );
  }

  group('UI Smoke & Regression Tests (Desktop + Mobile)', () {
    late Directory tempDir;
    late AppDatabase db;
    late BlobStore blobs;
    late InMemoryApiKeyVault vault;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('zm_ui_test_');
      db = AppDatabase(NativeDatabase.memory());
      blobs = BlobStore(baseDirOverride: tempDir);
      vault = InMemoryApiKeyVault();
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'responsive navigation & continuation import enters workspace with working back button + original outline preview',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          final profile = SourceNovelProfileData(
            id: 'sp_ui_1',
            title: '雾港诡影',
            meta: const ScanMeta(
              totalChapters: 3,
              totalChars: 600,
              scanMode: ScanMode.evidence,
            ),
            characters: const [
              CanonCharacter(
                name: '林深',
                oneLine: '守夜人',
                personality: '冷静',
                voiceSamples: ['别回头'],
                currentState: '在旧钟表店门前',
              ),
            ],
            timeline: const [
              CanonEvent(
                phase: '开篇',
                chapterRange: '第1-3章',
                summary: '林深踏入雾港并在钟表店外遭遇异常钟声',
              ),
            ],
            worldbuilding: const [
              CanonWorldEntry(
                category: '规则',
                name: '午夜钟声',
                content: '零点钟响时严禁直视门外',
              ),
            ],
            openThreads: const [
              CanonThread(
                title: '钟表店地下室密码',
                detail: '铜牌背后刻着半组数字',
                plantedChapter: 1,
              ),
            ],
            activeArcs: const ['破解地下室暗门'],
            continuationFromChapter: 3,
            hasSourceText: true,
            scanState: const ScanState(
              stage: ScanStage.done,
              totalChunks: 3,
              doneChunks: 3,
            ),
          );
          await blobs.saveText(
            BlobKinds.continuation,
            profile.id,
            '第1章 入港\n雾色浓重。\n\n第2章 钟声\n钟响三声。\n\n第3章 暗门\n地下室铁门紧锁。',
          );
          await db.upsertSourceProfile(
            SourceProfilesCompanion.insert(
              id: profile.id,
              title: profile.title,
              payloadJson: profile.toJsonString(),
              createdAt: profile.createdAt,
            ),
          );
        });

        await tester.pumpWidget(buildApp(db, blobs, vault));
        await flushAsyncAndPump(tester);

        // 1) 桌面端默认在「书库」，左侧 Rail 展示 4 入口
        expect(find.text('织命 · 书库'), findsOneWidget);
        expect(find.text('原作库'), findsOneWidget);

        // 2) 切换到「原作库」并点开档案详情 -> 点击「以此续写」
        await tester.tap(find.text('原作库'));
        await flushAsyncAndPump(tester);
        expect(find.text('雾港诡影'), findsOneWidget);

        await tester.tap(find.text('查看/编辑'));
        await flushAsyncAndPump(tester);
        expect(find.text('以此续写'), findsOneWidget);

        await tester.tap(find.text('以此续写'));
        await flushAsyncAndPump(tester, rounds: 8);

        // 3) 已进入续写工作台：因含 skipsClarification 立项会话，默认直达「助手」立项页；
        //    左上角存在「返回书架」按钮，切回「写作」即可见到「原作（3 章）」与「第一卷」。
        expect(find.text('《雾港诡影》续写'), findsOneWidget);
        expect(find.byTooltip('返回书架'), findsOneWidget);
        await tester.tap(find.text('写作'));
        await flushAsyncAndPump(tester);
        expect(find.text('原作（3 章）'), findsOneWidget);
        expect(find.text('第一卷'), findsOneWidget);

        // 点击第 2 章只读原作章：右侧参考栏显示原作剧情脉络总览而非空白
        await tester.tap(find.text('第2章 钟声'));
        await flushAsyncAndPump(tester);
        expect(find.textContaining('原作剧情脉络总览'), findsOneWidget);
        expect(find.textContaining('破解地下室暗门'), findsOneWidget);

        // 验证设定集 -> 角色卡 / 世界观已正确灌入（不再空白）
        await tester.tap(find.text('设定集'));
        await flushAsyncAndPump(tester);
        await tester.tap(find.text('角色卡'));
        await flushAsyncAndPump(tester);
        expect(find.text('林深'), findsOneWidget);

        await tester.tap(find.text('世界观'));
        await flushAsyncAndPump(tester);
        expect(find.text('午夜钟声'), findsOneWidget);

        // 新增世界观条目支持关键词与常驻开关
        await tester.tap(find.text('新增设定'));
        await flushAsyncAndPump(tester);
        await tester.enterText(
          find.widgetWithText(TextField, '条目名称 *'),
          '提灯戒律',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '触发关键词（顿号或逗号分隔，命中即自动注入）'),
          '黑雾、提灯',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '设定说明'),
          '入雾必须手提黄铜灯。',
        );
        await tester.tap(find.text('常驻注入（每章续写自动携带）'));
        await tester.tap(find.text('保存'));
        await flushAsyncAndPump(tester);
        expect(find.text('提灯戒律'), findsOneWidget);
        expect(find.text('常驻'), findsOneWidget);
        expect(find.textContaining('黑雾、提灯'), findsOneWidget);

        // 验证左上角返回按钮可正常退出工作台回到原页面（修复实测 Bug #1）
        await tester.tap(find.byTooltip('返回书架'));
        await flushAsyncAndPump(tester);
        expect(find.text('《雾港诡影》续写'), findsNothing);
        await unmountAndDrain(tester);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'StatsAndExportSheet renders all 65 chapters without 40-chapter cap & supports incomplete filter',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = NovelRepository(db);
        await tester.runAsync(() async {
          final now = DateTime.now();
          await db.upsertNovel(
            NovelsCompanion.insert(
              id: 'n_stats',
              title: '长篇统计测试',
              createdAt: now,
              updatedAt: now,
            ),
          );
          await db.upsertVolume(
            VolumesCompanion.insert(
              id: 'v_stats',
              novelId: 'n_stats',
              name: '第一卷',
              sortOrder: 1,
            ),
          );
          for (var i = 1; i <= 65; i++) {
            final isShort = i == 65;
            await db.upsertChapter(
              ChaptersCompanion.insert(
                id: 'ch_$i',
                volumeId: 'v_stats',
                title: '第$i章 测试节点$i',
                content: Value(isShort ? '短章内容' : ('正文文本' * 300)),
                wordCount: Value(isShort ? 4 : 1200),
                sortOrder: i,
                updatedAt: now,
              ),
            );
          }
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              blobStoreProvider.overrideWithValue(blobs),
              apiKeyVaultProvider.overrideWithValue(vault),
              novelRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              home: NovelWorkspacePage(novelId: 'n_stats'),
            ),
          ),
        );
        await flushAsyncAndPump(tester);

        // 打开「统计与导出」弹窗
        await tester.tap(find.byTooltip('数据统计与导出'));
        await flushAsyncAndPump(tester);

        expect(find.textContaining('共 65 章'), findsOneWidget);
        // 向下滚动到末尾第 65 章，确认不再被 .take(40) 截断
        final sheet = find.byType(StatsAndExportSheet);
        final scrollable = find
            .descendant(
              of: find.byType(DraggableScrollableSheet),
              matching: find.byType(Scrollable),
            )
            .first;
        final ch65InSheet = find.descendant(
          of: sheet,
          matching: find.text('第65章 测试节点65'),
        );
        final ch1InSheet = find.descendant(
          of: sheet,
          matching: find.text('第1章 测试节点1'),
        );
        final filterInSheet = find.descendant(
          of: sheet,
          matching: find.text('仅看短/空章'),
        );
        await tester.scrollUntilVisible(
          ch65InSheet,
          300,
          scrollable: scrollable,
        );
        expect(ch65InSheet, findsOneWidget);

        // 滚回顶部切换「仅看短/空章」筛出第 65 章
        await tester.scrollUntilVisible(
          filterInSheet,
          -300,
          scrollable: scrollable,
        );
        await tester.tap(filterInSheet);
        await flushAsyncAndPump(tester);
        expect(ch65InSheet, findsOneWidget);
        expect(ch1InSheet, findsNothing);
        await unmountAndDrain(tester);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'Editor bottom bar exposes Fact Review & AutoWriteSheet exposes 5-Dim Fact Review Gate toggle',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = NovelRepository(db);
        late final String novelId;
        await tester.runAsync(() async {
          novelId = await repo.createBlankNovel(title: '编辑器功能测试');
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              blobStoreProvider.overrideWithValue(blobs),
              apiKeyVaultProvider.overrideWithValue(vault),
              novelRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: NovelWorkspacePage(novelId: novelId),
            ),
          ),
        );
        await flushAsyncAndPump(tester);

        expect(find.text('风格体检'), findsOneWidget);
        expect(find.text('事实审稿'), findsOneWidget);
        expect(find.text('摘要建档'), findsOneWidget);

        // 打开自动撰写流水线，确认包含「5 维事实审稿拦截门」且默认开启
        await tester.tap(find.byTooltip('自动撰写流水线'));
        await flushAsyncAndPump(tester);
        expect(find.text('5 维事实审稿拦截门'), findsOneWidget);
        final gateSwitch = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, '5 维事实审稿拦截门'),
        );
        expect(gateSwitch.value, isTrue);

        Navigator.of(tester.element(find.byType(AutoWriteSheet))).pop();
        await flushAsyncAndPump(tester);
        await unmountAndDrain(tester);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
