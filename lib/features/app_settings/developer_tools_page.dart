import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/prompts/prompt_defaults.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/zm_widgets.dart';

/// 开发者工坊：全套内置系统提示词覆写 + 3 类示例标签库维护
class DeveloperToolsPage extends ConsumerWidget {
  const DeveloperToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('开发者工坊'),
          bottom: TabBar(
            tabs: [
              Tab(text: '系统提示词（${PromptDefaults.builtInPrompts.length}）'),
              const Tab(text: '示例标签库'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PromptsTab(), _TagsTab()],
        ),
      ),
    );
  }
}

class _PromptsTab extends ConsumerWidget {
  const _PromptsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(promptLibraryProvider);
    final grouped = <String, List<BuiltInPrompt>>{};
    for (final p in PromptDefaults.builtInPrompts) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.s4),
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _PromptTile(
                        prompt: entry.value[i],
                        customized: library.isCustomized(entry.value[i].id),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                _PromptEditPage(prompt: entry.value[i]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.s3),
            ],
          ],
        ),
      ),
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({
    required this.prompt,
    required this.customized,
    required this.onTap,
  });

  final BuiltInPrompt prompt;
  final bool customized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(prompt.name),
      subtitle: Text(
        prompt.id,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '已自定义',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PromptEditPage extends ConsumerStatefulWidget {
  const _PromptEditPage({required this.prompt});
  final BuiltInPrompt prompt;

  @override
  ConsumerState<_PromptEditPage> createState() => _PromptEditPageState();
}

class _PromptEditPageState extends ConsumerState<_PromptEditPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final current = ref
        .read(promptLibraryProvider)
        .resolvedText(widget.prompt.id);
    _ctrl = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(promptLibraryProvider.notifier)
        .setOverride(widget.prompt.id, _ctrl.text);
    if (mounted) {
      showZmSnackBar(context, '已保存提示词');
      Navigator.of(context).pop();
    }
  }

  Future<void> _reset() async {
    final ok = await showZmConfirmDialog(
      context,
      title: '恢复出厂默认？',
      message: '将清空此提示词的自定义内容并恢复为默认文本。',
      confirmLabel: '恢复默认',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(promptLibraryProvider.notifier)
        .resetOverride(widget.prompt.id);
    _ctrl.text = widget.prompt.defaultText;
    if (mounted) showZmSnackBar(context, '已恢复出厂默认');
  }

  @override
  Widget build(BuildContext context) {
    final isCustomized = ref
        .watch(promptLibraryProvider)
        .isCustomized(widget.prompt.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prompt.name),
        actions: [
          if (isCustomized)
            TextButton(onPressed: _reset, child: const Text('恢复默认')),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: AppTokens.s3),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTokens.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.prompt.placeholders.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final ph in widget.prompt.placeholders)
                    Chip(label: Text(ph, style: const TextStyle(fontSize: 12))),
                ],
              ),
              const SizedBox(height: AppTokens.s3),
            ],
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                maxLength: PromptLimits.maxOverrideChars,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 14, height: 1.6),
                decoration: const InputDecoration(
                  hintText: '输入系统提示词内容…',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagsTab extends ConsumerWidget {
  const _TagsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(promptLibraryProvider).tagCategories;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.s4),
          children: [
            for (final cat in categories) ...[
              Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    '${cat.name}（${cat.tags.length}）',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: IconButton(
                    tooltip: '新增标签',
                    icon: const Icon(Icons.add),
                    onPressed: () => _openTagEditor(context, ref, cat.id, null),
                  ),
                  children: [
                    for (final tag in cat.tags)
                      ListTile(
                        title: Text(tag.name),
                        subtitle: Text(
                          '关键词：${tag.keywords.join('、')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openTagEditor(context, ref, cat.id, tag),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.s3),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTagEditor(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
    PromptTag? tag,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TagEditPage(categoryId: categoryId, tag: tag),
      ),
    );
  }
}

class _TagEditPage extends ConsumerStatefulWidget {
  const _TagEditPage({required this.categoryId, this.tag});
  final String categoryId;
  final PromptTag? tag;

  @override
  ConsumerState<_TagEditPage> createState() => _TagEditPageState();
}

class _TagEditPageState extends ConsumerState<_TagEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _keywordsCtrl;
  late final TextEditingController _presetCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tag?.name ?? '');
    _keywordsCtrl = TextEditingController(
      text: widget.tag?.keywords.join('，') ?? '',
    );
    _presetCtrl = TextEditingController(text: widget.tag?.presetText ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keywordsCtrl.dispose();
    _presetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showZmSnackBar(context, '请填写标签名', isError: true);
      return;
    }
    final keywords = _keywordsCtrl.text
        .split(RegExp(r'[,，、;；\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final updated = PromptTag(
      id: widget.tag?.id ?? 'tag.${const Uuid().v4()}',
      name: name,
      keywords: keywords.isEmpty ? [name] : keywords,
      presetText: _presetCtrl.text.trim(),
    );
    await ref
        .read(promptLibraryProvider.notifier)
        .upsertTag(updated, categoryId: widget.categoryId);
    if (mounted) {
      showZmSnackBar(context, '标签已保存');
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final tag = widget.tag;
    if (tag == null) return;
    final ok = await showZmConfirmDialog(
      context,
      title: '删除标签「${tag.name}」？',
      message: '删除后立项时将不再提供该智能注入标签。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(promptLibraryProvider.notifier)
        .deleteTag(tag.id, categoryId: widget.categoryId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tag == null ? '新增示例标签' : '编辑标签'),
        actions: [
          if (widget.tag != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _delete,
            ),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: AppTokens.s3),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.s4),
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '标签名称'),
              ),
              const SizedBox(height: AppTokens.s3),
              TextField(
                controller: _keywordsCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '触发关键词（逗号或顿号分隔）',
                  hintText: '例如：推理，侦探，凶案，诡计',
                ),
              ),
              const SizedBox(height: AppTokens.s3),
              TextField(
                controller: _presetCtrl,
                minLines: 5,
                maxLines: 14,
                maxLength: PromptLimits.maxTagPresetChars,
                decoration: const InputDecoration(
                  labelText: '预设创作约束内容',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
