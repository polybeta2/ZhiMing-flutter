import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';
import 'package:zhiming/domain/source/source_batch_helper.dart';
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
}
