import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
import 'package:zhiming/domain/source/novel_local_indexer.dart';
import 'package:zhiming/domain/source/source_batch_helper.dart';
import 'package:zhiming/domain/source/source_graph_aggregator.dart';
import 'package:zhiming/domain/source/source_graph_reducer.dart';
import 'package:zhiming/domain/source/source_micro_summarizer.dart';
import 'package:zhiming/domain/source/source_scan_chunker.dart';

void main() {
  group('SourceNovelProfileData v2 additive contract', () {
    test('round-trips camps, relations, enriched threads and timeline', () {
      final profile = SourceNovelProfileData(
        id: 'p1',
        title: '诡异降临',
        camps: const [
          CanonCamp(name: '星光之城', stance: '中立', brief: '城主庇佑之地'),
        ],
        characters: const [
          CanonCharacter(
            name: '莫烬',
            aliases: ['末路灰烬', '狼人行商'],
            camp: '独立',
            stance: '主角方',
            importance: CanonImportance.major,
            currentState: '在群星之城接住力竭的月莲',
          ),
        ],
        relations: const [
          CanonRelationEdge(
            from: '莫烬',
            to: '爱丽丝',
            relationType: '敌对',
            label: '执念追杀',
            description: '爱丽丝执着于永远占有莫烬并反复追杀他',
            strength: 5,
            line: '暗线',
            firstChapter: 1,
            lastChapter: 250,
            evolution: [
              CanonRelationEvolution(chapterLabel: '第1章', state: '追杀至钟表屋'),
            ],
            evidence: '第1章爱丽丝称莫烬为哥哥/小偷',
          ),
        ],
        timeline: const [
          CanonEvent(
            id: 'ev_1',
            phase: '降临前夕',
            chapterRange: '第1-3章',
            chapterStart: 1,
            chapterEnd: 3,
            inWorldTime: '2029年7月8日',
            summary: '莫烬借银色怀表回到现实公寓并失忆',
            participants: ['莫烬', '薇拉', '爱丽丝'],
            linkedClueTitles: ['银色怀表来历'],
            importance: CanonImportance.major,
          ),
        ],
        worldbuilding: const [
          CanonWorldEntry(
            category: '地点',
            name: '星光之城',
            content: '受城主庇佑可减少低语侵蚀',
            keywords: ['星光之城', '群星城', '石门'],
          ),
        ],
        openThreads: const [
          CanonThread(
            title: '银色怀表来历',
            detail: '薇拉赠予莫烬的破碎怀表可扭曲时间',
            plantedChapter: 1,
            status: 'partial',
            resolvedChapter: null,
            involvedCharacters: ['莫烬', '薇拉'],
            relatedEventSummary: '钟表屋离别',
            payoffDetail: '中期揭示与轮回有关但未完全解开',
          ),
        ],
      );

      final decoded = SourceNovelProfileData.fromJsonString(
        profile.toJsonString(),
      );
      expect(decoded.camps.single.name, '星光之城');
      expect(decoded.characters.single.camp, '独立');
      expect(decoded.characters.single.importance, CanonImportance.major);
      expect(decoded.relations.single.line, '暗线');
      expect(decoded.relations.single.evolution.single.chapterLabel, '第1章');
      expect(decoded.timeline.single.chapterStart, 1);
      expect(decoded.timeline.single.inWorldTime, '2029年7月8日');
      expect(decoded.timeline.single.linkedClueTitles, ['银色怀表来历']);
      expect(decoded.worldbuilding.single.keywords, contains('群星城'));
      expect(decoded.openThreads.single.status, 'partial');
      expect(decoded.openThreads.single.involvedCharacters, ['莫烬', '薇拉']);
    });

    test('loads legacy v1 profile JSON with safe defaults', () {
      final legacyJson = jsonEncode({
        'id': 'old-1',
        'title': '旧书',
        'characters': [
          {'name': '林深', 'aliases': ['阿深']},
        ],
        'timeline': [
          {'summary': '初入雾港', 'participants': ['林深']},
        ],
        'worldbuilding': [
          {'category': '规则', 'name': '低语', 'content': '侵蚀理智'},
        ],
        'openThreads': [
          {'title': '钟楼秘密', 'detail': '午夜停摆', 'plantedChapter': 3},
        ],
      });

      final decoded = SourceNovelProfileData.fromJsonString(legacyJson);
      expect(decoded.camps, isEmpty);
      expect(decoded.relations, isEmpty);
      expect(decoded.characters.single.importance, CanonImportance.normal);
      expect(decoded.worldbuilding.single.keywords, isEmpty);
      expect(decoded.openThreads.single.status, 'open');
      expect(decoded.openThreads.single.involvedCharacters, isEmpty);
    });
  });

  group('SourceScanChunker & MicroSummary & SourceBatchHelper', () {
    test('long chapter split preserves real chapterNo and part metadata', () {
      final longBody = '钟声响起，迷雾涌动。' * 500; // 5000 chars -> 2 parts
      final book = '第1章 雾起\n$longBody\n\n第2章 交易\n莫烬来到下城区。';
      final chunks = SourceScanChunker.chunks(book, mode: ScanMode.full);
      expect(chunks.length, 3);
      expect(chunks[0].chapterNo, 1);
      expect(chunks[0].partIndex, 0);
      expect(chunks[0].partCount, 2);
      expect(chunks[0].chapterTitle, contains('第1章'));
      expect(chunks[1].chapterNo, 1);
      expect(chunks[1].partIndex, 1);
      expect(chunks[1].partCount, 2);
      expect(chunks[2].chapterNo, 2);
      expect(chunks[2].partCount, 1);
    });

    test('MicroSummary parses aliases, relations, inWorldTime and targetHint', () {
      const raw = '''
{
  "chapter": 50,
  "characters": [{"name": "林医生", "aliases": ["老林"], "role_hint": "配角", "camp_hint": "星光之城", "traits": "炼金术师", "state_change": "重逢莫烬"}],
  "relations": [{"from": "莫烬", "to": "林医生", "relation": "欠债2000魂", "kind": "盟友", "line": "明线", "evidence": "妃莉娅代付"}],
  "events": [{"summary": "进入星光之城", "in_world_time": "次日黄昏", "participants": ["莫烬", "妃莉娅"], "importance": "major"}],
  "worldbuilding": [{"name": "星光之城", "category": "地点", "content": "城主庇佑"}],
  "foreshadowing": [{"summary": "莫烬对林医生有莫名熟悉感", "planted": true, "characters": ["莫烬", "林医生"], "target_hint": ""}]
}
''';
      final parsed = SourceMicroSummarizer.parse(raw);
      expect(parsed.chapterNo, 50);
      expect(parsed.characters.single.aliases, ['老林']);
      expect(parsed.characters.single.campHint, '星光之城');
      expect(parsed.relations.single.from, '莫烬');
      expect(parsed.relations.single.to, '林医生');
      expect(parsed.events.single.inWorldTime, '次日黄昏');
      expect(parsed.events.single.importance, 'major');
      expect(parsed.worldbuilding.single.category, '地点');
      expect(parsed.foreshadowing.single.characters, ['莫烬', '林医生']);
    });

    test('SourceBatchHelper parses duplicate chapterNo rows from multi-part chapter', () {
      const raw = '''
{"chapter": 1, "characters": [{"name": "莫烬", "traits": "冷静"}], "relations": [{"from": "莫烬", "to": "薇拉", "relation": "同伴", "kind": "亲友", "line": "明线"}], "events": [{"summary": "上半段事件", "participants": ["莫烬"]}], "worldbuilding": [], "foreshadowing": [{"summary": "伏笔A", "planted": true, "characters": ["莫烬"]}]}
{"chapter": 1, "characters": [{"name": "爱丽丝", "aliases": ["人偶女孩"]}], "relations": [], "events": [{"summary": "下半段事件", "participants": ["爱丽丝"]}], "worldbuilding": [], "foreshadowing": []}
''';
      final entries = SourceBatchHelper.parseBatchEntries(raw);
      expect(entries.length, 2);
      expect(entries[0].chapterNo, 1);
      expect(entries[1].chapterNo, 1);
      final merged = SourceBatchHelper.parseBatchOutput(raw);
      expect(merged[0]!.characters.length, 2);
      expect(merged[0]!.events.length, 2);
    });
  });

  group('NovelLocalIndexer noise filtering', () {
    test('strips protagonist+adverb glued noise and action verbs', () {
      const chapter = '''
第1章 测试
莫烬说道：“走吧。”莫烬问道：“谁在那里？”莫烬笑道：“有意思。”
莫烬急忙说道：“快躲开！”莫烬急忙转身。莫烬急忙开口。
莫烬继续说道：“接着聊。”莫烬继续看着前方。莫烬继续沉默。
转过头来问道：“你是谁？”转过头来看向门口。转过头来皱眉。
开口说道：“别吵。”开口问道：“懂了吗？”开口笑道：“行。”
佩洛冷笑道：“蠢货。”佩洛问道：“准备好了吗？”佩洛转身离开。
''';
      final indexer = NovelLocalIndexer.fromRawText(chapter);
      final names = indexer.topEntities.map((e) => e.name).toList();
      expect(names, containsAll(['莫烬', '佩洛']));
      expect(names, isNot(contains('莫烬急忙')));
      expect(names, isNot(contains('莫烬继续')));
      expect(names, isNot(contains('转过头来')));
      expect(names, isNot(contains('开口')));
    });
  });

  group('SourceGraphAggregator', () {
    test('aggregates all chapters losslessly and rewrites names via aliasMap', () {
      final records = <({int chapterNo, MicroSummary summary})>[
        (
          chapterNo: 1,
          summary: const MicroSummary(
            chapterNo: 1,
            characters: [
              MicroCharacter(name: '莫烬', aliases: ['末路灰烬'], traits: '冷静'),
              MicroCharacter(name: '罗娜', traits: '群星城主', campHint: '群星之城'),
            ],
            relations: [
              MicroRelation(
                from: '莫烬',
                to: '罗娜',
                relation: '初识',
                kind: '盟友',
                line: '明线',
              ),
            ],
            events: [
              MicroEvent(
                summary: '莫烬遇见罗娜',
                inWorldTime: '第1天',
                participants: ['莫烬', '罗娜'],
                importance: 'major',
              ),
            ],
            foreshadowing: [
              MicroForeshadow(
                summary: '罗娜的铃铛来源不明',
                planted: true,
                characters: ['罗娜'],
              ),
            ],
          ),
        ),
        (
          chapterNo: 248,
          summary: const MicroSummary(
            chapterNo: 248,
            characters: [
              MicroCharacter(name: '小黑猫', stateChange: '昏迷被帕梅拉带走'),
              MicroCharacter(name: '路人甲', traits: '背景板'),
            ],
            relations: [
              MicroRelation(
                from: '末路灰烬',
                to: '小黑猫',
                relation: '托付群星之城',
                kind: '盟友',
                line: '暗线',
              ),
            ],
            events: [
              MicroEvent(
                summary: '小黑猫交出铃铛',
                participants: ['小黑猫', '末路灰烬'],
                importance: 'major',
              ),
            ],
            foreshadowing: [
              MicroForeshadow(
                summary: '铃铛是城主权柄核心',
                planted: false,
                characters: ['小黑猫'],
                targetHint: '罗娜的铃铛来源不明',
              ),
            ],
          ),
        ),
      ];

      final raw = SourceGraphAggregator.build(records, totalChapters: 250);
      expect(raw.rawEvents.length, 2);
      expect(raw.rawEvents[0].chapterNo, 1);
      expect(raw.rawEvents[1].chapterNo, 248);
      expect(raw.rawClues.length, 2);

      final normalized = raw.applyAliasMap(
        const {'莫烬': '莫烬', '末路灰烬': '莫烬', '罗娜': '罗娜', '小黑猫': '罗娜'},
        dropNames: const {'路人甲'},
      );
      expect(normalized.characterCandidates.containsKey('路人甲'), isFalse);
      expect(normalized.characterCandidates['罗娜']!.chapterNos, {1, 248});
      expect(
        normalized.characterCandidates['罗娜']!.stateChanges.single.chapterNo,
        248,
      );
      expect(normalized.rawEvents[1].participants, containsAll(['莫烬', '罗娜']));
      expect(normalized.rawClues[1].characters, ['罗娜']);

      final pairs = normalized.groupedRelationsByPair(
        allowedNames: {'莫烬', '罗娜'},
      );
      expect(pairs.length, 1);
      expect(pairs.values.single.length, 2);
    });
  });

  group('SourceGraphReducer 4-pass parsers & builders', () {
    test('parses Pass 1 canon entity resolution and builds aliasMap', () {
      const raw = '''
{
  "camps": [{"name": "群星之城", "stance": "中立", "brief": "庇护所"}],
  "characters": [
    {"name": "罗娜", "aliases": ["小黑猫", "群星城主"], "role": "核心配角", "camp": "群星之城", "stance": "主角方", "importance": "major"},
    {"name": "莫烬", "aliases": ["末路灰烬"], "role": "主角", "camp": "独立", "stance": "主角方", "importance": "major"}
  ],
  "not_characters": ["路人甲", "无头战友"]
}
''';
      final res = SourceGraphReducer.parsePass1Canon(raw);
      expect(res.camps.single.name, '群星之城');
      expect(res.aliasMap['小黑猫'], '罗娜');
      expect(res.aliasMap['末路灰烬'], '莫烬');
      expect(res.dropNames, containsAll(['路人甲', '无头战友']));
    });

    test('parses Pass 3 relations and Pass 4 reconciled clues & timeline', () {
      const relRaw = '''
{
  "relations": [
    {
      "from": "莫烬",
      "to": "罗娜",
      "relationType": "盟友",
      "label": "托付群星之城",
      "description": "罗娜力竭变回黑猫前将城主权柄托付",
      "strength": 4,
      "line": "暗线",
      "firstChapter": 50,
      "lastChapter": 250,
      "evolution": [{"chapterLabel": "第248章", "state": "舍弃力量化为小黑猫"}]
    }
  ]
}
''';
      final rels = SourceGraphReducer.parsePass3Relations(relRaw);
      expect(rels.single.from, '莫烬');
      expect(rels.single.line, '暗线');
      expect(rels.single.lastChapter, 250);

      const clueRaw = '''
{
  "threads": [
    {
      "title": "罗娜的铃铛权柄",
      "detail": "第1章起提及的铃铛实为群星之城权柄载体",
      "status": "resolved",
      "plantedChapter": 1,
      "resolvedChapter": 248,
      "involvedCharacters": ["罗娜", "月莲"],
      "relatedEventSummary": "罗娜交出铃铛",
      "payoffDetail": "第248章移交月莲"
    },
    {
      "title": "主的真实意图",
      "detail": "3号载体临死宣称主的力量必须归还",
      "status": "open",
      "plantedChapter": 249,
      "involvedCharacters": ["月莲", "莫烬"]
    }
  ]
}
''';
      final clues = SourceGraphReducer.parsePass4Clues(clueRaw);
      expect(clues.length, 2);
      expect(clues[0].status, 'resolved');
      expect(clues[0].resolvedChapter, 248);
      expect(clues[1].status, 'open');
      expect(clues[1].plantedChapter, 249);
    });
  });
}
