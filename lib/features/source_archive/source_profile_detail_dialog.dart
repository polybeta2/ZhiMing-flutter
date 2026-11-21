import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/storage/blob_store.dart';
import '../../core/widgets/character_graph_canvas.dart';
import '../../core/widgets/story_timeline_view.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/source_profile_models.dart';
import 'source_injection_helper.dart';

/// 原作档案详情编辑器：人物 / 时间线 / 世界观 / 续写伏笔 四视图 + 文风绑定 + 一键建同人/续写。
class SourceProfileDetailDialog extends ConsumerStatefulWidget {
  const SourceProfileDetailDialog({super.key, required this.initialProfile});

  final SourceNovelProfileData initialProfile;

  static Future<void> show(
    BuildContext context, {
    required SourceNovelProfileData profile,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SourceProfileDetailDialog(initialProfile: profile),
    );
  }

  @override
  ConsumerState<SourceProfileDetailDialog> createState() =>
      _SourceProfileDetailDialogState();
}

class _SourceProfileDetailDialogState
    extends ConsumerState<SourceProfileDetailDialog>
    with SingleTickerProviderStateMixin {
  late SourceNovelProfileData _profile;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _save(SourceNovelProfileData next) async {
    setState(() => _profile = next);
    await ref
        .read(appDatabaseProvider)
        .upsertSourceProfile(
          SourceProfilesCompanion.insert(
            id: next.id,
            title: next.title,
            author: Value(next.author),
            payloadJson: next.toJsonString(),
            createdAt: next.createdAt,
          ),
        );
  }

  Future<void> _pickStyle() async {
    final styles = await ref
        .read(appDatabaseProvider)
        .watchStyleProfiles()
        .first;
    if (!mounted) return;
    final picked = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('绑定原作文风'),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('不绑定文风'),
                trailing: _profile.styleProfileId == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop('__none__'),
              ),
              for (final s in styles)
                ListTile(
                  title: Text(s.name),
                  trailing: _profile.styleProfileId == s.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(s.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    if (picked == '__none__') {
      await _save(_profile.copyWith(clearStyleProfileId: true));
    } else {
      await _save(_profile.copyWith(styleProfileId: picked));
    }
  }

  Future<void> _createFanfic() async {
    final styles = await ref
        .read(appDatabaseProvider)
        .watchStyleProfiles()
        .first;
    if (!mounted) return;
    String? chosenStyleId = _profile.styleProfileId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('以《${_profile.title}》创作同人'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('创建后将进入立项澄清阶段，确认同人遵守度（严格原作线 / IF 线 / 仅借设定）。'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: chosenStyleId,
                  decoration: const InputDecoration(labelText: '继承或切换文风（可选）'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('不启用文风卡')),
                    ...styles.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => chosenStyleId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('创建同人书'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final novelId = await ref
        .read(sourceAndStyleBridgeProvider)
        .createFanficNovel(profile: _profile, styleProfileId: chosenStyleId);
    if (!mounted) return;
    Navigator.of(context).pop();
    context.push('/novel/$novelId');
  }

  Future<void> _createContinuation() async {
    if (_profile.continuationFromChapter == null) {
      final ok = await showZmConfirmDialog(
        context,
        title: '同人精度档案续写提醒',
        message: '该档案为常规同人精度档案，缺少续写专用的深度现状与伏笔清单。是否仍要以它创建续写作品？',
        confirmLabel: '仍要续写',
      );
      if (!ok || !mounted) return;
    }
    final novelId = await ref
        .read(sourceAndStyleBridgeProvider)
        .createContinuationNovel(profile: _profile);
    if (!mounted) return;
    Navigator.of(context).pop();
    context.push('/novel/$novelId');
  }

  Future<void> _deleteProfile() async {
    final ok = await showZmConfirmDialog(
      context,
      title: '删除「${_profile.title}」原作档案？',
      message: '档案下的人物、时间线、世界观及关联原文缓存将被彻底清理，引用该档案的同人书会自动解绑。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref
        .read(appDatabaseProvider)
        .deleteSourceProfileCompletely(_profile.id, ref.read(blobStoreProvider));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editCharacter(int? index) async {
    final existing = index != null ? _profile.characters[index] : null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final aliasCtrl = TextEditingController(
      text: existing?.aliases.join('，') ?? '',
    );
    final oneLineCtrl = TextEditingController(text: existing?.oneLine ?? '');
    final personalityCtrl = TextEditingController(
      text: existing?.personality ?? '',
    );
    final abilitiesCtrl = TextEditingController(
      text: existing?.abilities ?? '',
    );
    final stateCtrl = TextEditingController(
      text: existing?.currentState ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '新增原作人物' : '编辑原作人物'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '姓名'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: aliasCtrl,
                  decoration: const InputDecoration(labelText: '别名（逗号分隔）'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: oneLineCtrl,
                  decoration: const InputDecoration(labelText: '一句话定位'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: personalityCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '性格'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: abilitiesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '能力'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stateCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '当前现状快照（续写用）'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final item = CanonCharacter(
        name: nameCtrl.text.trim(),
        aliases: aliasCtrl.text
            .split(RegExp(r'[,，、;；]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        oneLine: oneLineCtrl.text.trim().isEmpty
            ? null
            : oneLineCtrl.text.trim(),
        personality: personalityCtrl.text.trim().isEmpty
            ? null
            : personalityCtrl.text.trim(),
        abilities: abilitiesCtrl.text.trim().isEmpty
            ? null
            : abilitiesCtrl.text.trim(),
        currentState: stateCtrl.text.trim().isEmpty
            ? null
            : stateCtrl.text.trim(),
        relationships: existing?.relationships ?? const [],
        arc: existing?.arc ?? const [],
        role: existing?.role,
        appearance: existing?.appearance,
      );
      final list = [..._profile.characters];
      if (index == null) {
        list.add(item);
      } else {
        list[index] = item;
      }
      await _save(_profile.copyWith(characters: list));
    }
    nameCtrl.dispose();
    aliasCtrl.dispose();
    oneLineCtrl.dispose();
    personalityCtrl.dispose();
    abilitiesCtrl.dispose();
    stateCtrl.dispose();
  }

  Future<void> _editEvent(int? index) async {
    final existing = index != null ? _profile.timeline[index] : null;
    final phaseCtrl = TextEditingController(text: existing?.phase ?? '');
    final rangeCtrl = TextEditingController(text: existing?.chapterRange ?? '');
    final summaryCtrl = TextEditingController(text: existing?.summary ?? '');
    var importance = existing?.importance ?? CanonImportance.normal;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? '新增时间线事件' : '编辑事件'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phaseCtrl,
                  decoration: const InputDecoration(labelText: '所属阶段'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rangeCtrl,
                  decoration: const InputDecoration(labelText: '章节范围（如 第1-20章）'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: summaryCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '事件摘要'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CanonImportance>(
                  initialValue: importance,
                  decoration: const InputDecoration(labelText: '重要程度'),
                  items: CanonImportance.values
                      .map(
                        (im) =>
                            DropdownMenuItem(value: im, child: Text(im.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => importance = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && summaryCtrl.text.trim().isNotEmpty) {
      final item = CanonEvent(
        phase: phaseCtrl.text.trim().isEmpty ? null : phaseCtrl.text.trim(),
        chapterRange: rangeCtrl.text.trim().isEmpty
            ? null
            : rangeCtrl.text.trim(),
        summary: summaryCtrl.text.trim(),
        participants: existing?.participants ?? const [],
        importance: importance,
      );
      final list = [..._profile.timeline];
      if (index == null) {
        list.add(item);
      } else {
        list[index] = item;
      }
      await _save(_profile.copyWith(timeline: list));
    }
    phaseCtrl.dispose();
    rangeCtrl.dispose();
    summaryCtrl.dispose();
  }

  Future<void> _editWorld(int? index) async {
    final existing = index != null ? _profile.worldbuilding[index] : null;
    final catCtrl = TextEditingController(text: existing?.category ?? '规则');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '新增世界观设定' : '编辑世界观设定'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: '分类（规则/势力/地理/器物）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '词条名'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '设定说明'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final item = CanonWorldEntry(
        category: catCtrl.text.trim().isEmpty ? '设定' : catCtrl.text.trim(),
        name: nameCtrl.text.trim(),
        content: contentCtrl.text.trim(),
      );
      final list = [..._profile.worldbuilding];
      if (index == null) {
        list.add(item);
      } else {
        list[index] = item;
      }
      await _save(_profile.copyWith(worldbuilding: list));
    }
    catCtrl.dispose();
    nameCtrl.dispose();
    contentCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCont = _profile.continuationFromChapter != null;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _profile.title,
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (isCont ? Colors.indigo : cs.primary)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isCont
                                    ? '续写 · 截至第 ${_profile.continuationFromChapter} 章'
                                    : '同人档案 · ${_profile.meta.totalChapters} 章',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: isCont
                                          ? Colors.indigo
                                          : cs.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_profile.scanState.totalChunks} 块 · '
                          'Token ${(_profile.scanState.tokensIn / 1000).toStringAsFixed(1)}k 入 / '
                          '${(_profile.scanState.tokensOut / 1000).toStringAsFixed(1)}k 出',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickStyle,
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: Text(
                          _profile.styleProfileId == null ? '绑定文风' : '已绑文风',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _createFanfic,
                        icon: const Icon(Icons.auto_stories, size: 16),
                        label: const Text('同人立项'),
                      ),
                      FilledButton.icon(
                        onPressed: _createContinuation,
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text('以此续写'),
                      ),
                      IconButton(
                        tooltip: '删除档案',
                        onPressed: _deleteProfile,
                        icon: Icon(Icons.delete_outline, color: cs.error),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: [
                Tab(text: '人物 (${_profile.characters.length})'),
                Tab(text: '关系图谱 (${_profile.relations.length})'),
                Tab(text: '时间线 (${_profile.timeline.length})'),
                Tab(text: '世界观 (${_profile.worldbuilding.length})'),
                Tab(text: '伏笔与弧线 (${_profile.openThreads.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildCharactersTab(),
                  _buildRelationsTab(),
                  _buildTimelineTab(),
                  _buildWorldTab(),
                  _buildThreadsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationsTab() {
    final nodes = [
      for (final c in _profile.characters)
        GraphNode(
          id: c.name,
          name: c.name,
          camp: c.camp,
          role: c.role,
          importance: c.importance.raw,
          subtitle: c.currentState ?? c.oneLine,
        ),
    ];
    final knownNames = nodes.map((n) => n.id).toSet();
    final edges = <GraphEdge>[];
    final seen = <String>{};
    for (var i = 0; i < _profile.relations.length; i++) {
      final r = _profile.relations[i];
      if (!knownNames.contains(r.from) || !knownNames.contains(r.to)) continue;
      final key = r.from.compareTo(r.to) <= 0
          ? '${r.from}||${r.to}'
          : '${r.to}||${r.from}';
      seen.add(key);
      edges.add(
        GraphEdge(
          id: 'rel_$i',
          fromId: r.from,
          toId: r.to,
          relationType: r.relationType,
          label: r.label.isNotEmpty ? r.label : r.relationType,
          description: r.description,
          strength: r.strength,
          line: r.line,
          firstChapter: r.firstChapter,
          lastChapter: r.lastChapter,
          evolution: [
            for (final ev in r.evolution)
              (chapterLabel: ev.chapterLabel, state: ev.state),
          ],
        ),
      );
    }
    // 兼容旧档案：从 character.relationships 补充
    var fallbackIdx = 0;
    for (final c in _profile.characters) {
      for (final rel in c.relationships) {
        if (!knownNames.contains(rel.target) || rel.target == c.name) continue;
        final key = c.name.compareTo(rel.target) <= 0
            ? '${c.name}||${rel.target}'
            : '${rel.target}||${c.name}';
        if (!seen.add(key)) continue;
        edges.add(
          GraphEdge(
            id: 'legacy_${fallbackIdx++}',
            fromId: c.name,
            toId: rel.target,
            relationType: normalizeRelationType(rel.relation),
            label: rel.relation,
          ),
        );
      }
    }
    return CharacterGraphCanvas(nodes: nodes, edges: edges);
  }

  Widget _buildCharactersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: () => _editCharacter(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加人物'),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _profile.characters.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ZmCard(
              onTap: () => _editCharacter(i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _profile.characters[i].name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (_profile.characters[i].aliases.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${_profile.characters[i].aliases.join(" / ")})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () {
                          final list = [..._profile.characters]..removeAt(i);
                          _save(_profile.copyWith(characters: list));
                        },
                      ),
                    ],
                  ),
                  if (_profile.characters[i].oneLine != null)
                    Text(_profile.characters[i].oneLine!),
                  if (_profile.characters[i].currentState != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '现状：${_profile.characters[i].currentState}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineTab() {
    final items = [
      for (var i = 0; i < _profile.timeline.length; i++)
        TimelineEventItem(
          id: '$i',
          chapterLabel: (_profile.timeline[i].chapterRange ?? '').isNotEmpty
              ? _profile.timeline[i].chapterRange!
              : (_profile.timeline[i].chapterStart != null
                    ? '第${_profile.timeline[i].chapterStart}章'
                    : '阶段节点'),
          inWorldTime: _profile.timeline[i].inWorldTime,
          phase: _profile.timeline[i].phase,
          title: _profile.timeline[i].summary.length <= 24
              ? _profile.timeline[i].summary
              : '${_profile.timeline[i].summary.substring(0, 23)}…',
          summary: _profile.timeline[i].summary,
          participants: _profile.timeline[i].participants,
          linkedClueBadges: [
            for (final c in _profile.timeline[i].linkedClueTitles) '[伏笔] $c',
          ],
          importance: _profile.timeline[i].importance.raw,
        ),
    ];
    return StoryTimelineView(
      events: items,
      onAddEvent: () => _editEvent(null),
      onEditEvent: (item) {
        final idx = int.tryParse(item.id);
        if (idx != null) _editEvent(idx);
      },
      onDeleteEvent: (item) {
        final idx = int.tryParse(item.id);
        if (idx == null || idx < 0 || idx >= _profile.timeline.length) return;
        final list = [..._profile.timeline]..removeAt(idx);
        _save(_profile.copyWith(timeline: list));
      },
    );
  }

  Widget _buildWorldTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: () => _editWorld(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加设定'),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _profile.worldbuilding.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ZmCard(
              onTap: () => _editWorld(i),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '[${_profile.worldbuilding[i].category}] ${_profile.worldbuilding[i].name}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(_profile.worldbuilding[i].content),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      final list = [..._profile.worldbuilding]..removeAt(i);
                      _save(_profile.copyWith(worldbuilding: list));
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThreadsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_profile.activeArcs.isNotEmpty) ...[
          const ZmSectionHeader(title: '进行中剧情弧'),
          for (final arc in _profile.activeArcs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ZmCard(child: Text(arc)),
            ),
          const SizedBox(height: 12),
        ],
        const ZmSectionHeader(title: '伏笔台账（含埋/收对账）'),
        if (_profile.openThreads.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('暂无伏笔记录（续写深度分析后自动提取）')),
          )
        else
          for (final t in _profile.openThreads)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ZmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (t.status == 'resolved'
                                    ? Colors.green
                                    : (t.status == 'partial'
                                          ? Colors.orange
                                          : Colors.indigo))
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            switch (t.status) {
                              'resolved' => '已回收',
                              'partial' => '部分推进',
                              _ => '未回收',
                            },
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.status == 'resolved'
                                  ? Colors.green.shade700
                                  : (t.status == 'partial'
                                        ? Colors.orange.shade800
                                        : Colors.indigo),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (t.plantedChapter != null)
                          t.resolvedChapter != null
                              ? '第${t.plantedChapter}章埋 → 第${t.resolvedChapter}章收'
                              : '埋设：第${t.plantedChapter}章',
                        if (t.involvedCharacters.isNotEmpty)
                          '角色：${t.involvedCharacters.join('、')}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (t.detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(t.detail),
                    ],
                    if ((t.payoffDetail ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '回收说明：${t.payoffDetail}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
