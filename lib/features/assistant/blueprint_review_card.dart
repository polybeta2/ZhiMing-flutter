import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/creation/creation_session_engine.dart';
import '../../domain/models/blueprint_models.dart';

/// 立项阶段进度条
class CreationStageBar extends StatelessWidget {
  const CreationStageBar({super.key, required this.phase});
  final CreationPhase phase;

  static const _steps = [
    (CreationPhase.collecting, '澄清'),
    (CreationPhase.proposing, '结构'),
    (CreationPhase.blueprintReady, '蓝图'),
    (CreationPhase.outlining, '卷章纲'),
    (CreationPhase.confirmed, '落库'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final curIdx = _steps.indexWhere((s) => s.$1 == phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= curIdx
                      ? cs.primary
                      : cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: i == curIdx
                    ? cs.primary
                    : i < curIdx
                    ? cs.primary.withValues(alpha: 0.14)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${i + 1}.${_steps[i].$2}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: i == curIdx
                      ? cs.onPrimary
                      : i < curIdx
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 卷章结构提案卡（proposing 阶段）
class StructureProposalCard extends StatelessWidget {
  const StructureProposalCard({
    super.key,
    required this.proposal,
    required this.busy,
    required this.onConfirm,
  });

  final StructureProposal proposal;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                const Text(
                  '卷章结构提案',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: busy ? null : onConfirm,
                  child: const Text('确认结构，生成蓝图'),
                ),
              ],
            ),
            if ((proposal.concept ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    proposal.concept!,
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < proposal.volumes.length; i++)
                  Chip(
                    label: Text(
                      '${proposal.volumes[i].name ?? '第${i + 1}卷'} · ${proposal.volumes[i].chapterCount ?? 0}章',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 蓝图审阅与批次推进面板（blueprintReady / outlining 阶段）
class BlueprintActionPanel extends StatelessWidget {
  const BlueprintActionPanel({
    super.key,
    required this.state,
    required this.progress,
    required this.busy,
    required this.onGenerateVolumeBatch,
    required this.onGenerateChapterBatch,
    required this.onGenerateChapterNames,
    required this.onToggleAutoContinue,
    required this.onChaptersPerBatchChanged,
    required this.onEditBlueprint,
    required this.onConfirmPersist,
  });

  final CreationSessionState state;
  final OutlineProgress progress;
  final bool busy;
  final VoidCallback onGenerateVolumeBatch;
  final VoidCallback onGenerateChapterBatch;
  final ValueChanged<int> onGenerateChapterNames;
  final ValueChanged<bool> onToggleAutoContinue;
  final ValueChanged<int> onChaptersPerBatchChanged;
  final VoidCallback onEditBlueprint;
  final VoidCallback onConfirmPersist;

  @override
  Widget build(BuildContext context) {
    final bp = state.blueprint;
    if (bp == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final needVolumes = progress.volumeDone < progress.volumeTotal;
    final needChapters = progress.outlineDone < progress.outlineTotal;

    final emptyTitleVolIdx = bp.volumes.indexWhere(
      (v) =>
          v.chapters.isNotEmpty &&
          v.chapters.every((c) => (c.title ?? '').trim().isEmpty),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '《${bp.titleSuggestion ?? '未命名蓝图'}》 · ${bp.characters.length} 角色 · ${bp.worldbuilding.length} 设定',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditBlueprint,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('查看/编辑蓝图'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '卷纲：${progress.volumeDone}/${progress.volumeTotal}  ·  章细纲：${progress.outlineDone}/${progress.outlineTotal}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (needVolumes)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onGenerateVolumeBatch,
                    icon: const Icon(Icons.layers_outlined, size: 16),
                    label: Text(
                      '生成卷纲（剩余 ${progress.volumeTotal - progress.volumeDone}）',
                    ),
                  )
                else if (emptyTitleVolIdx >= 0)
                  FilledButton.tonalIcon(
                    onPressed: busy
                        ? null
                        : () => onGenerateChapterNames(emptyTitleVolIdx),
                    icon: const Icon(Icons.title_rounded, size: 16),
                    label: Text(
                      '生成《${bp.volumes[emptyTitleVolIdx].name ?? '第${emptyTitleVolIdx + 1}卷'}》章名',
                    ),
                  )
                else if (needChapters)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onGenerateChapterBatch,
                    icon: const Icon(Icons.format_list_bulleted, size: 16),
                    label: Text(
                      '生成细纲（每批 ${state.chaptersPerBatch} 章，剩 ${progress.outlineTotal - progress.outlineDone}）',
                    ),
                  ),
                if (needVolumes || needChapters) ...[
                  DropdownButton<int>(
                    value: state.chaptersPerBatch.clamp(1, 5),
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var n = 1; n <= 5; n++)
                        DropdownMenuItem(value: n, child: Text('$n 章/批')),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) onChaptersPerBatchChanged(v);
                          },
                  ),
                  FilterChip(
                    label: const Text('自动连续', style: TextStyle(fontSize: 12)),
                    selected: state.autoContinue,
                    onSelected: onToggleAutoContinue,
                  ),
                ],
                FilledButton.icon(
                  onPressed: busy ? null : onConfirmPersist,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('创建作品落库'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 蓝图全文审阅与就地编辑弹窗
Future<void> showBlueprintEditorDialog(
  BuildContext context, {
  required NovelBlueprint blueprint,
  required VoidCallback onChanged,
}) async {
  final titleCtrl = TextEditingController(text: blueprint.titleSuggestion ?? '');
  final themeCtrl = TextEditingController(text: blueprint.theme ?? '');
  final synopsisCtrl = TextEditingController(text: blueprint.synopsis ?? '');
  final perspectiveCtrl = TextEditingController(
    text: blueprint.perspective ?? '',
  );
  final styleCtrl = TextEditingController(text: blueprint.styleGuide ?? '');

  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '审阅与编辑蓝图',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: '推荐书名'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: themeCtrl,
                            decoration: const InputDecoration(labelText: '主题基调'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: perspectiveCtrl,
                            decoration: const InputDecoration(labelText: '叙事视角'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: synopsisCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: '故事梗概',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: styleCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '文风约束',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      '角色（${blueprint.characters.length}）',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    for (final c in blueprint.characters)
                      ListTile(
                        dense: true,
                        title: Text('${c.name ?? ''}（${c.role ?? '角色'}）'),
                        subtitle: Text(
                          [c.personality, c.goal]
                              .where((s) => (s ?? '').isNotEmpty)
                              .join(' · '),
                        ),
                      ),
                    const Divider(height: 24),
                    Text(
                      '卷章蓝图（${blueprint.volumes.length} 卷）',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < blueprint.volumes.length; i++)
                      ExpansionTile(
                        dense: true,
                        title: Text(
                          blueprint.volumes[i].name ?? '第${i + 1}卷',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          (blueprint.volumes[i].outline ?? '').isEmpty
                              ? '${blueprint.volumes[i].chapters.length} 章 · 待生成卷纲'
                              : blueprint.volumes[i].outline!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        children: [
                          for (final ch in blueprint.volumes[i].chapters)
                            ListTile(
                              dense: true,
                              title: Text(ch.title ?? '未命名章'),
                              subtitle: (ch.detailedOutline ?? '').isNotEmpty
                                  ? Text(ch.detailedOutline!)
                                  : null,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      blueprint.titleSuggestion = titleCtrl.text.trim();
                      blueprint.theme = themeCtrl.text.trim();
                      blueprint.synopsis = synopsisCtrl.text.trim();
                      blueprint.perspective = perspectiveCtrl.text.trim();
                      blueprint.styleGuide = styleCtrl.text.trim();
                      onChanged();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('保存修改'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  titleCtrl.dispose();
  themeCtrl.dispose();
  synopsisCtrl.dispose();
  perspectiveCtrl.dispose();
  styleCtrl.dispose();
}
