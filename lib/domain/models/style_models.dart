import 'dart:convert';

import 'package:uuid/uuid.dart';

/// 宽松数组解析（复刻原版 FlexStringArray：容忍数组/分隔字符串/缺失）
List<String> flexStringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw is String) {
    return raw
        .split(RegExp(r'[，、；;,\n\r]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return const [];
}

class StyleNarrativeVoice {
  StyleNarrativeVoice({
    this.pov,
    this.distance,
    this.temperature,
    this.interiority,
    List<String>? cameraHabits,
  }) : cameraHabits = cameraHabits ?? [];

  String? pov;
  String? distance;
  String? temperature;
  String? interiority;
  List<String> cameraHabits;

  factory StyleNarrativeVoice.fromJson(dynamic raw) {
    if (raw is! Map) return StyleNarrativeVoice();
    return StyleNarrativeVoice(
      pov: raw['pov']?.toString(),
      distance: raw['distance']?.toString(),
      temperature: raw['temperature']?.toString(),
      interiority: raw['interiority']?.toString(),
      cameraHabits: flexStringList(raw['camera_habits'] ?? raw['cameraHabits']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (pov != null) 'pov': pov,
    if (distance != null) 'distance': distance,
    if (temperature != null) 'temperature': temperature,
    if (interiority != null) 'interiority': interiority,
    'cameraHabits': cameraHabits,
  };
}

class StyleSentenceSyntax {
  StyleSentenceSyntax({
    this.shape,
    this.longShortRatio,
    this.punctuationRhythm,
    this.paragraphCadence,
    List<String>? signatureMoves,
  }) : signatureMoves = signatureMoves ?? [];

  String? shape;
  String? longShortRatio;
  String? punctuationRhythm;
  String? paragraphCadence;
  List<String> signatureMoves;

  factory StyleSentenceSyntax.fromJson(dynamic raw) {
    if (raw is! Map) return StyleSentenceSyntax();
    return StyleSentenceSyntax(
      shape: raw['shape']?.toString(),
      longShortRatio: (raw['long_short_ratio'] ?? raw['longShortRatio'])
          ?.toString(),
      punctuationRhythm:
          (raw['punctuation_rhythm'] ?? raw['punctuationRhythm'])?.toString(),
      paragraphCadence: (raw['paragraph_cadence'] ?? raw['paragraphCadence'])
          ?.toString(),
      signatureMoves: flexStringList(
        raw['signature_moves'] ?? raw['signatureMoves'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    if (shape != null) 'shape': shape,
    if (longShortRatio != null) 'longShortRatio': longShortRatio,
    if (punctuationRhythm != null) 'punctuationRhythm': punctuationRhythm,
    if (paragraphCadence != null) 'paragraphCadence': paragraphCadence,
    'signatureMoves': signatureMoves,
  };
}

class StyleDiction {
  StyleDiction({
    this.register,
    List<String>? lexicalFields,
    List<String>? verbHabits,
    List<String>? imageSystems,
    this.sensoryWeights,
    List<String>? bannedMoves,
  }) : lexicalFields = lexicalFields ?? [],
       verbHabits = verbHabits ?? [],
       imageSystems = imageSystems ?? [],
       bannedMoves = bannedMoves ?? [];

  String? register;
  List<String> lexicalFields;
  List<String> verbHabits;
  List<String> imageSystems;
  String? sensoryWeights;
  List<String> bannedMoves;

  factory StyleDiction.fromJson(dynamic raw) {
    if (raw is! Map) return StyleDiction();
    return StyleDiction(
      register: raw['register']?.toString(),
      lexicalFields: flexStringList(
        raw['lexical_fields'] ?? raw['lexicalFields'],
      ),
      verbHabits: flexStringList(raw['verb_habits'] ?? raw['verbHabits']),
      imageSystems: flexStringList(raw['image_systems'] ?? raw['imageSystems']),
      sensoryWeights: (raw['sensory_weights'] ?? raw['sensoryWeights'])
          ?.toString(),
      bannedMoves: flexStringList(raw['banned_moves'] ?? raw['bannedMoves']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (register != null) 'register': register,
    'lexicalFields': lexicalFields,
    'verbHabits': verbHabits,
    'imageSystems': imageSystems,
    if (sensoryWeights != null) 'sensoryWeights': sensoryWeights,
    'bannedMoves': bannedMoves,
  };
}

class StyleSceneRhythm {
  StyleSceneRhythm({
    this.openings,
    this.closings,
    this.actInnerEnvRatio,
    this.transitions,
  });

  String? openings;
  String? closings;
  String? actInnerEnvRatio;
  String? transitions;

  factory StyleSceneRhythm.fromJson(dynamic raw) {
    if (raw is! Map) return StyleSceneRhythm();
    return StyleSceneRhythm(
      openings: raw['openings']?.toString(),
      closings: raw['closings']?.toString(),
      actInnerEnvRatio:
          (raw['act_inner_env_ratio'] ?? raw['actInnerEnvRatio'])?.toString(),
      transitions: raw['transitions']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (openings != null) 'openings': openings,
    if (closings != null) 'closings': closings,
    if (actInnerEnvRatio != null) 'actInnerEnvRatio': actInnerEnvRatio,
    if (transitions != null) 'transitions': transitions,
  };
}

class StyleDialogue {
  StyleDialogue({
    this.lineLength,
    this.subtextLevel,
    this.tagHabits,
    this.silenceAndGesture,
  });

  String? lineLength;
  String? subtextLevel;
  String? tagHabits;
  String? silenceAndGesture;

  factory StyleDialogue.fromJson(dynamic raw) {
    if (raw is! Map) return StyleDialogue();
    return StyleDialogue(
      lineLength: (raw['line_length'] ?? raw['lineLength'])?.toString(),
      subtextLevel: (raw['subtext_level'] ?? raw['subtextLevel'])?.toString(),
      tagHabits: (raw['tag_habits'] ?? raw['tagHabits'])?.toString(),
      silenceAndGesture:
          (raw['silence_and_gesture'] ?? raw['silenceAndGesture'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (lineLength != null) 'lineLength': lineLength,
    if (subtextLevel != null) 'subtextLevel': subtextLevel,
    if (tagHabits != null) 'tagHabits': tagHabits,
    if (silenceAndGesture != null) 'silenceAndGesture': silenceAndGesture,
  };
}

class StyleEmotion {
  StyleEmotion({
    this.directness,
    List<String>? preferredCarriers,
    this.intensityCurve,
    List<String>? avoidMoves,
  }) : preferredCarriers = preferredCarriers ?? [],
       avoidMoves = avoidMoves ?? [];

  String? directness;
  List<String> preferredCarriers;
  String? intensityCurve;
  List<String> avoidMoves;

  factory StyleEmotion.fromJson(dynamic raw) {
    if (raw is! Map) return StyleEmotion();
    return StyleEmotion(
      directness: raw['directness']?.toString(),
      preferredCarriers: flexStringList(
        raw['preferred_carriers'] ?? raw['preferredCarriers'],
      ),
      intensityCurve: (raw['intensity_curve'] ?? raw['intensityCurve'])
          ?.toString(),
      avoidMoves: flexStringList(raw['avoid_moves'] ?? raw['avoidMoves']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (directness != null) 'directness': directness,
    'preferredCarriers': preferredCarriers,
    if (intensityCurve != null) 'intensityCurve': intensityCurve,
    'avoidMoves': avoidMoves,
  };
}

class StyleAntiAI {
  StyleAntiAI({List<String>? forbiddenPatterns, List<String>? revisionChecks})
    : forbiddenPatterns = forbiddenPatterns ?? [],
      revisionChecks = revisionChecks ?? [];

  List<String> forbiddenPatterns;
  List<String> revisionChecks;

  factory StyleAntiAI.fromJson(dynamic raw) {
    if (raw is! Map) return StyleAntiAI();
    return StyleAntiAI(
      forbiddenPatterns: flexStringList(
        raw['forbidden_patterns'] ?? raw['forbiddenPatterns'],
      ),
      revisionChecks: flexStringList(
        raw['revision_checks'] ?? raw['revisionChecks'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'forbiddenPatterns': forbiddenPatterns,
    'revisionChecks': revisionChecks,
  };
}

class StyleExample {
  StyleExample({
    String? id,
    required this.plain,
    required this.styled,
    this.principle = '',
  }) : id = id ?? const Uuid().v4();

  final String id;
  String plain;
  String styled;
  String principle;

  factory StyleExample.fromJson(dynamic raw) {
    if (raw is! Map) return StyleExample(plain: '', styled: '');
    return StyleExample(
      id: raw['id']?.toString(),
      plain: raw['plain']?.toString() ?? '',
      styled: raw['styled']?.toString() ?? '',
      principle: raw['principle']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plain': plain,
    'styled': styled,
    'principle': principle,
  };
}

class StyleEvidence {
  StyleEvidence({
    required this.trait,
    required this.snippet,
    this.confidence = 'medium',
  });

  final String trait;
  final String snippet;
  final String confidence;

  factory StyleEvidence.fromJson(dynamic raw) {
    if (raw is! Map) return StyleEvidence(trait: '', snippet: '');
    return StyleEvidence(
      trait: raw['trait']?.toString() ?? '',
      snippet: raw['snippet']?.toString() ?? '',
      confidence: raw['confidence']?.toString() ?? 'medium',
    );
  }

  Map<String, dynamic> toJson() => {
    'trait': trait,
    'snippet': snippet,
    'confidence': confidence,
  };
}

class StyleCorrection {
  StyleCorrection({
    required this.layer,
    required this.field,
    required this.before,
    required this.after,
    required this.reason,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String layer;
  final String field;
  final String before;
  final String after;
  final String reason;
  final DateTime at;

  factory StyleCorrection.fromJson(dynamic raw) {
    if (raw is! Map) {
      return StyleCorrection(
        layer: '',
        field: '',
        before: '',
        after: '',
        reason: '',
      );
    }
    return StyleCorrection(
      layer: raw['layer']?.toString() ?? 'augment',
      field: raw['field']?.toString() ?? '',
      before: raw['before']?.toString() ?? '',
      after: raw['after']?.toString() ?? '',
      reason: raw['reason']?.toString() ?? '',
      at: DateTime.tryParse(raw['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'layer': layer,
    'field': field,
    'before': before,
    'after': after,
    'reason': reason,
    'at': at.toIso8601String(),
  };
}

class StyleMetricsSnapshot {
  const StyleMetricsSnapshot({
    this.sampleCharCount = 0,
    this.sentenceCount = 0,
    this.medianSentenceLength = 0,
    this.shortSentenceRatio = 0,
    this.longSentenceRatio = 0,
    this.alternationRate = 0,
    this.dialogueLineRatio = 0,
    this.dashPer1k = 0,
    this.ellipsisPer1k = 0,
    this.exclamationPer1k = 0,
    this.questionPer1k = 0,
  });

  final int sampleCharCount;
  final int sentenceCount;
  final double medianSentenceLength;
  final double shortSentenceRatio;
  final double longSentenceRatio;
  final double alternationRate;
  final double dialogueLineRatio;
  final double dashPer1k;
  final double ellipsisPer1k;
  final double exclamationPer1k;
  final double questionPer1k;

  String toPromptText() =>
      '样本字数：$sampleCharCount，句数：$sentenceCount，句长中位数：${medianSentenceLength.toStringAsFixed(1)} 字；'
      '短句（≤10字）占比：${(shortSentenceRatio * 100).toStringAsFixed(1)}%，'
      '长句（≥25字）占比：${(longSentenceRatio * 100).toStringAsFixed(1)}%，'
      '长短句交替率：${(alternationRate * 100).toStringAsFixed(1)}%，'
      '对话行占比：${(dialogueLineRatio * 100).toStringAsFixed(1)}%；'
      '每千字破折号 ${dashPer1k.toStringAsFixed(2)}、省略号 ${ellipsisPer1k.toStringAsFixed(2)}、'
      '感叹号 ${exclamationPer1k.toStringAsFixed(2)}、问号 ${questionPer1k.toStringAsFixed(2)}。';

  factory StyleMetricsSnapshot.fromJson(dynamic raw) {
    if (raw is! Map) return const StyleMetricsSnapshot();
    double d(String k) => (raw[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (raw[k] as num?)?.toInt() ?? 0;
    return StyleMetricsSnapshot(
      sampleCharCount: i('sampleCharCount'),
      sentenceCount: i('sentenceCount'),
      medianSentenceLength: d('medianSentenceLength'),
      shortSentenceRatio: d('shortSentenceRatio'),
      longSentenceRatio: d('longSentenceRatio'),
      alternationRate: d('alternationRate'),
      dialogueLineRatio: d('dialogueLineRatio'),
      dashPer1k: d('dashPer1k'),
      ellipsisPer1k: d('ellipsisPer1k'),
      exclamationPer1k: d('exclamationPer1k'),
      questionPer1k: d('questionPer1k'),
    );
  }

  Map<String, dynamic> toJson() => {
    'sampleCharCount': sampleCharCount,
    'sentenceCount': sentenceCount,
    'medianSentenceLength': medianSentenceLength,
    'shortSentenceRatio': shortSentenceRatio,
    'longSentenceRatio': longSentenceRatio,
    'alternationRate': alternationRate,
    'dialogueLineRatio': dialogueLineRatio,
    'dashPer1k': dashPer1k,
    'ellipsisPer1k': ellipsisPer1k,
    'exclamationPer1k': exclamationPer1k,
    'questionPer1k': questionPer1k,
  };
}

/// 完整七层文风档案领域模型
class StyleProfileData {
  StyleProfileData({
    String? id,
    required this.name,
    this.sourceNote = '',
    this.sampleCharCount = 0,
    this.confidence = 'medium',
    this.fingerprintSummary = '',
    List<String>? tags,
    List<String>? mustRules,
    List<String>? avoidRules,
    List<StyleExample>? examples,
    List<StyleEvidence>? evidence,
    List<StyleCorrection>? corrections,
    StyleNarrativeVoice? narrativeVoice,
    StyleSentenceSyntax? sentenceSyntax,
    StyleDiction? diction,
    StyleSceneRhythm? sceneRhythm,
    StyleDialogue? dialogue,
    StyleEmotion? emotion,
    StyleAntiAI? antiAI,
    this.localMetrics = const StyleMetricsSnapshot(),
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       tags = tags ?? [],
       mustRules = mustRules ?? [],
       avoidRules = avoidRules ?? [],
       examples = examples ?? [],
       evidence = evidence ?? [],
       corrections = corrections ?? [],
       narrativeVoice = narrativeVoice ?? StyleNarrativeVoice(),
       sentenceSyntax = sentenceSyntax ?? StyleSentenceSyntax(),
       diction = diction ?? StyleDiction(),
       sceneRhythm = sceneRhythm ?? StyleSceneRhythm(),
       dialogue = dialogue ?? StyleDialogue(),
       emotion = emotion ?? StyleEmotion(),
       antiAI = antiAI ?? StyleAntiAI(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String sourceNote;
  int sampleCharCount;
  String confidence;
  String fingerprintSummary;
  List<String> tags;
  List<String> mustRules;
  List<String> avoidRules;
  List<StyleExample> examples;
  List<StyleEvidence> evidence;
  List<StyleCorrection> corrections;
  StyleNarrativeVoice narrativeVoice;
  StyleSentenceSyntax sentenceSyntax;
  StyleDiction diction;
  StyleSceneRhythm sceneRhythm;
  StyleDialogue dialogue;
  StyleEmotion emotion;
  StyleAntiAI antiAI;
  StyleMetricsSnapshot localMetrics;
  DateTime updatedAt;

  StyleProfileData deepCopy() =>
      StyleProfileData.fromJson(jsonDecode(jsonEncode(toJson())));

  factory StyleProfileData.fromJson(dynamic raw) {
    if (raw is! Map) return StyleProfileData(name: '未命名文风');
    return StyleProfileData(
      id: raw['id']?.toString(),
      name: raw['name']?.toString() ?? '未命名文风',
      sourceNote: raw['sourceNote']?.toString() ?? '',
      sampleCharCount: (raw['sampleCharCount'] as num?)?.toInt() ?? 0,
      confidence: raw['confidence']?.toString() ?? 'medium',
      fingerprintSummary: raw['fingerprintSummary']?.toString() ?? '',
      tags: flexStringList(raw['tags']),
      mustRules: flexStringList(raw['mustRules']),
      avoidRules: flexStringList(raw['avoidRules']),
      examples: raw['examples'] is List
          ? (raw['examples'] as List).map(StyleExample.fromJson).toList()
          : [],
      evidence: raw['evidence'] is List
          ? (raw['evidence'] as List).map(StyleEvidence.fromJson).toList()
          : [],
      corrections: raw['corrections'] is List
          ? (raw['corrections'] as List).map(StyleCorrection.fromJson).toList()
          : [],
      narrativeVoice: StyleNarrativeVoice.fromJson(raw['narrativeVoice']),
      sentenceSyntax: StyleSentenceSyntax.fromJson(raw['sentenceSyntax']),
      diction: StyleDiction.fromJson(raw['diction']),
      sceneRhythm: StyleSceneRhythm.fromJson(raw['sceneRhythm']),
      dialogue: StyleDialogue.fromJson(raw['dialogue']),
      emotion: StyleEmotion.fromJson(raw['emotion']),
      antiAI: StyleAntiAI.fromJson(raw['antiAI']),
      localMetrics: StyleMetricsSnapshot.fromJson(raw['localMetrics']),
      updatedAt:
          DateTime.tryParse(raw['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sourceNote': sourceNote,
    'sampleCharCount': sampleCharCount,
    'confidence': confidence,
    'fingerprintSummary': fingerprintSummary,
    'tags': tags,
    'mustRules': mustRules,
    'avoidRules': avoidRules,
    'examples': [for (final e in examples) e.toJson()],
    'evidence': [for (final e in evidence) e.toJson()],
    'corrections': [for (final c in corrections) c.toJson()],
    'narrativeVoice': narrativeVoice.toJson(),
    'sentenceSyntax': sentenceSyntax.toJson(),
    'diction': diction.toJson(),
    'sceneRhythm': sceneRhythm.toJson(),
    'dialogue': dialogue.toJson(),
    'emotion': emotion.toJson(),
    'antiAI': antiAI.toJson(),
    'localMetrics': localMetrics.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());
}

class StyleEvalScore {
  const StyleEvalScore({
    required this.dimension,
    required this.score,
    required this.note,
  });

  final String dimension;
  final int score;
  final String note;

  factory StyleEvalScore.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const StyleEvalScore(dimension: '未知维度', score: 0, note: '');
    }
    return StyleEvalScore(
      dimension: raw['dimension']?.toString() ?? '未知维度',
      score: (raw['score'] as num?)?.toInt() ?? 0,
      note: raw['note']?.toString() ?? '',
    );
  }
}

class StyleEvalResult {
  const StyleEvalResult({
    required this.overall,
    required this.scores,
    required this.drifts,
    required this.aiFlavor,
    required this.moves,
  });

  final int overall;
  final List<StyleEvalScore> scores;
  final List<String> drifts;
  final List<String> aiFlavor;
  final List<String> moves;

  factory StyleEvalResult.fromJson(Map<String, dynamic> json) => StyleEvalResult(
    overall: (json['overall'] as num?)?.toInt() ?? 0,
    scores: json['scores'] is List
        ? (json['scores'] as List).map(StyleEvalScore.fromJson).toList()
        : const [],
    drifts: flexStringList(json['drifts']),
    aiFlavor: flexStringList(json['ai_flavor'] ?? json['aiFlavor']),
    moves: flexStringList(json['moves']),
  );
}
