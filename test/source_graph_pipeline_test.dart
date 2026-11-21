import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/domain/models/source_profile_models.dart';

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
}
