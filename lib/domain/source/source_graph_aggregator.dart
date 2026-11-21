import 'dart:math' as math;

import 'source_micro_summarizer.dart';

class CharacterCandidate {
  CharacterCandidate({
    required this.name,
    Set<String>? aliases,
    this.mentions = 0,
    Set<int>? chapterNos,
    this.recentHits = 0,
    Set<String>? roleHints,
    Set<String>? campHints,
    List<String>? traits,
    List<({int chapterNo, String change})>? stateChanges,
  }) : aliases = aliases ?? <String>{},
       chapterNos = chapterNos ?? <int>{},
       roleHints = roleHints ?? <String>{},
       campHints = campHints ?? <String>{},
       traits = traits ?? <String>[],
       stateChanges = stateChanges ?? <({int chapterNo, String change})>[];

  final String name;
  final Set<String> aliases;
  int mentions;
  final Set<int> chapterNos;
  int recentHits;
  final Set<String> roleHints;
  final Set<String> campHints;
  final List<String> traits;
  final List<({int chapterNo, String change})> stateChanges;

  int get firstChapter => chapterNos.isEmpty ? 0 : chapterNos.reduce(math.min);
  int get lastChapter => chapterNos.isEmpty ? 0 : chapterNos.reduce(math.max);
  int get chapterCount => chapterNos.length;

  void mergeFrom(CharacterCandidate other, {required int recentStart}) {
    if (other.name != name) aliases.add(other.name);
    aliases.addAll(other.aliases);
    aliases.remove(name);
    mentions += other.mentions;
    chapterNos.addAll(other.chapterNos);
    recentHits = chapterNos.where((c) => c >= recentStart).length;
    roleHints.addAll(other.roleHints);
    campHints.addAll(other.campHints);
    for (final t in other.traits) {
      if (!traits.contains(t)) traits.add(t);
    }
    stateChanges.addAll(other.stateChanges);
    stateChanges.sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
  }
}

class IndexedRawEvent {
  const IndexedRawEvent({
    required this.id,
    required this.chapterNo,
    this.inWorldTime,
    required this.summary,
    this.participants = const [],
    this.importance = 'normal',
  });

  final String id;
  final int chapterNo;
  final String? inWorldTime;
  final String summary;
  final List<String> participants;
  final String importance;
}

class RawRelationEvidence {
  const RawRelationEvidence({
    required this.chapterNo,
    required this.from,
    required this.to,
    required this.relation,
    this.kind = '未知',
    this.line = '明线',
    this.evidence,
  });

  final int chapterNo;
  final String from;
  final String to;
  final String relation;
  final String kind;
  final String line;
  final String? evidence;
}

class RawClueRecord {
  const RawClueRecord({
    required this.chapterNo,
    required this.planted,
    required this.summary,
    this.characters = const [],
    this.targetHint,
  });

  final int chapterNo;
  final bool planted;
  final String summary;
  final List<String> characters;
  final String? targetHint;
}

class RawWorldCandidate {
  RawWorldCandidate({
    required this.name,
    this.category,
    List<String>? contents,
    Set<int>? chapterNos,
  }) : contents = contents ?? <String>[],
       chapterNos = chapterNos ?? <int>{};

  final String name;
  String? category;
  final List<String> contents;
  final Set<int> chapterNos;
}

class AggregatedSourceGraph {
  const AggregatedSourceGraph({
    required this.totalChapters,
    required this.characterCandidates,
    required this.rawEvents,
    required this.rawRelations,
    required this.rawClues,
    required this.rawWorldEntries,
    required this.cooccurrence,
  });

  final int totalChapters;
  final Map<String, CharacterCandidate> characterCandidates;
  final List<IndexedRawEvent> rawEvents;
  final List<RawRelationEvidence> rawRelations;
  final List<RawClueRecord> rawClues;
  final Map<String, RawWorldCandidate> rawWorldEntries;
  final Map<String, int> cooccurrence;

  List<CharacterCandidate> get orderedCandidates {
    final list = characterCandidates.values.toList()
      ..sort((a, b) {
        final scoreA = a.chapterCount * 10 + a.mentions + a.recentHits * 6;
        final scoreB = b.chapterCount * 10 + b.mentions + b.recentHits * 6;
        return scoreB.compareTo(scoreA);
      });
    return list;
  }

  /// Pass 1 完成后由代码确定性重写全书事件、关系边、伏笔和角色候选池。
  AggregatedSourceGraph applyAliasMap(
    Map<String, String> aliasMap, {
    Set<String> dropNames = const {},
  }) {
    final recentStart = math.max(1, totalChapters - 14);
    String? resolve(String raw) {
      final clean = raw.trim();
      if (clean.isEmpty || dropNames.contains(clean)) return null;
      final mapped = aliasMap[clean] ?? clean;
      if (dropNames.contains(mapped)) return null;
      return mapped;
    }

    final mergedChars = <String, CharacterCandidate>{};
    for (final cand in characterCandidates.values) {
      final canon = resolve(cand.name);
      if (canon == null) continue;
      final dst = mergedChars.putIfAbsent(
        canon,
        () => CharacterCandidate(name: canon),
      );
      dst.mergeFrom(cand, recentStart: recentStart);
    }

    final normEvents = <IndexedRawEvent>[];
    for (final ev in rawEvents) {
      final parts = <String>[];
      final seen = <String>{};
      for (final p in ev.participants) {
        final r = resolve(p);
        if (r != null && seen.add(r)) parts.add(r);
      }
      normEvents.add(
        IndexedRawEvent(
          id: ev.id,
          chapterNo: ev.chapterNo,
          inWorldTime: ev.inWorldTime,
          summary: ev.summary,
          participants: parts,
          importance: ev.importance,
        ),
      );
    }

    final normRelations = <RawRelationEvidence>[];
    for (final rel in rawRelations) {
      final a = resolve(rel.from);
      final b = resolve(rel.to);
      if (a == null || b == null || a == b) continue;
      normRelations.add(
        RawRelationEvidence(
          chapterNo: rel.chapterNo,
          from: a,
          to: b,
          relation: rel.relation,
          kind: rel.kind,
          line: rel.line,
          evidence: rel.evidence,
        ),
      );
    }

    final normClues = <RawClueRecord>[];
    for (final clue in rawClues) {
      final chars = <String>[];
      final seen = <String>{};
      for (final c in clue.characters) {
        final r = resolve(c);
        if (r != null && seen.add(r)) chars.add(r);
      }
      normClues.add(
        RawClueRecord(
          chapterNo: clue.chapterNo,
          planted: clue.planted,
          summary: clue.summary,
          characters: chars,
          targetHint: clue.targetHint,
        ),
      );
    }

    return AggregatedSourceGraph(
      totalChapters: totalChapters,
      characterCandidates: mergedChars,
      rawEvents: normEvents,
      rawRelations: normRelations,
      rawClues: normClues,
      rawWorldEntries: rawWorldEntries,
      cooccurrence: _computeCooccurrence(normEvents),
    );
  }

  /// 按无序角色对聚合关系证据（保留时间顺序）。
  Map<String, List<RawRelationEvidence>> groupedRelationsByPair({
    Set<String>? allowedNames,
  }) {
    final map = <String, List<RawRelationEvidence>>{};
    for (final rel in rawRelations) {
      if (allowedNames != null &&
          (!allowedNames.contains(rel.from) ||
              !allowedNames.contains(rel.to))) {
        continue;
      }
      final key = pairKey(rel.from, rel.to);
      map.putIfAbsent(key, () => []).add(rel);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
    }
    return map;
  }

  static String pairKey(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a||$b' : '$b||$a';

  static Map<String, int> _computeCooccurrence(List<IndexedRawEvent> events) {
    final counts = <String, int>{};
    for (final ev in events) {
      final ps = ev.participants;
      for (var i = 0; i < ps.length; i++) {
        for (var j = i + 1; j < ps.length; j++) {
          final key = pairKey(ps[i], ps[j]);
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    return counts;
  }
}

/// 0-Token 零损程序化聚合器：取代旧版 40 章→1500 字散文漏斗与 12000 字静默截断。
abstract final class SourceGraphAggregator {
  static AggregatedSourceGraph build(
    List<({int chapterNo, MicroSummary summary})> records, {
    required int totalChapters,
  }) {
    final sorted = [...records]
      ..sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
    final recentStart = math.max(1, totalChapters - 14);
    final chars = <String, CharacterCandidate>{};
    final events = <IndexedRawEvent>[];
    final relations = <RawRelationEvidence>[];
    final clues = <RawClueRecord>[];
    final worlds = <String, RawWorldCandidate>{};
    final perChapterSeq = <int, int>{};

    for (final rec in sorted) {
      final chNo = rec.chapterNo;
      final m = rec.summary;

      for (final c in m.characters) {
        final name = c.name.trim();
        if (name.isEmpty) continue;
        final cand = chars.putIfAbsent(
          name,
          () => CharacterCandidate(name: name),
        );
        cand.mentions += 1;
        cand.chapterNos.add(chNo);
        cand.recentHits = cand.chapterNos.where((n) => n >= recentStart).length;
        for (final a in c.aliases) {
          final cleanA = a.trim();
          if (cleanA.isNotEmpty && cleanA != name) cand.aliases.add(cleanA);
        }
        if (c.roleHint != null && c.roleHint!.isNotEmpty) {
          cand.roleHints.add(c.roleHint!);
        }
        if (c.campHint != null && c.campHint!.isNotEmpty) {
          cand.campHints.add(c.campHint!);
        }
        if (c.traits != null &&
            c.traits!.isNotEmpty &&
            !cand.traits.contains(c.traits!)) {
          cand.traits.add(c.traits!);
        }
        if (c.stateChange != null && c.stateChange!.isNotEmpty) {
          cand.stateChanges.add((chapterNo: chNo, change: c.stateChange!));
        }
      }

      for (final r in m.relations) {
        final from = r.from.trim();
        final to = r.to.trim();
        if (from.isEmpty || to.isEmpty || from == to) continue;
        relations.add(
          RawRelationEvidence(
            chapterNo: chNo,
            from: from,
            to: to,
            relation: r.relation,
            kind: r.kind,
            line: r.line,
            evidence: r.evidence,
          ),
        );
      }

      for (final e in m.events) {
        final sum = e.summary.trim();
        if (sum.isEmpty) continue;
        final seq = (perChapterSeq[chNo] ?? 0) + 1;
        perChapterSeq[chNo] = seq;
        events.add(
          IndexedRawEvent(
            id: 'ev_c${chNo}_$seq',
            chapterNo: chNo,
            inWorldTime: e.inWorldTime,
            summary: sum,
            participants: e.participants,
            importance: e.importance,
          ),
        );
      }

      for (final f in m.foreshadowing) {
        final sum = f.summary.trim();
        if (sum.isEmpty) continue;
        clues.add(
          RawClueRecord(
            chapterNo: chNo,
            planted: f.planted,
            summary: sum,
            characters: f.characters,
            targetHint: f.targetHint,
          ),
        );
      }

      for (final w in m.worldbuilding) {
        final name = w.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        final cand = worlds.putIfAbsent(
          key,
          () => RawWorldCandidate(name: name, category: w.category),
        );
        cand.category ??= w.category;
        cand.chapterNos.add(chNo);
        final content = w.content.trim();
        if (content.isNotEmpty && !cand.contents.contains(content)) {
          cand.contents.add(content);
        }
      }
    }

    // 预合并：若候选 B 明确出现在高频候选 A 的 aliases 中，无损归并
    final aliasOwner = <String, String>{};
    final orderedNames = chars.values.toList()
      ..sort((a, b) => b.mentions.compareTo(a.mentions));
    for (final c in orderedNames) {
      for (final a in c.aliases) {
        aliasOwner.putIfAbsent(a, () => c.name);
      }
    }
    for (final entry in aliasOwner.entries) {
      final alias = entry.key;
      final owner = entry.value;
      if (alias != owner &&
          chars.containsKey(alias) &&
          chars.containsKey(owner) &&
          chars[owner]!.mentions >= chars[alias]!.mentions) {
        chars[owner]!.mergeFrom(chars[alias]!, recentStart: recentStart);
        chars.remove(alias);
      }
    }

    return AggregatedSourceGraph(
      totalChapters: totalChapters,
      characterCandidates: chars,
      rawEvents: events,
      rawRelations: relations,
      rawClues: clues,
      rawWorldEntries: worlds,
      cooccurrence: AggregatedSourceGraph._computeCooccurrence(events),
    );
  }
}
