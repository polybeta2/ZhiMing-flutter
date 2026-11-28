import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/prompts/prompt_library.dart';
import 'package:zhiming/core/prompts/prompt_templates.dart';
import 'package:zhiming/domain/models/novel_domain.dart';
import 'package:zhiming/domain/writing/context_builder.dart';
import 'package:zhiming/domain/writing/fact_review_service.dart';
import 'package:zhiming/domain/writing/writing_director_config.dart';

class _FakeFactReviewClient implements LLMClient {
  final List<List<LLMMessage>> recordedMessages = [];
  final List<GenerationConfig> recordedConfigs = [];
  final List<String> replies;
  var _callIndex = 0;

  _FakeFactReviewClient(this.replies);

  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    recordedMessages.add(messages);
    recordedConfigs.add(config);
    final reply = replies[_callIndex++];
    yield ContentDelta(reply);
  }

  @override
  Future<List<String>> fetchModelIds({CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<String> testConnection({CancelToken? cancelToken}) async => 'ok';
}

ChapterBundle _makeChapter({
  required String id,
  required int order,
  String title = '',
  String content = '',
  String? outline,
  ChapterSummary? summary,
  DateTime? now,
}) {
  final ts = now ?? DateTime(2026, 11, 27);
  return ChapterBundle(
    chapter: Chapter(
      id: id,
      volumeId: 'v1',
      title: title.isEmpty ? '第$order章' : title,
      detailedOutline: outline,
      content: content,
      sortOrder: order,
      wordCount: content.length,
      isOriginal: false,
      updatedAt: ts,
    ),
    volumeId: 'v1',
    volumeName: '第一卷',
    summary: summary,
  );
}

void main() {
  group('3-tier KV cache ordering & invariantExtras', () {
    test(
      'updating mutable character state and sourceWindow keeps system message 100% byte-identical while updating user dynamicSuffix',
      () {
        final now = DateTime(2026, 11, 27);
        const lib = PromptLibraryState();
        const directorCfg = WritingDirectorConfig(
          cameraMode: ProseCameraMode.cinematic,
          strictAntiOmniscience: true,
        );

        final c1ChapterA = Character(
          id: 'c1',
          novelId: 'n1',
          name: '莫烬',
          aliasesJson: '["末路灰烬"]',
          personality: '沉静克制，观察入微',
          background: '前守夜人档案员',
          currentLocation: '钟楼一层',
          physicalState: '左肩轻微擦伤',
          mentalState: '高度警惕',
          currentGoal: '找回铜钥匙',
          lastSeenChapterTitle: '第1章',
          isSceneRelevant: true,
          arcJson: '[]',
          sortOrder: 0,
        );
        final c1ChapterB = c1ChapterA.copyWith(
          currentLocation: const Value('雾港老码头'),
          physicalState: const Value('右臂骨折包扎'),
          mentalState: const Value('极度疲惫但冷静'),
          currentGoal: const Value('登上三号走私船'),
          lastSeenChapterTitle: const Value('第2章'),
        );

        final world1 = WorldEntry(
          id: 'w1',
          novelId: 'n1',
          category: '规则',
          name: '钟声法则',
          content: '午夜钟响后所有门窗必须落锁。',
          keywordsJson: '["钟楼","钟声"]',
          isAlwaysOn: true,
          sortOrder: 0,
        );

        final rel = CharacterRelation(
          id: 'r1',
          novelId: 'n1',
          sourceCharacterId: 'c1',
          targetCharacterId: 'c2',
          relationType: '盟友',
          label: '秘密联络',
          description: '仅在危机时接头',
          strength: 4,
          line: '暗线',
          status: 'active',
          evolutionJson: '[]',
          updatedAt: now,
        );
        final c2 = Character(
          id: 'c2',
          novelId: 'n1',
          name: '罗娜',
          aliasesJson: '[]',
          personality: '果断冷峻',
          background: '群星之城执政官',
          isSceneRelevant: true,
          arcJson: '[]',
          sortOrder: 1,
        );

        final ch1 = _makeChapter(
          id: 'ch1',
          order: 1,
          content: '钟楼风声猎猎，莫烬将铜钥匙收入风衣内袋。',
          now: now,
        );
        final ch2 = _makeChapter(
          id: 'ch2',
          order: 2,
          outline: '莫烬潜入雾港老码头寻找走私船。',
          content: '',
          now: now,
        );
        final ch3 = _makeChapter(
          id: 'ch3',
          order: 3,
          outline: '在老码头遭遇巡逻队盘查并借雾脱身。',
          content: '',
          now: now,
        );

        NovelBundle makeBundle(Character ch1Char) => NovelBundle(
          novel: Novel(
            id: 'n1',
            title: '灰雾纪元',
            synopsis: '守夜人寻找真相的故事',
            styleGuide: '冷硬克制，注重环境细节',
            enabledTagIdsJson: '[]',
            r18Enabled: false,
            lastTotalWordCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
          volumes: [
            VolumeBundle(
              volume: const Volume(
                id: 'v1',
                novelId: 'n1',
                name: '第一卷',
                sortOrder: 1,
              ),
              chapters: [ch1, ch2, ch3],
            ),
          ],
          characters: [ch1Char, c2],
          worldEntries: [world1],
          foreshadowings: const [],
          relations: [rel],
          timelineEvents: const [],
        );

        final ctxA = ContextBuilder.buildContinueContext(
          chapter: ch2,
          bundle: makeBundle(c1ChapterA),
          budgetChars: 24000,
          styleCard: '【文风卡】白描短句为主',
          sourceWindow: '原作第2章：莫烬刚离开钟楼。',
          directorConfig: directorCfg,
          promptLibrary: lib,
        );
        final ctxB = ContextBuilder.buildContinueContext(
          chapter: ch3,
          bundle: makeBundle(c1ChapterB),
          budgetChars: 24000,
          styleCard: '【文风卡】白描短句为主',
          sourceWindow: '原作第3章：老码头戒严。',
          directorConfig: directorCfg,
          promptLibrary: lib,
        );

        final msgsA = PromptTemplates.writing(
          library: lib,
          invariantExtras: const ['【全局补充指令】保持第三人称有限视角', '【去AI味】禁用套话'],
          staticContext: ctxA.staticPrefix,
          renderedContext: ctxA.dynamicSuffix,
          wordTarget: 2000,
        );
        final msgsB = PromptTemplates.writing(
          library: lib,
          invariantExtras: const ['【全局补充指令】保持第三人称有限视角', '【去AI味】禁用套话'],
          staticContext: ctxB.staticPrefix,
          renderedContext: ctxB.dynamicSuffix,
          wordTarget: 2000,
        );

        // System message is 100% byte-identical and flagged for cacheControl
        expect(msgsA.first.role, LLMRole.system);
        expect(msgsA.first.cacheControl, isTrue);
        expect(msgsB.first.cacheControl, isTrue);
        expect(msgsA.first.content, equals(msgsB.first.content));

        // Ordering in system: baseSystem -> invariantExtras -> staticPrefix
        final sysText = msgsA.first.content;
        final extraPos = sysText.indexOf('【全局补充指令】');
        final antiAiPos = sysText.indexOf('【去AI味】');
        final styleGuidePos = sysText.lastIndexOf('【风格约束】');
        final directorPos = sysText.indexOf('【写作导演微调】');
        final styleCardPos = sysText.indexOf('【文风卡】');
        final worldPos = sysText.indexOf('【世界观条目】');
        final relPos = sysText.indexOf('【人物关系网');
        final staticCharPos = sysText.indexOf('【角色固定档案】');
        expect(extraPos, greaterThan(0));
        expect(antiAiPos, greaterThan(extraPos));
        expect(styleGuidePos, greaterThan(antiAiPos));
        expect(directorPos, greaterThan(styleGuidePos));
        expect(styleCardPos, greaterThan(directorPos));
        expect(staticCharPos, greaterThan(styleCardPos));
        expect(worldPos, greaterThan(staticCharPos));
        expect(relPos, greaterThan(worldPos));

        // Static prefix has NO mutable state or sourceWindow
        expect(ctxA.staticPrefix, isNot(contains('钟楼一层')));
        expect(ctxA.staticPrefix, isNot(contains('左肩轻微擦伤')));
        expect(ctxA.staticPrefix, isNot(contains('【原作该阶段人物与事件】')));

        // Dynamic suffix reflects updated mutable character state & sourceWindow
        expect(ctxA.dynamicSuffix, contains('【角色本章实时现状】'));
        expect(ctxA.dynamicSuffix, contains('钟楼一层'));
        expect(ctxA.dynamicSuffix, contains('左肩轻微擦伤'));
        expect(ctxA.dynamicSuffix, contains('原作第2章：莫烬刚离开钟楼。'));

        expect(ctxB.dynamicSuffix, contains('雾港老码头'));
        expect(ctxB.dynamicSuffix, contains('右臂骨折包扎'));
        expect(ctxB.dynamicSuffix, contains('极度疲惫但冷静'));
        expect(ctxB.dynamicSuffix, contains('原作第3章：老码头戒严。'));

        // Assistant context also isolates staticPrefix from mutable character state
        final astA = ContextBuilder.buildAssistantContext(
          bundle: makeBundle(c1ChapterA),
          budgetChars: 24000,
        );
        final astB = ContextBuilder.buildAssistantContext(
          bundle: makeBundle(c1ChapterB),
          budgetChars: 24000,
        );
        expect(astA.staticPrefix, equals(astB.staticPrefix));
        expect(astA.staticPrefix, contains('【世界观条目】'));
        expect(astA.staticPrefix, contains('【全书结构】'));
        expect(astA.staticPrefix, contains('【角色固定档案】'));
        expect(astA.staticPrefix, contains('【人物关系网'));
        expect(astA.dynamicSuffix, contains('【角色当前状态】'));
        expect(astA.dynamicSuffix, contains('钟楼一层'));
        expect(astB.dynamicSuffix, contains('雾港老码头'));
        expect(astA.rendered, contains('【世界观条目】'));
        expect(astA.rendered, contains('【角色当前状态】'));
      },
    );

    test(
      'staticPrefix retains 【人物关系网 and 暗线 for living_story_graph_test compatibility',
      () {
        final now = DateTime(2026, 11, 27);
        final c1 = Character(
          id: 'c1',
          novelId: 'n1',
          name: '莫烬',
          aliasesJson: '[]',
          arcJson: '[]',
          isSceneRelevant: true,
          sortOrder: 0,
        );
        final c2 = Character(
          id: 'c2',
          novelId: 'n1',
          name: '爱丽丝',
          aliasesJson: '[]',
          arcJson: '[]',
          isSceneRelevant: false,
          sortOrder: 1,
        );
        final rel = CharacterRelation(
          id: 'r1',
          novelId: 'n1',
          sourceCharacterId: 'c1',
          targetCharacterId: 'c2',
          relationType: '敌对',
          label: '执念追杀',
          description: '暗中监视',
          strength: 5,
          line: '暗线',
          status: 'active',
          evolutionJson: '[]',
          updatedAt: now,
        );
        final ch1 = _makeChapter(id: 'ch1', order: 1, content: '莫烬醒来。', now: now);
        final ch2 = _makeChapter(
          id: 'ch2',
          order: 2,
          outline: '莫烬在公寓警戒。',
          now: now,
        );
        final bundle = NovelBundle(
          novel: Novel(
            id: 'n1',
            title: '测试',
            synopsis: '',
            enabledTagIdsJson: '[]',
            r18Enabled: false,
            lastTotalWordCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
          volumes: [
            VolumeBundle(
              volume: const Volume(
                id: 'v1',
                novelId: 'n1',
                name: '第一卷',
                sortOrder: 1,
              ),
              chapters: [ch1, ch2],
            ),
          ],
          characters: [c1, c2],
          worldEntries: const [],
          foreshadowings: const [],
          relations: [rel],
          timelineEvents: const [],
        );

        final ctx = ContextBuilder.buildContinueContext(
          chapter: ch2,
          bundle: bundle,
          budgetChars: 20000,
        );
        expect(ctx.staticPrefix, contains('【人物关系网'));
        expect(ctx.staticPrefix, contains('暗线'));
        expect(ctx.staticPrefix, contains('爱丽丝'));
      },
    );
  });

  group('FactReview KV cache chaining', () {
    test(
      'factReviewFixFollowUp shares byte-identical [0] system and [1] user with factReview and service chains rawJsonReply',
      () async {
        const lib = PromptLibraryState();
        const truthArchive = '【真相档案】莫烬左手骨折，持有三号铜钥匙。';
        const draftContent = '莫烬用完好无损的左手推开沉重的铁门。';
        const reviewJson = '''
{
  "overall_pass": false,
  "summary": "发现 1 处身体状态矛盾",
  "dimension_results": [],
  "issues": [
    {
      "severity": "critical",
      "category": "continuity",
      "location": "第1段",
      "description": "莫烬左手骨折却完好无损推门",
      "evidence": "档案写明左臂骨折",
      "fix_hint": "改为右手推门",
      "blocking": true
    }
  ]
}
''';

        final reviewMsgs = PromptTemplates.applyingExtra(
          '额外系统约束',
          PromptTemplates.factReview(
            library: lib,
            truthArchive: truthArchive,
            chapterTitle: '第2章',
            draftContent: draftContent,
          ),
        );
        expect(reviewMsgs[0].cacheControl, isTrue);

        final followUpMsgs = PromptTemplates.factReviewFixFollowUp(
          reviewMessages: reviewMsgs,
          reviewAssistantReply: reviewJson,
          issuesChecklist: '1. [衔接与物品 · 阻断] 第1段：莫烬左手骨折却完好无损推门',
        );

        expect(followUpMsgs.length, 4);
        expect(followUpMsgs[0].role, LLMRole.system);
        expect(followUpMsgs[0].content, equals(reviewMsgs[0].content));
        expect(followUpMsgs[0].cacheControl, isTrue);
        expect(followUpMsgs[1].role, LLMRole.user);
        expect(followUpMsgs[1].content, equals(reviewMsgs[1].content));
        expect(followUpMsgs[2].role, LLMRole.assistant);
        expect(followUpMsgs[2].content, equals(reviewJson));
        expect(followUpMsgs[3].role, LLMRole.user);
        expect(followUpMsgs[3].content, contains('定点最小化勘误'));

        final fakeClient = _FakeFactReviewClient([
          reviewJson,
          '莫烬用右手推开沉重的铁门。',
        ]);
        final service = FactReviewService(
          client: fakeClient,
          library: lib,
          providerExtra: '额外系统约束',
        );

        final reviewRes = await service.review(
          truthArchive: truthArchive,
          chapterTitle: '第2章',
          draftContent: draftContent,
        );
        expect(reviewRes.rawJsonReply, equals(reviewJson));
        expect(fakeClient.recordedConfigs[0].jsonMode, isTrue);
        expect(fakeClient.recordedConfigs[0].reasoningEffort, isNull);
        expect(fakeClient.recordedConfigs[0].enablePromptCacheControl, isTrue);

        final fixed = await service.applyFixes(
          truthArchive: truthArchive,
          chapterTitle: '第2章',
          draftContent: draftContent,
          issues: reviewRes.blockingIssues,
          priorReviewReply: reviewRes.rawJsonReply,
        );
        expect(fixed, equals('莫烬用右手推开沉重的铁门。'));
        expect(fakeClient.recordedConfigs[1].enablePromptCacheControl, isTrue);
        expect(fakeClient.recordedMessages[1].length, 4);
        expect(
          fakeClient.recordedMessages[1][0].content,
          equals(fakeClient.recordedMessages[0][0].content),
        );
        expect(
          fakeClient.recordedMessages[1][1].content,
          equals(fakeClient.recordedMessages[0][1].content),
        );
      },
    );
  });

  group('Adaptive long context budget scaling', () {
    test(
      '128000 budget scales prev prose tail > 1200 chars, summaries > 3, and expands character/world limits vs compact budget',
      () {
        final now = DateTime(2026, 11, 27);
        final chapters = <ChapterBundle>[];
        for (var i = 1; i <= 10; i++) {
          final prose = i == 10
              ? '前章开头${'风雪夜行。' * 500}' // ~2504 chars > 1200
              : '第$i章正文内容';
          chapters.add(
            _makeChapter(
              id: 'ch$i',
              order: i,
              content: prose,
              summary: ChapterSummary(
                chapterId: 'ch$i',
                summaryText: '第$i章发生了关键推进事件$i。',
                keyFactsJson: '["事实$i"]',
                updatedAt: now,
              ),
              now: now,
            ),
          );
        }
        final targetChapter = _makeChapter(
          id: 'ch11',
          order: 11,
          outline: '主角准备进入终局大厅。',
          content: '当前章已有前缀${'门廊烛火摇曳。' * 300}', // ~2107 chars
          now: now,
        );
        chapters.add(targetChapter);

        final chars = [
          for (var i = 0; i < 18; i++)
            Character(
              id: 'c$i',
              novelId: 'n1',
              name: '角色_$i',
              aliasesJson: '[]',
              isSceneRelevant: true,
              arcJson: '[]',
              sortOrder: i,
            ),
        ];
        final worlds = [
          for (var i = 0; i < 15; i++)
            WorldEntry(
              id: 'w$i',
              novelId: 'n1',
              category: '规则',
              name: '规则_$i',
              content: '世界规则说明$i',
              keywordsJson: '[]',
              isAlwaysOn: true,
              sortOrder: i,
            ),
        ];

        final bundle = NovelBundle(
          novel: Novel(
            id: 'n1',
            title: '长篇测试',
            synopsis: '',
            enabledTagIdsJson: '[]',
            r18Enabled: false,
            lastTotalWordCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
          volumes: [
            VolumeBundle(
              volume: const Volume(
                id: 'v1',
                novelId: 'n1',
                name: '第一卷',
                sortOrder: 1,
              ),
              chapters: chapters,
            ),
          ],
          characters: chars,
          worldEntries: worlds,
          foreshadowings: const [],
        );

        final compactCtx = ContextBuilder.buildContinueContext(
          chapter: targetChapter,
          bundle: bundle,
          budgetChars: 20000,
        );
        final longCtx = ContextBuilder.buildContinueContext(
          chapter: targetChapter,
          bundle: bundle,
          budgetChars: 128000,
        );

        // Extract 【上一章正文末尾】 length
        String extractSection(String doc, String header) {
          final start = doc.indexOf(header);
          expect(start, greaterThanOrEqualTo(0));
          final rest = doc.substring(start + header.length).trimLeft();
          final nextHeader = rest.indexOf('\n\n【');
          return nextHeader < 0 ? rest : rest.substring(0, nextHeader);
        }

        final compactPrev = extractSection(
          compactCtx.dynamicSuffix,
          '【上一章正文末尾】',
        );
        final longPrev = extractSection(longCtx.dynamicSuffix, '【上一章正文末尾】');
        expect(compactPrev.length, lessThanOrEqualTo(ContextBuilder.neighborTailLength + 4));
        expect(longPrev.length, greaterThan(1200));

        // Current chapter 【正文末尾】 scales beyond tailLength (800)
        final compactCurTail = extractSection(
          compactCtx.dynamicSuffix,
          '【正文末尾】',
        );
        final longCurTail = extractSection(longCtx.dynamicSuffix, '【正文末尾】');
        expect(compactCurTail.length, equals(ContextBuilder.tailLength));
        expect(longCurTail.length, greaterThan(1200));

        // Summaries scale from 3 to 10 (all available < 15)
        expect(compactCtx.dynamicSuffix, contains('【前文摘要（最近 3 章）】'));
        expect(compactCtx.dynamicSuffix, isNot(contains('第1章发生了关键推进事件1')));
        expect(longCtx.dynamicSuffix, contains('【前文摘要（最近 10 章）】'));
        expect(longCtx.dynamicSuffix, contains('第1章发生了关键推进事件1'));
        expect(longCtx.dynamicSuffix, contains('第10章发生了关键推进事件10'));

        // Characters (18 > 12) and WorldEntries (15 > 8) scale up in long mode
        expect(compactCtx.staticPrefix, isNot(contains('角色_15')));
        expect(longCtx.staticPrefix, contains('角色_15'));
        expect(compactCtx.staticPrefix, isNot(contains('规则_12')));
        expect(longCtx.staticPrefix, contains('规则_12'));
      },
    );

    test(
      'appending world entry & updating relation preserves entire earlier staticPrefix byte-for-byte',
      () {
        final now = DateTime(2026, 11, 27);
        final c1 = Character(
          id: 'c1',
          novelId: 'n1',
          name: '莫烬',
          aliasesJson: '[]',
          personality: '沉静克制',
          isSceneRelevant: true,
          arcJson: '[]',
          sortOrder: 0,
        );
        final c2 = Character(
          id: 'c2',
          novelId: 'n1',
          name: '罗娜',
          aliasesJson: '[]',
          personality: '冷静果断',
          isSceneRelevant: true,
          arcJson: '[]',
          sortOrder: 1,
        );
        final w1 = WorldEntry(
          id: 'w1',
          novelId: 'n1',
          category: '规则',
          name: '钟声法则',
          content: '午夜钟响后落锁。',
          keywordsJson: '[]',
          isAlwaysOn: true,
          sortOrder: 0,
        );
        final w2 = WorldEntry(
          id: 'w2',
          novelId: 'n1',
          category: '势力',
          name: '银辉议会',
          content: '新发现的地下议会。',
          keywordsJson: '[]',
          isAlwaysOn: true,
          sortOrder: 1,
        );
        final relBefore = CharacterRelation(
          id: 'r1',
          novelId: 'n1',
          sourceCharacterId: 'c1',
          targetCharacterId: 'c2',
          relationType: '盟友',
          label: '试探合作',
          description: '初识搭档',
          strength: 3,
          line: '明线',
          status: 'active',
          evolutionJson: '[]',
          updatedAt: now,
        );
        final relAfter = relBefore.copyWith(
          label: '生死同盟',
          strength: 5,
        );
        final ch1 = _makeChapter(id: 'ch1', order: 1, outline: '莫烬与罗娜合作。', now: now);
        final ch2 = _makeChapter(id: 'ch2', order: 2, outline: '议会正式现身。', now: now);

        NovelBundle buildBundle(List<WorldEntry> worlds, CharacterRelation rel) =>
            NovelBundle(
              novel: Novel(
                id: 'n1',
                title: '测试',
                synopsis: '',
                styleGuide: '冷硬克制',
                enabledTagIdsJson: '[]',
                r18Enabled: false,
                lastTotalWordCount: 0,
                createdAt: now,
                updatedAt: now,
              ),
              volumes: [
                VolumeBundle(
                  volume: const Volume(
                    id: 'v1',
                    novelId: 'n1',
                    name: '第一卷',
                    sortOrder: 1,
                  ),
                  chapters: [ch1, ch2],
                ),
              ],
              characters: [c1, c2],
              worldEntries: worlds,
              foreshadowings: const [],
              relations: [rel],
              timelineEvents: const [],
            );

        final ctx1 = ContextBuilder.buildContinueContext(
          chapter: ch1,
          bundle: buildBundle([w1], relBefore),
          budgetChars: 128000,
        );
        final ctx2 = ContextBuilder.buildContinueContext(
          chapter: ch2,
          bundle: buildBundle([w1, w2], relAfter),
          budgetChars: 128000,
        );

        final relMarker = ctx1.staticPrefix.indexOf('【人物关系网');
        expect(relMarker, greaterThan(0));
        final stablePrefix1 = ctx1.staticPrefix.substring(0, relMarker).trimRight();
        expect(ctx2.staticPrefix.startsWith(stablePrefix1), isTrue);
      },
    );
  });
}
