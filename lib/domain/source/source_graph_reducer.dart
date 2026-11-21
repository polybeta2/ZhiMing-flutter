import 'dart:convert';
import 'dart:math' as math;

import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../models/source_profile_models.dart';
import 'source_graph_aggregator.dart';

/// 4 阶段专职归并在 `ScanReduces` 表中的确定性断点键（与旧 seq=1..99 互不冲突）
abstract final class GraphReduceSeq {
  static const int pass1Canon = 1000;
  static const int pass2CharBase = 2000;
  static const int pass3RelBase = 3000;
  static const int pass3World = 3500;
  static const int pass4Clues = 4000;
  static const int pass4Timeline = 4500;
}

class CanonSkeleton {
  const CanonSkeleton({
    required this.name,
    this.aliases = const [],
    this.role,
    this.camp,
    this.stance,
    this.importance = CanonImportance.normal,
  });

  final String name;
  final List<String> aliases;
  final String? role;
  final String? camp;
  final String? stance;
  final CanonImportance importance;

  Map<String, dynamic> toJson() => {
    'name': name,
    'aliases': aliases,
    if (role != null) 'role': role,
    if (camp != null) 'camp': camp,
    if (stance != null) 'stance': stance,
    'importance': importance.raw,
  };

  factory CanonSkeleton.fromJson(Map<String, dynamic> json) => CanonSkeleton(
    name: json['name']?.toString().trim() ?? '',
    aliases: (json['aliases'] as List? ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    role: _optStr(json['role']),
    camp: _optStr(json['camp']),
    stance: _optStr(json['stance']),
    importance: CanonImportance.fromRaw(json['importance']?.toString()),
  );
}

class CanonPassResult {
  const CanonPassResult({
    required this.camps,
    required this.skeletons,
    required this.aliasMap,
    required this.dropNames,
  });

  final List<CanonCamp> camps;
  final List<CanonSkeleton> skeletons;
  final Map<String, String> aliasMap;
  final Set<String> dropNames;

  String toJsonString() => jsonEncode({
    'camps': camps.map((e) => e.toJson()).toList(),
    'characters': skeletons.map((e) => e.toJson()).toList(),
    'not_characters': dropNames.toList(),
  });
}

class TimelinePassResult {
  const TimelinePassResult({
    required this.timeline,
    required this.activeArcs,
  });

  final List<CanonEvent> timeline;
  final List<String> activeArcs;
}

/// 4 阶段专职 Graph-Reduce 归并器：
/// Pass 1: Canon 实体消歧与阵营名录 → 生成权威 aliasMap
/// Pass 2: 角色分批建档（10-12人/批，25-48核心+重要配角）
/// Pass 3A/3B: 关系图谱归并（含明暗线与演变） + 世界观词条归并
/// Pass 4A/4B: 伏笔埋收生命周期对账 + 时间线里程碑与进行中主线
abstract final class SourceGraphReducer {
  static const int charBatchSize = 12;
  static const int maxProfileCharacters = 48;
  static const int relPairBatchSize = 48;

  // ---- Pass 1: Canon 实体消歧与阵营名录 ----

  static List<LLMMessage> pass1CanonPrompt(
    AggregatedSourceGraph graph, {
    required String title,
  }) {
    const sys = '''你是长篇小说实体消歧与名录编辑。阅读全书程序汇总的角色候选表，将同一角色的不同称呼/形态/别称合并到唯一权威主名下，划分阵营与重要度，并剔除非人物噪音词。
只输出合法 JSON 对象（不要代码块、不要任何说明文字）：
{
  "camps": [{"name": "阵营/势力名", "stance": "主角方|对立|中立|摇摆", "brief": "一句话说明"}],
  "characters": [
    {
      "name": "权威主名",
      "aliases": ["别称1", "形态名2"],
      "role": "主角|核心配角|反派|配角",
      "camp": "所属阵营名（独立则填独立）",
      "stance": "主角方|对立|中立|摇摆",
      "importance": "major|normal|minor"
    }
  ],
  "not_characters": ["不是具名角色的泛称/路人/物件/动词"]
}
规则：
1. 凡是同一角色的绰号、外貌代称、变身形态（如“小黑猫”与“罗娜”、“狼人”与“莫烬”），必须合并到同一个 characters 条目的 aliases 中，严禁拆成两个人；
2. 泛称/一次性无名龙套（如“无头战友”“路人”“娼馆老板娘”“地精小男孩”）列入 not_characters；
3. 主角与跨多章核心人物标 importance="major"，重要配角/阶段反派标 "normal"，偶尔出场的具名配角标 "minor"。''';

    final buf = StringBuffer()
      ..writeln('《$title》（全书共 ${graph.totalChapters} 章）候选角色汇总表：');
    final top = graph.orderedCandidates.take(120).toList();
    for (final c in top) {
      final aliases = c.aliases.isEmpty ? '无' : c.aliases.take(6).join('、');
      final roles = c.roleHints.isEmpty ? '未知' : c.roleHints.take(2).join('/');
      final camps = c.campHints.isEmpty ? '未知' : c.campHints.take(2).join('/');
      final traitHint = c.traits.isEmpty
          ? ''
          : '｜特征:${_trim(c.traits.take(2).join('；'), 50)}';
      buf.writeln(
        '- ${c.name}｜别称:$aliases｜跨${c.chapterCount}章(第${c.firstChapter}-${c.lastChapter}章,近15章:${c.recentHits})｜定位:$roles｜阵营:$camps$traitHint',
      );
    }

    return [
      const LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: buf.toString()),
    ];
  }

  static CanonPassResult parsePass1Canon(String raw) {
    final map = LLMJSONParser.decodeTopLevelObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('Pass 1 Canon 实体消歧 JSON 解析失败');
    }
    final camps = (map['camps'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonCamp.fromJson(e.cast<String, dynamic>()))
        .where((c) => c.name.isNotEmpty)
        .toList();
    final dropNames = (map['not_characters'] as List? ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final skeletons = <CanonSkeleton>[];
    final aliasMap = <String, String>{};
    final seenNames = <String>{};

    for (final item in (map['characters'] as List? ?? const [])) {
      if (item is! Map) continue;
      final sk = CanonSkeleton.fromJson(item.cast<String, dynamic>());
      if (sk.name.isEmpty || dropNames.contains(sk.name)) continue;
      if (!seenNames.add(sk.name)) continue;
      skeletons.add(sk);
      aliasMap[sk.name] = sk.name;
      for (final a in sk.aliases) {
        if (a.isNotEmpty && !dropNames.contains(a)) {
          aliasMap[a] = sk.name;
        }
      }
    }
    if (skeletons.isEmpty) {
      throw const FormatException('Pass 1 Canon 未解析出任何权威角色');
    }
    return CanonPassResult(
      camps: camps,
      skeletons: skeletons,
      aliasMap: aliasMap,
      dropNames: dropNames,
    );
  }

  /// 筛选进入 Pass 2 分批建档的 25-48 名核心+重要配角（过滤一次性路人）
  static List<CanonSkeleton> selectProfileTargets(
    CanonPassResult canon,
    AggregatedSourceGraph normalized, {
    int maxCharacters = maxProfileCharacters,
  }) {
    final scored = <({CanonSkeleton sk, int score})>[];
    for (final sk in canon.skeletons) {
      final cand = normalized.characterCandidates[sk.name];
      final chCount = cand?.chapterCount ?? 0;
      final recent = cand?.recentHits ?? 0;
      if (sk.importance == CanonImportance.minor && chCount < 2 && recent == 0) {
        continue;
      }
      final impWeight = switch (sk.importance) {
        CanonImportance.major => 1000,
        CanonImportance.normal => 300,
        CanonImportance.minor => 50,
      };
      scored.add((
        sk: sk,
        score: impWeight + chCount * 10 + recent * 20 + (cand?.mentions ?? 0),
      ));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final picked = scored.take(maxCharacters).map((e) => e.sk).toList();
    return picked.isNotEmpty ? picked : canon.skeletons.take(maxCharacters).toList();
  }

  // ---- Pass 2: 角色分批建档 ----

  static List<LLMMessage> pass2CharBatchPrompt({
    required String title,
    required List<CanonSkeleton> batch,
    required AggregatedSourceGraph normalized,
    required bool isContinuation,
    String? tailContextSnippet,
  }) {
    final upTo = normalized.totalChapters;
    final stateHint = isContinuation
        ? '"currentState": "截至第$upTo章末尾的精确现状（位置、形态、伤势、心境，≤80字）",'
        : '"currentState": "全书后期的最终或最新状态（≤60字）",';
    final sys = '''你是长篇小说人物建档编辑。根据以下已消歧角色的全书聚合轨迹，为这批角色逐一生成精炼、准确的结构化人物档案 JSON（只输出合法 JSON 对象，不要代码块或说明）。
Schema:
{
  "characters": [
    {
      "name": "必须与输入主名完全一致",
      "aliases": ["别名"],
      "oneLine": "一句话定位（注明性别/种族/身份，≤35字）",
      "role": "主角|核心配角|反派|配角",
      "camp": "阵营",
      "stance": "主角方|对立|中立|摇摆",
      "importance": "major|normal|minor",
      "appearance": "外貌特征（≤45字）",
      "personality": "性格与行为倾向（≤60字）",
      "abilities": "核心能力/道具/手段（≤60字）",
      $stateHint
      "arc": [{"phase": "阶段名", "state": "该阶段关键变化（≤45字）"}]
    }
  ]
}
规则：必须覆盖输入中的全部 ${batch.length} 名角色，不得遗漏或篡改主名；每名角色 arc 保留 2-4 个关键节点；严禁编造原文未给出的设定。''';

    final buf = StringBuffer()
      ..writeln('《$title》（共 $upTo 章）本批建档角色（共 ${batch.length} 人）：\n');

    for (final sk in batch) {
      final cand = normalized.characterCandidates[sk.name];
      final aliases = {...sk.aliases, ...?cand?.aliases}..remove(sk.name);
      buf.writeln(
        '### ${sk.name}（定位:${sk.role ?? "配角"}｜阵营:${sk.camp ?? "独立"}｜立场:${sk.stance ?? "中立"}｜重要度:${sk.importance.raw}｜别名:${aliases.isEmpty ? "无" : aliases.take(6).join("、")}）',
      );
      if (cand != null) {
        buf.writeln(
          '- 出场：跨 ${cand.chapterCount} 章（第${cand.firstChapter}-${cand.lastChapter}章，近15章出场 ${cand.recentHits} 次）',
        );
        if (cand.traits.isNotEmpty) {
          buf.writeln(
            '- 特征线索：${_trim(cand.traits.take(8).join("；"), 360)}',
          );
        }
        if (cand.stateChanges.isNotEmpty) {
          final changes = cand.stateChanges;
          final picked = changes.length <= 10
              ? changes
              : [...changes.take(3), ...changes.sublist(changes.length - 7)];
          buf.writeln(
            '- 状态演变：${picked.map((e) => "[第${e.chapterNo}章]${_trim(e.change, 60)}").join(" → ")}',
          );
        }
      }
      buf.writeln();
    }

    if (isContinuation &&
        tailContextSnippet != null &&
        tailContextSnippet.trim().isNotEmpty) {
      buf
        ..writeln('【截断处末尾正文参考（用于校准角色截至第 $upTo 章的精确现状）】')
        ..writeln(_trim(tailContextSnippet.trim(), 2600));
    }

    return [
      LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: buf.toString()),
    ];
  }

  static List<CanonCharacter> parsePass2CharBatch(String raw) {
    final map = LLMJSONParser.decodeTopLevelObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('Pass 2 角色分批建档 JSON 解析失败');
    }
    return ((map['characters'] ?? map['chars']) as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonCharacter.fromJson(e.cast<String, dynamic>()))
        .where((c) => c.name.trim().isNotEmpty)
        .toList();
  }

  // ---- Pass 3A: 关系图谱归并 ----

  static List<MapEntry<String, List<RawRelationEvidence>>> selectRelationPairs(
    AggregatedSourceGraph normalized, {
    required Set<String> allowedNames,
  }) {
    final grouped = normalized.groupedRelationsByPair(
      allowedNames: allowedNames,
    );
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final coA = normalized.cooccurrence[a.key] ?? 0;
        final coB = normalized.cooccurrence[b.key] ?? 0;
        final scoreA = a.value.length * 5 + coA;
        final scoreB = b.value.length * 5 + coB;
        return scoreB.compareTo(scoreA);
      });
    return entries;
  }

  static List<LLMMessage> pass3RelationsPrompt({
    required String title,
    required List<MapEntry<String, List<RawRelationEvidence>>> pairBatch,
    required Map<String, int> cooccurrence,
  }) {
    const sys = '''你是长篇小说人物关系图谱编辑。把每对角色跨越全书的互动证据归并为一条结构化关系边（含明/暗线、强度与演变节点）。
只输出合法 JSON 对象（不要代码块或说明）：
{
  "relations": [
    {
      "from": "角色A（权威主名）",
      "to": "角色B（权威主名）",
      "relationType": "亲友|盟友|爱恋|敌对|从属|竞争|未知",
      "label": "简短关系标签（2-8字，如：生死并肩/执念追杀）",
      "description": "当前关系全貌与核心张力（≤70字）",
      "strength": 4,
      "line": "明线|暗线",
      "firstChapter": 1,
      "lastChapter": 248,
      "evolution": [{"chapterLabel": "第1章", "state": "关系阶段变化（≤30字）"}],
      "evidence": "关键原文事件依据（≤40字）"
    }
  ]
}
规则：
1. 若某段关系存在隐瞒、秘密契约、单方不知情或幕后操控，line 标为 "暗线"，否则标为 "明线"；
2. strength 取 1-5（5 为核心羁绊或死敌，1 为浅层认识）；
3. 严禁修改输入中的权威角色名；忽略毫无实质关系的偶遇。''';

    final buf = StringBuffer()
      ..writeln('《$title》角色对互动证据（共 ${pairBatch.length} 组）：\n');
    for (final entry in pairBatch) {
      final names = entry.key.split('||');
      if (names.length != 2) continue;
      final evs = entry.value;
      final co = cooccurrence[entry.key] ?? 0;
      final picked = evs.length <= 8
          ? evs
          : [...evs.take(3), ...evs.sublist(evs.length - 5)];
      buf.writeln(
        '- ${names[0]} ↔ ${names[1]}（显式互动 ${evs.length} 次，同章共现 $co 次，章域 第${evs.first.chapterNo}-${evs.last.chapterNo}章）：',
      );
      for (final r in picked) {
        final evText = r.evidence != null ? '（${_trim(r.evidence!, 30)}）' : '';
        buf.writeln(
          '  * [第${r.chapterNo}章][${r.kind}/${r.line}] ${r.from}→${r.to}：${_trim(r.relation, 55)}$evText',
        );
      }
    }

    return [
      const LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: buf.toString()),
    ];
  }

  static List<CanonRelationEdge> parsePass3Relations(String raw) {
    final map = LLMJSONParser.decodeTopLevelObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('Pass 3A 关系图谱 JSON 解析失败');
    }
    return ((map['relations'] ?? map['edges']) as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonRelationEdge.fromJson(e.cast<String, dynamic>()))
        .where((r) => r.from.isNotEmpty && r.to.isNotEmpty && r.from != r.to)
        .toList();
  }

  // ---- Pass 3B: 世界观归并 ----

  static List<LLMMessage> pass3WorldPrompt(
    AggregatedSourceGraph graph, {
    required String title,
  }) {
    const sys = '''你是长篇小说世界观编辑。对全书抽取的世界观词条候选池去重合并，保留核心力量体系、地点、势力、规则与关键器物，并为每条配置 Lorebook 触发关键词。
只输出合法 JSON 对象（不要代码块或说明）：
{
  "worldbuilding": [
    {
      "category": "力量体系|地理|势力|规则|器物",
      "name": "规范词条名",
      "content": "凝练准确的设定说明（≤100字）",
      "keywords": ["触发词1", "别称2"]
    }
  ]
}
规则：合并同义词条（如“星光之城”与“群星城”合一并将别名放进 keywords），精选 15-30 条高价值长期设定，过滤一次性杂物。''';

    final ordered = graph.rawWorldEntries.values.toList()
      ..sort((a, b) => b.chapterNos.length.compareTo(a.chapterNos.length));
    final buf = StringBuffer()
      ..writeln('《$title》全书世界观候选池（共 ${ordered.length} 条，按跨章频次排序）：\n');
    var used = 0;
    for (final w in ordered.take(60)) {
      final line =
          '- [${w.category ?? "设定"}] ${w.name}（跨${w.chapterNos.length}章）：${_trim(w.contents.take(4).join("；"), 180)}';
      if (used + line.length > 14000 && used > 0) break;
      buf.writeln(line);
      used += line.length + 1;
    }

    return [
      const LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: buf.toString()),
    ];
  }

  static List<CanonWorldEntry> parsePass3World(String raw) {
    final map = LLMJSONParser.decodeTopLevelObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('Pass 3B 世界观归并 JSON 解析失败');
    }
    return ((map['worldbuilding'] ?? map['world']) as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonWorldEntry.fromJson(e.cast<String, dynamic>()))
        .where((w) => w.name.isNotEmpty)
        .toList();
  }

  // ---- Pass 4A: 伏笔生命周期对账 ----

  static List<LLMMessage> pass4CluesPrompt(
    AggregatedSourceGraph graph, {
    required String title,
    required bool isContinuation,
  }) {
    final upTo = graph.totalChapters;
    final focus = isContinuation
        ? '重点完整保留所有截至第 $upTo 章仍未解决（open）或仅部分推进（partial）的伏笔，同时保留关键已回收（resolved）主线大伏笔以供时间线对照。目标产出 20-40 条高质量、无重复的伏笔台账。'
        : '完整梳理全书核心伏笔的埋设与回收闭环，产出 15-35 条高质量伏笔台账。';
    final sys = '''你是长篇小说伏笔审计与生命周期对账编辑。下面提供全书按真实章号排列的【新埋伏笔池】与【回收/揭晓池】，请完成跨章因果配对、合并重复条目、精确标注埋设章号与回收章号。
只输出合法 JSON 对象（不要代码块或说明）：
{
  "threads": [
    {
      "title": "伏笔简明标题（≤20字）",
      "detail": "已埋线索与悬念核心（≤80字）",
      "status": "open|partial|resolved",
      "plantedChapter": 1,
      "resolvedChapter": null,
      "involvedCharacters": ["权威角色名"],
      "relatedEventSummary": "关联关键事件一句（≤30字）",
      "payoffDetail": "若 partial/resolved，写明在何处揭晓了什么（≤60字，否则省略）"
    }
  ]
}
规则：
1. $focus
2. 同一悬念在不同章节被反复暗示时，合并为一条，plantedChapter 取最早埋设章号；
3. 严禁把已在后文明确解开的悬念错标为 open，也严禁把尚未彻底揭晓的大谜团错标为 resolved（若仅揭晓一半标为 partial）；
4. involvedCharacters 必须使用输入中的权威角色名。''';

    final planted = graph.rawClues.where((c) => c.planted).toList();
    final resolved = graph.rawClues.where((c) => !c.planted).toList();

    final buf = StringBuffer()
      ..writeln('《$title》（共 $upTo 章）全书伏笔证据池：\n')
      ..writeln('【一、新埋伏笔池（共 ${planted.length} 条）】');

    var used = 0;
    const plantedBudget = 13000;
    final selectedPlanted = _sampleSpread(planted, maxItems: 140);
    for (final c in selectedPlanted) {
      final who = c.characters.isEmpty ? '' : '[${c.characters.take(3).join("、")}]';
      final line = '- [第${c.chapterNo}章]$who ${_trim(c.summary, 85)}';
      if (used + line.length > plantedBudget && used > 0) break;
      buf.writeln(line);
      used += line.length + 1;
    }

    buf.writeln('\n【二、回收/揭晓池（共 ${resolved.length} 条）】');
    var resUsed = 0;
    const resBudget = 5500;
    for (final c in resolved) {
      final who = c.characters.isEmpty ? '' : '[${c.characters.take(3).join("、")}]';
      final hint = (c.targetHint != null && c.targetHint!.isNotEmpty)
          ? ' → 回指:${_trim(c.targetHint!, 40)}'
          : '';
      final line = '- [第${c.chapterNo}章]$who ${_trim(c.summary, 80)}$hint';
      if (resUsed + line.length > resBudget && resUsed > 0) break;
      buf.writeln(line);
      resUsed += line.length + 1;
    }

    return [
      LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: buf.toString()),
    ];
  }

  static List<CanonThread> parsePass4Clues(String raw) {
    final map = LLMJSONParser.decodeTopLevelObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('Pass 4A 伏笔对账 JSON 解析失败');
    }
    return ((map['threads'] ?? map['openThreads'] ?? map['foreshadowings'])
                as List? ??
            const [])
        .whereType<Map>()
        .map((e) => CanonThread.fromJson(e.cast<String, dynamic>()))
        .where((t) => t.title.trim().isNotEmpty)
        .toList();
  }

  // ---- Pass 4B: 时间线里程碑与进行中主线 ----

  static List<LLMMessage> pass4TimelinePrompt(
    AggregatedSourceGraph graph, {
    required String title,
    required List<CanonThread> reconciledThreads,
    required bool isContinuation,
  }) {
    final upTo = graph.totalChapters;
    const sys = '''你是长篇小说剧情时间线编辑。根据全书按真实章号排列的事件流与已对账伏笔标题，梳理出清晰分阶段的剧情里程碑时间线与当前进行中的主线弧。
只输出合法 JSON 对象（不要代码块或说明）：
{
  "timeline": [
    {
      "id": "tl_1",
      "phase": "剧情阶段/篇名",
      "chapterRange": "第1-5章",
      "chapterStart": 1,
      "chapterEnd": 5,
      "inWorldTime": "书内时间锚点（若有则填，否则省略）",
      "summary": "该节点的核心事件与因果推进（≤80字）",
      "participants": ["权威角色名"],
      "linkedClueTitles": ["关联的伏笔标题（须与输入伏笔清单一致，无则空数组）"],
      "importance": "major|normal|minor"
    }
  ],
  "activeArcs": ["截至书末仍在推进中的核心主线/冲突弧（3-6条）"]
}
规则：
1. 按时间顺序输出 15-32 个关键里程碑，均匀覆盖开篇、中段转折与收尾/截断处，chapterStart 与 chapterEnd 必须填准确整数；
2. 关联伏笔标题从提供的伏笔清单中精确挑选。''';

    final buf = StringBuffer()
      ..writeln(
        '《$title》（共 $upTo 章${isContinuation ? "，续写截断于第$upTo章" : ""}）事件流：',
      );
    if (reconciledThreads.isNotEmpty) {
      buf.writeln(
        '\n【已对账伏笔标题清单】\n${reconciledThreads.take(40).map((t) => "- [${t.status}|第${t.plantedChapter ?? "?"}章] ${t.title}").join("\n")}\n',
      );
    }

    final prioritized = _selectTimelineEvents(graph.rawEvents, maxBudget: 17000);
    buf.writeln('【全书按章序事件流（精选 ${prioritized.length}/${graph.rawEvents.length} 条）】');
    for (final ev in prioritized) {
      final t = (ev.inWorldTime != null && ev.inWorldTime!.isNotEmpty)
          ? '|${ev.inWorldTime}'
          : '';
      final p = ev.participants.isEmpty
          ? ''
          : '(${ev.participants.take(4).join("、")})';
      buf.writeln('- [第${ev.chapterNo}章$t][${ev.importance}] ${ev.summary}$p');
    }

    return [
      const LLMMessage(role: LLMRole.system, content: sys),
      LLMMessage(role: LLMRole.user, content: buf.toString()),
    ];
  }

  static TimelinePassResult parsePass4Timeline(String raw) {
    final map = LLMJSONParser.decodeTopLevelObject(raw, (m) => m);
    if (map == null) {
      throw const FormatException('Pass 4B 时间线归并 JSON 解析失败');
    }
    final timeline = ((map['timeline'] ?? map['events']) as List? ?? const [])
        .whereType<Map>()
        .map((e) => CanonEvent.fromJson(e.cast<String, dynamic>()))
        .where((e) => e.summary.trim().isNotEmpty)
        .toList();
    final activeArcs = ((map['activeArcs'] ?? map['active_arcs']) as List? ??
            const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return TimelinePassResult(timeline: timeline, activeArcs: activeArcs);
  }

  // ---- Helpers ----

  static List<T> _sampleSpread<T>(List<T> items, {required int maxItems}) {
    if (items.length <= maxItems) return items;
    final out = <T>[];
    final head = (maxItems * 0.25).round();
    final tail = (maxItems * 0.35).round();
    final midBudget = maxItems - head - tail;
    out.addAll(items.take(head));
    final midStart = head;
    final midEnd = items.length - tail;
    if (midBudget > 0 && midEnd > midStart) {
      final step = (midEnd - midStart) / midBudget;
      for (var i = 0; i < midBudget; i++) {
        final idx = (midStart + i * step).floor().clamp(midStart, midEnd - 1);
        out.add(items[idx]);
      }
    }
    out.addAll(items.sublist(items.length - tail));
    return out;
  }

  static List<IndexedRawEvent> _selectTimelineEvents(
    List<IndexedRawEvent> events, {
    required int maxBudget,
  }) {
    if (events.isEmpty) return const [];
    final major = events.where((e) => e.importance == 'major').toList();
    final others = events.where((e) => e.importance != 'major').toList();
    final picked = <IndexedRawEvent>[];
    var used = 0;

    for (final e in major) {
      final cost = e.summary.length + 32;
      if (used + cost > maxBudget && picked.isNotEmpty) break;
      picked.add(e);
      used += cost;
    }
    if (used < maxBudget && others.isNotEmpty) {
      final spread = _sampleSpread(others, maxItems: 120);
      for (final e in spread) {
        final cost = e.summary.length + 32;
        if (used + cost > maxBudget) break;
        picked.add(e);
        used += cost;
      }
    }
    picked.sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
    return picked;
  }

  static String _trim(String s, int maxLen) =>
      s.length <= maxLen ? s : '${s.substring(0, math.max(1, maxLen - 1))}…';
}

String? _optStr(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
