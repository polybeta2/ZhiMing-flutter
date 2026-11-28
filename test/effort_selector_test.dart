import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiming/core/database/app_database.dart' show ProviderRecord;
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/llm/openai_sse_client.dart';
import 'package:zhiming/core/llm/provider_client_factory.dart';
import 'package:zhiming/core/security/api_key_vault.dart';
import 'package:zhiming/core/widgets/effort_selector_bar.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Map<String, dynamic>? body,
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
    Map<String, dynamic>? decodedBody;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) {
        decodedBody = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)) as Map,
        );
      }
    } else if (options.data is Map) {
      decodedBody = Map<String, dynamic>.from(options.data as Map);
    }
    final idx = callCount++;
    return _handler(options, decodedBody, idx);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ReasoningEffort 7-tier model & parsing', () {
    test('exposes exact 7 selectable tiers and parses variants', () {
      expect(
        ReasoningEffort.selectableTiers.map((e) => e.label).toList(),
        ['OFF', 'Low', 'Medium', 'High', 'Xhigh', 'Max', 'Ultra'],
      );
      expect(
        ReasoningEffort.selectableTiers.map((e) => e.wireValue).toList(),
        ['none', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra'],
      );
      expect(ReasoningEffort.none.isThinkingEnabled, isFalse);
      expect(ReasoningEffort.xhigh.isThinkingEnabled, isTrue);
      expect(ReasoningEffort.max.isThinkingEnabled, isTrue);
      expect(ReasoningEffort.ultra.isThinkingEnabled, isTrue);

      expect(ReasoningEffort.tryParse('OFF'), ReasoningEffort.none);
      expect(ReasoningEffort.tryParse('x-high'), ReasoningEffort.xhigh);
      expect(ReasoningEffort.tryParse('extra_high'), ReasoningEffort.xhigh);
      expect(ReasoningEffort.tryParse('Maximum'), ReasoningEffort.max);
      expect(ReasoningEffort.tryParse('ULTRA'), ReasoningEffort.ultra);
      expect(ReasoningEffort.tryParse('unknown_tier'), isNull);
    });

    test('parses supported effort tiers from heterogeneous /models schemas', () {
      final cap1 = OpenAiSseClient.parseSupportedEffortsFromModelObject({
        'id': 'gpt-5',
        'supported_reasoning_efforts': ['ultra', 'low', 'none', 'high', 'xhigh'],
      });
      expect(cap1.fromEndpoint, isTrue);
      expect(cap1.displayEfforts, [
        ReasoningEffort.none,
        ReasoningEffort.low,
        ReasoningEffort.high,
        ReasoningEffort.xhigh,
        ReasoningEffort.ultra,
      ]);

      final cap2 = OpenAiSseClient.parseSupportedEffortsFromModelObject({
        'id': 'claude-opus',
        'capabilities': {
          'reasoning_effort': {
            'enum': ['low', 'medium', 'max'],
          },
        },
      });
      expect(cap2.fromEndpoint, isTrue);
      expect(cap2.displayEfforts, [
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.max,
      ]);

      final capFallback = OpenAiSseClient.parseSupportedEffortsFromModelObject({
        'id': 'deepseek-v4.1-flash',
        'object': 'model',
        'owned_by': 'deepseek',
      });
      expect(capFallback.fromEndpoint, isFalse);
      expect(capFallback.displayEfforts, ReasoningEffort.selectableTiers);
    });

    test('probes /models then /models/{id} and falls back cleanly when absent', () async {
      final dio = Dio();
      dio.httpClientAdapter = _StubAdapter((options, body, idx) async {
        final path = options.uri.path;
        if (path.endsWith('/models')) {
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': 'model-no-meta'},
                {
                  'id': 'model-with-meta',
                  'reasoning_efforts': ['none', 'low', 'medium'],
                },
              ],
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        if (path.endsWith('/models/model-detail-only')) {
          return ResponseBody.fromString(
            jsonEncode({
              'id': 'model-detail-only',
              'parameters': {
                'reasoning_effort': {
                  'values': ['low', 'high', 'xhigh'],
                },
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final c1 = OpenAiSseClient(
        baseUrl: 'https://probe.example.com/v1',
        apiKey: 'sk-test',
        model: 'model-with-meta',
        dio: dio,
      );
      final r1 = await c1.probeModelEffortCapabilities();
      expect(r1.target.fromEndpoint, isTrue);
      expect(r1.target.displayEfforts, [
        ReasoningEffort.none,
        ReasoningEffort.low,
        ReasoningEffort.medium,
      ]);

      final c2 = OpenAiSseClient(
        baseUrl: 'https://probe.example.com/v1',
        apiKey: 'sk-test',
        model: 'model-detail-only',
        dio: dio,
      );
      final r2 = await c2.probeModelEffortCapabilities();
      expect(r2.target.fromEndpoint, isTrue);
      expect(r2.target.displayEfforts, [
        ReasoningEffort.low,
        ReasoningEffort.high,
        ReasoningEffort.xhigh,
      ]);

      final c3 = OpenAiSseClient(
        baseUrl: 'https://probe.example.com/v1',
        apiKey: 'sk-test',
        model: 'model-no-meta',
        dio: dio,
      );
      final r3 = await c3.probeModelEffortCapabilities();
      expect(r3.target.fromEndpoint, isFalse);
      expect(r3.target.displayEfforts, ReasoningEffort.selectableTiers);
    });

    test('extended tier rejection throws clear error without poisoning standard tiers', () async {
      OpenAiSseClient.clearUnsupportedExtensionCache();
      final captured = <Map<String, dynamic>>[];
      final dio = Dio();
      dio.httpClientAdapter = _StubAdapter((options, body, idx) async {
        captured.add(body ?? {});
        if (body?['reasoning_effort'] == 'ultra') {
          return ResponseBody.fromString(
            '{"error":{"message":"invalid reasoning_effort: ultra is not supported"}}',
            400,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/event-stream'],
          },
        );
      });

      final client = OpenAiSseClient(
        baseUrl: 'https://effort-check.example.com/v1',
        apiKey: 'sk-test',
        model: 'test-model',
        defaultReasoningEffort: ReasoningEffort.none,
        dio: dio,
      );

      // 1) Selecting Ultra boosts max_tokens to 32768 and surfaces a clear error on 400
      await expectLater(
        client
            .streamChat(
              const [LLMMessage(role: LLMRole.user, content: 'hi')],
              config: const GenerationConfig(
                maxTokens: 16384,
                reasoningEffort: ReasoningEffort.ultra,
              ),
            )
            .toList(),
        throwsA(
          isA<LLMException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Effort「Ultra」'), contains('ultra')),
          ),
        ),
      );
      expect(captured[0]['max_tokens'], 32768);
      expect(captured[0]['reasoning_effort'], 'ultra');

      // 2) Subsequent call with standard effort still sends reasoning_effort & jsonMode cleanly
      final events = await client
          .streamChat(
            const [LLMMessage(role: LLMRole.user, content: 'hi again')],
            config: const GenerationConfig(
              jsonMode: true,
              reasoningEffort: ReasoningEffort.high,
            ),
          )
          .toList();
      expect(events.whereType<ContentDelta>().single.text, 'ok');
      expect(captured[1]['reasoning_effort'], 'high');
      expect(captured[1]['response_format'], {'type': 'json_object'});
      OpenAiSseClient.clearUnsupportedExtensionCache();
    });

    test('createClientForProvider resolves explicit > provider override > global preference', () async {
      SharedPreferences.setMockInitialValues({
        ReasoningPreferenceNotifier.prefKey: 'high',
        ProviderEffortOverridesNotifier.prefKey: jsonEncode({'p1': 'xhigh'}),
      });
      final vault = InMemoryApiKeyVault();
      await vault.save('k1', 'sk-demo');
      final p1 = ProviderRecord(
        id: 'p1',
        name: 'P1',
        baseUrl: 'https://api.example.com/v1',
        apiKeyId: 'k1',
        modelName: 'demo-model',
        temperature: 0.7,
        maxTokens: 16384,
        contextBudgetChars: 60000,
        isDefault: true,
        createdAt: DateTime(2026, 11, 28),
      );
      final p2 = p1.copyWith(id: 'p2');

      // Explicit override wins
      final cExplicit =
          await createClientForProvider(
                p1,
                vault,
                defaultReasoningEffort: ReasoningEffort.max,
              )
              as OpenAiSseClient;
      expect(cExplicit.defaultReasoningEffort, ReasoningEffort.max);

      // Provider-level override beats global
      final cProvider = await createClientForProvider(p1, vault) as OpenAiSseClient;
      expect(cProvider.defaultReasoningEffort, ReasoningEffort.xhigh);

      // Global preference applies when provider has no override
      final cGlobal = await createClientForProvider(p2, vault) as OpenAiSseClient;
      expect(cGlobal.defaultReasoningEffort, ReasoningEffort.high);
    });
  });

  group('EffortSelectorBar & EffortCompactChip widgets', () {
    testWidgets('shows all 7 tiers when endpoint does not report capabilities', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      ReasoningEffort? picked;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: EffortSelectorBar(
                  value: picked,
                  onChanged: (v) => picked = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final label in const [
        'OFF',
        'Low',
        'Medium',
        'High',
        'Xhigh',
        'Max',
        'Ultra',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('端点未返回可用 Effort 列表'), findsOneWidget);

      await tester.tap(find.text('Xhigh'));
      await tester.pump();
      expect(picked, ReasoningEffort.xhigh);
    });

    testWidgets('shows only endpoint-declared tiers when cached discovery exists', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final provider = ProviderRecord(
        id: 'p-cap',
        name: 'CapProvider',
        baseUrl: 'https://cap.example.com/v1',
        apiKeyId: 'k-cap',
        modelName: 'cap-model',
        temperature: 0.7,
        maxTokens: 16384,
        contextBudgetChars: 60000,
        isDefault: true,
        createdAt: DateTime(2026, 11, 28),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(effortDiscoveryProvider.notifier).seedFromModelsFetch(
        provider.baseUrl,
        {
          provider.modelName: const EffortCapabilities(
            supportedEfforts: [
              ReasoningEffort.none,
              ReasoningEffort.low,
              ReasoningEffort.high,
            ],
            fromEndpoint: true,
          ),
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: EffortSelectorBar(
                  value: null,
                  provider: provider,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('端点已识别'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Ultra'), findsNothing);
    });

    testWidgets('EffortCompactChip opens bottom sheet and propagates selection', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      ReasoningEffort? selected;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (ctx, setLocal) => Center(
                  child: EffortCompactChip(
                    value: selected,
                    onChanged: (v) => setLocal(() => selected = v),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Effort: OFF'), findsOneWidget);
      await tester.tap(find.text('Effort: OFF'));
      await tester.pumpAndSettle();

      expect(find.text('调节模型努力程度（Effort）'), findsOneWidget);
      await tester.tap(find.text('Max'));
      await tester.pumpAndSettle();

      expect(selected, ReasoningEffort.max);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('Effort: Max'), findsOneWidget);
    });
  });
}
