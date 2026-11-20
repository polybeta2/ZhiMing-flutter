import '../models/source_profile_models.dart';

class SourceTimeWindowSlice {
  const SourceTimeWindowSlice({
    required this.phase,
    required this.characters,
    required this.events,
    required this.worldbuilding,
  });

  final String? phase;
  final List<CanonCharacter> characters;
  final List<CanonEvent> events;
  final List<CanonWorldEntry> worldbuilding;

  /// 按 maxChars 预算渲染可注入文本（核心设定 → 角色 → 事件）。
  String rendered({int maxChars = 3000}) {
    if (maxChars <= 0) return '';
    final sections = <String>[];
    var used = 0;

    void appendSection(String title, List<String> lines) {
      if (lines.isEmpty || used >= maxChars) return;
      final buf = StringBuffer('【$title】');
      var added = 0;
      for (final line in lines) {
        if (used + buf.length + line.length + 2 > maxChars) break;
        buf.write('\n- $line');
        added += 1;
      }
      if (added > 0) {
        final block = buf.toString();
        sections.add(block);
        used += block.length + 2;
      }
    }

    if (phase != null && phase!.trim().isNotEmpty) {
      final header = '当前定位阶段：${phase!.trim()}';
      sections.add(header);
      used += header.length + 2;
    }

    appendSection(
      '核心人物',
      characters.map((c) {
        final parts = <String>[
          c.name,
          if (c.aliases.isNotEmpty) '又名:${c.aliases.take(2).join("/")}',
          if (c.oneLine != null && c.oneLine!.isNotEmpty) c.oneLine!,
          if (c.personality != null && c.personality!.isNotEmpty)
            '性格:${c.personality!}',
          if (c.abilities != null && c.abilities!.isNotEmpty)
            '能力:${c.abilities!}',
          if (c.arc.isNotEmpty)
            '阶段:${c.arc.last.phase}->${c.arc.last.state}',
        ];
        return parts.join('｜');
      }).toList(),
    );

    appendSection(
      '时间线事件',
      events.map((e) {
        final prefix = [
          if (e.phase != null && e.phase!.isNotEmpty) e.phase!,
          if (e.chapterRange != null && e.chapterRange!.isNotEmpty)
            e.chapterRange!,
        ].join(' ');
        final p = e.participants.isEmpty
            ? ''
            : '（${e.participants.take(4).join("、")}）';
        return prefix.isEmpty ? '${e.summary}$p' : '[$prefix] ${e.summary}$p';
      }).toList(),
    );

    appendSection(
      '世界观设定',
      worldbuilding.map((w) => '[${w.category}] ${w.name}：${w.content}').toList(),
    );

    return sections.join('\n\n');
  }
}

/// 同人时间窗切片器：按目标阶段定位最近事件与人物状态，避免剧透后段并严守预算。
class SourceTimeWindow {
  const SourceTimeWindow._();

  static SourceTimeWindowSlice window({
    String? phase,
    required SourceNovelProfileData profile,
  }) {
    final normalizedPhase = phase?.trim();
    List<CanonEvent> selectedEvents;

    if (normalizedPhase == null || normalizedPhase.isEmpty) {
      // 全书梗概：优先核心事件
      selectedEvents = [
        ...profile.timeline.where((e) => e.importance == CanonImportance.major),
        ...profile.timeline.where((e) => e.importance != CanonImportance.major),
      ];
    } else {
      // 取直到目标阶段为止的事件（当前阶段优先，前面核心事件兜底）
      final idx = profile.timeline.lastIndexWhere(
        (e) => (e.phase ?? '').trim() == normalizedPhase,
      );
      if (idx >= 0) {
        final currentPhaseEvents = profile.timeline
            .where((e) => (e.phase ?? '').trim() == normalizedPhase)
            .toList();
        final priorMajor = profile.timeline
            .take(idx)
            .where(
              (e) =>
                  (e.phase ?? '').trim() != normalizedPhase &&
                  e.importance == CanonImportance.major,
            )
            .toList();
        selectedEvents = [...currentPhaseEvents, ...priorMajor];
      } else {
        selectedEvents = profile.timeline;
      }
    }

    // 涉及本窗事件的角色优先排序
    final activeNames = <String>{
      for (final ev in selectedEvents) ...ev.participants,
    };
    final orderedChars = [...profile.characters]
      ..sort((a, b) {
        final aHit = activeNames.contains(a.name) ? 0 : 1;
        final bHit = activeNames.contains(b.name) ? 0 : 1;
        return aHit.compareTo(bHit);
      });

    return SourceTimeWindowSlice(
      phase: normalizedPhase,
      characters: orderedChars,
      events: selectedEvents,
      worldbuilding: profile.worldbuilding,
    );
  }
}
