import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/storage/blob_store.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
import 'package:zhiming/domain/source/continuation_context.dart';
import 'package:zhiming/domain/source/source_batch_helper.dart';
import 'package:zhiming/domain/source/source_reduce_watermark.dart';
import 'package:zhiming/domain/source/source_reducer.dart';
import 'package:zhiming/domain/source/source_scan_chunker.dart';
import 'package:zhiming/domain/source/source_time_window.dart';
import 'package:zhiming/features/source_archive/source_injection_helper.dart';

void main() {
  group('SourceScanChunker & MicroSummarizer & BatchHelper', () {
    test('SourceScanChunker splits fast head+tail vs full parts', () {
      final longBody = '雾港钟楼响起雨夜钟声。' * 400; // 4400 chars
      final shortBody = '短章正文内容。' * 40; // 280 chars
      final book = '第一章 雨夜启程\n$longBody\n\n第二章 短章过渡\n$shortBody';

      final fastChunks = SourceScanChunker.chunks(book, mode: ScanMode.fast);
      expect(fastChunks.length, 3);
      expect(fastChunks[0].kind, 'head');
      expect(fastChunks[1].kind, 'tail');
      expect(fastChunks[2].kind, 'full');

      final fullChunks = SourceScanChunker.chunks(book, mode: ScanMode.full);
      expect(fullChunks.length, 3);
      expect(fullChunks[0].kind, 'part');
      expect(fullChunks[1].kind, 'part');
      expect(fullChunks[2].kind, 'full');
    });

    test('SourceBatchHelper extracts multiple JSON objects amidst noise', () {
      const raw = '''
好的，这是分析结果：
```json
{"chapter": 1, "characters": [{"name": "沈屿", "traits": "冷静"}], "events": [{"summary": "收到密信", "participants": ["沈屿"]}], "worldbuilding": [{"name": "雾港", "content": "海雾终年不散"}], "foreshadowing": [{"summary": "火漆印记缺失一角", "planted": true}]}
```
下一章说明：
{"chapter": 2, "characters": [], "events": [{"summary": "钟楼交锋", "participants": ["沈屿"]}], "worldbuilding": [], "foreshadowing": [{"summary": "火漆印记来源揭晓", "planted": false}]}
''';
      final parsed = SourceBatchHelper.parseBatchOutput(raw);
      expect(parsed.keys, containsAll([0, 1]));
      expect(parsed[0]!.characters.first.name, '沈屿');
      expect(parsed[0]!.foreshadowing.first.planted, isTrue);
      expect(parsed[1]!.foreshadowing.first.planted, isFalse);
    });
  });

  group('SourceReduceWatermark & Reducer & TimeWindow', () {
    test('SourceReduceWatermark advances only on contiguous prefix', () {
      final wm = SourceReduceWatermark(nextSeq: 0, watermark: -1);
      // seq 1 finishes before seq 0 -> watermark must NOT advance yet!
      expect(wm.complete(seq: 1, hiPos: 79), isNull);
      expect(wm.watermark, -1);

      // seq 0 finishes -> watermark jumps straight through seq 0 and seq 1 to 79
      expect(wm.complete(seq: 0, hiPos: 39), 79);
      expect(wm.watermark, 79);
      expect(wm.nextContiguousSeq, 2);
    });

    test('SourceReducer parses continuation profile and renders context', () {
      const raw = '''
{
  "title": "雾港秘史",
  "author": "佚名",
  "characters": [
    {"name": "沈屿", "aliases": ["老沈"], "oneLine": "钟表匠", "currentState": "左臂负伤，正躲在灯塔地下室", "relationships": [{"target": "林岚", "relation": "搭档"}]}
  ],
  "timeline": [
    {"phase": "初入雾港", "chapterRange": "第1-10章", "summary": "发现暗门", "participants": ["沈屿"], "importance": "major"}
  ],
  "worldbuilding": [
    {"category": "规则", "name": "潮汐律", "content": "满潮时蒸汽装置失效"}
  ],
  "openThreads": [
    {"title": "银钥匙归属", "detail": "第3章拾得但尚未找到锁孔", "plantedChapter": 3}
  ],
  "activeArcs": ["追查灯塔失踪船员"]
}
''';
      final profile = SourceReducer.parseContinuation(
        raw,
        fallbackTitle: '默认书名',
        upToChapter: 10,
      );
      expect(profile.title, '雾港秘史');
      expect(profile.continuationFromChapter, 10);
      expect(profile.characters.first.currentState, contains('左臂负伤'));
      expect(profile.openThreads.first.plantedChapter, 3);

      final ctx = ContinuationContext.rendered(
        profile: profile,
        recentText: '灯塔外的雾越来越浓，沈屿听见楼上传来靴底摩擦木板的声音。',
        maxChars: 2000,
      );
      expect(ctx, contains('第 10 章'));
      expect(ctx, contains('左臂负伤'));
      expect(ctx, contains('银钥匙归属'));
      expect(ctx, contains('灯塔外的雾越来越浓'));

      final win = SourceTimeWindow.window(
        phase: '初入雾港',
        profile: profile,
      ).rendered(maxChars: 1500);
      expect(win, contains('发现暗门'));
      expect(win, contains('潮汐律'));
    });
  });

  group('SourceAndStyleBridge full continuation novel import', () {
    late AppDatabase db;
    late Directory tmpDir;
    late BlobStore blobs;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tmpDir = await Directory.systemTemp.createTemp('zm_source_test_');
      blobs = BlobStore(baseDirOverride: tmpDir);
    });

    tearDown(() async {
      await db.close();
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('createContinuationNovel imports read-only original chapters & entities', () async {
      final profile = SourceNovelProfileData(
        title: '星渊行者',
        continuationFromChapter: 2,
        hasSourceText: true,
        characters: const [
          CanonCharacter(
            name: '陈默',
            aliases: ['默哥'],
            oneLine: '星图测绘师',
            currentState: '刚穿过跃迁门',
          ),
        ],
        worldbuilding: const [
          CanonWorldEntry(category: '势力组织', name: '白帆会', content: '星港行会'),
        ],
        openThreads: const [
          CanonThread(title: '黑匣子密码', detail: '尚未破译', plantedChapter: 1),
        ],
      );

      await blobs.saveText(
        BlobKinds.continuation,
        profile.id,
        '第一章 启航\n星港灯火通明。\n\n第二章 跃迁\n跃迁门在眼前展开。',
      );

      final bridge = SourceAndStyleBridge(db: db, blobs: blobs);
      final novelId = await bridge.createContinuationNovel(profile: profile);

      final volumes = await db.getVolumes(novelId);
      expect(volumes.length, 2);
      expect(volumes.first.name, '原作（2 章）');

      final origChapters = await db.getChaptersByVolume(volumes.first.id);
      expect(origChapters.length, 2);
      expect(origChapters.every((c) => c.isOriginal), isTrue);

      final chars = await db.getCharacters(novelId);
      expect(chars.length, 1);
      expect(chars.first.physicalState, '刚穿过跃迁门');

      final worlds = await db.getWorldEntries(novelId);
      expect(worlds.length, 1);
      expect(worlds.first.category, '势力');

      final fs = await db.getForeshadowings(novelId);
      expect(fs.length, 1);
      expect(fs.first.title, '黑匣子密码');

      final threads = await db.getChatThreads(novelId);
      expect(threads.first.purpose, 'creation');
      expect(threads.first.skipsClarification, isTrue);
    });
  });
}
