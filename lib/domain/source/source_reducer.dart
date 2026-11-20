import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../models/source_profile_models.dart';
import 'source_micro_summarizer.dart';

/// Reduce 阶段：滚动批归并 + 终归并（同人档案）/ 深度归并（续写档案）。
class SourceReducer {
  const SourceReducer._();

  static const int perStageCapChars = 4000;
  static const int finalInputCapChars = 180000;

  static String batchPrompt(
    List<MicroSummary> micros, {
    int batchChars = 12000,
  }) {
    final buf = StringBuffer()
      ..writeln(
        '把以下连续多章的微摘要归并为一段紧凑的阶段摘要（不超过 1500 字），按四个小节输出：'
        '【人物与变化】【核心事件】【世界设定】【伏笔（新埋/回收）】。去重并合并同一角色的重复描述，保留关键因果与尚未解决的悬念。',
      )
      ..writeln();

    var used = 0;
    for (var i = 0; i < micros.length; i++) {
      final line = _formatMicro(i + 1, micros[i]);
      if (used + line.length > batchChars && used > 0) break;
      buf.writeln(line);
      used += line.length;
    }
    return buf.toString();
  }

  static List<LLMMessage> finalPrompt({
    required List<String> stageSummaries,
    List<String> characters = const [],
  }) {
    const sys = '''你是小说档案编辑。把多段阶段摘要整合为全书原作档案 JSON（只输出合法 JSON 对象，无代码块、无说明）。
Schema:
{
  "title": "书名（未知留空）",
  "author": "作者（未知省略）",
  "characters": [{
    "name": "主名",
    "aliases": ["别名"],
    "oneLine": "一句话定位",
    "role": "主角/反派/配角",
    "appearance": "外貌",
    "personality": "性格",
    "abilities": "能力",
    "relationships": [{"target": "对象", "relation": "关系"}],
    "arc": [{"phase": "阶段名", "state": "该阶段状态"}]
  }],
  "timeline": [{
    "phase": "阶段名",
    "chapterRange": "约第X-Y章",
    "summary": "核心事件",
    "participants": ["角色"],
    "importance": "major|normal|minor"
  }],
  "worldbuilding": [{"category": "力量体系|地理|势力|规则|器物", "name": "词条", "content": "说明"}]
}
规则：主要人物保留完整关系与成长弧；次要人物精简；事件按时间顺序组织并划分清晰阶段。''';

    final user = StringBuffer();
    if (characters.isNotEmpty) {
      user.writeln('已知人物线索：${characters.join('、')}\n');
    }
    user.writeln('全书各阶段摘要（按时间先后）：');
    user.write(_cappedStageBody(stageSummaries));

    return [
      const LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: user.toString()),
    ];
  }

  static List<LLMMessage> continuationPrompt({
    required List<String> stageSummaries,
    required int upToChapter,
  }) {
    final sys = '''你是小说续写档案编辑。把原作第 1~$upToChapter 章的阶段摘要整合为【续写档案】JSON（只输出合法 JSON 对象，无代码块、无说明）。
Schema:
{
  "title": "书名（未知留空）",
  "author": "作者（未知省略）",
  "characters": [{
    "name": "主名",
    "aliases": ["别名"],
    "oneLine": "一句话定位",
    "role": "主角/反派/配角",
    "appearance": "外貌",
    "personality": "性格",
    "abilities": "能力",
    "currentState": "截至第$upToChapter章的精确现状（位置、伤势、心境、正面临的危机或决定）",
    "relationships": [{"target": "对象", "relation": "当前关系"}],
    "arc": [{"phase": "阶段名", "state": "该阶段状态"}]
  }],
  "timeline": [{
    "phase": "阶段名",
    "chapterRange": "约第X-Y章",
    "summary": "核心事件",
    "participants": ["角色"],
    "importance": "major|normal|minor"
  }],
  "worldbuilding": [{"category": "力量体系|地理|势力|规则|器物", "name": "词条", "content": "说明"}],
  "openThreads": [{"title": "未回收伏笔标题", "detail": "已埋线索与悬而未决之处", "plantedChapter": 12}],
  "activeArcs": ["截至第$upToChapter章正在推进中的剧情弧线"]
}
重点要求：
1. 每个重要角色的 currentState 必须精确到第 $upToChapter 章末尾的最新处境。
2. openThreads 只保留尚未解决/未回收的伏笔，已回收的不要列入。
3. activeArcs 列出当前尚未收束的主要矛盾与剧情线。''';

    final user = StringBuffer()
      ..writeln('原作第 1~$upToChapter 章阶段摘要（按时间先后）：')
      ..write(_cappedStageBody(stageSummaries));

    return [
      LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: user.toString()),
    ];
  }

  static SourceNovelProfileData parseFinal(
    String raw, {
    required String fallbackTitle,
    String? profileId,
  }) {
    final map = LLMJSONParser.decodeObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('终归并 JSON 解析失败');
    }
    return _buildProfile(
      map,
      fallbackTitle: fallbackTitle,
      profileId: profileId,
      continuationFromChapter: null,
    );
  }

  static SourceNovelProfileData parseContinuation(
    String raw, {
    required String fallbackTitle,
    required int upToChapter,
    String? profileId,
  }) {
    final map = LLMJSONParser.decodeObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('续写深度归并 JSON 解析失败');
    }
    return _buildProfile(
      map,
      fallbackTitle: fallbackTitle,
      profileId: profileId,
      continuationFromChapter: upToChapter,
    );
  }

  static SourceNovelProfileData _buildProfile(
    Map<String, dynamic> map, {
    required String fallbackTitle,
    String? profileId,
    required int? continuationFromChapter,
  }) {
    final rawTitle = map['title']?.toString().trim() ?? '';
    final title = rawTitle.isEmpty ? fallbackTitle : rawTitle;
    final rawAuthor = map['author']?.toString().trim();

    final characters = (map['characters'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonCharacter.fromJson(e.cast<String, dynamic>()))
        .where((c) => c.name.trim().isNotEmpty)
        .toList();

    final timeline = (map['timeline'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonEvent.fromJson(e.cast<String, dynamic>()))
        .where((e) => e.summary.trim().isNotEmpty)
        .toList();

    final worldbuilding = (map['worldbuilding'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonWorldEntry.fromJson(e.cast<String, dynamic>()))
        .where((w) => w.name.trim().isNotEmpty || w.content.trim().isNotEmpty)
        .toList();

    final openThreads =
        ((map['openThreads'] ?? map['open_threads']) as List? ?? const [])
            .whereType<Map>()
            .map((e) => CanonThread.fromJson(e.cast<String, dynamic>()))
            .where((t) => t.title.trim().isNotEmpty || t.detail.trim().isNotEmpty)
            .toList();

    final activeArcs = ((map['activeArcs'] ?? map['active_arcs']) as List? ??
            const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return SourceNovelProfileData(
      id: profileId,
      title: title,
      author: (rawAuthor == null || rawAuthor.isEmpty) ? null : rawAuthor,
      characters: characters,
      timeline: timeline,
      worldbuilding: worldbuilding,
      openThreads: openThreads,
      activeArcs: activeArcs,
      continuationFromChapter: continuationFromChapter,
    );
  }

  static String _formatMicro(int index, MicroSummary m) {
    final parts = <String>[];
    if (m.characters.isNotEmpty) {
      final chars = m.characters
          .map((c) {
            final extras = [
              if (c.traits != null && c.traits!.isNotEmpty) c.traits!,
              if (c.stateChange != null && c.stateChange!.isNotEmpty)
                '变化:${c.stateChange!}',
            ].join('；');
            return extras.isEmpty ? c.name : '${c.name}($extras)';
          })
          .join('、');
      parts.add('人物：$chars');
    }
    if (m.events.isNotEmpty) {
      final evs = m.events
          .map(
            (e) => e.participants.isEmpty
                ? e.summary
                : '${e.summary}[${e.participants.join('、')}]',
          )
          .join('；');
      parts.add('事件：$evs');
    }
    if (m.worldbuilding.isNotEmpty) {
      final wb = m.worldbuilding.map((w) => '${w.name}:${w.content}').join('；');
      parts.add('设定：$wb');
    }
    if (m.foreshadowing.isNotEmpty) {
      final fs = m.foreshadowing
          .map((f) => '${f.planted ? "[埋]" : "[收]"}${f.summary}')
          .join('；');
      parts.add('伏笔：$fs');
    }
    return '[$index] ${parts.join(' | ')}';
  }

  /// 按单段上限截断，并确保总长不超 finalInputCapChars（尾部优先保近期）
  static String _cappedStageBody(List<String> summaries) {
    if (summaries.isEmpty) return '（无阶段摘要）';
    final normalized = <String>[];
    for (var i = 0; i < summaries.length; i++) {
      var s = summaries[i].trim();
      if (s.length > perStageCapChars) {
        s = '${s.substring(0, perStageCapChars)}…';
      }
      normalized.add('--- 阶段 ${i + 1} ---\n$s');
    }
    final total = normalized.fold<int>(0, (sum, e) => sum + e.length + 2);
    if (total <= finalInputCapChars) {
      return normalized.join('\n\n');
    }
    // 首尾保留 + 中段按比例预算
    final perSlot =
        (finalInputCapChars ~/ normalized.length).clamp(400, perStageCapChars);
    return normalized
        .map(
          (s) => s.length <= perSlot ? s : '${s.substring(0, perSlot)}…',
        )
        .join('\n\n');
  }
}
