import 'dart:convert';

import 'package:uuid/uuid.dart';

enum ScanMode {
  evidence('evidence', '极速证据建档（推荐）'),
  fast('fast', '全书快扫'),
  full('full', '全书精扫');

  const ScanMode(this.raw, this.label);
  final String raw;
  final String label;

  static ScanMode fromRaw(String? raw) => switch (raw) {
    'full' => ScanMode.full,
    'fast' => ScanMode.fast,
    _ => ScanMode.evidence,
  };
}

enum ScanStage {
  idle('idle'),
  mapping('mapping'),
  reducing('reducing'),
  done('done'),
  failed('failed');

  const ScanStage(this.raw);
  final String raw;

  static ScanStage fromRaw(String? raw) => ScanStage.values.firstWhere(
    (e) => e.raw == raw,
    orElse: () => ScanStage.idle,
  );
}

enum CanonImportance {
  major('major', '核心'),
  normal('normal', '普通'),
  minor('minor', '次要');

  const CanonImportance(this.raw, this.label);
  final String raw;
  final String label;

  static CanonImportance fromRaw(String? raw) =>
      CanonImportance.values.firstWhere(
        (e) => e.raw == raw,
        orElse: () => CanonImportance.normal,
      );
}

class ScanMeta {
  const ScanMeta({
    this.totalChapters = 0,
    this.totalChars = 0,
    this.scanMode = ScanMode.fast,
  });

  final int totalChapters;
  final int totalChars;
  final ScanMode scanMode;

  Map<String, dynamic> toJson() => {
    'totalChapters': totalChapters,
    'totalChars': totalChars,
    'scanMode': scanMode.raw,
  };

  factory ScanMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScanMeta();
    return ScanMeta(
      totalChapters: (json['totalChapters'] as num?)?.toInt() ?? 0,
      totalChars: (json['totalChars'] as num?)?.toInt() ?? 0,
      scanMode: ScanMode.fromRaw(json['scanMode']?.toString()),
    );
  }
}

class ScanState {
  const ScanState({
    this.stage = ScanStage.idle,
    this.totalChunks = 0,
    this.doneChunks = 0,
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.startedAt,
  });

  final ScanStage stage;
  final int totalChunks;
  final int doneChunks;
  final int tokensIn;
  final int tokensOut;
  final DateTime? startedAt;

  bool get isComplete => stage == ScanStage.done;

  Map<String, dynamic> toJson() => {
    'stage': stage.raw,
    'totalChunks': totalChunks,
    'doneChunks': doneChunks,
    'tokensIn': tokensIn,
    'tokensOut': tokensOut,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
  };

  factory ScanState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScanState();
    return ScanState(
      stage: ScanStage.fromRaw(json['stage']?.toString()),
      totalChunks: (json['totalChunks'] as num?)?.toInt() ?? 0,
      doneChunks: (json['doneChunks'] as num?)?.toInt() ?? 0,
      tokensIn: (json['tokensIn'] as num?)?.toInt() ?? 0,
      tokensOut: (json['tokensOut'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
    );
  }
}

class CanonRelationship {
  const CanonRelationship({required this.target, required this.relation});

  final String target;
  final String relation;

  Map<String, dynamic> toJson() => {'target': target, 'relation': relation};

  factory CanonRelationship.fromJson(Map<String, dynamic> json) =>
      CanonRelationship(
        target: json['target']?.toString() ?? '',
        relation: json['relation']?.toString() ?? '',
      );
}

class CanonArc {
  const CanonArc({required this.phase, required this.state});

  final String phase;
  final String state;

  Map<String, dynamic> toJson() => {'phase': phase, 'state': state};

  factory CanonArc.fromJson(Map<String, dynamic> json) => CanonArc(
    phase: json['phase']?.toString() ?? '',
    state: json['state']?.toString() ?? '',
  );
}

class CanonCharacter {
  const CanonCharacter({
    required this.name,
    this.aliases = const [],
    this.oneLine,
    this.role,
    this.appearance,
    this.personality,
    this.abilities,
    this.relationships = const [],
    this.arc = const [],
    this.currentState,
    this.voiceSamples = const [],
  });

  final String name;
  final List<String> aliases;
  final String? oneLine;
  final String? role;
  final String? appearance;
  final String? personality;
  final String? abilities;
  final List<CanonRelationship> relationships;
  final List<CanonArc> arc;
  final String? currentState;
  final List<String> voiceSamples;

  CanonCharacter copyWith({
    String? name,
    List<String>? aliases,
    String? oneLine,
    String? role,
    String? appearance,
    String? personality,
    String? abilities,
    List<CanonRelationship>? relationships,
    List<CanonArc>? arc,
    String? currentState,
    List<String>? voiceSamples,
  }) {
    return CanonCharacter(
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      oneLine: oneLine ?? this.oneLine,
      role: role ?? this.role,
      appearance: appearance ?? this.appearance,
      personality: personality ?? this.personality,
      abilities: abilities ?? this.abilities,
      relationships: relationships ?? this.relationships,
      arc: arc ?? this.arc,
      currentState: currentState ?? this.currentState,
      voiceSamples: voiceSamples ?? this.voiceSamples,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'aliases': aliases,
    if (oneLine != null) 'oneLine': oneLine,
    if (role != null) 'role': role,
    if (appearance != null) 'appearance': appearance,
    if (personality != null) 'personality': personality,
    if (abilities != null) 'abilities': abilities,
    'relationships': relationships.map((e) => e.toJson()).toList(),
    'arc': arc.map((e) => e.toJson()).toList(),
    if (currentState != null) 'currentState': currentState,
    if (voiceSamples.isNotEmpty) 'voiceSamples': voiceSamples,
  };

  factory CanonCharacter.fromJson(Map<String, dynamic> json) {
    return CanonCharacter(
      name: json['name']?.toString() ?? '',
      aliases: _stringList(json['aliases']),
      oneLine: _optString(json['oneLine'] ?? json['one_line']),
      role: _optString(json['role']),
      appearance: _optString(json['appearance']),
      personality: _optString(json['personality']),
      abilities: _optString(json['abilities']),
      relationships: (json['relationships'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonRelationship.fromJson(e.cast<String, dynamic>()))
          .toList(),
      arc: (json['arc'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonArc.fromJson(e.cast<String, dynamic>()))
          .toList(),
      currentState: _optString(json['currentState'] ?? json['current_state']),
      voiceSamples: _stringList(json['voiceSamples'] ?? json['voice_samples']),
    );
  }
}

class CanonEvent {
  const CanonEvent({
    this.phase,
    this.chapterRange,
    required this.summary,
    this.participants = const [],
    this.importance = CanonImportance.normal,
  });

  final String? phase;
  final String? chapterRange;
  final String summary;
  final List<String> participants;
  final CanonImportance importance;

  CanonEvent copyWith({
    String? phase,
    String? chapterRange,
    String? summary,
    List<String>? participants,
    CanonImportance? importance,
  }) {
    return CanonEvent(
      phase: phase ?? this.phase,
      chapterRange: chapterRange ?? this.chapterRange,
      summary: summary ?? this.summary,
      participants: participants ?? this.participants,
      importance: importance ?? this.importance,
    );
  }

  Map<String, dynamic> toJson() => {
    if (phase != null) 'phase': phase,
    if (chapterRange != null) 'chapterRange': chapterRange,
    'summary': summary,
    'participants': participants,
    'importance': importance.raw,
  };

  factory CanonEvent.fromJson(Map<String, dynamic> json) => CanonEvent(
    phase: _optString(json['phase']),
    chapterRange: _optString(json['chapterRange'] ?? json['chapter_range']),
    summary: json['summary']?.toString() ?? '',
    participants: _stringList(json['participants']),
    importance: CanonImportance.fromRaw(json['importance']?.toString()),
  );
}

class CanonWorldEntry {
  const CanonWorldEntry({
    required this.category,
    required this.name,
    required this.content,
  });

  final String category;
  final String name;
  final String content;

  CanonWorldEntry copyWith({String? category, String? name, String? content}) {
    return CanonWorldEntry(
      category: category ?? this.category,
      name: name ?? this.name,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'name': name,
    'content': content,
  };

  factory CanonWorldEntry.fromJson(Map<String, dynamic> json) =>
      CanonWorldEntry(
        category: json['category']?.toString() ?? '设定',
        name: json['name']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
      );
}

class CanonThread {
  const CanonThread({
    required this.title,
    required this.detail,
    this.plantedChapter,
  });

  final String title;
  final String detail;
  final int? plantedChapter;

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
    if (plantedChapter != null) 'plantedChapter': plantedChapter,
  };

  factory CanonThread.fromJson(Map<String, dynamic> json) => CanonThread(
    title: json['title']?.toString() ?? '',
    detail: json['detail']?.toString() ?? '',
    plantedChapter: (json['plantedChapter'] ?? json['planted_chapter']) is num
        ? ((json['plantedChapter'] ?? json['planted_chapter']) as num).toInt()
        : int.tryParse(
            (json['plantedChapter'] ?? json['planted_chapter'])?.toString() ??
                '',
          ),
  );
}

class SourceNovelProfileData {
  SourceNovelProfileData({
    String? id,
    required this.title,
    this.author,
    this.meta = const ScanMeta(),
    this.characters = const [],
    this.timeline = const [],
    this.worldbuilding = const [],
    this.openThreads = const [],
    this.activeArcs = const [],
    this.styleProfileId,
    this.continuationFromChapter,
    this.hasSourceText = false,
    this.scanState = const ScanState(),
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String? author;
  final ScanMeta meta;
  final List<CanonCharacter> characters;
  final List<CanonEvent> timeline;
  final List<CanonWorldEntry> worldbuilding;
  final List<CanonThread> openThreads;
  final List<String> activeArcs;
  final String? styleProfileId;
  final int? continuationFromChapter;
  final bool hasSourceText;
  final ScanState scanState;
  final DateTime createdAt;

  SourceNovelProfileData copyWith({
    String? id,
    String? title,
    String? author,
    ScanMeta? meta,
    List<CanonCharacter>? characters,
    List<CanonEvent>? timeline,
    List<CanonWorldEntry>? worldbuilding,
    List<CanonThread>? openThreads,
    List<String>? activeArcs,
    String? styleProfileId,
    bool clearStyleProfileId = false,
    int? continuationFromChapter,
    bool? hasSourceText,
    ScanState? scanState,
    DateTime? createdAt,
  }) {
    return SourceNovelProfileData(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      meta: meta ?? this.meta,
      characters: characters ?? this.characters,
      timeline: timeline ?? this.timeline,
      worldbuilding: worldbuilding ?? this.worldbuilding,
      openThreads: openThreads ?? this.openThreads,
      activeArcs: activeArcs ?? this.activeArcs,
      styleProfileId: clearStyleProfileId
          ? null
          : (styleProfileId ?? this.styleProfileId),
      continuationFromChapter:
          continuationFromChapter ?? this.continuationFromChapter,
      hasSourceText: hasSourceText ?? this.hasSourceText,
      scanState: scanState ?? this.scanState,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (author != null) 'author': author,
    'meta': meta.toJson(),
    'characters': characters.map((e) => e.toJson()).toList(),
    'timeline': timeline.map((e) => e.toJson()).toList(),
    'worldbuilding': worldbuilding.map((e) => e.toJson()).toList(),
    'openThreads': openThreads.map((e) => e.toJson()).toList(),
    'activeArcs': activeArcs,
    if (styleProfileId != null) 'styleProfileId': styleProfileId,
    if (continuationFromChapter != null)
      'continuationFromChapter': continuationFromChapter,
    'hasSourceText': hasSourceText,
    'scanState': scanState.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory SourceNovelProfileData.fromJson(Map<String, dynamic> json) {
    return SourceNovelProfileData(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '未命名原作',
      author: _optString(json['author']),
      meta: ScanMeta.fromJson(
        json['meta'] is Map
            ? (json['meta'] as Map).cast<String, dynamic>()
            : null,
      ),
      characters: (json['characters'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonCharacter.fromJson(e.cast<String, dynamic>()))
          .toList(),
      timeline: (json['timeline'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonEvent.fromJson(e.cast<String, dynamic>()))
          .toList(),
      worldbuilding: (json['worldbuilding'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonWorldEntry.fromJson(e.cast<String, dynamic>()))
          .toList(),
      openThreads: (json['openThreads'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonThread.fromJson(e.cast<String, dynamic>()))
          .toList(),
      activeArcs: _stringList(json['activeArcs']),
      styleProfileId: _optString(
        json['styleProfileId'] ?? json['styleProfileID'],
      ),
      continuationFromChapter: (json['continuationFromChapter'] as num?)
          ?.toInt(),
      hasSourceText: json['hasSourceText'] == true,
      scanState: ScanState.fromJson(
        json['scanState'] is Map
            ? (json['scanState'] as Map).cast<String, dynamic>()
            : null,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory SourceNovelProfileData.fromJsonString(String raw) =>
      SourceNovelProfileData.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,，、;；\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

String? _optString(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
