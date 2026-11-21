import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/prompts/prompt_library.dart';
import 'package:zhiming/domain/models/novel_domain.dart';
import 'package:zhiming/domain/writing/chapter_ledger.dart';
import 'package:zhiming/domain/writing/fact_review_service.dart';
import 'package:zhiming/domain/writing/lorebook_matcher.dart';

class _StubLLMClient implements LLMClient {
  _StubLLMClient(this.responder);

  final String Function(List<LLMMessage> messages, GenerationConfig config)
  responder;
  GenerationConfig? lastConfig;

  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    lastConfig = config;
    yield ContentDelta(responder(messages, config));
  }

  @override
  Future<String> testConnection({CancelToken? cancelToken}) async => 'ok';

  @override
  Future<List<String>> fetchModelIds({CancelToken? cancelToken}) async =>
      const [];
}

void main() {
  group('LorebookMatcher', () {
    final chars = [
      Character(
        id: 'c1',
        novelId: 'n1',
        name: '林深',
        aliasesJson: '["阿深"]',
        isSceneRelevant: true,
        sortOrder: 0,
      ),
      Character(
        id: 'c2',
        novelId: 'n1',
        name: '白鸦',
        aliasesJson: '["鸦羽先生","老鸦"]',
        isSceneRelevant: false,
        sortOrder: 1,
      ),
      Character(
        id: 'c3',
        novelId: 'n1',
        name: '陆沉',
        aliasesJson: '[]',
        isSceneRelevant: false,
        sortOrder: 2,
      ),
    ];

    final worlds = [
      WorldEntry(
        id: 'w1',
        novelId: 'n1',
        category: '规则',
        name: '核心法则',
        content: '不可违背',
        keywordsJson: '[]',
        isAlwaysOn: true,
        sortOrder: 0,
      ),
      WorldEntry(
        id: 'w2',
        novelId: 'n1',
        category: '地点',
        name: '旧钟楼',
        content: '午夜停摆',
        keywordsJson: '["钟楼","铜钟"]',
        isAlwaysOn: false,
        sortOrder: 1,
      ),
      WorldEntry(
        id: 'w3',
        novelId: 'n1',
        category: '物品',
        name: '白银怀表',
        content: '能倒流三秒',
        keywordsJson: '["怀表"]',
        isAlwaysOn: false,
        sortOrder: 2,
      ),
    ];

    test('triggers dormant character by alias and world entry by keyword in stable sortOrder', () {
      final sel = LorebookMatcher.selectByProbe(
        probeText: '细纲：主角带着铜钟线索寻找鸦羽先生。',
        characters: chars,
        worldEntries: worlds,
      );

      expect(sel.characters.map((c) => c.id).toList(), ['c1', 'c2']);
      expect(sel.triggeredCharacterIds, {'c2'});
      expect(sel.worldEntries.map((w) => w.id).toList(), ['w1', 'w2']);
      expect(sel.triggeredWorldEntryIds, {'w2'});
    });

    test('falls back to top entries when neither always-on nor keyword hits', () {
      final plainWorlds = [
        for (var i = 0; i < 8; i++)
          WorldEntry(
            id: 'pw$i',
            novelId: 'n1',
            category: '其他',
            name: '条目$i',
            content: '内容$i',
            keywordsJson: '[]',
            isAlwaysOn: false,
            sortOrder: i,
          ),
      ];
      final sel = LorebookMatcher.selectByProbe(
        probeText: '完全无关的文本',
        characters: const [],
        worldEntries: plainWorlds,
        fallbackWorldEntries: 4,
      );
      expect(sel.worldEntries.map((w) => w.id).toList(), [
        'pw0',
        'pw1',
        'pw2',
        'pw3',
      ]);
    });
  });

  group('ChapterLedgerExtraction & ChapterLedgerApplier', () {
    late AppDatabase db;
    late NovelRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NovelRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('parses deltas & new entities, strips no-change sentinels, and applies non-destructively', () async {
      final now = DateTime.now();
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: 'n1',
          title: '测试书',
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
          id: 'ch1',
          volumeId: 'v1',
          title: '第1章 雨夜突围',
          sortOrder: 1,
          updatedAt: now,
        ),
      );
      await db.upsertCharacter(
        CharactersCompanion.insert(
          id: 'char1',
          novelId: 'n1',
          name: '林深',
          aliasesJson: const Value('["阿深"]'),
          personality: const Value('冷静克制'),
          currentLocation: const Value('雾港码头'),
          physicalState: const Value('完好'),
          currentGoal: const Value('寻找密信'),
        ),
      );
      await db.upsertForeshadowing(
        ForeshadowingsCompanion.insert(
          id: 'fs1',
          novelId: 'n1',
          title: '港口旧钟停摆之谜',
          createdAt: now,
        ),
      );

      const llmJson = '''
```json
{
  "summary": "阿深在雨夜突围时左肩负伤，退入旧钟楼，结识守塔人老周，并发现钟楼禁制规则。",
  "key_facts": ["阿深左肩中箭", "旧钟楼午夜会封锁出口"],
  "new_foreshadowings": [{"title": "老周袖口的血纹", "detail": "与失踪案徽记相同"}],
  "resolved_foreshadowing_titles": ["港口旧钟停摆之谜"],
  "character_deltas": [
    {
      "name": "阿深",
      "current_location": "旧钟楼二层",
      "physical_state": "左肩箭伤已草草包扎",
      "mental_state": "无变化",
      "current_goal": "天亮前查清血纹来源"
    }
  ],
  "new_characters": [
    {
      "name": "老周",
      "aliases": ["守塔人"],
      "personality": "沉默寡言、警觉",
      "current_location": "旧钟楼"
    },
    {
      "name": "林深",
      "personality": "重复角色应被去重"
    }
  ],
  "new_world_entries": [
    {
      "category": "规则",
      "name": "午夜封楼禁制",
      "keywords": ["钟楼", "午夜", "禁制"],
      "content": "每日零点钟声响起后，旧钟楼所有门窗将自动反锁至黎明。"
    }
  ]
}
```''';

      final extraction = ChapterLedgerExtraction.tryParse(llmJson);
      expect(extraction, isNotNull);
      expect(extraction!.characterDeltas.length, 1);
      expect(extraction.characterDeltas.first.mentalState, isNull); // "无变化" filtered
      expect(extraction.newCharacters.length, 2);
      expect(extraction.newWorldEntries.length, 1);

      final chapter = (await db.getChapter('ch1'))!;
      final report = await ChapterLedgerApplier.applyToDb(
        db: db,
        repo: repo,
        novelId: 'n1',
        chapter: chapter,
        extraction: extraction,
      );

      expect(report.updatedCharacters, 1);
      expect(report.createdCharacters, 1); // 林深去重，仅建老周
      expect(report.createdWorldEntries, 1);
      expect(report.createdForeshadowings, 1);
      expect(report.flaggedResolvedForeshadowings, 1);

      final chars = await db.getCharacters('n1');
      final linshen = chars.firstWhere((c) => c.id == 'char1');
      expect(linshen.personality, '冷静克制'); // 原有性格未被破坏
      expect(linshen.currentLocation, '旧钟楼二层');
      expect(linshen.physicalState, '左肩箭伤已草草包扎');
      expect(linshen.currentGoal, '天亮前查清血纹来源');
      expect(linshen.lastSeenChapterTitle, '第1章 雨夜突围');

      final laozhou = chars.firstWhere((c) => c.name == '老周');
      expect(decodeStringList(laozhou.aliasesJson), ['守塔人']);

      final worlds = await db.getWorldEntries('n1');
      expect(worlds.length, 1);
      expect(decodeStringList(worlds.first.keywordsJson), ['钟楼', '午夜', '禁制']);

      final fs = await db.getForeshadowings('n1');
      expect(fs.firstWhere((f) => f.id == 'fs1').suggestedResolved, isTrue);
    });
  });

  group('FactReviewResult & FactReviewService', () {
    test('normalizes missing dimensions and forces overallPass=false when blocking issue exists', () {
      const raw = '''
{
  "overall_pass": true,
  "summary": "发现一处信息壁垒穿帮",
  "dimension_results": [
    {"dimension": "character", "pass": false, "note": "苏青说出了尚未被告知的暗室密码"}
  ],
  "issues": [
    {
      "severity": "critical",
      "category": "character",
      "location": "第2段对话",
      "description": "苏青在未被告知的情况下直接念出了地下室四位密码",
      "evidence": "原文「密码是0419」 vs 档案「仅林深一人知晓密码」",
      "fix_hint": "改为由林深输入密码，或先补写林深低声告知的过程",
      "blocking": true
    }
  ]
}''';
      final parsed = FactReviewResult.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.hasBlocking, isTrue);
      expect(parsed.overallPass, isFalse);
      expect(parsed.dimensionResults.length, 5);
      expect(
        parsed.dimensionResults.firstWhere((d) => d.dimension == 'character').pass,
        isFalse,
      );
      expect(
        parsed.dimensionResults.firstWhere((d) => d.dimension == 'setting').pass,
        isTrue,
      );
    });

    test('FactReviewService enforces maxTokens >= 12288 for reasoning models', () async {
      final stub = _StubLLMClient((msgs, cfg) {
        if (msgs.first.content.contains('精准勘误编辑')) {
          return '修订后的完整正文内容。';
        }
        return '''
{
  "overall_pass": false,
  "summary": "存在空间瞬移",
  "dimension_results": [
    {"dimension": "setting", "pass": true, "note": "无冲突"},
    {"dimension": "timeline", "pass": false, "note": "从港口瞬移到山顶"},
    {"dimension": "continuity", "pass": true, "note": "无冲突"},
    {"dimension": "character", "pass": true, "note": "无冲突"},
    {"dimension": "logic", "pass": true, "note": "无冲突"}
  ],
  "issues": [
    {
      "severity": "critical",
      "category": "timeline",
      "location": "开头",
      "description": "上一章还在码头，本章无过渡直接出现在山顶",
      "evidence": "原文「山风凛冽」 vs 档案「当前位置：雾港码头」",
      "fix_hint": "补一句赶路过渡或改回码头开场",
      "blocking": true
    }
  ]
}''';
      });

      final service = FactReviewService(
        client: stub,
        library: const PromptLibraryState(),
      );
      final res = await service.review(
        truthArchive: '【角色档案】林深：当前位置雾港码头',
        chapterTitle: '第2章',
        draftContent: '山风凛冽，林深站在崖边。',
        maxTokens: 2048, // deliberately small to test guardrail
      );
      expect(stub.lastConfig!.maxTokens, greaterThanOrEqualTo(12288));
      expect(res.hasBlocking, isTrue);

      final fixed = await service.applyFixes(
        truthArchive: '【角色档案】林深：当前位置雾港码头',
        chapterTitle: '第2章',
        draftContent: '山风凛冽，林深站在崖边。',
        issues: res.blockingIssues,
        maxTokens: 2048,
      );
      expect(stub.lastConfig!.maxTokens, greaterThanOrEqualTo(12288));
      expect(fixed, '修订后的完整正文内容。');
    });
  });
}
