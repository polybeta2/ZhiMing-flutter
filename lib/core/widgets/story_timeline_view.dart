import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'zm_widgets.dart';

class TimelineEventItem {
  const TimelineEventItem({
    required this.id,
    this.chapterId,
    required this.chapterLabel,
    this.inWorldTime,
    this.phase,
    required this.title,
    required this.summary,
    this.location,
    this.participants = const [],
    this.linkedClueBadges = const [],
    this.importance = 'normal',
  });

  final String id;
  final String? chapterId;
  final String chapterLabel;
  final String? inWorldTime;
  final String? phase;
  final String title;
  final String summary;
  final String? location;
  final List<String> participants;
  final List<String> linkedClueBadges;
  final String importance; // 'major' | 'normal' | 'minor'
}

/// 故事时间线通用组件（复用于作品工作台「大纲伏笔 → 故事时间线」与原作档案详情「时间线」）
class StoryTimelineView extends StatefulWidget {
  const StoryTimelineView({
    super.key,
    required this.events,
    this.onAddEvent,
    this.onEditEvent,
    this.onDeleteEvent,
    this.onJumpToChapter,
  });

  final List<TimelineEventItem> events;
  final VoidCallback? onAddEvent;
  final ValueChanged<TimelineEventItem>? onEditEvent;
  final ValueChanged<TimelineEventItem>? onDeleteEvent;
  final ValueChanged<String>? onJumpToChapter;

  @override
  State<StoryTimelineView> createState() => _StoryTimelineViewState();
}

class _StoryTimelineViewState extends State<StoryTimelineView> {
  String _search = '';
  String? _selectedCharacter;
  bool _onlyMajor = false;

  List<String> get _allParticipants {
    final set = <String>{};
    for (final e in widget.events) {
      set.addAll(e.participants);
    }
    return set.toList()..sort();
  }

  List<TimelineEventItem> get _filtered {
    final q = _search.trim().toLowerCase();
    return widget.events.where((e) {
      if (_onlyMajor && e.importance != 'major') return false;
      if (_selectedCharacter != null &&
          !e.participants.contains(_selectedCharacter)) {
        return false;
      }
      if (q.isNotEmpty) {
        final hit =
            e.title.toLowerCase().contains(q) ||
            e.summary.toLowerCase().contains(q) ||
            (e.phase ?? '').toLowerCase().contains(q) ||
            (e.inWorldTime ?? '').toLowerCase().contains(q) ||
            e.participants.any((p) => p.toLowerCase().contains(q));
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _filtered;
    final participants = _allParticipants;

    // 按阶段分节保留原顺序
    final grouped = <String, List<TimelineEventItem>>{};
    for (final item in list) {
      final key = (item.phase ?? '').trim().isEmpty ? '主线时间轴' : item.phase!.trim();
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 170,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '搜索事件/时间/人物…',
                    prefixIcon: Icon(Icons.search, size: 16),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              if (participants.isNotEmpty)
                DropdownButton<String?>(
                  value: _selectedCharacter,
                  hint: const Text('全部角色', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('全部角色', style: TextStyle(fontSize: 12)),
                    ),
                    for (final p in participants)
                      DropdownMenuItem(
                        value: p,
                        child: Text(p, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selectedCharacter = v),
                ),
              FilterChip(
                label: const Text('仅核心里程碑', style: TextStyle(fontSize: 12)),
                selected: _onlyMajor,
                onSelected: (v) => setState(() => _onlyMajor = v),
                visualDensity: VisualDensity.compact,
              ),
              if (_selectedCharacter != null)
                InputChip(
                  label: Text(
                    '角色：$_selectedCharacter',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onDeleted: () => setState(() => _selectedCharacter = null),
                  visualDensity: VisualDensity.compact,
                ),
              if (widget.onAddEvent != null)
                FilledButton.tonalIcon(
                  onPressed: widget.onAddEvent,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新增事件'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? ZmEmptyState(
                  icon: Icons.timeline_rounded,
                  title: '暂无故事时间线事件',
                  description: '可通过续写精扫自动提取全书时间线，或在每章摘要活账本与手动录入中逐步沉淀。',
                  action: widget.onAddEvent != null
                      ? FilledButton.tonalIcon(
                          onPressed: widget.onAddEvent,
                          icon: const Icon(Icons.add),
                          label: const Text('新增时间线事件'),
                        )
                      : null,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppTokens.s4),
                  children: [
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.key}（${entry.value.length}）',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < entry.value.length; i++)
                        _buildTimelineRow(
                          context,
                          entry.value[i],
                          isLast: i == entry.value.length - 1,
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineRow(
    BuildContext context,
    TimelineEventItem item, {
    required bool isLast,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isMajor = item.importance == 'major';
    final canJump =
        widget.onJumpToChapter != null &&
        item.chapterId != null &&
        item.chapterId!.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: isMajor ? 12 : 9,
                  height: isMajor ? 12 : 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMajor ? cs.primary : cs.surface,
                    border: Border.all(
                      color: isMajor ? cs.primary : cs.outline,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: cs.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: canJump
                              ? () => widget.onJumpToChapter!(item.chapterId!)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(
                                alpha: canJump ? 0.14 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.chapterLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                                if (canJump) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.open_in_new,
                                    size: 11,
                                    color: cs.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if ((item.inWorldTime ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.inWorldTime!,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                        if ((item.location ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '@${item.location}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (widget.onEditEvent != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => widget.onEditEvent!(item),
                          ),
                        if (widget.onDeleteEvent != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => widget.onDeleteEvent!(item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    if (item.summary.isNotEmpty &&
                        item.summary != item.title) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.summary,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (item.participants.isNotEmpty ||
                        item.linkedClueBadges.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final p in item.participants)
                            ActionChip(
                              label: Text(
                                p,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              onPressed: () => setState(
                                () => _selectedCharacter =
                                    _selectedCharacter == p ? null : p,
                              ),
                            ),
                          for (final badge in item.linkedClueBadges)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
