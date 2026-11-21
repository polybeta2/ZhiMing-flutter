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

class CanonCamp {
  const CanonCamp({required this.name, this.stance, this.brief});

  final String name;
  final String? stance;
  final String? brief;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (stance != null) 'stance': stance,
    if (brief != null) 'brief': brief,
  };

  factory CanonCamp.fromJson(Map<String, dynamic> json) => CanonCamp(
    name: json['name']?.toString().trim() ?? '',
    stance: _optString(json['stance']),
    brief: _optString(json['brief']),
  );
}

class CanonRelationEvolution {
  const CanonRelationEvolution({
    required this.chapterLabel,
    required this.state,
  });

  final String chapterLabel;
  final String state;

  Map<String, dynamic> toJson() => {
    'chapterLabel': chapterLabel,
    'state': state,
  };

  factory CanonRelationEvolution.fromJson(Map<String, dynamic> json) =>
      CanonRelationEvolution(
        chapterLabel:
            (json['chapterLabel'] ?? json['chapter_label'] ?? json['chapter'])
                ?.toString()
                .trim() ??
            '',
        state: (json['state'] ?? json['desc'])?.toString().trim() ?? '',
      );
}

class CanonRelationEdge {
  const CanonRelationEdge({
    required this.from,
    required this.to,
    this.relationType = '未知',
    required this.label,
    this.description = '',
    this.strength = 3,
    this.line = '明线',
    this.firstChapter,
    this.lastChapter,
    this.evolution = const [],
    this.evidence,
  });

  final String from;
  final String to;
  final String relationType;
  final String label;
  final String description;
  final int strength;
  final String line;
  final int? firstChapter;
  final int? lastChapter;
  final List<CanonRelationEvolution> evolution;
  final String? evidence;

  CanonRelationEdge copyWith({
    String? from,
    String? to,
    String? relationType,
    String? label,
    String? description,
    int? strength,
    String? line,
    int? firstChapter,
    int? lastChapter,
    List<CanonRelationEvolution>? evolution,
    String? evidence,
  }) => CanonRelationEdge(
    from: from ?? this.from,
    to: to ?? this.to,
    relationType: relationType ?? this.relationType,
    label: label ?? this.label,
    description: description ?? this.description,
    strength: strength ?? this.strength,
    line: line ?? this.line,
    firstChapter: firstChapter ?? this.firstChapter,
    lastChapter: lastChapter ?? this.lastChapter,
    evolution: evolution ?? this.evolution,
    evidence: evidence ?? this.evidence,
  );

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'relationType': relationType,
    'label': label,
    if (description.isNotEmpty) 'description': description,
    'strength': strength,
    'line': line,
    if (firstChapter != null) 'firstChapter': firstChapter,
    if (lastChapter != null) 'lastChapter': lastChapter,
    if (evolution.isNotEmpty)
      'evolution': evolution.map((e) => e.toJson()).toList(),
    if (evidence != null) 'evidence': evidence,
  };

  factory CanonRelationEdge.fromJson(Map<String, dynamic> json) {
    final rawLine = (json['line'] ?? '明线').toString().trim();
    final line = rawLine.contains('暗') ? '暗线' : '明线';
    final rawStrength = (json['strength'] as num?)?.toInt() ?? 3;
    return CanonRelationEdge(
      from: (json['from'] ?? json['a'] ?? json['source'])?.toString().trim() ??
          '',
      to: (json['to'] ?? json['b'] ?? json['target'])?.toString().trim() ?? '',
      relationType: normalizeRelationType(
        (json['relationType'] ?? json['relation_type'] ?? json['kind'])
            ?.toString(),
      ),
      label: (json['label'] ?? json['relation'])?.toString().trim() ?? '',
      description:
          (json['description'] ?? json['desc'])?.toString().trim() ?? '',
      strength: rawStrength.clamp(1, 5),
      line: line,
      firstChapter: _optInt(json['firstChapter'] ?? json['first_chapter']),
      lastChapter: _optInt(json['lastChapter'] ?? json['last_chapter']),
      evolution: (json['evolution'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonRelationEvolution.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.state.isNotEmpty)
          .toList(),
      evidence: _optString(json['evidence']),
    );
  }
}

String normalizeRelationType(String? raw) {
  final t = (raw ?? '').trim();
  const allowed = {'亲友', '盟友', '爱恋', '敌对', '从属', '竞争', '未知'};
  if (allowed.contains(t)) return t;
  if (t.contains('敌') ||
      t.contains('仇') ||
      t.contains('杀') ||
      t.contains('反')) {
    return '敌对';
  }
  if (t.contains('爱') ||
      t.contains('恋') ||
      t.contains('情') ||
      t.contains('妻') ||
      t.contains('夫')) {
    return '爱恋';
  }
  if (t.contains('亲') ||
      t.contains('友') ||
      t.contains('兄') ||
      t.contains('妹') ||
      t.contains('父') ||
      t.contains('母') ||
      t.contains('师')) {
    return '亲友';
  }
  if (t.contains('盟') ||
      t.contains('合') ||
      t.contains('同') ||
      t.contains('搭档')) {
    return '盟友';
  }
  if (t.contains('属') ||
      t.contains('主') ||
      t.contains('仆') ||
      t.contains('契约') ||
      t.contains('下级')) {
    return '从属';
  }
  if (t.contains('竞') || t.contains('对手')) return '竞争';
  return '未知';
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
    this.camp,
    this.stance,
    this.importance = CanonImportance.normal,
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
  final String? camp;
  final String? stance;
  final CanonImportance importance;
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
    String? camp,
    String? stance,
    CanonImportance? importance,
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
      camp: camp ?? this.camp,
      stance: stance ?? this.stance,
      importance: importance ?? this.importance,
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
    if (camp != null) 'camp': camp,
    if (stance != null) 'stance': stance,
    'importance': importance.raw,
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
      camp: _optString(json['camp']),
      stance: _optString(json['stance']),
      importance: CanonImportance.fromRaw(json['importance']?.toString()),
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
    this.id,
    this.phase,
    this.chapterRange,
    this.chapterStart,
    this.chapterEnd,
    this.inWorldTime,
    required this.summary,
    this.participants = const [],
    this.linkedClueTitles = const [],
    this.importance = CanonImportance.normal,
  });

  final String? id;
  final String? phase;
  final String? chapterRange;
  final int? chapterStart;
  final int? chapterEnd;
  final String? inWorldTime;
  final String summary;
  final List<String> participants;
  final List<String> linkedClueTitles;
  final CanonImportance importance;

  CanonEvent copyWith({
    String? id,
    String? phase,
    String? chapterRange,
    int? chapterStart,
    int? chapterEnd,
    String? inWorldTime,
    String? summary,
    List<String>? participants,
    List<String>? linkedClueTitles,
    CanonImportance? importance,
  }) {
    return CanonEvent(
      id: id ?? this.id,
      phase: phase ?? this.phase,
      chapterRange: chapterRange ?? this.chapterRange,
      chapterStart: chapterStart ?? this.chapterStart,
      chapterEnd: chapterEnd ?? this.chapterEnd,
      inWorldTime: inWorldTime ?? this.inWorldTime,
      summary: summary ?? this.summary,
      participants: participants ?? this.participants,
      linkedClueTitles: linkedClueTitles ?? this.linkedClueTitles,
      importance: importance ?? this.importance,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (phase != null) 'phase': phase,
    if (chapterRange != null) 'chapterRange': chapterRange,
    if (chapterStart != null) 'chapterStart': chapterStart,
    if (chapterEnd != null) 'chapterEnd': chapterEnd,
    if (inWorldTime != null) 'inWorldTime': inWorldTime,
    'summary': summary,
    'participants': participants,
    if (linkedClueTitles.isNotEmpty) 'linkedClueTitles': linkedClueTitles,
    'importance': importance.raw,
  };

  factory CanonEvent.fromJson(Map<String, dynamic> json) => CanonEvent(
    id: _optString(json['id']),
    phase: _optString(json['phase']),
    chapterRange: _optString(json['chapterRange'] ?? json['chapter_range']),
    chapterStart: _optInt(json['chapterStart'] ?? json['chapter_start']),
    chapterEnd: _optInt(json['chapterEnd'] ?? json['chapter_end']),
    inWorldTime: _optString(json['inWorldTime'] ?? json['in_world_time']),
    summary: (json['summary'] ?? json['event'])?.toString() ?? '',
    participants: _stringList(json['participants']),
    linkedClueTitles: _stringList(
      json['linkedClueTitles'] ?? json['linked_clue_titles'],
    ),
    importance: CanonImportance.fromRaw(json['importance']?.toString()),
  );
}

class CanonWorldEntry {
  const CanonWorldEntry({
    required this.category,
    required this.name,
    required this.content,
    this.keywords = const [],
  });

  final String category;
  final String name;
  final String content;
  final List<String> keywords;

  CanonWorldEntry copyWith({
    String? category,
    String? name,
    String? content,
    List<String>? keywords,
  }) {
    return CanonWorldEntry(
      category: category ?? this.category,
      name: name ?? this.name,
      content: content ?? this.content,
      keywords: keywords ?? this.keywords,
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'name': name,
    'content': content,
    if (keywords.isNotEmpty) 'keywords': keywords,
  };

  factory CanonWorldEntry.fromJson(Map<String, dynamic> json) =>
      CanonWorldEntry(
        category: json['category']?.toString() ?? '设定',
        name: json['name']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        keywords: _stringList(json['keywords']),
      );
}

class CanonThread {
  const CanonThread({
    required this.title,
    required this.detail,
    this.plantedChapter,
    this.status = 'open',
    this.resolvedChapter,
    this.involvedCharacters = const [],
    this.relatedEventSummary,
    this.payoffDetail,
  });

  final String title;
  final String detail;
  final int? plantedChapter;
  final String status; // 'open' | 'partial' | 'resolved'
  final int? resolvedChapter;
  final List<String> involvedCharacters;
  final String? relatedEventSummary;
  final String? payoffDetail;

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
    if (plantedChapter != null) 'plantedChapter': plantedChapter,
    'status': status,
    if (resolvedChapter != null) 'resolvedChapter': resolvedChapter,
    if (involvedCharacters.isNotEmpty) 'involvedCharacters': involvedCharacters,
    if (relatedEventSummary != null) 'relatedEventSummary': relatedEventSummary,
    if (payoffDetail != null) 'payoffDetail': payoffDetail,
  };

  factory CanonThread.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status']?.toString().trim().toLowerCase() ?? 'open');
    final status = switch (rawStatus) {
      'resolved' || 'closed' || '已回收' => 'resolved',
      'partial' || 'partially_resolved' || '部分推进' => 'partial',
      _ => 'open',
    };
    return CanonThread(
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      plantedChapter: _optInt(
        json['plantedChapter'] ?? json['planted_chapter'],
      ),
      status: status,
      resolvedChapter: _optInt(
        json['resolvedChapter'] ?? json['resolved_chapter'],
      ),
      involvedCharacters: _stringList(
        json['involvedCharacters'] ?? json['involved_characters'],
      ),
      relatedEventSummary: _optString(
        json['relatedEventSummary'] ?? json['related_event_summary'],
      ),
      payoffDetail: _optString(json['payoffDetail'] ?? json['payoff_detail']),
    );
  }
}

class SourceNovelProfileData {
  SourceNovelProfileData({
    String? id,
    required this.title,
    this.author,
    this.meta = const ScanMeta(),
    this.camps = const [],
    this.characters = const [],
    this.relations = const [],
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
  final List<CanonCamp> camps;
  final List<CanonCharacter> characters;
  final List<CanonRelationEdge> relations;
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
    List<CanonCamp>? camps,
    List<CanonCharacter>? characters,
    List<CanonRelationEdge>? relations,
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
      camps: camps ?? this.camps,
      characters: characters ?? this.characters,
      relations: relations ?? this.relations,
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
    if (camps.isNotEmpty) 'camps': camps.map((e) => e.toJson()).toList(),
    'characters': characters.map((e) => e.toJson()).toList(),
    if (relations.isNotEmpty)
      'relations': relations.map((e) => e.toJson()).toList(),
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
      camps: (json['camps'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonCamp.fromJson(e.cast<String, dynamic>()))
          .where((c) => c.name.isNotEmpty)
          .toList(),
      characters: (json['characters'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonCharacter.fromJson(e.cast<String, dynamic>()))
          .toList(),
      relations: (json['relations'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CanonRelationEdge.fromJson(e.cast<String, dynamic>()))
          .where((r) => r.from.isNotEmpty && r.to.isNotEmpty)
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

int? _optInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
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
