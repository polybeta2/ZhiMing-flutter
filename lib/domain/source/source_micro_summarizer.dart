import 'dart:convert';

import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';

class MicroCharacter {
  const MicroCharacter({
    required this.name,
    this.aliases = const [],
    this.roleHint,
    this.campHint,
    this.traits,
    this.stateChange,
  });

  final String name;
  final List<String> aliases;
  final String? roleHint;
  final String? campHint;
  final String? traits;
  final String? stateChange;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (aliases.isNotEmpty) 'aliases': aliases,
    if (roleHint != null) 'role_hint': roleHint,
    if (campHint != null) 'camp_hint': campHint,
    if (traits != null) 'traits': traits,
    if (stateChange != null) 'state_change': stateChange,
  };

  factory MicroCharacter.fromJson(Map<String, dynamic> json) => MicroCharacter(
    name: json['name']?.toString().trim() ?? '',
    aliases: _strList(json['aliases']),
    roleHint: _opt(json['role_hint'] ?? json['roleHint'] ?? json['role']),
    campHint: _opt(json['camp_hint'] ?? json['campHint'] ?? json['camp']),
    traits: _opt(json['traits']),
    stateChange: _opt(json['state_change'] ?? json['stateChange']),
  );
}

class MicroRelation {
  const MicroRelation({
    required this.from,
    required this.to,
    required this.relation,
    this.kind = '未知',
    this.line = '明线',
    this.evidence,
  });

  final String from;
  final String to;
  final String relation;
  final String kind;
  final String line;
  final String? evidence;

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'relation': relation,
    'kind': kind,
    'line': line,
    if (evidence != null) 'evidence': evidence,
  };

  factory MicroRelation.fromJson(Map<String, dynamic> json) => MicroRelation(
    from: (json['from'] ?? json['a'] ?? json['source'])?.toString().trim() ?? '',
    to: (json['to'] ?? json['b'] ?? json['target'])?.toString().trim() ?? '',
    relation:
        (json['relation'] ?? json['label'] ?? json['desc'])
            ?.toString()
            .trim() ??
        '',
    kind: _opt(json['kind'] ?? json['relation_type'] ?? json['relationType']) ??
        '未知',
    line: (json['line']?.toString().contains('暗') ?? false) ? '暗线' : '明线',
    evidence: _opt(json['evidence']),
  );
}

class MicroEvent {
  const MicroEvent({
    required this.summary,
    this.inWorldTime,
    this.participants = const [],
    this.importance = 'normal',
  });

  final String summary;
  final String? inWorldTime;
  final List<String> participants;
  final String importance;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    if (inWorldTime != null) 'in_world_time': inWorldTime,
    'participants': participants,
    if (importance != 'normal') 'importance': importance,
  };

  factory MicroEvent.fromJson(Map<String, dynamic> json) {
    final rawImp = (json['importance']?.toString().trim().toLowerCase() ?? 'normal');
    final imp = switch (rawImp) {
      'major' || '核心' => 'major',
      'minor' || '次要' => 'minor',
      _ => 'normal',
    };
    return MicroEvent(
      summary: json['summary']?.toString().trim() ?? '',
      inWorldTime: _opt(json['in_world_time'] ?? json['inWorldTime']),
      participants: _strList(json['participants']),
      importance: imp,
    );
  }
}

class MicroWorld {
  const MicroWorld({required this.name, this.category, required this.content});

  final String name;
  final String? category;
  final String content;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (category != null) 'category': category,
    'content': content,
  };

  factory MicroWorld.fromJson(Map<String, dynamic> json) => MicroWorld(
    name: json['name']?.toString().trim() ?? '',
    category: _opt(json['category']),
    content: json['content']?.toString().trim() ?? '',
  );
}

class MicroForeshadow {
  const MicroForeshadow({
    required this.summary,
    this.planted = true,
    this.characters = const [],
    this.targetHint,
  });

  final String summary;
  final bool planted;
  final List<String> characters;
  final String? targetHint;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'planted': planted,
    if (characters.isNotEmpty) 'characters': characters,
    if (targetHint != null) 'target_hint': targetHint,
  };

  factory MicroForeshadow.fromJson(Map<String, dynamic> json) =>
      MicroForeshadow(
        summary: json['summary']?.toString().trim() ?? '',
        planted: json['planted'] != false,
        characters: _strList(json['characters'] ?? json['involved_characters']),
        targetHint: _opt(json['target_hint'] ?? json['targetHint']),
      );
}

class MicroSummary {
  const MicroSummary({
    this.chapterNo,
    this.characters = const [],
    this.relations = const [],
    this.events = const [],
    this.worldbuilding = const [],
    this.foreshadowing = const [],
  });

  final int? chapterNo;
  final List<MicroCharacter> characters;
  final List<MicroRelation> relations;
  final List<MicroEvent> events;
  final List<MicroWorld> worldbuilding;
  final List<MicroForeshadow> foreshadowing;

  MicroSummary mergeWith(MicroSummary other) => MicroSummary(
    chapterNo: chapterNo ?? other.chapterNo,
    characters: [...characters, ...other.characters],
    relations: [...relations, ...other.relations],
    events: [...events, ...other.events],
    worldbuilding: [...worldbuilding, ...other.worldbuilding],
    foreshadowing: [...foreshadowing, ...other.foreshadowing],
  );

  Map<String, dynamic> toJson() => {
    if (chapterNo != null) 'chapter': chapterNo,
    'characters': characters.map((e) => e.toJson()).toList(),
    if (relations.isNotEmpty)
      'relations': relations.map((e) => e.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'worldbuilding': worldbuilding.map((e) => e.toJson()).toList(),
    'foreshadowing': foreshadowing.map((e) => e.toJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory MicroSummary.fromJson(Map<String, dynamic> json) {
    final rawCh = json['chapter'];
    final chapterNo = rawCh is num
        ? rawCh.toInt()
        : int.tryParse(rawCh?.toString().trim() ?? '');
    return MicroSummary(
      chapterNo: chapterNo,
      characters: (json['characters'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MicroCharacter.fromJson(e.cast<String, dynamic>()))
          .where((c) => c.name.isNotEmpty)
          .toList(),
      relations: ((json['relations'] ?? json['relationships']) as List? ?? const [])
          .whereType<Map>()
          .map((e) => MicroRelation.fromJson(e.cast<String, dynamic>()))
          .where((r) => r.from.isNotEmpty && r.to.isNotEmpty)
          .toList(),
      events: (json['events'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MicroEvent.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.summary.isNotEmpty)
          .toList(),
      worldbuilding: (json['worldbuilding'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MicroWorld.fromJson(e.cast<String, dynamic>()))
          .where((w) => w.name.isNotEmpty || w.content.isNotEmpty)
          .toList(),
      foreshadowing: (json['foreshadowing'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MicroForeshadow.fromJson(e.cast<String, dynamic>()))
          .where((f) => f.summary.isNotEmpty)
          .toList(),
    );
  }

  factory MicroSummary.fromJsonString(String raw) =>
      MicroSummary.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
}

/// Map 阶段单块微摘要提示词与解析器。
class SourceMicroSummarizer {
  const SourceMicroSummarizer._();

  static const String systemPrompt = '''你是专业小说内容分析师。只提取原文明确出现的事实，绝不臆造，只输出合法 JSON 对象（不要代码块、不要任何说明文字）。
Schema:
{
  "chapter": 1,
  "characters": [{"name": "角色名", "aliases": ["别名/形态/称呼"], "role_hint": "主角/反派/配角（可选）", "camp_hint": "所属势力或阵营（可选）", "traits": "性格或能力关键词（可选）", "state_change": "本段状态变化（可选）"}],
  "relations": [{"from": "角色A", "to": "角色B", "relation": "本段展现或变化的关系简述", "kind": "亲友|盟友|爱恋|敌对|从属|竞争|未知", "line": "明线|暗线", "evidence": "简短依据（可选）"}],
  "events": [{"summary": "本段核心事件一句话", "in_world_time": "书内时间锚点（若有则填）", "participants": ["角色A"], "importance": "major|normal|minor"}],
  "worldbuilding": [{"name": "设定词条", "category": "力量体系|地理|势力|规则|器物", "content": "简述"}],
  "foreshadowing": [{"summary": "本段新埋或回收的伏笔/悬念一句话", "planted": true, "characters": ["涉及角色"], "target_hint": "若planted=false，简述回收的是前期哪条悬念"}]
}
规则：
1. 新埋伏笔记 planted=true；明确揭晓/回收的记 planted=false 并填写 target_hint；
2. 关系若涉及秘密、单方不知情或幕后操控，line 记为 "暗线"，否则记为 "明线"；
3. 无新增信息则给空数组，不要编造。''';

  static List<LLMMessage> messages({
    required String chunk,
    String? chapterMarker,
  }) {
    final header = (chapterMarker != null && chapterMarker.trim().isNotEmpty)
        ? '【$chapterMarker】\n'
        : '';
    return [
      const LLMMessage(role: LLMRole.system, content: systemPrompt),
      LLMMessage(role: LLMRole.user, content: '$header$chunk'),
    ];
  }

  static MicroSummary parse(String raw) {
    final map = LLMJSONParser.decodeObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('无法解析微摘要 JSON');
    }
    return MicroSummary.fromJson(map);
  }
}

String? _opt(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

List<String> _strList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,，、;；\n]+'))
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return const [];
}
