import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/r18_toggle_tile.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/novel_domain.dart';

/// 作品设定集：将原版散落的「基本信息/文风/R18」「角色卡」「世界观」统一收口为单页三段切换
class BookSettingsView extends ConsumerStatefulWidget {
  const BookSettingsView({super.key, required this.novelId});
  final String novelId;

  @override
  ConsumerState<BookSettingsView> createState() => _BookSettingsViewState();
}

class _BookSettingsViewState extends ConsumerState<BookSettingsView> {
  int _tab = 0; // 0: 基本信息, 1: 角色卡, 2: 世界观

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.s4,
            AppTokens.s3,
            AppTokens.s4,
            AppTokens.s2,
          ),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('作品信息'),
                icon: Icon(Icons.tune_rounded, size: 16),
              ),
              ButtonSegment(
                value: 1,
                label: Text('角色卡'),
                icon: Icon(Icons.people_outline, size: 16),
              ),
              ButtonSegment(
                value: 2,
                label: Text('世界观'),
                icon: Icon(Icons.public_outlined, size: 16),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => _BasicMetaPane(novelId: widget.novelId),
            1 => _CharacterListPane(novelId: widget.novelId),
            _ => _WorldListPane(novelId: widget.novelId),
          },
        ),
      ],
    );
  }
}

class _BasicMetaPane extends ConsumerStatefulWidget {
  const _BasicMetaPane({required this.novelId});
  final String novelId;

  @override
  ConsumerState<_BasicMetaPane> createState() => _BasicMetaPaneState();
}

class _BasicMetaPaneState extends ConsumerState<_BasicMetaPane> {
  final _titleCtrl = TextEditingController();
  final _synopsisCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  final _perspectiveCtrl = TextEditingController();
  final _styleGuideCtrl = TextEditingController();
  String? _loadedId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _synopsisCtrl.dispose();
    _genreCtrl.dispose();
    _perspectiveCtrl.dispose();
    _styleGuideCtrl.dispose();
    super.dispose();
  }

  void _syncFromNovel(Novel novel) {
    if (_loadedId == novel.id) return;
    _loadedId = novel.id;
    _titleCtrl.text = novel.title;
    _synopsisCtrl.text = novel.synopsis;
    _genreCtrl.text = novel.genre ?? '';
    _perspectiveCtrl.text = novel.perspective ?? '';
    _styleGuideCtrl.text = novel.styleGuide ?? '';
  }

  Future<void> _saveMeta(Novel novel) async {
    await ref
        .read(novelRepositoryProvider)
        .updateNovelMeta(
          novel.id,
          title: _titleCtrl.text.trim().isEmpty
              ? novel.title
              : _titleCtrl.text.trim(),
          synopsis: _synopsisCtrl.text,
          genre: _genreCtrl.text,
          perspective: _perspectiveCtrl.text,
          styleGuide: _styleGuideCtrl.text,
        );
    if (mounted) showZmSnackBar(context, '作品信息已保存');
  }

  @override
  Widget build(BuildContext context) {
    final asyncNovel = ref.watch(novelStreamProvider(widget.novelId));
    final stylesStream = ref.watch(appDatabaseProvider).watchStyleProfiles();

    return asyncNovel.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (novel) {
        if (novel == null) return const SizedBox.shrink();
        _syncFromNovel(novel);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(AppTokens.s4),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(labelText: '书名'),
                        ),
                        const SizedBox(height: AppTokens.s3),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _genreCtrl,
                                decoration: const InputDecoration(
                                  labelText: '类型',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTokens.s3),
                            Expanded(
                              child: TextField(
                                controller: _perspectiveCtrl,
                                decoration: const InputDecoration(
                                  labelText: '叙事视角',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.s3),
                        TextField(
                          controller: _synopsisCtrl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: '作品梗概',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: AppTokens.s3),
                        TextField(
                          controller: _styleGuideCtrl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: '风格约束（优先级高于文风档案）',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: AppTokens.s3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _saveMeta(novel),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('保存基本信息'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.s4),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.s4),
                    child: StreamBuilder<List<StyleProfile>>(
                      stream: stylesStream,
                      builder: (context, snap) {
                        final profiles = snap.data ?? const [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '绑定文风档案',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              initialValue: profiles.any(
                                      (p) => p.id == novel.activeStyleProfileId,
                                    )
                                  ? novel.activeStyleProfileId
                                  : null,
                              decoration: const InputDecoration(
                                hintText: '未启用文风档案',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('未启用'),
                                ),
                                for (final p in profiles)
                                  DropdownMenuItem<String?>(
                                    value: p.id,
                                    child: Text(p.name),
                                  ),
                              ],
                              onChanged: (val) async {
                                await ref
                                    .read(novelRepositoryProvider)
                                    .updateNovelMeta(
                                      novel.id,
                                      activeStyleProfileId: Value(val),
                                    );
                              },
                            ),
                            const SizedBox(height: AppTokens.s3),
                            R18ToggleTile(
                              value: novel.r18Enabled,
                              onChanged: (enabled) async {
                                final nextHex = enabled
                                    ? AppTokens.r18AccentHex
                                    : (novel.accentColorHex ==
                                              AppTokens.r18AccentHex
                                          ? AppTokens.accentPresets.first.hex
                                          : novel.accentColorHex);
                                await ref
                                    .read(novelRepositoryProvider)
                                    .updateNovelMeta(
                                      novel.id,
                                      r18Enabled: enabled,
                                      accentColorHex: nextHex,
                                    );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CharacterListPane extends ConsumerWidget {
  const _CharacterListPane({required this.novelId});
  final String novelId;

  Future<void> _editCharacter(
    BuildContext context,
    WidgetRef ref, [
    Character? existing,
  ]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final aliasesCtrl = TextEditingController(
      text: decodeStringList(existing?.aliasesJson).join('、'),
    );
    final appCtrl = TextEditingController(text: existing?.appearance ?? '');
    final perCtrl = TextEditingController(text: existing?.personality ?? '');
    final bgCtrl = TextEditingController(text: existing?.background ?? '');
    final goalCtrl = TextEditingController(text: existing?.currentGoal ?? '');
    final locCtrl = TextEditingController(
      text: existing?.currentLocation ?? '',
    );
    final physCtrl = TextEditingController(text: existing?.physicalState ?? '');
    final mentCtrl = TextEditingController(text: existing?.mentalState ?? '');
    var relevant = existing?.isSceneRelevant ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(existing == null ? '新增角色卡' : '编辑角色卡'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '姓名 *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: aliasesCtrl,
                    decoration: const InputDecoration(
                      labelText: '别名（顿号或逗号分隔）',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: perCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '性格'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: appCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '外貌'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bgCtrl,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '背景经历'),
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: goalCtrl,
                    decoration: const InputDecoration(labelText: '当前目标'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(labelText: '当前位置'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: physCtrl,
                    decoration: const InputDecoration(labelText: '身体状态'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mentCtrl,
                    decoration: const InputDecoration(labelText: '心理状态'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('参与近期剧情（续写优先注入）'),
                    value: relevant,
                    onChanged: (v) => setModal(() => relevant = v),
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
      ),
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      final aliases = aliasesCtrl.text
          .split(RegExp(r'[,，、;；\s]+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      await ref
          .read(appDatabaseProvider)
          .upsertCharacter(
            CharactersCompanion.insert(
              id: existing?.id ?? const Uuid().v4(),
              novelId: novelId,
              name: nameCtrl.text.trim(),
              aliasesJson: Value(encodeStringList(aliases)),
              appearance: Value(_opt(appCtrl.text)),
              personality: Value(_opt(perCtrl.text)),
              background: Value(_opt(bgCtrl.text)),
              currentGoal: Value(_opt(goalCtrl.text)),
              currentLocation: Value(_opt(locCtrl.text)),
              physicalState: Value(_opt(physCtrl.text)),
              mentalState: Value(_opt(mentCtrl.text)),
              isSceneRelevant: Value(relevant),
              sortOrder: Value(existing?.sortOrder ?? 0),
            ),
          );
      await ref.read(novelRepositoryProvider).touchNovel(novelId);
    }

    nameCtrl.dispose();
    aliasesCtrl.dispose();
    appCtrl.dispose();
    perCtrl.dispose();
    bgCtrl.dispose();
    goalCtrl.dispose();
    locCtrl.dispose();
    physCtrl.dispose();
    mentCtrl.dispose();
  }

  static String? _opt(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCharacter(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('新增角色'),
      ),
      body: StreamBuilder<List<Character>>(
        stream: db.watchCharacters(novelId),
        builder: (context, snap) {
          final chars = snap.data ?? const [];
          if (chars.isEmpty) {
            return const ZmEmptyState(
              icon: Icons.people_outline,
              title: '还没有角色卡',
              description: '创建主要角色并维护「当前状态」，AI 续写时会自动注入防止 OOC。',
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.s4,
                  AppTokens.s2,
                  AppTokens.s4,
                  88,
                ),
                itemCount: chars.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppTokens.s3),
                itemBuilder: (_, i) {
                  final c = chars[i];
                  final aliases = decodeStringList(c.aliasesJson);
                  return Card(
                    child: ListTile(
                      title: Row(
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (aliases.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${aliases.join('/')})',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const Spacer(),
                          if (c.isSceneRelevant)
                            const Chip(
                              label: Text('近期活跃', style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          if ((c.personality ?? '').isNotEmpty)
                            '性格：${c.personality}',
                          if ((c.currentGoal ?? '').isNotEmpty)
                            '目标：${c.currentGoal}',
                          if ((c.currentLocation ?? '').isNotEmpty)
                            '位置：${c.currentLocation}',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () async {
                          final ok = await showZmConfirmDialog(
                            context,
                            title: '删除角色「${c.name}」？',
                            message: '删除后无法恢复。',
                            confirmLabel: '删除',
                            destructive: true,
                          );
                          if (ok) await db.deleteCharacter(c.id);
                        },
                      ),
                      onTap: () => _editCharacter(context, ref, c),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorldListPane extends ConsumerStatefulWidget {
  const _WorldListPane({required this.novelId});
  final String novelId;

  @override
  ConsumerState<_WorldListPane> createState() => _WorldListPaneState();
}

class _WorldListPaneState extends ConsumerState<_WorldListPane> {
  String _selectedCategory = '全部';

  Future<void> _editEntry([WorldEntry? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    var category = existing?.category ?? WorldCategories.all.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(existing == null ? '新增世界观条目' : '编辑世界观条目'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: WorldCategories.all.contains(category)
                      ? category
                      : '其他',
                  decoration: const InputDecoration(labelText: '分类'),
                  items: [
                    for (final c in WorldCategories.all)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) =>
                      setModal(() => category = v ?? WorldCategories.all.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '条目名称 *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '设定说明',
                    alignLabelWithHint: true,
                  ),
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

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      await ref
          .read(appDatabaseProvider)
          .upsertWorldEntry(
            WorldEntriesCompanion.insert(
              id: existing?.id ?? const Uuid().v4(),
              novelId: widget.novelId,
              category: category,
              name: nameCtrl.text.trim(),
              content: Value(contentCtrl.text.trim()),
              sortOrder: Value(existing?.sortOrder ?? 0),
            ),
          );
      await ref.read(novelRepositoryProvider).touchNovel(widget.novelId);
    }

    nameCtrl.dispose();
    contentCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final filters = ['全部', ...WorldCategories.all];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEntry(),
        icon: const Icon(Icons.add),
        label: const Text('新增设定'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s4,
              vertical: AppTokens.s2,
            ),
            child: Row(
              children: [
                for (final cat in filters) ...[
                  ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<WorldEntry>>(
              stream: db.watchWorldEntries(widget.novelId),
              builder: (context, snap) {
                final all = snap.data ?? const [];
                final list = _selectedCategory == '全部'
                    ? all
                    : all
                          .where((w) => w.category == _selectedCategory)
                          .toList();
                if (list.isEmpty) {
                  return const ZmEmptyState(
                    icon: Icons.public_outlined,
                    title: '暂无世界观条目',
                    description: '按地点 / 势力 / 规则 / 物品 / 其他分类沉淀设定。',
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.s4,
                        AppTokens.s2,
                        AppTokens.s4,
                        88,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTokens.s3),
                      itemBuilder: (_, i) {
                        final w = list[i];
                        return Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Chip(
                                  label: Text(
                                    w.category,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                w.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () async {
                                final ok = await showZmConfirmDialog(
                                  context,
                                  title: '删除条目「${w.name}」？',
                                  message: '删除后无法恢复。',
                                  confirmLabel: '删除',
                                  destructive: true,
                                );
                                if (ok) await db.deleteWorldEntry(w.id);
                              },
                            ),
                            onTap: () => _editEntry(w),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
