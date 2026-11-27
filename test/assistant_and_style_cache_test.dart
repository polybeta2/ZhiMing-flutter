import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/prompts/prompt_library.dart';
import 'package:zhiming/core/prompts/prompt_limits.dart';
import 'package:zhiming/domain/style/style_distillation_service.dart';
import 'package:zhiming/features/assistant/assistant_chat_view.dart';

class _CapturedCall {
  const _CapturedCall({required this.messages, required this.config});

  final List<LLMMessage> messages;
  final GenerationConfig config;
}

class _FakeRecordingLLMClient extends LLMClient {
  _FakeRecordingLLMClient(this._responder);

  final String Function(List<LLMMessage> messages, int callIndex) _responder;
  final List<_CapturedCall> calls = [];

  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    final idx = calls.length;
    calls.add(_CapturedCall(messages: List.of(messages), config: config));
    final reply = _responder(messages, idx);
    yield ContentDelta(reply);
  }

  @override
  Future<List<String>> fetchModelIds({CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<String> testConnection({CancelToken? cancelToken}) async => 'ok';
}

String _sampleAnalysisJson() => jsonEncode({
  'enough': true,
  'narrative_voice': {'pov': '第三人称有限', 'distance': '贴近'},
  'sentence_syntax': {'shape': '短句切分', 'long_short_ratio': '3:7'},
  'diction': {'register': '冷峻克制'},
  'scene_rhythm': {'openings': '动作切入'},
  'dialogue': {'line_length': '简短'},
  'emotion': {'directness': '动作外化'},
  'anti_ai': {'forbidden_patterns': <String>[]},
  'evidence': <Map<String, dynamic>>[],
});

String _sampleCardJson({String styled = '他抬眼扫过巷口，指节抵在刀鞘上。'}) =>
    jsonEncode({
      'name': '冷峻短句风',
      'fingerprint_summary': '短句推进，少形容词',
      'tags': ['冷峻', '短句'],
      'must_rules': ['动词先行'],
      'avoid_rules': ['禁止总结升华'],
      'examples': [
        {
          'plain': '他心里很紧张，看着巷口。',
          'styled': styled,
          'principle': '动作代替心理形容',
        },
      ],
    });

String _buildLongChapterSource({required int targetBodyChars}) {
  final buf = StringBuffer('第1章 暴雨长夜\n');
  var lineNo = 0;
  while (buf.length < targetBodyChars + 20) {
    buf.writeln('第${lineNo.toString().padLeft(4, '0')}步雨水打湿青石阶，风穿过旧巷。');
    lineNo++;
  }
  return buf.toString();
}

void main() {
  group('selectCacheFriendlyHistory', () {
    test('lengths 1..24 return all items starting at index 0', () {
      for (final len in [1, 12, 24]) {
        final input = List<int>.generate(len, (i) => i);
        final out = selectCacheFriendlyHistory(input);
        expect(out, equals(input));
        expect(out.first, 0);
      }
    });

    test('lengths 25..36 drop first block of 12 and pin start at 12', () {
      for (final len in [25, 30, 36]) {
        final input = List<int>.generate(len, (i) => i);
        final out = selectCacheFriendlyHistory(input);
        expect(out, equals(input.sublist(12)));
        expect(out.first, 12);
      }
    });

    test('lengths 37..48 drop first 24 items and pin start at 24', () {
      for (final len in [37, 48]) {
        final input = List<int>.generate(len, (i) => i);
        final out = selectCacheFriendlyHistory(input);
        expect(out, equals(input.sublist(24)));
        expect(out.first, 24);
      }
    });
  });

  group('StyleDistillationService KV Cache & adaptive sampling', () {
    const library = PromptLibraryState();

    test('S2 runs with jsonMode/medium/cacheControl and chains cleanly into S3', () async {
      final s2Reply = _sampleAnalysisJson();
      final s3Reply = _sampleCardJson();
      final client = _FakeRecordingLLMClient((messages, callIdx) {
        if (callIdx == 0) return s2Reply;
        return s3Reply;
      });

      final service = StyleDistillationService(
        client: client,
        library: library,
        providerExtra: '附加测试规则',
      );

      final source = [
        '第1章 启程\n${List.generate(30, (i) => '风吹第$i号渡口，船灯晃在水面上。').join('\n')}',
        '第2章 入城\n${List.generate(30, (i) => '第$i声更鼓敲响时，城门缓缓合拢。').join('\n')}',
      ].join('\n\n');

      final events = await service
          .distill(sourceText: source, sourceNote: '测试样本')
          .toList();

      expect(events.whereType<StyleDistillCompleted>(), hasLength(1));
      expect(client.calls, hasLength(2));

      final s2 = client.calls[0];
      expect(s2.messages, hasLength(2));
      expect(s2.messages[0].role, LLMRole.system);
      expect(s2.messages[0].cacheControl, isTrue);
      expect(s2.messages[0].content, contains('附加测试规则'));
      expect(s2.messages[1].role, LLMRole.user);
      expect(s2.messages[1].content, contains('【样本文本】'));
      expect(s2.config.jsonMode, isTrue);
      expect(s2.config.reasoningEffort, ReasoningEffort.medium);
      expect(s2.config.enablePromptCacheControl, isTrue);

      final s3 = client.calls[1];
      expect(s3.messages, hasLength(4));
      expect(s3.messages[0].role, LLMRole.system);
      expect(s3.messages[0].content, equals(s2.messages[0].content));
      expect(s3.messages[0].cacheControl, equals(s2.messages[0].cacheControl));
      expect(s3.messages[1].role, LLMRole.user);
      expect(s3.messages[1].content, equals(s2.messages[1].content));
      expect(s3.messages[2].role, LLMRole.assistant);
      expect(s3.messages[2].content, equals(s2Reply));
      expect(s3.messages[3].role, LLMRole.user);
      expect(
        s3.messages[3].content,
        contains(library.resolvedText(PromptID.styleDistillCard)),
      );
      expect(s3.config.jsonMode, isTrue);
      expect(s3.config.reasoningEffort, ReasoningEffort.medium);
      expect(s3.config.enablePromptCacheControl, isTrue);
    });

    test('S3 uses standalone prompt with cacheControl when cachedAnalysisRaw skips S2', () async {
      final client = _FakeRecordingLLMClient((_, _) => _sampleCardJson());
      final service = StyleDistillationService(
        client: client,
        library: library,
        providerExtra: '断点规则',
      );

      final source = _buildLongChapterSource(targetBodyChars: 1200);
      await service
          .distill(
            sourceText: source,
            sourceNote: '断点续蒸',
            cachedAnalysisRaw: _sampleAnalysisJson(),
          )
          .drain<void>();

      expect(client.calls, hasLength(1));
      final s3 = client.calls.single;
      expect(s3.messages, hasLength(2));
      expect(s3.messages[0].role, LLMRole.system);
      expect(s3.messages[0].cacheControl, isTrue);
      expect(s3.messages[0].content, contains('断点规则'));
      expect(s3.messages[1].content, contains('【机制分析】'));
      expect(s3.config.jsonMode, isTrue);
      expect(s3.config.reasoningEffort, ReasoningEffort.medium);
      expect(s3.config.enablePromptCacheControl, isTrue);
    });

    test('contextBudgetChars: 128000 reads >3000 chars of a 5500-char chapter', () async {
      final longSource = _buildLongChapterSource(targetBodyChars: 5500);
      final markerIndex = longSource.indexOf('第0240步');
      expect(markerIndex, greaterThan(3500));

      final shortClient = _FakeRecordingLLMClient(
        (_, callIdx) => callIdx == 0 ? _sampleAnalysisJson() : _sampleCardJson(),
      );
      final shortService = StyleDistillationService(
        client: shortClient,
        library: library,
        contextBudgetChars: 60000,
      );
      await shortService
          .distill(sourceText: longSource, sourceNote: '短窗')
          .drain<void>();

      final shortSampleMsg = shortClient.calls[0].messages[1].content;
      expect(shortSampleMsg, contains('第0010步'));
      expect(shortSampleMsg, isNot(contains('第0240步')));

      final longClient = _FakeRecordingLLMClient(
        (_, callIdx) => callIdx == 0 ? _sampleAnalysisJson() : _sampleCardJson(),
      );
      final longService = StyleDistillationService(
        client: longClient,
        library: library,
        contextBudgetChars: 128000,
      );
      await longService
          .distill(sourceText: longSource, sourceNote: '长窗')
          .drain<void>();

      final longSampleMsg = longClient.calls[0].messages[1].content;
      expect(PromptLimits.styleSampleCapLong, 72000);
      expect(PromptLimits.styleChapterCapLong, 8000);
      expect(longSampleMsg, contains('第0240步'));
      expect(longSampleMsg.length, greaterThan(PromptLimits.styleChapterCap));
      expect(longSampleMsg.length, greaterThan(5000));
    });

    test('S4 rewrite uses jsonMode, low reasoningEffort, and prompt cache control', () async {
      final source = _buildLongChapterSource(targetBodyChars: 1200);
      // Intentional 8-gram overlap with source text to trigger S4 rewrite
      final client = _FakeRecordingLLMClient((_, callIdx) {
        if (callIdx == 0) return _sampleAnalysisJson();
        if (callIdx == 1) {
          return _sampleCardJson(styled: '第0001步雨水打湿青石阶，风穿过旧巷。');
        }
        return jsonEncode([
          {
            'index': 0,
            'styled': '雨丝斜落石梯，风声掠过门檐。',
            'principle': '重写避开原文词串',
          },
        ]);
      });

      final service = StyleDistillationService(
        client: client,
        library: library,
      );
      await service
          .distill(sourceText: source, sourceNote: '查重测试')
          .drain<void>();

      expect(client.calls, hasLength(3));
      final s4 = client.calls[2];
      expect(s4.messages[0].cacheControl, isTrue);
      expect(s4.config.jsonMode, isTrue);
      expect(s4.config.reasoningEffort, ReasoningEffort.low);
      expect(s4.config.enablePromptCacheControl, isTrue);
    });

    test('StyleEvaluator passes cacheControl and expected GenerationConfig', () async {
      final client = _FakeRecordingLLMClient((_, callIdx) {
        if (callIdx == 0) {
          return jsonEncode({
            'overall': 8,
            'scores': [
              {'dimension': '叙事视角', 'score': 8, 'note': '稳定'},
            ],
            'drifts': <String>[],
            'ai_flavor': <String>[],
            'moves': ['压短对话标签'],
          });
        }
        return '改写后的完整正文。';
      });

      final evaluator = StyleEvaluator(
        client: client,
        library: library,
        providerExtra: '评估附加规则',
      );
      final evalRes = await evaluator.evaluate(
        draft: '测试草稿正文。',
        evalCard: '测试风格卡',
        localReport: '',
      );
      final fixed = await evaluator.applyFixes(
        draft: '测试草稿正文。',
        evalResult: evalRes,
        evalCard: '测试风格卡',
        maxTokens: 4096,
      );

      expect(fixed, '改写后的完整正文。');
      expect(client.calls, hasLength(2));

      final evalCall = client.calls[0];
      expect(evalCall.messages[0].cacheControl, isTrue);
      expect(evalCall.messages[0].content, contains('评估附加规则'));
      expect(evalCall.config.jsonMode, isTrue);
      expect(evalCall.config.reasoningEffort, ReasoningEffort.medium);
      expect(evalCall.config.enablePromptCacheControl, isTrue);

      final fixCall = client.calls[1];
      expect(fixCall.messages[0].cacheControl, isTrue);
      expect(fixCall.config.jsonMode, isFalse);
      expect(fixCall.config.enablePromptCacheControl, isTrue);
      expect(fixCall.config.maxTokens, 4096);
    });
  });
}
