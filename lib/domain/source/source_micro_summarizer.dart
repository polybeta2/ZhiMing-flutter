import 'dart:convert';

import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';

class MicroCharacter {
  const MicroCharacter({
    required this.name,
    this.traits,
    this.stateChange,
  });

  final String name;
  final String? traits;
  final String? stateChange;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (traits != null) 'traits': traits,
    if (stateChange != null) 'state_change': stateChange,
  };

  factory MicroCharacter.fromJson(Map<String, dynamic> json) => MicroCharacter(
    name: json['name']?.toString() ?? '',
    traits: _opt(json['traits']),
    stateChange: _opt(json['state_change'] ?? json['stateChange']),
  );
}

class MicroEvent {
  const MicroEvent({required this.summary, this.participants = const []});

  final String summary;
  final List<String> participants;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'participants': participants,
  };

  factory MicroEvent.fromJson(Map<String, dynamic> json) => MicroEvent(
    summary: json['summary']?.toString() ?? '',
    participants: (json['participants'] as List? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(),
  );
}

class MicroWorld {
  const MicroWorld({required this.name, required this.content});

  final String name;
  final String content;

  Map<String, dynamic> toJson() => {'name': name, 'content': content};

  factory MicroWorld.fromJson(Map<String, dynamic> json) => MicroWorld(
    name: json['name']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
  );
}

class MicroForeshadow {
  const MicroForeshadow({required this.summary, this.planted = true});

  final String summary;
  final bool planted;

  Map<String, dynamic> toJson() => {'summary': summary, 'planted': planted};

  factory MicroForeshadow.fromJson(Map<String, dynamic> json) =>
      MicroForeshadow(
        summary: json['summary']?.toString() ?? '',
        planted: json['planted'] != false,
      );
}

class MicroSummary {
  const MicroSummary({
    this.characters = const [],
    this.events = const [],
    this.worldbuilding = const [],
    this.foreshadowing = const [],
  });

  final List<MicroCharacter> characters;
  final List<MicroEvent> events;
  final List<MicroWorld> worldbuilding;
  final List<MicroForeshadow> foreshadowing;

  Map<String, dynamic> toJson() => {
    'characters': characters.map((e) => e.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'worldbuilding': worldbuilding.map((e) => e.toJson()).toList(),
    'foreshadowing': foreshadowing.map((e) => e.toJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory MicroSummary.fromJson(Map<String, dynamic> json) => MicroSummary(
    characters: (json['characters'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MicroCharacter.fromJson(e.cast<String, dynamic>()))
        .toList(),
    events: (json['events'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MicroEvent.fromJson(e.cast<String, dynamic>()))
        .toList(),
    worldbuilding: (json['worldbuilding'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MicroWorld.fromJson(e.cast<String, dynamic>()))
        .toList(),
    foreshadowing: (json['foreshadowing'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MicroForeshadow.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );

  factory MicroSummary.fromJsonString(String raw) =>
      MicroSummary.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
}

/// Map 阶段单块微摘要提示词与解析器。
class SourceMicroSummarizer {
  const SourceMicroSummarizer._();

  static const String systemPrompt = '''你是专业小说内容分析师。只提取原文明确出现的事实，绝不臆造，只输出合法 JSON 对象（不要代码块、不要任何说明文字）。
Schema:
{
  "characters": [{"name": "角色名", "traits": "性格或能力关键词（可选）", "state_change": "本段状态变化（可选）"}],
  "events": [{"summary": "本段核心事件一句话", "participants": ["角色A"]}],
  "worldbuilding": [{"name": "设定词条", "content": "简述"}],
  "foreshadowing": [{"summary": "本段新埋或回收的伏笔/悬念一句话", "planted": true}]
}
伏笔规则：本段新埋下的记 planted=true；本段明确回收/揭晓的记 planted=false；无则空数组。''';

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
