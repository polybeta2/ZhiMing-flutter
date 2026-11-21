import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/character_graph_canvas.dart';
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
  int _tab = 0; // 0: 基本信息, 1: 角色卡, 2: 关系图谱, 3: 世界观

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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
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
                  label: Text('关系图谱'),
                  icon: Icon(Icons.hub_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('世界观'),
                  icon: Icon(Icons.public_outlined, size: 16),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => _BasicMetaPane(novelId: widget.novelId),
            1 => _CharacterListPane(novelId: widget.novelId),
            2 => _RelationGraphPane(novelId: widget.novelId),
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
    final result = await showDialog<_CharacterDraft>(
      context: context,
      builder: (_) => _EditCharacterDialog(existing: existing),
    );
    if (result == null) return;
    await ref
        .read(appDatabaseProvider)
        .upsertCharacter(
          CharactersCompanion.insert(
            id: existing?.id ?? const Uuid().v4(),
            novelId: novelId,
            name: result.name,
            aliasesJson: Value(encodeStringList(result.aliases)),
            appearance: Value(_opt(result.appearance)),
            personality: Value(_opt(result.personality)),
            background: Value(_opt(result.background)),
            currentGoal: Value(_opt(result.goal)),
            currentLocation: Value(_opt(result.location)),
            physicalState: Value(_opt(result.physicalState)),
            mentalState: Value(_opt(result.mentalState)),
            isSceneRelevant: Value(result.relevant),
            sortOrder: Value(existing?.sortOrder ?? 0),
          ),
        );
    await ref.read(novelRepositoryProvider).touchNovel(novelId);
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
    final result = await showDialog<_WorldEntryDraft>(
      context: context,
      builder: (_) => _EditWorldEntryDialog(existing: existing),
    );
    if (result == null) return;
    await ref
        .read(appDatabaseProvider)
        .upsertWorldEntry(
          WorldEntriesCompanion.insert(
            id: existing?.id ?? const Uuid().v4(),
            novelId: widget.novelId,
            category: result.category,
            name: result.name,
            content: Value(result.content),
            keywordsJson: Value(encodeStringList(result.keywords)),
            isAlwaysOn: Value(result.isAlwaysOn),
            sortOrder: Value(existing?.sortOrder ?? 0),
          ),
        );
    await ref.read(novelRepositoryProvider).touchNovel(widget.novelId);
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
                        final keywords = decodeStringList(w.keywordsJson);
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
                                if (w.isAlwaysOn)
                                  const Chip(
                                    label: Text(
                                      '常驻',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (keywords.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '触发词：${keywords.join('、')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ],
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

class _CharacterDraft {
  const _CharacterDraft({
    required this.name,
    required this.aliases,
    required this.appearance,
    required this.personality,
    required this.background,
    required this.goal,
    required this.location,
    required this.physicalState,
    required this.mentalState,
    required this.relevant,
  });

  final String name;
  final List<String> aliases;
  final String appearance;
  final String personality;
  final String background;
  final String goal;
  final String location;
  final String physicalState;
  final String mentalState;
  final bool relevant;
}

class _EditCharacterDialog extends StatefulWidget {
  const _EditCharacterDialog({this.existing});
  final Character? existing;

  @override
  State<_EditCharacterDialog> createState() => _EditCharacterDialogState();
}

class _EditCharacterDialogState extends State<_EditCharacterDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _aliasesCtrl;
  late final TextEditingController _appCtrl;
  late final TextEditingController _perCtrl;
  late final TextEditingController _bgCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _physCtrl;
  late final TextEditingController _mentCtrl;
  late bool _relevant;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _aliasesCtrl = TextEditingController(
      text: decodeStringList(e?.aliasesJson).join('、'),
    );
    _appCtrl = TextEditingController(text: e?.appearance ?? '');
    _perCtrl = TextEditingController(text: e?.personality ?? '');
    _bgCtrl = TextEditingController(text: e?.background ?? '');
    _goalCtrl = TextEditingController(text: e?.currentGoal ?? '');
    _locCtrl = TextEditingController(text: e?.currentLocation ?? '');
    _physCtrl = TextEditingController(text: e?.physicalState ?? '');
    _mentCtrl = TextEditingController(text: e?.mentalState ?? '');
    _relevant = e?.isSceneRelevant ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aliasesCtrl.dispose();
    _appCtrl.dispose();
    _perCtrl.dispose();
    _bgCtrl.dispose();
    _goalCtrl.dispose();
    _locCtrl.dispose();
    _physCtrl.dispose();
    _mentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增角色卡' : '编辑角色卡'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '姓名 *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _aliasesCtrl,
                decoration: const InputDecoration(labelText: '别名（顿号或逗号分隔）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _perCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '性格'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _appCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '外貌'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bgCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '背景经历'),
              ),
              const Divider(height: 24),
              TextField(
                controller: _goalCtrl,
                decoration: const InputDecoration(labelText: '当前目标'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locCtrl,
                decoration: const InputDecoration(labelText: '当前位置'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _physCtrl,
                decoration: const InputDecoration(labelText: '身体状态'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mentCtrl,
                decoration: const InputDecoration(labelText: '心理状态'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('参与近期剧情（续写优先注入）'),
                value: _relevant,
                onChanged: (v) => setState(() => _relevant = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final aliases = _aliasesCtrl.text
                .split(RegExp(r'[,，、;；\s]+'))
                .where((s) => s.trim().isNotEmpty)
                .toList();
            Navigator.of(context).pop(
              _CharacterDraft(
                name: name,
                aliases: aliases,
                appearance: _appCtrl.text,
                personality: _perCtrl.text,
                background: _bgCtrl.text,
                goal: _goalCtrl.text,
                location: _locCtrl.text,
                physicalState: _physCtrl.text,
                mentalState: _mentCtrl.text,
                relevant: _relevant,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _WorldEntryDraft {
  const _WorldEntryDraft({
    required this.category,
    required this.name,
    required this.keywords,
    required this.content,
    required this.isAlwaysOn,
  });

  final String category;
  final String name;
  final List<String> keywords;
  final String content;
  final bool isAlwaysOn;
}

class _EditWorldEntryDialog extends StatefulWidget {
  const _EditWorldEntryDialog({this.existing});
  final WorldEntry? existing;

  @override
  State<_EditWorldEntryDialog> createState() => _EditWorldEntryDialogState();
}

class _EditWorldEntryDialogState extends State<_EditWorldEntryDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _keywordsCtrl;
  late final TextEditingController _contentCtrl;
  late String _category;
  late bool _isAlwaysOn;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _keywordsCtrl = TextEditingController(
      text: decodeStringList(e?.keywordsJson).join('、'),
    );
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _category = e?.category ?? WorldCategories.all.first;
    _isAlwaysOn = e?.isAlwaysOn ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keywordsCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增世界观条目' : '编辑世界观条目'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: WorldCategories.all.contains(_category)
                    ? _category
                    : '其他',
                decoration: const InputDecoration(labelText: '分类'),
                items: [
                  for (final c in WorldCategories.all)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(
                  () => _category = v ?? WorldCategories.all.first,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '条目名称 *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _keywordsCtrl,
                decoration: const InputDecoration(
                  labelText: '触发关键词（顿号或逗号分隔，命中即自动注入）',
                  hintText: '例如：诡异副本、收容物、禁区',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '设定说明',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('常驻注入（每章续写自动携带）'),
                subtitle: const Text(
                  '关闭时仅在细纲/上下文提及条目名或关键词时按需激活',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isAlwaysOn,
                onChanged: (v) => setState(() => _isAlwaysOn = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final keywords = _keywordsCtrl.text
                .split(RegExp(r'[,，、;；\s]+'))
                .where((s) => s.trim().isNotEmpty)
                .toList();
            Navigator.of(context).pop(
              _WorldEntryDraft(
                category: _category,
                name: name,
                keywords: keywords,
                content: _contentCtrl.text.trim(),
                isAlwaysOn: _isAlwaysOn,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _RelationGraphPane extends ConsumerWidget {
  const _RelationGraphPane({required this.novelId});
  final String novelId;

  Future<void> _editRelation(
    BuildContext context,
    WidgetRef ref,
    List<Character> chars, [
    CharacterRelation? existing,
  ]) async {
    if (chars.length < 2) {
      showZmSnackBar(context, '至少需要 2 名角色才能建立关系', isError: true);
      return;
    }
    final draft = await showDialog<_RelationDraft>(
      context: context,
      builder: (_) => _EditRelationDialog(
        characters: chars,
        existing: existing,
      ),
    );
    if (draft == null) return;
    await ref
        .read(appDatabaseProvider)
        .upsertCharacterRelation(
          CharacterRelationsCompanion.insert(
            id: existing?.id ?? const Uuid().v4(),
            novelId: novelId,
            sourceCharacterId: draft.sourceId,
            targetCharacterId: draft.targetId,
            relationType: Value(draft.relationType),
            label: draft.label,
            description: Value(draft.description),
            strength: Value(draft.strength),
            line: Value(draft.line),
            evolutionJson: Value(existing?.evolutionJson ?? '[]'),
            firstChapterOrder: Value(existing?.firstChapterOrder),
            lastChapterOrder: Value(existing?.lastChapterOrder),
            updatedAt: DateTime.now(),
          ),
        );
    await ref.read(novelRepositoryProvider).touchNovel(novelId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return StreamBuilder<List<Character>>(
      stream: db.watchCharacters(novelId),
      builder: (context, charSnap) {
        final chars = charSnap.data ?? const [];
        return StreamBuilder<List<CharacterRelation>>(
          stream: db.watchCharacterRelations(novelId),
          builder: (context, relSnap) {
            final rels = relSnap.data ?? const [];
            final relById = {for (final r in rels) r.id: r};
            final nodes = [
              for (final c in chars)
                GraphNode(
                  id: c.id,
                  name: c.name,
                  camp: c.camp,
                  role: c.role,
                  importance: c.isSceneRelevant ? 'major' : 'normal',
                  subtitle: [
                    if ((c.currentLocation ?? '').isNotEmpty)
                      '位置：${c.currentLocation}',
                    if ((c.physicalState ?? '').isNotEmpty) c.physicalState!,
                  ].join(' · '),
                ),
            ];
            final edges = [
              for (final r in rels)
                GraphEdge(
                  id: r.id,
                  fromId: r.sourceCharacterId,
                  toId: r.targetCharacterId,
                  relationType: r.relationType,
                  label: r.label,
                  description: r.description,
                  strength: r.strength,
                  line: r.line,
                  firstChapter: r.firstChapterOrder,
                  lastChapter: r.lastChapterOrder,
                  evolution: [
                    for (final pt in RelationEvolutionPoint.decodeList(
                      r.evolutionJson,
                    ))
                      (chapterLabel: pt.chapterLabel, state: pt.state),
                  ],
                ),
            ];

            return CharacterGraphCanvas(
              nodes: nodes,
              edges: edges,
              onAddRelation: () => _editRelation(context, ref, chars),
              onEditRelation: (edge) =>
                  _editRelation(context, ref, chars, relById[edge.id]),
              onDeleteRelation: (edge) async {
                final ok = await showZmConfirmDialog(
                  context,
                  title: '删除关系「${edge.label}」？',
                  message: '将同时移除该关系的历史演变记录。',
                  confirmLabel: '删除',
                  destructive: true,
                );
                if (ok) {
                  await db.deleteCharacterRelation(edge.id);
                  await ref.read(novelRepositoryProvider).touchNovel(novelId);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _RelationDraft {
  const _RelationDraft({
    required this.sourceId,
    required this.targetId,
    required this.relationType,
    required this.label,
    required this.description,
    required this.strength,
    required this.line,
  });

  final String sourceId;
  final String targetId;
  final String relationType;
  final String label;
  final String description;
  final int strength;
  final String line;
}

class _EditRelationDialog extends StatefulWidget {
  const _EditRelationDialog({required this.characters, this.existing});

  final List<Character> characters;
  final CharacterRelation? existing;

  @override
  State<_EditRelationDialog> createState() => _EditRelationDialogState();
}

class _EditRelationDialogState extends State<_EditRelationDialog> {
  late String _sourceId;
  late String _targetId;
  late String _relationType;
  late String _line;
  late int _strength;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _sourceId = e?.sourceCharacterId ?? widget.characters.first.id;
    _targetId = e?.targetCharacterId ??
        widget.characters
            .firstWhere(
              (c) => c.id != _sourceId,
              orElse: () => widget.characters.last,
            )
            .id;
    _relationType = e?.relationType ?? '盟友';
    _line = e?.line ?? '明线';
    _strength = (e?.strength ?? 3).clamp(1, 5);
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增人物关系' : '编辑人物关系'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sourceId,
                      decoration: const InputDecoration(labelText: '角色 A'),
                      items: [
                        for (final c in widget.characters)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sourceId = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _targetId,
                      decoration: const InputDecoration(labelText: '角色 B'),
                      items: [
                        for (final c in widget.characters)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _targetId = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _relationType,
                      decoration: const InputDecoration(labelText: '关系类型'),
                      items: [
                        for (final t in ['亲友', '盟友', '爱恋', '敌对', '从属', '竞争', '未知'])
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _relationType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _line,
                      decoration: const InputDecoration(labelText: '明暗线'),
                      items: const [
                        DropdownMenuItem(value: '明线', child: Text('明线（公开）')),
                        DropdownMenuItem(value: '暗线', child: Text('暗线（秘密/隐藏）')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _line = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: '关系标签（如：生死同盟 / 宿敌追杀）',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('羁绊/冲突强度：', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _strength.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_strength',
                      onChanged: (v) => setState(() => _strength = v.round()),
                    ),
                  ),
                  Text('$_strength'),
                ],
              ),
              TextField(
                controller: _descCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '关系详情与张力说明',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_sourceId == _targetId) return;
            final label = _labelCtrl.text.trim();
            Navigator.of(context).pop(
              _RelationDraft(
                sourceId: _sourceId,
                targetId: _targetId,
                relationType: _relationType,
                label: label.isEmpty ? _relationType : label,
                description: _descCtrl.text.trim(),
                strength: _strength,
                line: _line,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
