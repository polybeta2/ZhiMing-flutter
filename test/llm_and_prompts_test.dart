import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiming/core/database/app_database.dart' show ProviderRecord;
import 'package:zhiming/core/llm/llm_json_parser.dart';
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/llm/openai_sse_client.dart';
import 'package:zhiming/core/llm/provider_client_factory.dart';
import 'package:zhiming/core/llm/stream_progress.dart';
import 'package:zhiming/core/platform/background_keep_alive.dart';
import 'package:zhiming/core/prompts/prompt_defaults.dart';
import 'package:zhiming/core/prompts/prompt_library.dart';
import 'package:zhiming/core/prompts/prompt_limits.dart';
import 'package:zhiming/core/prompts/prompt_templates.dart';
import 'package:zhiming/domain/writing/prose_checker.dart';

class _ScriptedHttpClientAdapter implements HttpClientAdapter {
  _ScriptedHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Map<String, dynamic> body,
    int callIndex,
  )
  _handler;

  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final decodedBody = bytes.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map)
        : Map<String, dynamic>.from(options.data as Map);
    final idx = callCount++;
    return _handler(options, decodedBody, idx);
  }

  @override
  void close({bool force = false}) {}
}

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
    test('locks all critical guardrail constants & 31 built-in prompts', () {
      expect(PromptLimits.maxOverrideChars, 20000);
      expect(PromptLimits.matchedSupplementCap, 8000);
      expect(PromptLimits.r18ModuleCharBudget, 12000);
      expect(PromptLimits.requiredFieldCap, 4000);
      expect(PromptLimits.requestWarnChars, 80000);
      expect(PromptDefaults.builtInPrompts.length, 31);
      expect(
        PromptDefaults.builtInPrompts.any((p) => p.id == PromptID.factReview),
        isTrue,
      );
      expect(
        PromptDefaults.builtInPrompts.any(
          (p) => p.id == PromptID.directorCinematic,
        ),
        isTrue,
      );
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
    test('detects duiju, progressive slop, abstract slop, tidy endings, cliches, simile abuse', () {
      final sample =
          '他不是为了复仇，而是为了寻找真相。这不仅仅是一次试探，更是一场博弈。'
          '空气仿佛凝固了，一种某种难以言喻的压力笼罩下来。他瞳孔骤缩，倒吸一口凉气，'
          '仿佛置身冰窖，犹如坠入深渊，宛如石化一般。与此同时，刹那间，霎时间，'
          '这让他感到一阵寒意，他意识到自己错了，心中一凛。'
          '他走了过去，拿了杯子，喝了水，关了灯，锁了门，躺了下来。命运的齿轮开始转动，真正的考验才刚刚开始。';
      final issues = ProseChecker.check(sample);
      final rules = issues.map((e) => e.rule).toSet();
      expect(
        rules,
        containsAll([
          '解释性对举句',
          '递进说明腔',
          '空洞抽象修饰',
          '强行升华套话',
          '比喻滥用',
          '强加因果',
          '认知直陈',
          '模板动作套话',
          '过渡套话',
        ]),
      );
    });
  });

  group('BackgroundKeepAliveService', () {
    test('ref-counts active sessions, hot-switches modes & persists choice', () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      final service = BackgroundKeepAliveService.forTesting(
        isIos: true,
        invoker: (method, [args]) async {
          calls.add(args == null ? method : '$method:${args['mode']}');
          if (method == 'requestLocationPermission') {
            return 'authorizedWhenInUse';
          }
          return null;
        },
      );

      expect(await service.loadFromPrefs(), BackgroundKeepAliveMode.none);
      await service.acquire();
      expect(calls, isEmpty); // none 不触发原生保活
      await service.release();

      await service.setMode(BackgroundKeepAliveMode.silentAudio);
      await service.acquire();
      await service.acquire(); // nested task should not duplicate start
      expect(calls, ['start:silent_audio']);

      await service.release();
      expect(service.activeCount, 1);
      expect(calls, ['start:silent_audio']);

      // 热切换模式到持续位置获取，立即重配置原生保活
      await service.setMode(BackgroundKeepAliveMode.lowPowerLocation);
      expect(calls, ['start:silent_audio', 'start:low_power_location']);

      await service.release();
      expect(service.activeCount, 0);
      expect(calls.last, 'stop');

      final perm = await service.requestLocationPermission();
      expect(perm, LocationPermissionState.authorizedWhenInUse);

      // 重建实例应从 SharedPreferences 恢复上次选择
      final reloaded = BackgroundKeepAliveService.forTesting(isIos: true);
      expect(
        await reloaded.loadFromPrefs(),
        BackgroundKeepAliveMode.lowPowerLocation,
      );
    });

    test('parses native status & runs timed self-test safely', () async {
      SharedPreferences.setMockInitialValues({});
      var active = false;
      var mode = 'none';
      final service = BackgroundKeepAliveService.forTesting(
        isIos: true,
        invoker: (method, [args]) async {
          if (method == 'start') {
            mode = (args?['mode'] as String?) ?? 'none';
            active = mode != 'none';
          } else if (method == 'stop') {
            active = false;
            mode = 'none';
          }
          return {
            'mode': mode,
            'active': active,
            'audioPlaying': false,
            'locationUpdating': active && mode == 'low_power_location',
            'locationAuth': 'authorizedWhenInUse',
            'blueIndicatorExpected': active && mode == 'low_power_location',
          };
        },
      );

      await service.setMode(BackgroundKeepAliveMode.lowPowerLocation);
      KeepAliveNativeStatus? startedSnapshot;
      final res = await service.runSelfTest(
        duration: Duration.zero,
        onStarted: (s) => startedSnapshot = s,
      );

      expect(startedSnapshot, isNotNull);
      expect(startedSnapshot!.active, isTrue);
      expect(startedSnapshot!.blueIndicatorExpected, isTrue);
      expect(res.locationUpdating, isTrue);
      expect(service.activeCount, 0);
      expect(service.lastStatus.active, isFalse);

      final desktopService = BackgroundKeepAliveService.forTesting(isIos: false);
      expect((await desktopService.getStatus()).active, isFalse);
    });
  });

  group('Wave 1: LLM Protocol Upgrade, Dual-Model Routing & Cache Telemetry', () {
    test(
      'buildRequestBody includes response_format, reasoning_effort and Anthropic cache_control',
      () {
        const messages = [
          LLMMessage(
            role: LLMRole.system,
            content: 'sys',
            cacheControl: true,
          ),
          LLMMessage(role: LLMRole.user, content: 'usr'),
        ];
        const config = GenerationConfig(
          temperature: 0.3,
          maxTokens: 2048,
          includeUsage: true,
          jsonMode: true,
          reasoningEffort: ReasoningEffort.low,
          enablePromptCacheControl: true,
        );

        final bodyWithCache = OpenAiSseClient.buildRequestBody(
          model: 'claude-3-7-sonnet',
          messages: messages,
          config: config,
          useExplicitCacheControl: true,
        );
        expect(bodyWithCache['response_format'], {'type': 'json_object'});
        expect(bodyWithCache['reasoning_effort'], 'low');
        final encodedMsgs = bodyWithCache['messages'] as List<dynamic>;
        expect(encodedMsgs.length, 2);
        expect(encodedMsgs[0], {
          'role': 'system',
          'content': [
            {
              'type': 'text',
              'text': 'sys',
              'cache_control': {'type': 'ephemeral'},
            },
          ],
        });
        expect(encodedMsgs[1], {'role': 'user', 'content': 'usr'});

        final bodyWithoutCache = OpenAiSseClient.buildRequestBody(
          model: 'gpt-4o',
          messages: messages,
          config: config,
          useExplicitCacheControl: false,
        );
        final plainMsgs = bodyWithoutCache['messages'] as List<dynamic>;
        expect(plainMsgs[0], {'role': 'system', 'content': 'sys'});
      },
    );

    test(
      'extractEvents parses Anthropic cache_read_input_tokens and cache_creation_input_tokens',
      () {
        const frame =
            '{"choices":[],"usage":{"prompt_tokens":4000,"completion_tokens":120,"cache_read_input_tokens":3200,"cache_creation_input_tokens":800}}';
        final events = OpenAiSseClient.extractEvents(frame);
        final usage = events.whereType<UsageReport>().single;
        expect(usage.promptTokens, 4000);
        expect(usage.completionTokens, 120);
        expect(usage.cachedTokens, 3200);
        expect(usage.cacheCreationTokens, 800);
        expect(usage.cacheHitRate, closeTo(0.8, 0.001));
      },
    );

    test(
      'streamChat falls back on HTTP 400 by stripping optional protocol extensions',
      () async {
        final capturedBodies = <Map<String, dynamic>>[];
        final dio = Dio();
        dio.httpClientAdapter = _ScriptedHttpClientAdapter((
          options,
          body,
          callIndex,
        ) async {
          capturedBodies.add(body);
          if (callIndex == 0) {
            return ResponseBody.fromString(
              '{"error":{"message":"unknown parameter response_format"}}',
              400,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(
            'data: {"choices":[{"delta":{"content":"ok"}}]}\n\ndata: [DONE]\n\n',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/event-stream'],
            },
          );
        });

        final client = OpenAiSseClient(
          baseUrl: 'https://api.anthropic.com/v1',
          apiKey: 'sk-test-key',
          model: 'claude-sonnet-4',
          dio: dio,
        );

        final events = await client
            .streamChat(
              const [
                LLMMessage(
                  role: LLMRole.system,
                  content: 'sys',
                  cacheControl: true,
                ),
                LLMMessage(role: LLMRole.user, content: 'hi'),
              ],
              config: const GenerationConfig(
                jsonMode: true,
                reasoningEffort: ReasoningEffort.low,
                enablePromptCacheControl: true,
              ),
            )
            .toList();

        expect(capturedBodies.length, 2);
        expect(capturedBodies[0]['response_format'], {'type': 'json_object'});
        expect(capturedBodies[0]['reasoning_effort'], 'low');
        expect((capturedBodies[0]['messages'] as List).first['content'], isList);

        expect(capturedBodies[1].containsKey('response_format'), isFalse);
        expect(capturedBodies[1].containsKey('reasoning_effort'), isFalse);
        expect((capturedBodies[1]['messages'] as List).first['content'], 'sys');

        final content = events.whereType<ContentDelta>().map((e) => e.text).join();
        expect(content, 'ok');
      },
    );

    test(
      'resolveProviderForRole routes fastTool when found and falls back to defaultProvider',
      () {
        final primary = ProviderRecord(
          id: 'p-primary',
          name: '主力模型',
          baseUrl: 'https://api.example.com/v1',
          apiKeyId: 'k1',
          modelName: 'claude-sonnet',
          temperature: 0.8,
          maxTokens: 16384,
          contextBudgetChars: 60000,
          isDefault: true,
          createdAt: DateTime(2026),
        );
        final fast = ProviderRecord(
          id: 'p-fast',
          name: '极速模型',
          baseUrl: 'https://api.example.com/v1',
          apiKeyId: 'k2',
          modelName: 'gpt-4o-mini',
          temperature: 0.3,
          maxTokens: 4096,
          contextBudgetChars: 60000,
          isDefault: false,
          createdAt: DateTime(2026),
        );
        final providers = [primary, fast];

        expect(
          resolveProviderForRole(
            providers,
            primary,
            'p-fast',
            ProviderRole.primary,
          )?.id,
          'p-primary',
        );
        expect(
          resolveProviderForRole(
            providers,
            primary,
            'p-fast',
            ProviderRole.fastTool,
          )?.id,
          'p-fast',
        );
        expect(
          resolveProviderForRole(
            providers,
            primary,
            null,
            ProviderRole.fastTool,
          )?.id,
          'p-primary',
        );
        expect(
          resolveProviderForRole(
            providers,
            primary,
            'non-existent',
            ProviderRole.fastTool,
          )?.id,
          'p-primary',
        );
        expect(
          resolveProviderForRole(
            const [],
            null,
            'p-fast',
            ProviderRole.fastTool,
          ),
          isNull,
        );
      },
    );

    test(
      'FastToolProviderIdNotifier persists and reloads from SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider.fastToolProviderId': 'p-fast',
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(fastToolProviderIdProvider);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(fastToolProviderIdProvider), 'p-fast');

        await container
            .read(fastToolProviderIdProvider.notifier)
            .setProviderId('p-other');
        expect(container.read(fastToolProviderIdProvider), 'p-other');

        await container
            .read(fastToolProviderIdProvider.notifier)
            .setProviderId(null);
        expect(container.read(fastToolProviderIdProvider), isNull);
      },
    );

    test(
      'StreamProgressTracker exposes cache statusText and preserves lastCompletedUsage across finish()',
      () {
        final tracker = StreamProgressTracker();
        addTearDown(tracker.dispose);

        tracker.begin();
        expect(tracker.lastCompletedUsage, isNull);
        expect(tracker.value.lastUsage, isNull);

        tracker.handle(const ContentDelta('正文'));
        tracker.handle(
          const UsageReport(
            promptTokens: 1000,
            completionTokens: 100,
            cachedTokens: 850,
            cacheCreationTokens: 150,
          ),
        );
        expect(tracker.value.statusText, contains('· 缓存命中 85%'));
        expect(tracker.lastCompletedUsage?.cacheCreationTokens, 150);

        tracker.finish();
        expect(tracker.value.stage, StreamStage.idle);
        expect(tracker.value.isActive, isFalse);
        expect(tracker.lastCompletedUsage?.cachedTokens, 850);
        expect(tracker.value.lastUsage?.cachedTokens, 850);

        tracker.begin();
        expect(tracker.lastCompletedUsage, isNull);
        expect(tracker.value.lastUsage, isNull);
      },
    );
  });
}
