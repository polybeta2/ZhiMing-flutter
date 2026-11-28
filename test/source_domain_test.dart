import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/storage/blob_store.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
import 'package:zhiming/domain/source/continuation_context.dart';
import 'package:zhiming/domain/source/novel_local_indexer.dart';
import 'package:zhiming/domain/source/novel_text_cleaner.dart';
import 'package:zhiming/domain/source/source_batch_helper.dart';
import 'package:zhiming/domain/source/source_reduce_watermark.dart';
import 'package:zhiming/domain/source/source_reducer.dart';
import 'package:zhiming/domain/source/source_scan_chunker.dart';
import 'package:zhiming/domain/source/source_time_window.dart';
import 'package:zhiming/domain/style/style_chapter_sampler.dart';
import 'package:zhiming/domain/writing/assistant_search.dart';
import 'package:zhiming/features/source_archive/source_injection_helper.dart';
import 'package:zhiming/features/source_archive/source_scan_controller.dart';

void main() {
  group('SourceScanChunker & NovelTextCleaner & BatchHelper', () {
    test('SourceScanChunker fast mode abridges single chunk and never exceeds full count', () {
      final longBody = '雾港钟楼响起雨夜钟声。' * 400; // 4400 chars
      final shortBody = '短章正文内容。' * 40; // 280 chars
      final book = '第一章 雨夜启程\n$longBody\n\n第二章 短章过渡\n$shortBody';

      final fastChunks = SourceScanChunker.chunks(book, mode: ScanMode.fast);
      expect(fastChunks.length, 2);
      expect(fastChunks[0].kind, 'fast_abridged');
      expect(fastChunks[1].kind, 'full');

      final fullChunks = SourceScanChunker.chunks(book, mode: ScanMode.full);
      expect(fullChunks.length, 3);
      expect(fastChunks.length <= fullChunks.length, isTrue);
    });

    test('NovelTextCleaner strips abandonment epilogue and tomato metadata', () {
      const dirty = '''
莫烬叹了口气，望向残破的群星之城。
……
《完》
这本书的成绩不太理想，坚持不了了，感谢大家一直以来的支持！！
（ '▿ ' ）
----------------------------------------
''';
      final cleaned = NovelTextCleaner.cleanChapterBody(dirty);
      expect(cleaned, contains('莫烬叹了口气'));
      expect(cleaned, isNot(contains('《完》')));
      expect(cleaned, isNot(contains('成绩不太理想')));

      const holidayDirty = '''
单纯多了几点信仰点，又能有什么问题呢。

而接下来要上演的才是重头戏。

……

元旦快乐哦诸位。

不谈虚的，给大家包个红包，比心。

zfb口令：温良恭俭让仁义礼智信
''';
      final cleanedHoliday = NovelTextCleaner.cleanChapterBody(holidayDirty);
      expect(cleanedHoliday, contains('重头戏'));
      expect(cleanedHoliday, isNot(contains('元旦快乐')));
      expect(cleanedHoliday, isNot(contains('zfb口令')));

      const parenthesizedEnd = '''
凯拉尔竖起中指。
旧日的世界在此刻寂灭。
……
（全书完。）
''';
      final cleanedEnd = NovelTextCleaner.cleanChapterBody(parenthesizedEnd);
      expect(cleanedEnd, contains('旧日的世界在此刻寂灭'));
      expect(cleanedEnd, isNot(contains('全书完')));

      final chaptersWithRushedEnd = [
        const SampleChapter(
          marker: '第178章 约会（七）',
          number: 178,
          symbol: '章',
          body: '约会还在继续。',
        ),
        const SampleChapter(
          marker: '第179章 世界的终结',
          number: 179,
          symbol: '章',
          body: '不能等把恋爱部分写完再完结吗？\n（全书完。）',
        ),
      ];
      final warning = NovelTextCleaner.detectEndingWarning(
        chaptersWithRushedEnd,
      );
      expect(warning, isNotNull);
      expect(warning!.suggestedFallbackTitle, '第178章 约会（七）');
    });

    test('NovelLocalIndexer auto-discovers entities, voice samples & grepSpan', () {
      const book = '''
书名：测试小说
简介：莫烬与月莲在雾港冒险的故事。
========================================
第1章 初遇
莫烬叹了口气说道：“这也太麻烦了。”
月莲冷笑道：“笨蛋狼人，这群人类关我屁事。”
莫烬望着怀里的银色怀表，微微一愣。

第2章 交易
莫烬问道：“罗娜怎么变回黑猫了？”
月莲翻了个白眼：“那只蠢猫早就想退休了。”
帕梅拉望着两人，沉默不语。
''';
      final indexer = NovelLocalIndexer.fromRawText(book);
      expect(indexer.chapters.length, 2);
      expect(indexer.headerSynopsis, contains('莫烬与月莲'));
      final names = indexer.topEntities.map((e) => e.name).toList();
      expect(names, containsAll(['莫烬', '月莲']));
      final hits = indexer.grepSpan('银色怀表');
      expect(hits.length, 1);
      expect(hits.first.chapterNo, 1);
      // 多词空格查询 + 章号过滤智能回退（命中章号与多词的 Ch 2 应排第一）
      final multiHits = indexer.grep('月莲 第2章 蠢猫 退休');
      expect(multiHits, isNotEmpty);
      expect(multiHits.first.chapterNo, 2);
      final prefix = indexer.buildEvidenceStaticPrefix(
        title: '测试小说',
        isContinuation: true,
      );
      expect(prefix, contains('全书高频角色/实体出场热力图'));
      expect(prefix, contains('原话声音样本'));
    });

    test('AssistantSearchProtocol extracts zm-search queries and strips block', () {
      const reply = '''
我先查一下前文细节。
```zm-search
{"queries": ["爱丽丝", "银色怀表"]}
```
''';
      expect(AssistantSearchProtocol.extractQueries(reply), ['爱丽丝', '银色怀表']);
      expect(AssistantSearchProtocol.stripSearchBlock(reply), '我先查一下前文细节。');
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
        continuationFromTitle: '第11章 跳号测试',
      );
      expect(profile.title, '雾港秘史');
      expect(profile.continuationFromChapter, 10);
      expect(profile.continuationFromTitle, '第11章 跳号测试');
      expect(profile.characters.first.currentState, contains('左臂负伤'));
      expect(profile.relations, isNotEmpty);
      expect(profile.relations.first.from, '沈屿');
      expect(profile.relations.first.to, '林岚');
      expect(profile.openThreads.first.plantedChapter, 3);

      final ctx = ContinuationContext.rendered(
        profile: profile,
        recentText: '灯塔外的雾越来越浓，沈屿听见楼上传来靴底摩擦木板的声音。',
        maxChars: 2000,
      );
      expect(ctx, contains('第11章 跳号测试'));
      expect(ctx, contains('第 10 节'));
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
            personality: '冷静',
            voiceSamples: ['星图不会说谎'],
            currentState: '刚穿过跃迁门',
          ),
        ],
        timeline: const [
          CanonEvent(
            phase: '启航篇',
            chapterRange: '第1-2章',
            summary: '陈默离开星港并穿过跃迁门',
          ),
        ],
        worldbuilding: const [
          CanonWorldEntry(category: '势力组织', name: '白帆会', content: '星港行会'),
        ],
        openThreads: const [
          CanonThread(title: '黑匣子密码', detail: '尚未破译', plantedChapter: 1),
        ],
        activeArcs: const ['破译黑匣子并逃离白帆会追捕'],
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
      expect(volumes.first.outline, contains('启航篇'));
      expect(volumes.last.outline, contains('破译黑匣子'));

      final origChapters = await db.getChaptersByVolume(volumes.first.id);
      expect(origChapters.length, 2);
      expect(origChapters.every((c) => c.isOriginal), isTrue);
      expect(origChapters.first.detailedOutline, contains('启航篇'));
      expect(origChapters.last.detailedOutline, contains('断更处正在推进的主线'));

      final chars = await db.getCharacters(novelId);
      expect(chars.length, 1);
      expect(chars.first.physicalState, '刚穿过跃迁门');
      expect(chars.first.personality, contains('星图不会说谎'));

      final worlds = await db.getWorldEntries(novelId);
      expect(worlds.length, 1);
      expect(worlds.first.category, '势力');
      expect(worlds.first.keywordsJson, contains('白帆会'));

      final fs = await db.getForeshadowings(novelId);
      expect(fs.length, 1);
      expect(fs.first.title, '黑匣子密码');

      final threads = await db.getChatThreads(novelId);
      expect(threads.first.purpose, 'creation');
      expect(threads.first.skipsClarification, isTrue);
    });

    test('SourceReducer recovers truncated top-level JSON and rejects empty-shell inner objects', () {
      // 模拟 Round 2 撞上 maxTokens 截断：顶部未闭合但内部已有完整的 openThread 对象
      const truncated = '''
{
  "title": "诡异降临：开局白捡一只可爱萝莉",
  "characters": [
    {"name": "莫烬", "role": "主角", "currentState": "刚经历狼人形态觉醒"},
    {"name": "爱丽丝", "role": "核心角色", "currentState": "仍在追寻莫烬"}
  ],
  "worldbuilding": [
    {"category": "规则", "name": "规则型灾祸", "content": "必须按规则规避"}
  ],
  "openThreads": [
    {"title": "爱丽丝的“永远在一起”追杀宿命", "detail": "开篇留下的宿命伏笔", "plantedChapter": 1},
    {"title": "被截断的下一条伏笔", "detail": "写到一半突然断''';

      final recovered = SourceReducer.parseContinuation(
        truncated,
        fallbackTitle: '诡异降临：开局白捡一只可爱萝莉',
        upToChapter: 250,
      );
      expect(recovered.title, '诡异降临：开局白捡一只可爱萝莉');
      expect(recovered.characters.length, 2);
      expect(recovered.worldbuilding.length, 1);
      expect(recovered.openThreads.length, greaterThanOrEqualTo(1));
      expect(recovered.openThreads.first.title, contains('爱丽丝'));

      // 纯空壳 JSON（仅有一个 title 字段）必须直接报错，严禁当作完整档案入库
      expect(
        () => SourceReducer.parseContinuation(
          '{"title": "爱丽丝的“永远在一起”追杀宿命", "detail": "某条伏笔"}',
          fallbackTitle: '诡异降临：开局白捡一只可爱萝莉',
          upToChapter: 250,
        ),
        throwsFormatException,
      );
    });

    test('SourceScanController fast & evidence Isolate.run do not capture CancelToken', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final db = AppDatabase(NativeDatabase.memory());
      final tmp = await Directory.systemTemp.createTemp('zm_scan_ctrl_');
      final blobs = BlobStore(baseDirOverride: tmp);
      final client = _StubScanLLMClient();
      final provider = ProviderRecord(
        id: 'p1',
        name: 'Stub',
        baseUrl: 'https://example.com/v1',
        apiKeyId: 'k1',
        modelName: 'stub-model',
        temperature: 0.5,
        maxTokens: 16384,
        contextBudgetChars: 60000,
        isDefault: true,
        createdAt: DateTime(2026),
      );
      final controller = SourceScanController(
        db: db,
        blobs: blobs,
        client: client,
        provider: provider,
      );

      const sampleBook = '''
第1章 雾起灯塔
莫烬走进雾港钟楼，月莲在楼顶擦拭银色怀表。

第2章 宿命回响
罗娜在巷口递来一封密信，信封盖着旧教会火漆。
''';
      try {
        await controller.start(
          sourceText: sampleBook,
          title: '雾港测试',
          mode: ScanMode.fast,
        );
        expect(controller.phase, ScanPhase.done, reason: controller.errorMessage);
        expect(controller.resultProfile, isNotNull);
        expect(controller.resultProfile!.title, '雾港测试');

        await controller.start(
          sourceText: sampleBook,
          title: '雾港测试',
          mode: ScanMode.evidence,
          isContinuation: true,
        );
        expect(controller.phase, ScanPhase.done, reason: controller.errorMessage);
        expect(controller.resultProfile?.characters.isNotEmpty, isTrue);
      } finally {
        controller.dispose();
        await db.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      }
    });
  });
}

class _StubScanLLMClient implements LLMClient {
  @override
  Future<List<String>> fetchModelIds({CancelToken? cancelToken}) async => const [
    'stub-model',
  ];

  @override
  Future<String> testConnection({CancelToken? cancelToken}) async => '连接成功';

  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    final joined = messages.map((m) => m.content).join('\n');
    String reply;
    if (joined.contains('待查证的')) {
      reply = '{"keywords": ["莫烬", "银色怀表"], "questions": ["怀表来历"], "focusCharacters": ["莫烬", "月莲"]}';
    } else if (joined.contains('【原文证据片段】') || joined.contains('续写')) {
      reply = '''
{
  "title": "雾港测试",
  "summary": "莫烬与月莲在雾港调查旧教会密信。",
  "characters": [{"name": "莫烬", "role": "主角", "currentState": "刚拿到火漆密信"}],
  "timeline": [{"chapter": "第1-2章", "event": "登塔与收信"}],
  "worldbuilding": [{"category": "物品", "name": "银色怀表", "content": "旧教会遗物"}],
  "openThreads": [{"title": "旧教会火漆密信", "detail": "罗娜巷口递信", "plantedChapter": 2}],
  "majorArcs": [{"name": "雾港序章", "chapters": "1-2", "summary": "初始调查"}]
}
''';
    } else if (joined.contains('增量式微摘要')) {
      reply = '''
{"chapter": 1, "characters": [{"name": "莫烬", "traits": "冷静", "state_change": "进钟楼"}], "events": [{"summary": "莫烬见到月莲擦拭怀表", "participants": ["莫烬", "月莲"]}], "worldbuilding": [{"category": "物品", "name": "银色怀表", "content": "旧物"}], "open_threads": ["怀表来历"]}
{"chapter": 2, "characters": [{"name": "罗娜", "traits": "神秘", "state_change": "巷口递信"}], "events": [{"summary": "罗娜递来火漆密信", "participants": ["罗娜", "莫烬"]}], "worldbuilding": [], "open_threads": ["旧教会火漆密信"]}
''';
    } else if (joined.contains('归并') || joined.contains('聚合') || joined.contains('档案')) {
      reply = '''
{
  "title": "雾港测试",
  "summary": "莫烬与月莲调查雾港密信。",
  "characters": [{"name": "莫烬", "role": "主角", "currentState": "拿到密信"}],
  "timeline": [{"chapter": "1", "event": "雾起灯塔"}],
  "worldbuilding": [{"category": "地点", "name": "雾港钟楼", "content": "旧港地标"}],
  "openThreads": [{"title": "密信来源", "detail": "罗娜交付", "plantedChapter": 2}]
}
''';
    } else {
      reply = '''
{
  "characters": [{"name": "莫烬", "traits": "冷静", "state_change": "进钟楼"}],
  "events": [{"summary": "莫烬见到月莲并收到密信", "participants": ["莫烬", "月莲", "罗娜"]}],
  "worldbuilding": [{"category": "物品", "name": "银色怀表", "content": "月莲持有"}],
  "open_threads": ["密信来源"]
}
''';
    }
    yield ContentDelta(reply);
    yield const UsageReport(promptTokens: 100, completionTokens: 80, cachedTokens: 60);
  }
}
