import '../../core/prompts/prompt_limits.dart';
import '../models/style_models.dart';

enum StyleCardVariant { writing, outline, antiAI, eval }

/// 文风卡按消费场景贪心裁剪渲染（4K / 1.5K / 2K / 5K 预算）
abstract final class StyleCardRenderer {
  static String render(StyleProfileData profile, StyleCardVariant variant) {
    final budget = switch (variant) {
      StyleCardVariant.writing => PromptLimits.styleProfileCap,
      StyleCardVariant.outline => PromptLimits.styleProfileOutlineCap,
      StyleCardVariant.antiAI => PromptLimits.styleProfileAntiAICap,
      StyleCardVariant.eval => PromptLimits.styleProfileEvalCap,
    };

    final sections = <String>[];
    switch (variant) {
      case StyleCardVariant.writing:
        sections.add('【文风档案：${profile.name}】（与上方【风格约束】冲突时，以风格约束为准）');
        if (profile.fingerprintSummary.isNotEmpty) {
          sections.add('风格指纹：${profile.fingerprintSummary}');
        }
        final m = profile.localMetrics;
        if (m.sentenceCount > 0) {
          final med = m.medianSentenceLength.round();
          final dlgPct = (m.dialogueLineRatio * 100).round();
          sections.add(
            '实测节奏区间：中位句长约 $med 字（建议控制在 ${(med - 3).clamp(6, 40)}~${(med + 4).clamp(10, 50)} 字），'
            '对话行占比约 $dlgPct%；请保持自然呼吸感，严禁为追求短句强行写碎成电报体。',
          );
        }
        // 聚焦 Top 7 最具辨识度的核心规则，避免 15+ 条细碎禁令过度规训压扁语感
        _appendNumbered('核心风格规则', profile.mustRules.take(7).toList(), sections);
        final layers = _layerLines(profile);
        if (layers != null) sections.add(layers);
        final dedupAvoid = <String>[];
        for (final r in [...profile.avoidRules, ...profile.antiAI.forbiddenPatterns]) {
          final t = r.trim();
          if (t.isNotEmpty && !dedupAvoid.contains(t)) dedupAvoid.add(t);
          if (dedupAvoid.length >= 8) break;
        }
        _appendNumbered('绝对禁止', dedupAvoid, sections);
        _appendExamples(profile.examples, sections);
      case StyleCardVariant.outline:
        sections.add('【文风档案：${profile.name}】');
        if (profile.tags.isNotEmpty) {
          sections.add('基调：${profile.tags.join('、')}');
        }
        final lines = <String>[
          if ((profile.narrativeVoice.pov ?? '').isNotEmpty)
            '视角：${profile.narrativeVoice.pov}',
          if ((profile.narrativeVoice.distance ?? '').isNotEmpty)
            '叙事距离：${profile.narrativeVoice.distance}',
          if ((profile.sceneRhythm.openings ?? '').isNotEmpty)
            '开场习惯：${profile.sceneRhythm.openings}',
          if ((profile.sceneRhythm.closings ?? '').isNotEmpty)
            '收束习惯：${profile.sceneRhythm.closings}',
          if ((profile.dialogue.subtextLevel ?? '').isNotEmpty)
            '对白：${profile.dialogue.subtextLevel}',
        ];
        if (lines.isNotEmpty) sections.add(lines.join('\n'));
      case StyleCardVariant.antiAI:
        sections.add('【文风档案：${profile.name} · 去AI味专项】');
        _appendNumbered('禁止模式', profile.antiAI.forbiddenPatterns, sections);
        _appendNumbered('自检清单', profile.antiAI.revisionChecks, sections);
        _appendNumbered('该文风禁用套话', profile.diction.bannedMoves, sections);
      case StyleCardVariant.eval:
        sections.add('【文风档案：${profile.name} · 风格体检基准】');
        if (profile.fingerprintSummary.isNotEmpty) {
          sections.add('风格指纹：${profile.fingerprintSummary}');
        }
        _appendNumbered('必遵规则', profile.mustRules, sections);
        final layers = _layerLines(profile);
        if (layers != null) sections.add(layers);
        _appendNumbered('自检清单', profile.antiAI.revisionChecks, sections);
        _appendNumbered(
          '绝对禁止',
          [...profile.avoidRules, ...profile.antiAI.forbiddenPatterns],
          sections,
        );
        _appendExamples(profile.examples, sections);
    }

    var out = '';
    for (final sec in sections) {
      final candidate = out.isEmpty ? sec : '$out\n$sec';
      if (candidate.length > budget) break;
      out = candidate;
    }
    return out;
  }

  static void _appendNumbered(
    String title,
    List<String> items,
    List<String> out,
  ) {
    final valid = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (valid.isEmpty) return;
    final numbered = [
      for (var i = 0; i < valid.length; i++) '${i + 1}. ${valid[i]}',
    ].join('\n');
    out.add('$title：\n$numbered');
  }

  static void _appendExamples(List<StyleExample> examples, List<String> out) {
    final lines = examples
        .take(3)
        .where((e) => e.plain.isNotEmpty && e.styled.isNotEmpty)
        .map((e) => '普通：「${e.plain}」→ 该文风：「${e.styled}」')
        .toList();
    if (lines.isNotEmpty) out.add('示范对照：\n${lines.join('\n')}');
  }

  static String? _layerLines(StyleProfileData p) {
    final lines = <String>[
      if ((p.narrativeVoice.temperature ?? '').isNotEmpty)
        '语气温度：${p.narrativeVoice.temperature}',
      if ((p.narrativeVoice.distance ?? '').isNotEmpty)
        '叙事距离：${p.narrativeVoice.distance}',
      if ((p.narrativeVoice.interiority ?? '').isNotEmpty)
        '内心戏：${p.narrativeVoice.interiority}',
      if ((p.sentenceSyntax.shape ?? '').isNotEmpty)
        '主导句型：${p.sentenceSyntax.shape}',
      if ((p.sentenceSyntax.longShortRatio ?? '').isNotEmpty)
        '长短句：${p.sentenceSyntax.longShortRatio}',
      if ((p.sentenceSyntax.punctuationRhythm ?? '').isNotEmpty)
        '标点节奏：${p.sentenceSyntax.punctuationRhythm}',
      if (p.sentenceSyntax.signatureMoves.isNotEmpty)
        '招牌句式：${p.sentenceSyntax.signatureMoves.join('；')}',
      if ((p.diction.register ?? '').isNotEmpty) '语域：${p.diction.register}',
      if (p.diction.lexicalFields.isNotEmpty)
        '词汇场：${p.diction.lexicalFields.join('、')}',
      if ((p.diction.sensoryWeights ?? '').isNotEmpty)
        '五感：${p.diction.sensoryWeights}',
      if ((p.sceneRhythm.actInnerEnvRatio ?? '').isNotEmpty)
        '动作/内心/环境：${p.sceneRhythm.actInnerEnvRatio}',
      if ((p.sceneRhythm.transitions ?? '').isNotEmpty)
        '转场：${p.sceneRhythm.transitions}',
      if ((p.dialogue.lineLength ?? '').isNotEmpty)
        '对白密度：${p.dialogue.lineLength}',
      if ((p.dialogue.tagHabits ?? '').isNotEmpty)
        '说话标签：${p.dialogue.tagHabits}',
      if ((p.emotion.directness ?? '').isNotEmpty)
        '情绪处理：${p.emotion.directness}',
      if (p.emotion.preferredCarriers.isNotEmpty)
        '情绪载体：${p.emotion.preferredCarriers.join('、')}',
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }
}

/// 增量蒸馏合并（新值非空覆盖并记入 corrections 上限 50 条；集合字段并集去重）
abstract final class StyleProfileAugment {
  static const int maxCorrections = 50;

  static void merge({
    required StyleProfileData existing,
    required StyleProfileData fresh,
    required String reason,
  }) {
    final added = <StyleCorrection>[];

    String? pickField(String field, String? oldVal, String? newVal) {
      final o = (oldVal ?? '').trim();
      final n = (newVal ?? '').trim();
      if (n.isEmpty) return oldVal;
      if (n != o) {
        added.add(
          StyleCorrection(
            layer: 'augment',
            field: field,
            before: o,
            after: n,
            reason: reason,
          ),
        );
      }
      return newVal;
    }

    existing.narrativeVoice.pov = pickField(
      'narrativeVoice.pov',
      existing.narrativeVoice.pov,
      fresh.narrativeVoice.pov,
    );
    existing.narrativeVoice.distance = pickField(
      'narrativeVoice.distance',
      existing.narrativeVoice.distance,
      fresh.narrativeVoice.distance,
    );
    existing.narrativeVoice.temperature = pickField(
      'narrativeVoice.temperature',
      existing.narrativeVoice.temperature,
      fresh.narrativeVoice.temperature,
    );
    existing.narrativeVoice.interiority = pickField(
      'narrativeVoice.interiority',
      existing.narrativeVoice.interiority,
      fresh.narrativeVoice.interiority,
    );
    existing.narrativeVoice.cameraHabits = _union(
      existing.narrativeVoice.cameraHabits,
      fresh.narrativeVoice.cameraHabits,
    );

    existing.sentenceSyntax.shape = pickField(
      'sentenceSyntax.shape',
      existing.sentenceSyntax.shape,
      fresh.sentenceSyntax.shape,
    );
    existing.sentenceSyntax.longShortRatio = pickField(
      'sentenceSyntax.longShortRatio',
      existing.sentenceSyntax.longShortRatio,
      fresh.sentenceSyntax.longShortRatio,
    );
    existing.sentenceSyntax.punctuationRhythm = pickField(
      'sentenceSyntax.punctuationRhythm',
      existing.sentenceSyntax.punctuationRhythm,
      fresh.sentenceSyntax.punctuationRhythm,
    );
    existing.sentenceSyntax.paragraphCadence = pickField(
      'sentenceSyntax.paragraphCadence',
      existing.sentenceSyntax.paragraphCadence,
      fresh.sentenceSyntax.paragraphCadence,
    );
    existing.sentenceSyntax.signatureMoves = _union(
      existing.sentenceSyntax.signatureMoves,
      fresh.sentenceSyntax.signatureMoves,
    );

    existing.diction.register = pickField(
      'diction.register',
      existing.diction.register,
      fresh.diction.register,
    );
    existing.diction.sensoryWeights = pickField(
      'diction.sensoryWeights',
      existing.diction.sensoryWeights,
      fresh.diction.sensoryWeights,
    );
    existing.diction.lexicalFields = _union(
      existing.diction.lexicalFields,
      fresh.diction.lexicalFields,
    );
    existing.diction.verbHabits = _union(
      existing.diction.verbHabits,
      fresh.diction.verbHabits,
    );
    existing.diction.imageSystems = _union(
      existing.diction.imageSystems,
      fresh.diction.imageSystems,
    );
    existing.diction.bannedMoves = _union(
      existing.diction.bannedMoves,
      fresh.diction.bannedMoves,
    );

    existing.sceneRhythm.openings = pickField(
      'sceneRhythm.openings',
      existing.sceneRhythm.openings,
      fresh.sceneRhythm.openings,
    );
    existing.sceneRhythm.closings = pickField(
      'sceneRhythm.closings',
      existing.sceneRhythm.closings,
      fresh.sceneRhythm.closings,
    );
    existing.sceneRhythm.actInnerEnvRatio = pickField(
      'sceneRhythm.actInnerEnvRatio',
      existing.sceneRhythm.actInnerEnvRatio,
      fresh.sceneRhythm.actInnerEnvRatio,
    );
    existing.sceneRhythm.transitions = pickField(
      'sceneRhythm.transitions',
      existing.sceneRhythm.transitions,
      fresh.sceneRhythm.transitions,
    );

    existing.dialogue.lineLength = pickField(
      'dialogue.lineLength',
      existing.dialogue.lineLength,
      fresh.dialogue.lineLength,
    );
    existing.dialogue.subtextLevel = pickField(
      'dialogue.subtextLevel',
      existing.dialogue.subtextLevel,
      fresh.dialogue.subtextLevel,
    );
    existing.dialogue.tagHabits = pickField(
      'dialogue.tagHabits',
      existing.dialogue.tagHabits,
      fresh.dialogue.tagHabits,
    );
    existing.dialogue.silenceAndGesture = pickField(
      'dialogue.silenceAndGesture',
      existing.dialogue.silenceAndGesture,
      fresh.dialogue.silenceAndGesture,
    );

    existing.emotion.directness = pickField(
      'emotion.directness',
      existing.emotion.directness,
      fresh.emotion.directness,
    );
    existing.emotion.intensityCurve = pickField(
      'emotion.intensityCurve',
      existing.emotion.intensityCurve,
      fresh.emotion.intensityCurve,
    );
    existing.emotion.preferredCarriers = _union(
      existing.emotion.preferredCarriers,
      fresh.emotion.preferredCarriers,
    );
    existing.emotion.avoidMoves = _union(
      existing.emotion.avoidMoves,
      fresh.emotion.avoidMoves,
    );

    existing.antiAI.forbiddenPatterns = _union(
      existing.antiAI.forbiddenPatterns,
      fresh.antiAI.forbiddenPatterns,
    );
    existing.antiAI.revisionChecks = _union(
      existing.antiAI.revisionChecks,
      fresh.antiAI.revisionChecks,
    );

    existing.fingerprintSummary =
        pickField(
          'fingerprintSummary',
          existing.fingerprintSummary,
          fresh.fingerprintSummary,
        ) ??
        existing.fingerprintSummary;
    existing.tags = _union(existing.tags, fresh.tags, cap: 8);
    existing.mustRules = _union(existing.mustRules, fresh.mustRules, cap: 15);
    existing.avoidRules = _union(existing.avoidRules, fresh.avoidRules, cap: 8);

    existing.examples = fresh.examples;
    existing.evidence = fresh.evidence;
    existing.localMetrics = fresh.localMetrics;
    existing.sampleCharCount += fresh.sampleCharCount;

    final mergedLogs = [...existing.corrections, ...added];
    existing.corrections = mergedLogs.length > maxCorrections
        ? mergedLogs.sublist(mergedLogs.length - maxCorrections)
        : mergedLogs;
    existing.updatedAt = DateTime.now();
  }

  static List<String> _union(List<String> a, List<String> b, {int cap = 0}) {
    final seen = <String>{};
    final out = <String>[];
    for (final list in [a, b]) {
      for (final raw in list) {
        final t = raw.trim();
        if (t.isEmpty || !seen.add(t)) continue;
        out.add(t);
        if (cap > 0 && out.length >= cap) return out;
      }
    }
    return out;
  }
}

class StyleFusionChoices {
  const StyleFusionChoices({
    required this.voiceId,
    required this.syntaxId,
    required this.dictionId,
    required this.rhythmId,
    required this.dialogueId,
    required this.emotionId,
  });

  final String voiceId;
  final String syntaxId;
  final String dictionId;
  final String rhythmId;
  final String dialogueId;
  final String emotionId;
}

/// 多档案按六层融合
abstract final class StyleFusion {
  static StyleProfileData? fuse({
    required String name,
    required StyleProfileData base,
    required List<StyleProfileData> participants,
    required StyleFusionChoices choices,
  }) {
    if (participants.isEmpty || !participants.any((p) => p.id == base.id)) {
      return null;
    }
    StyleProfileData? find(String id) =>
        participants.where((p) => p.id == id).firstOrNull;

    final voice = find(choices.voiceId);
    final syntax = find(choices.syntaxId);
    final diction = find(choices.dictionId);
    final rhythm = find(choices.rhythmId);
    final dialogue = find(choices.dialogueId);
    final emotion = find(choices.emotionId);
    if (voice == null ||
        syntax == null ||
        diction == null ||
        rhythm == null ||
        dialogue == null ||
        emotion == null) {
      return null;
    }

    List<String> unionAll(Iterable<List<String>> lists, {int cap = 0}) {
      final seen = <String>{};
      final out = <String>[];
      for (final list in lists) {
        for (final item in list) {
          final t = item.trim();
          if (t.isEmpty || !seen.add(t)) continue;
          out.add(t);
          if (cap > 0 && out.length >= cap) return out;
        }
      }
      return out;
    }

    final clippedName = name.trim().length > 20
        ? name.trim().substring(0, 20)
        : name.trim();
    final fused = StyleProfileData(
      name: clippedName.isEmpty ? '融合文风' : clippedName,
      sourceNote: '融合自 ${participants.length} 份档案',
      confidence: 'low',
      fingerprintSummary: base.fingerprintSummary,
      tags: unionAll(participants.map((p) => p.tags), cap: 8),
      mustRules: unionAll(participants.map((p) => p.mustRules), cap: 15),
      avoidRules: unionAll(participants.map((p) => p.avoidRules), cap: 8),
      examples: base.deepCopy().examples,
      narrativeVoice: voice.deepCopy().narrativeVoice,
      sentenceSyntax: syntax.deepCopy().sentenceSyntax,
      diction: diction.deepCopy().diction,
      sceneRhythm: rhythm.deepCopy().sceneRhythm,
      dialogue: dialogue.deepCopy().dialogue,
      emotion: emotion.deepCopy().emotion,
    );
    fused.antiAI.forbiddenPatterns = unionAll(
      participants.map((p) => p.antiAI.forbiddenPatterns),
    );
    fused.antiAI.revisionChecks = unionAll(
      participants.map((p) => p.antiAI.revisionChecks),
    );
    fused.diction.bannedMoves = unionAll(
      participants.map((p) => p.diction.bannedMoves),
    );
    return fused;
  }
}
