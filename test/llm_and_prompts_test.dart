import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/llm/llm_json_parser.dart';
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/llm/openai_sse_client.dart';
import 'package:zhiming/core/prompts/prompt_defaults.dart';
import 'package:zhiming/core/prompts/prompt_library.dart';
import 'package:zhiming/core/prompts/prompt_limits.dart';
import 'package:zhiming/core/prompts/prompt_templates.dart';
import 'package:zhiming/domain/writing/prose_checker.dart';

void main() {
  group('OpenAiSseClient framing & error handling', () {
    test('extracts reasoning_content, reasoning alias, content and usage', () {
      const frame =
          '{"choices":[{"delta":{"reasoning_content":"先思考","content":"正文"}}],"usage":{"prompt_tokens":120,"completion_tokens":45}}';
      final events = OpenAiSseClient.extractEvents(frame);
      expect(events.length, 3);
      expect((events[0] as ReasoningDelta).text, '先思考');
      expect((events[1] as ContentDelta).text, '正文');
      final usage = events[2] as UsageReport;
      expect(usage.promptTokens, 120);
      expect(usage.completionTokens, 45);

      const aliasFrame = '{"choices":[{"delta":{"reasoning":"别名思考"}}]}';
      final aliasEvents = OpenAiSseClient.extractEvents(aliasFrame);
      expect((aliasEvents.single as ReasoningDelta).text, '别名思考');
    });

    test('detects in-stream error frames without choices', () {
      const errFrame = '{"error":{"message":"rate limit exceeded"}}';
      expect(OpenAiSseClient.extractInStreamError(errFrame), 'rate limit exceeded');
      const okFrame = '{"choices":[{"delta":{"content":"ok"}}]}';
      expect(OpenAiSseClient.extractInStreamError(okFrame), isNull);
    });

    test('redacts Bearer tokens from error messages', () {
      final err = LLMException.httpStatus(
        401,
        'Unauthorized header Authorization: Bearer sk-secret-123456',
      );
      expect(err.message, isNot(contains('sk-secret-123456')));
      expect(err.message, contains('Bearer ***'));
    });
  });

  group('LLMJSONParser', () {
    test('extracts object & array with string-aware brackets and trailing commas', () {
      const raw = '前导废话：{假括号}，真正结果：\n```json\n[{"title":"第1章","note":"含}与]字符",},]\n```';
      final list = LLMJSONParser.decodeList<Map<String, dynamic>>(
        raw,
        (item) => Map<String, dynamic>.from(item as Map),
      );
      expect(list, isNotNull);
      expect(list!.single['title'], '第1章');
      expect(list.single['note'], '含}与]字符');
    });

    test('parses SummaryResult including foreshadowings', () {
      const raw = '''
```json
{
  "summary": "主角在雨夜收到密信。",
  "key_facts": ["火漆印章属于旧灯塔守望者"],
  "new_foreshadowings": [{"title": "黑蜡封信", "detail": "落款无名", "planned_resolve": "第三卷"}],
  "resolved_foreshadowing_titles": ["港口的旧钟"]
}
```''';
      final parsed = SummaryResult.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.summary, contains('密信'));
      expect(parsed.keyFacts.single, contains('灯塔'));
      expect(parsed.newForeshadowings.single.title, '黑蜡封信');
      expect(parsed.resolvedForeshadowingTitles.single, '港口的旧钟');
    });
  });

  group('PromptLibrary & PromptLimits & PromptTemplates', () {
    test('locks all critical guardrail constants & 24 built-in prompts', () {
      expect(PromptLimits.maxOverrideChars, 20000);
      expect(PromptLimits.matchedSupplementCap, 8000);
      expect(PromptLimits.r18ModuleCharBudget, 12000);
      expect(PromptLimits.requiredFieldCap, 4000);
      expect(PromptLimits.requestWarnChars, 80000);
      expect(PromptDefaults.builtInPrompts.length, 24);
      expect(
        PromptDefaults.defaultTagCategories.expand((c) => c.tags).length,
        15,
      );
    });

    test('detectLanguage separates zh and en with tie-breaker on last sentence', () {
      expect(PromptLibraryState.detectLanguage('雾港雨夜的灯塔'), 'zh');
      expect(PromptLibraryState.detectLanguage('Foggy harbor lighthouse'), 'en');
      expect(PromptLibraryState.detectLanguage('12345 !@#'), 'zh');
      expect(PromptLibraryState.detectLanguage('ab中文。cd'), 'en');
    });

    test('matchedSupplement only injects enabled + hit tags and enforces 8K cap', () {
      final bigTag = PromptTag(
        id: 't1',
        name: '巨大标签',
        keywords: const ['触发'],
        presetText: '甲' * 6000,
      );
      final bigTag2 = PromptTag(
        id: 't2',
        name: '巨大标签二',
        keywords: const ['触发'],
        presetText: '乙' * 6000,
      );
      final lib = PromptLibraryState(
        tagCategories: [
          PromptTagCategory(id: 'c1', name: '测试', tags: [bigTag, bigTag2]),
        ],
      );
      // 未启用不注入
      expect(lib.matchedSupplement(const [], '触发'), isNull);
      // 启用两个触发熔断：第二个被跳过并附提示
      final res = lib.matchedSupplement(const ['t1', 't2'], '我要触发这个标签');
      expect(res, isNotNull);
      expect(res, contains('巨大标签'));
      expect(res, isNot(contains('巨大标签二')));
      expect(res, contains('另有 1 条命中标签'));
    });

    test('r18Supplement loads core + smallest matching modules within 12K budget', () async {
      final lib = const PromptLibraryState();
      final result = await lib.r18Supplement(
        '同人 对白 玩法',
        skillLoader: (file, lang) async {
          if (lang != 'zh') return null;
          return switch (file) {
            'core' => 'CORE' * 1000, // 4000 chars
            'language-and-dialogue' => 'D' * 3000, // fits (4000+3000<=12000)
            'play-and-props' => 'P' * 4000, // fits (7000+4000<=12000)
            'canon-grounding-and-fanfiction' => 'C' * 5000, // exceeds 12000
            _ => null,
          };
        },
      );
      expect(result, contains('CORE'));
      expect(result, contains('语言与对白校准'));
      expect(result, contains('玩法与道具'));
      expect(result, isNot(contains('同人原作锚定')));
    });

    test('adjustedInputBudget subtracts dynamic injections cleanly', () {
      expect(
        PromptTemplates.adjustedInputBudget(60000, ['a' * 5000, null, 'b' * 3000]),
        52000,
      );
      expect(
        PromptTemplates.adjustedInputBudget(1000, ['a' * 5000]),
        0,
      );
    });

    test('SSE usage parses cached_tokens & reasoning_tokens and staticContext stays in system', () {
      final evs = OpenAiSseClient.extractEvents(
        '{"choices":[],"usage":{"prompt_tokens":10000,"completion_tokens":500,"prompt_cache_hit_tokens":8700,"completion_tokens_details":{"reasoning_tokens":320}}}',
      );
      final u = evs.whereType<UsageReport>().single;
      expect(u.cachedTokens, 8700);
      expect(u.reasoningTokens, 320);
      expect(u.cacheHitRate, closeTo(0.87, 0.001));

      final msgs = PromptTemplates.continueWriting(
        library: const PromptLibraryState(),
        staticContext: '【静态世界观与角色表】',
        renderedContext: '【本章动态细纲】',
        wordTarget: 1500,
      );
      expect(msgs.first.role, LLMRole.system);
      expect(msgs.first.content, contains('【静态世界观与角色表】'));
      expect(msgs.last.role, LLMRole.user);
      expect(msgs.last.content, isNot(contains('【静态世界观与角色表】')));
      expect(msgs.last.content, contains('【本章动态细纲】'));
    });
  });

  group('ProseChecker', () {
    test('detects duiju, cliches, simile abuse, and high le-density', () {
      final sample =
          '他不是为了复仇，而是为了寻找真相。他瞳孔骤缩，倒吸一口凉气，'
          '仿佛置身冰窖，犹如坠入深渊，宛如石化一般。与此同时，刹那间，霎时间，'
          '这让他感到一阵寒意，他意识到自己错了，心中一凛。'
          '他走了过去，拿了杯子，喝了水，关了灯，锁了门，躺了下来。';
      final issues = ProseChecker.check(sample);
      final rules = issues.map((e) => e.rule).toSet();
      expect(rules, containsAll(['解释性对举句', '比喻滥用', '强加因果', '认知直陈', '模板动作套话', '过渡套话']));
    });
  });
}
