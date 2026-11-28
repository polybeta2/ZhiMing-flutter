import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiming/app.dart';
import 'package:zhiming/core/database/app_database.dart' hide ScanMeta;
import 'package:zhiming/core/dev/ios_preview_shell.dart';
import 'package:zhiming/core/platform/background_keep_alive.dart';
import 'package:zhiming/core/security/api_key_vault.dart';
import 'package:zhiming/core/storage/blob_store.dart';

const bool _captureScreenshots = bool.fromEnvironment(
  'CAPTURE_IOS_SHOTS',
  defaultValue: false,
);

Future<void> _tryLoadWindowsFonts() async {
  if (!_captureScreenshots || !Platform.isWindows) return;
  try {
    final simhei = File(r'C:\Windows\Fonts\simhei.ttf');
    if (await simhei.exists()) {
      final bytes = await simhei.readAsBytes();
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  } catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<void> unmountAndDrain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> maybeSaveShot(
    WidgetTester tester,
    GlobalKey boundaryKey,
    String fileName,
  ) async {
    if (!_captureScreenshots) return;
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final outDir = Directory('build/ios_preview_shots');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      final outFile = File('${outDir.path}/$fileName');
      await outFile.writeAsBytes(byteData!.buffer.asUint8List());
    });
  }

  group('Windows iOS Preview Shell & Multi-Device Layout Audit', () {
    late Directory tempDir;
    late AppDatabase db;
    late BlobStore blobs;
    late InMemoryApiKeyVault vault;

    setUpAll(() async {
      await _tryLoadWindowsFonts();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      BackgroundKeepAliveService.instance.resetForTest();
      tempDir = await Directory.systemTemp.createTemp('zm_ios_preview_test_');
      db = AppDatabase(NativeDatabase.memory());
      blobs = BlobStore(baseDirOverride: tempDir);
      vault = InMemoryApiKeyVault();

      // 写入一本含章节正文的测试小说，便于验证工作台与编辑器键盘压缩布局
      await db.into(db.novels).insert(
        NovelsCompanion.insert(
          id: 'novel_ios_1',
          title: '深海织命录',
          genre: const Value('都市悬疑'),
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 27),
        ),
      );
      await db.into(db.volumes).insert(
        VolumesCompanion.insert(
          id: 'vol_1',
          novelId: 'novel_ios_1',
          name: '第一卷 潮汐信号',
          sortOrder: 1,
        ),
      );
      await db.into(db.chapters).insert(
        ChaptersCompanion.insert(
          id: 'ch_1',
          volumeId: 'vol_1',
          title: '第1章 雨夜船坞',
          content: const Value(
            '港口的钠灯在浓雾里散出橘黄晕圈，潮声拍打着生锈的铁桩。林默把湿透的记事本塞进风衣内袋，抬头望向灯塔顶部亮起的三短一长蓝光。',
          ),
          sortOrder: 1,
          wordCount: const Value(68),
          updatedAt: DateTime(2026, 11, 27),
        ),
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget buildPreviewApp({
      required GlobalKey boundaryKey,
      required IosDevicePreset preset,
      bool simulateKeyboard = false,
      bool showToolbar = true,
    }) {
      return RepaintBoundary(
        key: boundaryKey,
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            blobStoreProvider.overrideWithValue(blobs),
            apiKeyVaultProvider.overrideWithValue(vault),
          ],
          child: IosPreviewShell(
            initialPreset: preset,
            initialSimulateKeyboard: simulateKeyboard,
            showToolbar: showToolbar,
            appBuilder: (platformOverride, mediaQueryTransform) => ZhiMingApp(
              platformOverride: platformOverride,
              mediaQueryTransform: mediaQueryTransform,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'iPhone SE (375x667) renders library, settings & keep-alive dialog without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          buildPreviewApp(
            boundaryKey: boundaryKey,
            preset: IosDevicePreset.iphoneSe,
          ),
        );
        await flushAsyncAndPump(tester);

        expect(defaultTargetPlatform, TargetPlatform.iOS);
        expect(find.text('深海织命录'), findsOneWidget);
        expect(find.text('375×667 pt · TargetPlatform.iOS'), findsOneWidget);
        await maybeSaveShot(tester, boundaryKey, 'iphone_se_library.png');

        // 切换底部导航到「设置」，验证关于卡片定制图标并打开「后台保活（iOS）」弹窗
        await tester.tap(find.text('设置').last);
        await flushAsyncAndPump(tester);
        expect(find.text('后台保活（iOS）'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('织命 ZhiMing'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('织命 ZhiMing'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('后台保活（iOS）'),
          -200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(find.text('后台保活（iOS）'));
        await flushAsyncAndPump(tester);
        await tester.tap(find.text('后台保活（iOS）'));
        await flushAsyncAndPump(tester);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('后台保活（iOS）'),
          ),
          findsOneWidget,
        );
        expect(find.text('持续位置获取'), findsOneWidget);

        await tester.tap(find.text('持续位置获取'));
        await flushAsyncAndPump(tester);
        expect(find.text('试运行 6 秒验证保活'), findsOneWidget);
        await maybeSaveShot(
          tester,
          boundaryKey,
          'iphone_se_keepalive_dialog.png',
        );

        await tester.tap(find.text('完成'));
        await flushAsyncAndPump(tester);
        await unmountAndDrain(tester);
      },
    );

    testWidgets(
      'iPhone 15 Pro (393x852) enters workspace & toggles simulated 336pt iOS keyboard cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1020);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          buildPreviewApp(
            boundaryKey: boundaryKey,
            preset: IosDevicePreset.iphone15Pro,
          ),
        );
        await flushAsyncAndPump(tester);

        expect(find.text('393×852 pt · TargetPlatform.iOS'), findsOneWidget);
        expect(find.text('深海织命录'), findsOneWidget);

        // 进入小说工作台
        await tester.tap(find.text('深海织命录'));
        await flushAsyncAndPump(tester, rounds: 5);
        expect(find.text('第1章 雨夜船坞'), findsWidgets);
        await maybeSaveShot(tester, boundaryKey, 'iphone15pro_workspace.png');

        // 进入章节正文编辑器
        await tester.tap(find.text('第1章 雨夜船坞').first);
        await flushAsyncAndPump(tester, rounds: 5);

        // 点击工具栏上的「键盘」按钮，开启 336pt 模拟 iOS 键盘并验证零溢出
        await tester.tap(find.text('键盘'));
        await flushAsyncAndPump(tester);
        expect(find.text('中文拼音 · 模拟 iOS 键盘'), findsOneWidget);
        expect(find.text('viewInsets = 336pt'), findsOneWidget);
        await maybeSaveShot(
          tester,
          boundaryKey,
          'iphone15pro_editor_keyboard.png',
        );

        // 切换到横屏与 1.25x 字号，确保自适应无 RenderFlex 溢出
        await tester.tap(find.text('竖屏'));
        await flushAsyncAndPump(tester);
        expect(find.text('852×393 pt · TargetPlatform.iOS'), findsOneWidget);

        await tester.tap(find.text('1.00x 字号'));
        await flushAsyncAndPump(tester);
        expect(find.text('1.25x 字号'), findsOneWidget);

        await unmountAndDrain(tester);
      },
    );
  });
}
