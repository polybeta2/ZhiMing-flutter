import 'dart:convert';

import '../../core/database/app_database.dart' as db;

abstract final class WorldCategories {
  static const List<String> all = ['地点', '势力', '规则', '物品', '其他'];

  static String normalize(String raw) {
    final t = raw.trim();
    if (all.contains(t)) return t;
    if (t.contains('地') || t.contains('城') || t.contains('域') || t.contains('宗')) {
      return '地点';
    }
    if (t.contains('势') || t.contains('派') || t.contains('族') || t.contains('组织')) {
      return '势力';
    }
    if (t.contains('规') || t.contains('系') || t.contains('法') || t.contains('力')) {
      return '规则';
    }
    if (t.contains('物') || t.contains('器') || t.contains('宝') || t.contains('道')) {
      return '物品';
    }
    return '其他';
  }
}

class SceneCard {
  const SceneCard({this.goal = '', this.obstacle = '', this.hook = ''});

  final String goal;
  final String obstacle;
  final String hook;

  bool get isEmpty =>
      goal.trim().isEmpty && obstacle.trim().isEmpty && hook.trim().isEmpty;

  factory SceneCard.fromJson(dynamic raw) {
    if (raw is String) return SceneCard(goal: raw.trim());
    if (raw is Map) {
      return SceneCard(
        goal: raw['goal']?.toString() ?? '',
        obstacle: raw['obstacle']?.toString() ?? '',
        hook: raw['hook']?.toString() ?? '',
      );
    }
    return const SceneCard();
  }

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'obstacle': obstacle,
    'hook': hook,
  };

  SceneCard copyWith({String? goal, String? obstacle, String? hook}) =>
      SceneCard(
        goal: goal ?? this.goal,
        obstacle: obstacle ?? this.obstacle,
        hook: hook ?? this.hook,
      );

  static List<SceneCard> decodeList(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return const [];
    try {
      final raw = jsonDecode(jsonStr);
      if (raw is List) {
        return raw.map(SceneCard.fromJson).where((c) => !c.isEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  static String? encodeList(List<SceneCard> cards) {
    final cleaned = cards.where((c) => !c.isEmpty).toList();
    if (cleaned.isEmpty) return null;
    return jsonEncode([for (final c in cleaned) c.toJson()]);
  }
}

class ConflictRung {
  const ConflictRung({
    required this.level,
    required this.obstacle,
    this.turningPoint,
  });

  final int level;
  final String obstacle;
  final String? turningPoint;

  factory ConflictRung.fromJson(dynamic raw, {int fallbackLevel = 1}) {
    if (raw is String) {
      return ConflictRung(level: fallbackLevel, obstacle: raw.trim());
    }
    if (raw is Map) {
      final lv = (raw['level'] as num?)?.toInt() ?? fallbackLevel;
      final tp = (raw['turning_point'] ?? raw['turningPoint'])?.toString();
      return ConflictRung(
        level: lv,
        obstacle: raw['obstacle']?.toString() ?? '',
        turningPoint: (tp == null || tp.trim().isEmpty) ? null : tp,
      );
    }
    return ConflictRung(level: fallbackLevel, obstacle: '');
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'obstacle': obstacle,
    if (turningPoint != null && turningPoint!.isNotEmpty)
      'turningPoint': turningPoint,
  };

  static List<ConflictRung> decodeList(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return const [];
    try {
      final raw = jsonDecode(jsonStr);
      if (raw is List) {
        final out = <ConflictRung>[];
        for (var i = 0; i < raw.length; i++) {
          final item = ConflictRung.fromJson(raw[i], fallbackLevel: i + 1);
          if (item.obstacle.trim().isNotEmpty) out.add(item);
        }
        return out;
      }
    } catch (_) {}
    return const [];
  }

  static String? encodeList(List<ConflictRung> rungs) {
    final cleaned = rungs.where((r) => r.obstacle.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return null;
    return jsonEncode([
      for (var i = 0; i < cleaned.length; i++)
        ConflictRung(
          level: i + 1,
          obstacle: cleaned[i].obstacle,
          turningPoint: cleaned[i].turningPoint,
        ).toJson(),
    ]);
  }
}

class InfoGap {
  const InfoGap({this.start = '', this.end = ''});

  final String start;
  final String end;

  bool get isEmpty => start.trim().isEmpty && end.trim().isEmpty;

  factory InfoGap.fromJson(dynamic raw) {
    if (raw is String) return InfoGap(start: raw.trim());
    if (raw is Map) {
      return InfoGap(
        start: raw['start']?.toString() ?? '',
        end: raw['end']?.toString() ?? '',
      );
    }
    return const InfoGap();
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  static InfoGap? decode(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final gap = InfoGap.fromJson(jsonDecode(jsonStr));
      return gap.isEmpty ? null : gap;
    } catch (_) {
      return null;
    }
  }

  static String? encode(InfoGap? gap) {
    if (gap == null || gap.isEmpty) return null;
    return jsonEncode(gap.toJson());
  }
}

List<String> decodeStringList(String? jsonStr) {
  if (jsonStr == null || jsonStr.trim().isEmpty) return const [];
  try {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return const [];
}

String encodeStringList(List<String> list) =>
    jsonEncode(list.map((e) => e.trim()).where((s) => s.isNotEmpty).toList());

/// 纯 Dart 作品上下文快照（供 ContextBuilder / ExportService / StatisticsService 无耦合消费）
class ChapterBundle {
  const ChapterBundle({
    required this.chapter,
    required this.volumeId,
    required this.volumeName,
    this.summary,
  });

  final db.Chapter chapter;
  final String volumeId;
  final String volumeName;
  final db.ChapterSummary? summary;

  List<SceneCard> get sceneCards => SceneCard.decodeList(chapter.sceneCardsJson);

  List<String> get keyFacts => decodeStringList(summary?.keyFactsJson);
}

class VolumeBundle {
  const VolumeBundle({required this.volume, required this.chapters});

  final db.Volume volume;
  final List<ChapterBundle> chapters;

  List<String> get emotionArc => decodeStringList(volume.emotionArcJson);
  List<ConflictRung> get conflictLadder =>
      ConflictRung.decodeList(volume.conflictLadderJson);
  InfoGap? get infoGap => InfoGap.decode(volume.infoGapJson);
}

class NovelBundle {
  const NovelBundle({
    required this.novel,
    required this.volumes,
    required this.characters,
    required this.worldEntries,
    required this.foreshadowings,
  });

  final db.Novel novel;
  final List<VolumeBundle> volumes;
  final List<db.Character> characters;
  final List<db.WorldEntry> worldEntries;
  final List<db.Foreshadowing> foreshadowings;

  List<ChapterBundle> get allChaptersInOrder => [
    for (final v in volumes) ...v.chapters,
  ];

  /// 章节 ID → 全书 1-based 序号
  Map<String, int> globalIndexMap() {
    final map = <String, int>{};
    var idx = 1;
    for (final c in allChaptersInOrder) {
      map[c.chapter.id] = idx++;
    }
    return map;
  }

  /// 书名与 R18 免责声明文案（与原版统一）
  static const String r18NoticeText =
      '说明：此功能仅为合规的 R18 写作提示词注入，用于增强小说文采与场景表现力，并非「破甲」或「越狱」提示词。\n'
      '提醒：如需更高级别的 R18 内容生成，请自行配置相应模型或 API 权限，本功能不涉及任何绕过模型安全策略的操作。\n'
      '免责声明：生成的所有内容均由您自行负责，与本应用开发者及运营方无关。';
}
