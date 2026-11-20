import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/novel_repository.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/r18_toggle_tile.dart';
import '../../core/widgets/zm_widgets.dart';
import '../source_archive/source_injection_helper.dart';
import '../source_archive/source_scan_dialogs.dart';

enum _CreateMode { choose, blank, oneLine, fullIdea }

/// 新建作品统一向导（可滚动防小屏溢出，五入口齐全）
class NovelCreateSheet extends ConsumerStatefulWidget {
  const NovelCreateSheet({super.key});

  @override
  ConsumerState<NovelCreateSheet> createState() => _NovelCreateSheetState();
}

class _NovelCreateSheetState extends ConsumerState<NovelCreateSheet> {
  _CreateMode _mode = _CreateMode.choose;

  // 空白建书
  final _titleCtrl = TextEditingController();
  final _synopsisCtrl = TextEditingController();
  final _styleGuideCtrl = TextEditingController();
  String _perspective = '';
  int _accentIndex = 0;

  // 一句话立项 / 完整思路立项
  final _briefCtrl = TextEditingController();
  final _fullTitleCtrl = TextEditingController();
  final _fullIdeaCtrl = TextEditingController();
  final Set<String> _selectedTagIds = {};
  bool _r18Enabled = false;
  bool _submitting = false;

  static const _perspectives = [
    '',
    '第一人称',
    '第三人称限知',
    '第三人称全知',
    '多视角交替',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _synopsisCtrl.dispose();
    _styleGuideCtrl.dispose();
    _briefCtrl.dispose();
    _fullTitleCtrl.dispose();
    _fullIdeaCtrl.dispose();
    super.dispose();
  }

  String get _headerTitle => switch (_mode) {
    _CreateMode.choose => '新建作品',
    _CreateMode.blank => '空白建书',
    _CreateMode.oneLine => '一句话立项',
    _CreateMode.fullIdea => '完整思路立项',
  };

  Future<void> _submitBlank() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showZmSnackBar(context, '请填写书名', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final id = await ref
        .read(novelRepositoryProvider)
        .createBlankNovel(
          title: title,
          synopsis: _synopsisCtrl.text,
          perspective: _perspective,
          styleGuide: _styleGuideCtrl.text,
          accentColorHex: AppTokens.accentPresets[_accentIndex].hex,
          r18Enabled: _r18Enabled,
        );
    if (mounted) Navigator.of(context).pop(id);
  }

  Future<void> _submitOneLine() async {
    final brief = _briefCtrl.text.trim();
    if (brief.isEmpty) {
      showZmSnackBar(context, '请先写下一句话创意', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final autoTitle = brief.length > 14 ? '${brief.substring(0, 14)}…' : brief;
    final id = await ref
        .read(novelRepositoryProvider)
        .createCreationNovel(
          title: autoTitle,
          brief: brief,
          enabledTagIds: _selectedTagIds.toList(),
          r18Enabled: _r18Enabled,
          skipsClarification: false,
        );
    if (mounted) Navigator.of(context).pop(id);
  }

  Future<void> _submitFullIdea() async {
    final idea = _fullIdeaCtrl.text.trim();
    if (idea.isEmpty) {
      showZmSnackBar(context, '请粘贴或输入完整构思', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final title = _fullTitleCtrl.text.trim().isNotEmpty
        ? _fullTitleCtrl.text.trim()
        : (idea.length > 14 ? '${idea.substring(0, 14)}…' : idea);
    final id = await ref
        .read(novelRepositoryProvider)
        .createCreationNovel(
          title: title,
          brief: idea,
          r18Enabled: _r18Enabled,
          skipsClarification: true,
        );
    if (mounted) Navigator.of(context).pop(id);
  }

  void _previewTag(PromptTag tag) {
    final selected = _selectedTagIds.contains(tag.id);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tag.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '触发关键词：${tag.keywords.join('、')}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Text(tag.presetText, style: const TextStyle(height: 1.55)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                if (selected) {
                  _selectedTagIds.remove(tag.id);
                } else {
                  _selectedTagIds.add(tag.id);
                }
              });
              Navigator.of(ctx).pop();
            },
            child: Text(selected ? '取消启用' : '启用此标签'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s4,
              vertical: AppTokens.s2,
            ),
            child: Row(
              children: [
                if (_mode != _CreateMode.choose)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _mode = _CreateMode.choose),
                  ),
                Expanded(
                  child: Text(
                    _headerTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(AppTokens.s4),
              children: switch (_mode) {
                _CreateMode.choose => _buildChooseEntries(),
                _CreateMode.blank => _buildBlankForm(),
                _CreateMode.oneLine => _buildOneLineForm(),
                _CreateMode.fullIdea => _buildFullIdeaForm(),
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChooseEntries() {
    return [
      _EntryCard(
        icon: Icons.auto_awesome_rounded,
        tint: const Color(0xFF4D5C91),
        title: '一句话立项',
        subtitle: '说出一句灵感，AI 通过澄清问答 → 卷章结构 → 蓝图卡片 → 批量细纲带你共创',
        onTap: () => setState(() => _mode = _CreateMode.oneLine),
      ),
      const SizedBox(height: AppTokens.s3),
      _EntryCard(
        icon: Icons.description_outlined,
        tint: Colors.indigo,
        title: '完整思路立项',
        subtitle: '已有完整构思或大纲，跳过问答直接规划全书卷章与细纲',
        onTap: () => setState(() => _mode = _CreateMode.fullIdea),
      ),
      const SizedBox(height: AppTokens.s3),
      _EntryCard(
        icon: Icons.book_outlined,
        tint: Colors.teal,
        title: '空白建书',
        subtitle: '自己填写书名、梗概与风格，直接进入章节写作',
        onTap: () => setState(() => _mode = _CreateMode.blank),
      ),
      const SizedBox(height: AppTokens.s3),
      _EntryCard(
        icon: Icons.library_books_outlined,
        tint: Colors.deepPurple,
        title: '同人立项',
        subtitle: '前往「原作库」选择或导入原作 txt，基于时间窗档案创作不 OOC 同人作品',
        onTap: () {
          Navigator.of(context).pop();
          context.go('/sources');
        },
      ),
      const SizedBox(height: AppTokens.s3),
      _EntryCard(
        icon: Icons.edit_note_rounded,
        tint: Colors.orange.shade800,
        title: '续写小说 / IF 线',
        subtitle: '导入断更或未完结小说 txt，任选续写起点，全量导入原作只读卷、人物现状与未回收伏笔',
        onTap: () async {
          final profile = await ContinuationImportDialog.show(context);
          if (profile == null || !mounted) return;
          final novelId = await ref
              .read(sourceAndStyleBridgeProvider)
              .createContinuationNovel(profile: profile);
          if (mounted) Navigator.of(context).pop(novelId);
        },
      ),
    ];
  }

  List<Widget> _buildBlankForm() {
    return [
      TextField(
        controller: _titleCtrl,
        decoration: const InputDecoration(labelText: '书名 *'),
      ),
      const SizedBox(height: AppTokens.s3),
      TextField(
        controller: _synopsisCtrl,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: '梗概（可选）',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: AppTokens.s3),
      DropdownButtonFormField<String>(
        initialValue: _perspective,
        decoration: const InputDecoration(labelText: '叙事视角'),
        items: [
          for (final p in _perspectives)
            DropdownMenuItem(value: p, child: Text(p.isEmpty ? '暂不指定' : p)),
        ],
        onChanged: (v) => setState(() => _perspective = v ?? ''),
      ),
      const SizedBox(height: AppTokens.s3),
      TextField(
        controller: _styleGuideCtrl,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: '风格约束（续写时必注入）',
          hintText: '例如：冷峻白描、克制心理描写、对话重潜台词…',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: AppTokens.s3),
      if (!_r18Enabled) ...[
        Text('作品封面色', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (var i = 0; i < AppTokens.accentPresets.length; i++)
              ChoiceChip(
                label: Text(AppTokens.accentPresets[i].name),
                selected: _accentIndex == i,
                onSelected: (_) => setState(() => _accentIndex = i),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.s3),
      ],
      R18ToggleTile(
        value: _r18Enabled,
        onChanged: (v) => setState(() => _r18Enabled = v),
      ),
      const SizedBox(height: AppTokens.s4),
      FilledButton(
        onPressed: _submitting ? null : _submitBlank,
        child: const Text('创建并开始写作'),
      ),
    ];
  }

  List<Widget> _buildOneLineForm() {
    final categories = ref.watch(promptLibraryProvider).tagCategories;
    return [
      TextField(
        controller: _briefCtrl,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: '一句话创意 *',
          hintText: '例如：一名失忆的港口邮差，每周五都会收到自己三年前寄出的密信…',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: AppTokens.s4),
      Text(
        '智能方向标签（点选查看并启用；创意命中关键词时自动注入蓝图规划）',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppTokens.s2),
      for (final cat in categories) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            cat.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final tag in cat.tags)
              FilterChip(
                label: Text(tag.name),
                selected: _selectedTagIds.contains(tag.id),
                onSelected: (_) => _previewTag(tag),
              ),
          ],
        ),
      ],
      const SizedBox(height: AppTokens.s3),
      R18ToggleTile(
        value: _r18Enabled,
        onChanged: (v) => setState(() => _r18Enabled = v),
      ),
      const SizedBox(height: AppTokens.s4),
      FilledButton.icon(
        onPressed: _submitting ? null : _submitOneLine,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('进入 AI 立项共创'),
      ),
    ];
  }

  List<Widget> _buildFullIdeaForm() {
    return [
      TextField(
        controller: _fullTitleCtrl,
        decoration: const InputDecoration(
          labelText: '暂定书名（可选，留空由 AI 拟定）',
        ),
      ),
      const SizedBox(height: AppTokens.s3),
      TextField(
        controller: _fullIdeaCtrl,
        minLines: 7,
        maxLines: 14,
        decoration: const InputDecoration(
          labelText: '完整构思 / 设定 / 大纲 *',
          hintText: '粘贴你的角色、世界观、关键情节点或结局安排，AI 将跳过澄清问答直接规划卷章结构…',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: AppTokens.s3),
      R18ToggleTile(
        value: _r18Enabled,
        onChanged: (v) => setState(() => _r18Enabled = v),
      ),
      const SizedBox(height: AppTokens.s4),
      FilledButton.icon(
        onPressed: _submitting ? null : _submitFullIdea,
        icon: const Icon(Icons.rocket_launch_outlined),
        label: const Text('跳过问答，直接规划结构'),
      ),
    ];
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s4),
          child: Row(
            children: [
              ZmSettingsIcon(icon: icon, tint: tint, size: 42),
              const SizedBox(width: AppTokens.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
