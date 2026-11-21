/// 提示词体量护栏常量（与原版 v2.12.4 严格对齐，统一审计与单测锁定）
abstract final class PromptLimits {
  static const int maxOverrideChars = 20000;
  static const int maxTagPresetChars = 20000;
  static const int matchedSupplementCap = 8000;
  static const int r18ModuleCharBudget = 12000;
  static const int requiredFieldCap = 4000;
  static const int historyMessageCap = 2000;
  static const int requestWarnChars = 80000;
  static const int foreshadowReminderChapterThreshold = 8;
  static const int foreshadowReminderCap = 2000;
  static const int foreshadowTextFieldCap = 2000;
  static const int styleProfileCap = 4000;
  static const int styleProfileOutlineCap = 1500;
  static const int styleProfileAntiAICap = 2000;
  static const int styleProfileEvalCap = 5000;
  static const int styleSampleCap = 40000;
  static const int styleChapterCap = 3000;
  static const int styleEvidenceCap = 80;
}

/// 31 套稳定内置提示词 ID 常量
abstract final class PromptID {
  static const String continueWriting = 'prompt.continue.system';
  static const String writing = 'prompt.writing.system';
  static const String rewrite = 'prompt.rewrite.system';
  static const String summarize = 'prompt.summarize.system';
  static const String factReview = 'prompt.fact.review.system';
  static const String creationClarify = 'prompt.creation.clarify.system';
  static const String creationStructure = 'prompt.creation.structure.system';
  static const String creationFoundation = 'prompt.creation.foundation.system';
  static const String creationVolumeBatch =
      'prompt.creation.volume.batch.system';
  static const String creationChapterBatch =
      'prompt.creation.chapter.batch.system';
  static const String creationRevise = 'prompt.creation.revise.system';
  static const String creationChapterNames =
      'prompt.creation.chapter.names.system';
  static const String writingAssistant = 'prompt.assistant.system';
  static const String assistantReadWrite = 'prompt.assistant.rw.protocol';
  static const String antiAIFlavor = 'prompt.antiai.system';
  static const String antiAIInline = 'prompt.antiai.inline.system';
  static const String volumeOutline = 'prompt.volume.outline.system';
  static const String chapterOutline = 'prompt.chapter.outline.system';
  static const String chapterBatchOutline =
      'prompt.chapter.batch.outline.system';
  static const String r18zh = 'prompt.r18.system.zh';
  static const String r18en = 'prompt.r18.system.en';
  static const String styleDistillAnalyze =
      'prompt.style.distill.analyze.system';
  static const String styleDistillCard = 'prompt.style.distill.card.system';
  static const String styleDistillFix = 'prompt.style.distill.fix.system';
  static const String styleEval = 'prompt.style.eval.system';
  static const String directorCinematic = 'prompt.director.cinematic';
  static const String directorPureSensory = 'prompt.director.sensory';
  static const String directorR18Gentle = 'prompt.director.r18.gentle';
  static const String directorR18Soothing = 'prompt.director.r18.soothing';
  static const String directorR18Intense = 'prompt.director.r18.intense';
  static const String directorR18Gate = 'prompt.director.r18.gate';
}

class BuiltInPrompt {
  const BuiltInPrompt({
    required this.id,
    required this.name,
    required this.category,
    required this.placeholders,
    required this.defaultText,
  });

  final String id;
  final String name;
  final String category;
  final List<String> placeholders;
  final String defaultText;
}

class PromptTag {
  const PromptTag({
    required this.id,
    required this.name,
    required this.keywords,
    required this.presetText,
  });

  final String id;
  final String name;
  final List<String> keywords;
  final String presetText;

  factory PromptTag.fromJson(Map<String, dynamic> json) => PromptTag(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    keywords: (json['keywords'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    presetText: json['presetText']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'keywords': keywords,
    'presetText': presetText,
  };

  PromptTag copyWith({
    String? id,
    String? name,
    List<String>? keywords,
    String? presetText,
  }) => PromptTag(
    id: id ?? this.id,
    name: name ?? this.name,
    keywords: keywords ?? this.keywords,
    presetText: presetText ?? this.presetText,
  );
}

class PromptTagCategory {
  const PromptTagCategory({
    required this.id,
    required this.name,
    required this.tags,
  });

  final String id;
  final String name;
  final List<PromptTag> tags;

  PromptTagCategory copyWith({String? name, List<PromptTag>? tags}) =>
      PromptTagCategory(id: id, name: name ?? this.name, tags: tags ?? this.tags);
}
