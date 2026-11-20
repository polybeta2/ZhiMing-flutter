import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/prompts/prompt_library.dart';
import 'package:zhiming/core/prompts/prompt_limits.dart';
import 'package:zhiming/core/utils/text_encoding.dart';
import 'package:zhiming/domain/models/style_models.dart';
import 'package:zhiming/domain/style/style_card_renderer.dart';
import 'package:zhiming/domain/style/style_chapter_sampler.dart';
import 'package:zhiming/domain/style/style_distillation_service.dart';
import 'package:zhiming/domain/style/style_metrics.dart';

class _ScriptedMockLLMClient implements LLMClient {
  _ScriptedMockLLMClient(this.replies);
  final List<String> replies;
  int _idx = 0;

  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    final reply = replies[_idx++];
    yield ContentDelta(reply);
  }

  @override
  Future<String> testConnection({CancelToken? cancelToken}) async => 'ok';

  @override
  Future<List<String>> fetchModelIds({CancelToken? cancelToken}) async => [];
}

void main() {
  group('TextEncoding', () {
    test('detects UTF-8 BOM, strict UTF-8 and GBK automatically', () {
      final utf8Bom = [0xEF, 0xBB, 0xBF, ...utf8.encode('第一章 雾起')];
      expect(
        TextEncoding.decodeBytes(Uint8List.fromList(utf8Bom)),
        '第一章 雾起',
      );
      final gbkBytes = gbk.encode('第1章 斗罗大陆，异界唐三');
      expect(
        TextEncoding.decodeBytes(Uint8List.fromList(gbkBytes)),
        '第1章 斗罗大陆，异界唐三',
      );
    });
  });

  group('StyleChapterSampler', () {
    test('parses Chinese numerals and drops spike false chapters', () {
      expect(StyleChapterSampler.parseChineseNumeral('一百二十三'), 123);
      expect(StyleChapterSampler.parseChineseNumeral('两千〇五'), 2005);

      const text = '''
第1章 启程
正文一
第2章 雾港
正文二
178
正文内混入页码
第3章 灯塔
正文三
第4章 密信
正文四
''';
      final chapters = StyleChapterSampler.split(text);
      expect(chapters.length, 4);
      expect(chapters.map((c) => c.number), [1, 2, 3, 4]);
      expect(chapters[2].body, contains('178'));
    });

    test('selectInitial & expand stay within maxChapters', () {
      final init = StyleChapterSampler.selectInitial(
        20,
        pickRandom: (_) => 0,
      );
      expect(init.length, StyleChapterSampler.initialCount);
      expect(init.first, 0);
      expect(init.last, 19);

      final expanded = StyleChapterSampler.expand(
        init,
        20,
        pickRandom: (_) => 0,
      );
      expect(expanded.length, 8);
    });
  });

  group('StyleMetrics & NgramIndex & CardRenderer', () {
    test('reusable NgramIndex catches 8-gram copy deterministically', () {
      const original = '雨点砸在窗棂上，远处的灯塔忽明忽暗，像一句尚未说完的旧约。';
      final index = StyleMetrics.ngramIndex(original, n: 8);
      expect(index.hasViolation('他望着窗外：远处的灯塔忽明忽暗，心中叹息'), isTrue);
      expect(index.hasViolation('清晨的阳光照进书房，桌上摆着一杯温热的红茶'), isFalse);
    });

    test('StyleCardRenderer respects each variant char budget', () {
      final p = StyleProfileData(
        name: '冷峻白描',
        fingerprintSummary: '短句为主，动词精准。',
        tags: ['冷峻', '白描'],
        mustRules: [for (var i = 0; i < 30; i++) '必遵规则条目$i：${'细节' * 40}'],
        avoidRules: ['禁止说明腔'],
      );
      final writing = StyleCardRenderer.render(p, StyleCardVariant.writing);
      final outline = StyleCardRenderer.render(p, StyleCardVariant.outline);
      expect(writing.length, lessThanOrEqualTo(PromptLimits.styleProfileCap));
      expect(
        outline.length,
        lessThanOrEqualTo(PromptLimits.styleProfileOutlineCap),
      );
    });
  });

  group('StyleProfileAugment & StyleFusion & Distillation Pipeline', () {
    test('Augment merges fields, records corrections & caps at 50', () {
      final a = StyleProfileData(
        name: 'A',
        narrativeVoice: StyleNarrativeVoice(pov: '第一人称'),
        tags: ['冷峻'],
      );
      final b = StyleProfileData(
        name: 'B',
        narrativeVoice: StyleNarrativeVoice(pov: '第三人称限知'),
        tags: ['冷峻', '克制'],
        sampleCharCount: 5000,
      );
      StyleProfileAugment.merge(existing: a, fresh: b, reason: '二轮样本');
      expect(a.narrativeVoice.pov, '第三人称限知');
      expect(a.tags, ['冷峻', '克制']);
      expect(a.corrections.single.field, 'narrativeVoice.pov');
    });

    test('StyleFusion combines layers from participants', () {
      final p1 = StyleProfileData(
        name: '冷峻',
        narrativeVoice: StyleNarrativeVoice(temperature: '冷峻'),
        tags: ['冷峻'],
      );
      final p2 = StyleProfileData(
        name: '温情',
        dialogue: StyleDialogue(subtextLevel: '高潜台词'),
        tags: ['温情'],
      );
      final fused = StyleFusion.fuse(
        name: '冷峻高潜台词',
        base: p1,
        participants: [p1, p2],
        choices: StyleFusionChoices(
          voiceId: p1.id,
          syntaxId: p1.id,
          dictionId: p1.id,
          rhythmId: p1.id,
          dialogueId: p2.id,
          emotionId: p1.id,
        ),
      );
      expect(fused, isNotNull);
      expect(fused!.confidence, 'low');
      expect(fused.narrativeVoice.temperature, '冷峻');
      expect(fused.dialogue.subtextLevel, '高潜台词');
      expect(fused.tags, ['冷峻', '温情']);
    });

    test('StyleDistillationService runs S1-S4 with violation rewrite', () async {
      final sample = '远处的灯塔忽明忽暗，沈屿放下火漆信封，雨水顺着帽檐滑落。' * 20;
      final mock = _ScriptedMockLLMClient([
        // S2 analysis
        '{"enough":true,"narrative_voice":{"pov":"第三人称"},"sentence_syntax":{"shape":"短句"},"diction":{"register":"书面"},"scene_rhythm":{},"dialogue":{},"emotion":{},"anti_ai":{"forbidden_patterns":["瞳孔骤缩"]}}',
        // S3 card (intentionally copies 8-gram from sample!)
        '{"name":"雾港白描","tags":["冷峻"],"fingerprint_summary":"克制白描","must_rules":["短句"],"avoid_rules":["说明腔"],"examples":[{"plain":"他很难过","styled":"远处的灯塔忽明忽暗，沈屿放下火漆信封","principle":"外化"}]}',
        // S4 rewrite clean
        '[{"index":0,"styled":"风卷起桌上旧报，他把烟蒂按进瓷盘。","principle":"外化"}]',
      ]);

      final service = StyleDistillationService(
        client: mock,
        library: const PromptLibraryState(),
      );
      StyleProfileData? done;
      await for (final ev in service.distill(
        sourceText: sample,
        sourceNote: '测试样章',
      )) {
        if (ev is StyleDistillCompleted) done = ev.profile;
      }
      expect(done, isNotNull);
      expect(done!.name, '雾港白描');
      expect(done.examples.single.styled, contains('瓷盘'));
    });
  });
}
