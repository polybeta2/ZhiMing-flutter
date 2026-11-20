import 'dart:convert';

import 'novel_domain.dart';

/// 蓝图与分阶段立项数据结构（完整保留 v2.1.2 字符串容错与缺键容错）
class BlueprintCharacter {
  BlueprintCharacter({
    this.name,
    this.role,
    this.appearance,
    this.personality,
    this.goal,
  });

  String? name;
  String? role;
  String? appearance;
  String? personality;
  String? goal;

  factory BlueprintCharacter.fromJson(dynamic raw) {
    if (raw is String) return BlueprintCharacter(name: raw.trim());
    if (raw is Map) {
      return BlueprintCharacter(
        name: raw['name']?.toString(),
        role: raw['role']?.toString(),
        appearance: raw['appearance']?.toString(),
        personality: raw['personality']?.toString(),
        goal: raw['goal']?.toString(),
      );
    }
    return BlueprintCharacter();
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (role != null) 'role': role,
    if (appearance != null) 'appearance': appearance,
    if (personality != null) 'personality': personality,
    if (goal != null) 'goal': goal,
  };
}

class BlueprintWorld {
  BlueprintWorld({this.category, this.name, this.content});

  String? category;
  String? name;
  String? content;

  factory BlueprintWorld.fromJson(dynamic raw) {
    if (raw is String) return BlueprintWorld(name: raw.trim());
    if (raw is Map) {
      return BlueprintWorld(
        category: raw['category']?.toString(),
        name: raw['name']?.toString(),
        content: raw['content']?.toString(),
      );
    }
    return BlueprintWorld();
  }

  Map<String, dynamic> toJson() => {
    if (category != null) 'category': category,
    if (name != null) 'name': name,
    if (content != null) 'content': content,
  };
}

class BlueprintForeshadow {
  BlueprintForeshadow({this.title, this.detail, this.revealIn});

  String? title;
  String? detail;
  String? revealIn;

  factory BlueprintForeshadow.fromJson(dynamic raw) {
    if (raw is String) return BlueprintForeshadow(title: raw.trim());
    if (raw is Map) {
      return BlueprintForeshadow(
        title: raw['title']?.toString(),
        detail: raw['detail']?.toString(),
        revealIn: (raw['reveal_in'] ?? raw['revealIn'])?.toString(),
      );
    }
    return BlueprintForeshadow();
  }

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    if (detail != null) 'detail': detail,
    if (revealIn != null) 'reveal_in': revealIn,
  };
}

class BlueprintChapter {
  BlueprintChapter({
    this.title,
    this.detailedOutline,
    this.sceneCards,
    this.foreshadowings,
  });

  String? title;
  String? detailedOutline;
  List<SceneCard>? sceneCards;
  List<BlueprintForeshadow>? foreshadowings;

  factory BlueprintChapter.fromJson(dynamic raw) {
    if (raw is String) return BlueprintChapter(title: raw.trim());
    if (raw is Map) {
      final cardsRaw = raw['scene_cards'];
      final fsRaw = raw['foreshadowings'];
      return BlueprintChapter(
        title: raw['title']?.toString(),
        detailedOutline: (raw['detailed_outline'] ?? raw['detailedOutline'])
            ?.toString(),
        sceneCards: cardsRaw is List
            ? cardsRaw.map(SceneCard.fromJson).toList()
            : null,
        foreshadowings: fsRaw is List
            ? fsRaw.map(BlueprintForeshadow.fromJson).toList()
            : null,
      );
    }
    return BlueprintChapter();
  }

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    if (detailedOutline != null) 'detailed_outline': detailedOutline,
    if (sceneCards != null)
      'scene_cards': [for (final c in sceneCards!) c.toJson()],
    if (foreshadowings != null)
      'foreshadowings': [for (final f in foreshadowings!) f.toJson()],
  };
}

class BlueprintVolume {
  BlueprintVolume({
    this.name,
    this.outline,
    this.emotionArc,
    this.conflictLadder,
    this.infoGap,
    List<BlueprintChapter>? chapters,
  }) : chapters = chapters ?? [];

  String? name;
  String? outline;
  List<String>? emotionArc;
  List<ConflictRung>? conflictLadder;
  InfoGap? infoGap;
  List<BlueprintChapter> chapters;

  factory BlueprintVolume.fromJson(dynamic raw) {
    if (raw is! Map) return BlueprintVolume();
    final arcRaw = raw['emotion_arc'];
    final ladderRaw = raw['conflict_ladder'];
    final gapRaw = raw['info_gap'];
    final chsRaw = raw['chapters'];
    return BlueprintVolume(
      name: raw['name']?.toString(),
      outline: raw['outline']?.toString(),
      emotionArc: arcRaw is List
          ? arcRaw.map((e) => e.toString()).toList()
          : null,
      conflictLadder: ladderRaw is List
          ? [
              for (var i = 0; i < ladderRaw.length; i++)
                ConflictRung.fromJson(ladderRaw[i], fallbackLevel: i + 1),
            ]
          : null,
      infoGap: gapRaw != null ? InfoGap.fromJson(gapRaw) : null,
      chapters: chsRaw is List
          ? chsRaw.map(BlueprintChapter.fromJson).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (outline != null) 'outline': outline,
    if (emotionArc != null) 'emotion_arc': emotionArc,
    if (conflictLadder != null)
      'conflict_ladder': [for (final r in conflictLadder!) r.toJson()],
    if (infoGap != null) 'info_gap': infoGap!.toJson(),
    'chapters': [for (final c in chapters) c.toJson()],
  };
}

class NovelBlueprint {
  NovelBlueprint({
    this.titleSuggestion,
    this.theme,
    this.synopsis,
    this.perspective,
    this.styleGuide,
    List<BlueprintCharacter>? characters,
    List<BlueprintWorld>? worldbuilding,
    List<BlueprintVolume>? volumes,
  }) : characters = characters ?? [],
       worldbuilding = worldbuilding ?? [],
       volumes = volumes ?? [];

  String? titleSuggestion;
  String? theme;
  String? synopsis;
  String? perspective;
  String? styleGuide;
  List<BlueprintCharacter> characters;
  List<BlueprintWorld> worldbuilding;
  List<BlueprintVolume> volumes;

  factory NovelBlueprint.fromJson(Map<String, dynamic> json) {
    final charsRaw = json['characters'];
    final worldRaw = json['worldbuilding'];
    final volsRaw = json['volumes'];
    return NovelBlueprint(
      titleSuggestion: json['title_suggestion']?.toString(),
      theme: json['theme']?.toString(),
      synopsis: json['synopsis']?.toString(),
      perspective: json['perspective']?.toString(),
      styleGuide: json['style_guide']?.toString(),
      characters: charsRaw is List
          ? charsRaw.map(BlueprintCharacter.fromJson).toList()
          : [],
      worldbuilding: worldRaw is List
          ? worldRaw.map(BlueprintWorld.fromJson).toList()
          : [],
      volumes: volsRaw is List
          ? volsRaw.map(BlueprintVolume.fromJson).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (titleSuggestion != null) 'title_suggestion': titleSuggestion,
    if (theme != null) 'theme': theme,
    if (synopsis != null) 'synopsis': synopsis,
    if (perspective != null) 'perspective': perspective,
    if (styleGuide != null) 'style_guide': styleGuide,
    'characters': [for (final c in characters) c.toJson()],
    'worldbuilding': [for (final w in worldbuilding) w.toJson()],
    'volumes': [for (final v in volumes) v.toJson()],
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class ClarifyResult {
  const ClarifyResult({this.enough, this.reason, this.questions});
  final bool? enough;
  final String? reason;
  final List<String>? questions;

  factory ClarifyResult.fromJson(Map<String, dynamic> json) {
    final qRaw = json['questions'];
    return ClarifyResult(
      enough: json['enough'] is bool ? json['enough'] as bool : null,
      reason: json['reason']?.toString(),
      questions: qRaw is List ? qRaw.map((e) => e.toString()).toList() : null,
    );
  }
}

class ProposedVolume {
  ProposedVolume({this.name, this.chapterCount});
  String? name;
  int? chapterCount;

  factory ProposedVolume.fromJson(dynamic raw) {
    if (raw is! Map) return ProposedVolume();
    return ProposedVolume(
      name: raw['name']?.toString(),
      chapterCount: (raw['chapter_count'] ?? raw['chapterCount']) is num
          ? ((raw['chapter_count'] ?? raw['chapterCount']) as num).toInt()
          : int.tryParse('${raw['chapter_count'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (chapterCount != null) 'chapter_count': chapterCount,
  };
}

class StructureProposal {
  StructureProposal({this.concept, List<ProposedVolume>? volumes})
    : volumes = volumes ?? [];

  String? concept;
  List<ProposedVolume> volumes;

  factory StructureProposal.fromJson(Map<String, dynamic> json) {
    final volsRaw = json['volumes'];
    return StructureProposal(
      concept: json['concept']?.toString(),
      volumes: volsRaw is List
          ? volsRaw.map(ProposedVolume.fromJson).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (concept != null) 'concept': concept,
    'volumes': [for (final v in volumes) v.toJson()],
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class VolumeOutlinePatch {
  const VolumeOutlinePatch({
    this.name,
    this.outline,
    this.emotionArc,
    this.conflictLadder,
    this.infoGap,
  });

  final String? name;
  final String? outline;
  final List<String>? emotionArc;
  final List<ConflictRung>? conflictLadder;
  final InfoGap? infoGap;

  factory VolumeOutlinePatch.fromJson(dynamic raw) {
    if (raw is! Map) return const VolumeOutlinePatch();
    final arcRaw = raw['emotion_arc'];
    final ladderRaw = raw['conflict_ladder'];
    final gapRaw = raw['info_gap'];
    return VolumeOutlinePatch(
      name: raw['name']?.toString(),
      outline: raw['outline']?.toString(),
      emotionArc: arcRaw is List
          ? arcRaw.map((e) => e.toString()).toList()
          : null,
      conflictLadder: ladderRaw is List
          ? [
              for (var i = 0; i < ladderRaw.length; i++)
                ConflictRung.fromJson(ladderRaw[i], fallbackLevel: i + 1),
            ]
          : null,
      infoGap: gapRaw != null ? InfoGap.fromJson(gapRaw) : null,
    );
  }
}

enum CreationPhase { collecting, proposing, blueprintReady, outlining, confirmed }

enum CreationStreamKind {
  clarify,
  structure,
  foundation,
  revise,
  volumeBatch,
  chapterBatch,
  chapterNames,
}

class CreationSessionState {
  CreationSessionState({
    this.phase = CreationPhase.collecting,
    this.brief = '',
    this.qaText = '',
    this.proposal,
    this.blueprint,
    this.volumesPerBatch = 3,
    this.chaptersPerBatch = 2,
    this.autoContinue = false,
  });

  CreationPhase phase;
  String brief;
  String qaText;
  StructureProposal? proposal;
  NovelBlueprint? blueprint;
  int volumesPerBatch;
  int chaptersPerBatch;
  bool autoContinue;

  factory CreationSessionState.fromJson(Map<String, dynamic> json) {
    final phaseStr = json['phase']?.toString() ?? 'collecting';
    final phase = CreationPhase.values
        .where((p) => p.name == phaseStr)
        .firstOrNull ?? CreationPhase.collecting;
    return CreationSessionState(
      phase: phase,
      brief: json['brief']?.toString() ?? '',
      qaText: json['qaText']?.toString() ?? '',
      proposal: json['proposal'] is Map<String, dynamic>
          ? StructureProposal.fromJson(json['proposal'] as Map<String, dynamic>)
          : null,
      blueprint: json['blueprint'] is Map<String, dynamic>
          ? NovelBlueprint.fromJson(json['blueprint'] as Map<String, dynamic>)
          : null,
      volumesPerBatch: (json['volumesPerBatch'] as num?)?.toInt() ?? 3,
      chaptersPerBatch: (json['chaptersPerBatch'] as num?)?.toInt() ?? 2,
      autoContinue: false, // 恢复会话后安全起见默认关闭自动连续
    );
  }

  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    'brief': brief,
    'qaText': qaText,
    if (proposal != null) 'proposal': proposal!.toJson(),
    if (blueprint != null) 'blueprint': blueprint!.toJson(),
    'volumesPerBatch': volumesPerBatch,
    'chaptersPerBatch': chaptersPerBatch,
  };
}
