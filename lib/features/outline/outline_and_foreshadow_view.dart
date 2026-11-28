import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/novel_repository.dart';
import '../../core/llm/llm_json_parser.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/llm/token_usage_ledger.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/prompts/prompt_templates.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/prompt_guard.dart';
import '../../core/widgets/effort_selector_bar.dart';
import '../../core/widgets/story_timeline_view.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../core/widgets/thinking_process_card.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/novel_domain.dart';
import '../../domain/writing/context_builder.dart';

/// 作品「大纲与伏笔」统一视图：卷章四维结构 + AI 卷纲/细纲/批量细纲 + 独立伏笔台账 + 故事时间线
class OutlineAndForeshadowView extends ConsumerStatefulWidget {
  const OutlineAndForeshadowView({
    super.key,
    required this.novelId,
    this.onJumpToChapter,
  });

  final String novelId;
  final ValueChanged<String>? onJumpToChapter;

  @override
  ConsumerState<OutlineAndForeshadowView> createState() =>
      _OutlineAndForeshadowViewState();
}

class _OutlineAndForeshadowViewState
    extends ConsumerState<OutlineAndForeshadowView> {
  int _tab = 0; // 0: 卷章大纲, 1: 伏笔台账, 2: 故事时间线

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
                  label: Text('卷章大纲'),
                  icon: Icon(Icons.format_list_numbered, size: 16),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('伏笔台账'),
                  icon: Icon(Icons.bookmark_border_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('故事时间线'),
                  icon: Icon(Icons.timeline_rounded, size: 16),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => _OutlineListPane(novelId: widget.novelId),
            1 => _ForeshadowListPane(novelId: widget.novelId),
            _ => _TimelinePane(
              novelId: widget.novelId,
              onJumpToChapter: widget.onJumpToChapter,
            ),
          },
        ),
      ],
    );
  }
}

class _OutlineListPane extends ConsumerStatefulWidget {
  const _OutlineListPane({required this.novelId});
  final String novelId;

  @override
  ConsumerState<_OutlineListPane> createState() => _OutlineListPaneState();
}

class _OutlineListPaneState extends ConsumerState<_OutlineListPane> {
  final _progress = StreamProgressTracker();
  CancelToken? _cancel;
  bool _batchRunning = false;
  String _batchLabel = '';
  ReasoningEffort? _batchEffort;

  @override
  void dispose() {
    _cancel?.cancel();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _addVolume() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增卷'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '卷名（留空自动编号）',
            hintText: '例如：第一卷：雾起',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    await ref.read(novelRepositoryProvider).addVolume(widget.novelId, name: name);
  }

  Future<void> _addChapter(Volume volume) async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('在「${volume.name}」新增章节'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '章节标题（留空自动编号）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (title == null) return;
    await ref
        .read(novelRepositoryProvider)
        .addChapter(widget.novelId, volume.id, title: title);
  }

  Future<void> _editVolume(Volume volume) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _VolumeEditDialog(novelId: widget.novelId, volume: volume),
    );
  }

  Future<void> _editChapter(Chapter chapter) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _ChapterOutlineEditDialog(novelId: widget.novelId, chapter: chapter),
    );
  }

  Future<void> _runBatchChapterOutlines(Volume volume) async {
    final provider = ref.read(defaultProviderProvider);
    if (provider == null) {
      showZmSnackBar(context, '请先在「设置」配置模型提供商', isError: true);
      return;
    }
    final repo = ref.read(novelRepositoryProvider);
    final bundle = await repo.loadBundle(widget.novelId);
    if (bundle == null) return;
    final volBundle = bundle.volumes
        .where((v) => v.volume.id == volume.id)
        .firstOrNull;
    if (volBundle == null) return;

    final pending = volBundle.chapters
        .where(
          (c) =>
              !c.chapter.isOriginal &&
              (c.chapter.detailedOutline ?? '').trim().isEmpty,
        )
        .toList();
    if (pending.isEmpty) {
      if (mounted) showZmSnackBar(context, '本卷所有章节均已有细纲');
      return;
    }
    final batch = pending.take(5).toList();
    final titles = batch.map((c) => c.chapter.title).toList();

    final contextBuf = StringBuffer()
      ..writeln('【作品梗概】\n${bundle.novel.synopsis}')
      ..writeln('\n【所在卷】${volume.name}');
    if ((volume.outline ?? '').isNotEmpty) {
      contextBuf.writeln('卷纲：${volume.outline}');
    }
    final doneChapters = volBundle.chapters
        .where((c) => (c.chapter.detailedOutline ?? '').trim().isNotEmpty)
        .toList();
    if (doneChapters.isNotEmpty) {
      contextBuf.writeln('\n【已完成细纲】');
      for (final d in doneChapters.take(6)) {
        contextBuf.writeln('- ${d.chapter.title}：${d.chapter.detailedOutline}');
      }
    }
    final futureChapters = volBundle.chapters
        .where((c) => !batch.any((b) => b.chapter.id == c.chapter.id))
        .map((c) => c.chapter.title)
        .toList();
    if (futureChapters.isNotEmpty) {
      contextBuf.writeln('\n【本卷其他章节标题】${futureChapters.join('、')}');
    }

    final lib = ref.read(promptLibraryProvider);
    var messages = PromptTemplates.outline(
      library: lib,
      systemId: PromptID.chapterBatchOutline,
      renderedContext:
          '${contextBuf.toString()}\n\n【本批待生成章节】\n${[for (var i = 0; i < titles.length; i++) '${i + 1}. ${titles[i]}'].join('\n')}',
    );
    messages = PromptTemplates.applyingExtra(
      provider.systemPromptExtra,
      messages,
    );

    if (!mounted) return;
    final ok = await PromptGuard.authorize(
      context,
      totalChars: messages.totalContentChars,
    );
    if (!ok) return;

    setState(() {
      _batchRunning = true;
      _batchLabel = '批量生成细纲（${batch.length} 章）…';
    });
    _cancel = CancelToken();
    _progress.begin();
    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
        defaultReasoningEffort: _batchEffort,
      );
      final buf = StringBuffer();
      await for (final ev in client.streamChat(
        messages,
        config: GenerationConfig(
          temperature: provider.temperature,
          maxTokens: provider.maxTokens,
        ),
        cancelToken: _cancel,
      )) {
        _progress.handle(ev);
        if (ev is ContentDelta) buf.write(ev.text);
      }
      unawaited(
        ref
            .read(tokenUsageLedgerProvider.notifier)
            .recordUsage(
              usage: _progress.lastCompletedUsage,
              category: UsageCategory.outline,
              provider: provider,
              novelId: widget.novelId,
              effort: _batchEffort,
            ),
      );
      final parsed = LLMJSONParser.decodeList<Map<String, dynamic>>(
        buf.toString(),
        (e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
      );
      if (parsed == null || parsed.isEmpty) {
        if (mounted) {
          showZmSnackBar(context, '批量细纲 JSON 解析失败，请重试', isError: true);
        }
        return;
      }
      var written = 0;
      for (var i = 0; i < batch.length; i++) {
        final target = batch[i];
        final match =
            parsed
                .where(
                  (m) =>
                      _normalize(m['title']?.toString() ?? '') ==
                      _normalize(target.chapter.title),
                )
                .firstOrNull ??
            (i < parsed.length ? parsed[i] : null);
        if (match == null) continue;
        final outline = match['detailed_outline']?.toString().trim() ?? '';
        if (outline.isEmpty) continue;
        final cardsRaw = match['scene_cards'];
        final cards = cardsRaw is List
            ? cardsRaw.map(SceneCard.fromJson).where((c) => !c.isEmpty).toList()
            : <SceneCard>[];
        await repo.updateChapterOutline(
          novelId: widget.novelId,
          chapterId: target.chapter.id,
          detailedOutline: outline,
          sceneCards: cards.isEmpty ? null : cards,
        );
        written++;
      }
      if (mounted) showZmSnackBar(context, '已批量写入 $written 章细纲');
    } catch (e) {
      if (mounted) showZmSnackBar(context, '批量生成失败：$e', isError: true);
    } finally {
      _progress.finish();
      if (mounted) setState(() => _batchRunning = false);
    }
  }

  static String _normalize(String s) =>
      s.replaceAll(RegExp(r'[\s:：\-—《》「」『』""''、，,。.]'), '').toLowerCase();

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVolume,
        icon: const Icon(Icons.add),
        label: const Text('新增卷'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.s4,
              0,
              AppTokens.s4,
              4,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: EffortCompactChip(
                value: _batchEffort,
                provider: ref.watch(defaultProviderProvider),
                enabled: !_batchRunning,
                onChanged: (v) => setState(() => _batchEffort = v),
              ),
            ),
          ),
          if (_batchRunning)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s4,
                vertical: 6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      StreamingStatusChip(tracker: _progress),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _batchLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _cancel?.cancel(),
                        child: const Text('停止'),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ThinkingProcessCard(
                      tracker: _progress,
                      maxExpandedHeight: 120,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Volume>>(
              stream: db.watchVolumes(widget.novelId),
              builder: (context, snap) {
                final volumes = snap.data ?? const [];
                if (volumes.isEmpty) {
                  return const ZmEmptyState(
                    icon: Icons.format_list_numbered,
                    title: '还没有卷章结构',
                    description: '点击右下角「新增卷」开始搭建卷纲、四维结构与章节细纲。',
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.s4,
                        AppTokens.s2,
                        AppTokens.s4,
                        88,
                      ),
                      itemCount: volumes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTokens.s3),
                      itemBuilder: (_, idx) {
                        final vol = volumes[idx];
                        return _VolumeCard(
                          novelId: widget.novelId,
                          volume: vol,
                          index: idx + 1,
                          onEditVolume: () => _editVolume(vol),
                          onAddChapter: () => _addChapter(vol),
                          onBatchOutline: _batchRunning
                              ? null
                              : () => _runBatchChapterOutlines(vol),
                          onEditChapter: _editChapter,
                          onDeleteVolume: () async {
                            final ok = await showZmConfirmDialog(
                              context,
                              title: '删除「${vol.name}」？',
                              message: '本卷下全部章节正文与快照将一并删除，无法恢复。',
                              confirmLabel: '删除卷',
                              destructive: true,
                            );
                            if (ok) {
                              await ref
                                  .read(novelRepositoryProvider)
                                  .deleteVolumeAndNormalize(
                                    widget.novelId,
                                    vol.id,
                                  );
                            }
                          },
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

class _VolumeCard extends ConsumerWidget {
  const _VolumeCard({
    required this.novelId,
    required this.volume,
    required this.index,
    required this.onEditVolume,
    required this.onAddChapter,
    required this.onBatchOutline,
    required this.onEditChapter,
    required this.onDeleteVolume,
  });

  final String novelId;
  final Volume volume;
  final int index;
  final VoidCallback onEditVolume;
  final VoidCallback onAddChapter;
  final VoidCallback? onBatchOutline;
  final ValueChanged<Chapter> onEditChapter;
  final VoidCallback onDeleteVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final cs = Theme.of(context).colorScheme;
    final emotionArc = decodeStringList(volume.emotionArcJson);
    final ladder = ConflictRung.decodeList(volume.conflictLadderJson);
    final infoGap = InfoGap.decode(volume.infoGapJson);

    return Card(
      child: StreamBuilder<List<Chapter>>(
        stream: db.watchChaptersByVolume(volume.id),
        builder: (context, snap) {
          final chapters = snap.data ?? const [];
          final missingCount = chapters
              .where(
                (c) =>
                    !c.isOriginal && (c.detailedOutline ?? '').trim().isEmpty,
              )
              .length;

          return ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              '第$index卷 · ${volume.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${chapters.length} 章${(volume.outline ?? '').isNotEmpty ? ' · 已有卷纲' : ' · 待补卷纲'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: '编辑卷纲与四维结构',
                  icon: const Icon(Icons.edit_note_rounded),
                  onPressed: onEditVolume,
                ),
                IconButton(
                  tooltip: '新增章节',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAddChapter,
                ),
                IconButton(
                  tooltip: '删除卷',
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  onPressed: onDeleteVolume,
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((volume.outline ?? '').trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          volume.outline!,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),
                    if (emotionArc.isNotEmpty ||
                        ladder.isNotEmpty ||
                        infoGap != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (emotionArc.isNotEmpty)
                            Chip(
                              label: Text(
                                '情绪：${emotionArc.join(' → ')}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (ladder.isNotEmpty)
                            Chip(
                              label: Text(
                                '冲突阶梯 ${ladder.length} 级',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (infoGap != null)
                            Chip(
                              label: Text(
                                '信息差：${infoGap.start} → ${infoGap.end}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                    if (missingCount > 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: onBatchOutline,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: Text('AI 批量补全细纲（剩余 $missingCount 章，每次最多 5 章）'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final ch in chapters)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      '${ch.sortOrder}',
                      style: TextStyle(fontSize: 11, color: cs.primary),
                    ),
                  ),
                  title: Text(ch.title),
                  subtitle: Text(
                    (ch.detailedOutline ?? '').trim().isEmpty
                        ? '点击编写细纲与场景卡…'
                        : ch.detailedOutline!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (SceneCard.decodeList(ch.sceneCardsJson).isNotEmpty)
                        Chip(
                          label: Text(
                            '${SceneCard.decodeList(ch.sceneCardsJson).length} 卡',
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: cs.error,
                        ),
                        onPressed: () async {
                          final ok = await showZmConfirmDialog(
                            context,
                            title: '删除章节「${ch.title}」？',
                            message: '该章正文与历史快照将被删除，无法恢复。',
                            confirmLabel: '删除',
                            destructive: true,
                          );
                          if (ok) {
                            await ref
                                .read(novelRepositoryProvider)
                                .deleteChapterAndNormalize(
                                  novelId,
                                  volume.id,
                                  ch.id,
                                );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => onEditChapter(ch),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 卷纲 + 四维结构编辑 + AI 生成卷纲（支持解析 zm-dims 围栏）
class _VolumeEditDialog extends ConsumerStatefulWidget {
  const _VolumeEditDialog({required this.novelId, required this.volume});
  final String novelId;
  final Volume volume;

  @override
  ConsumerState<_VolumeEditDialog> createState() => _VolumeEditDialogState();
}

class _VolumeEditDialogState extends ConsumerState<_VolumeEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _outlineCtrl;
  late final TextEditingController _arcCtrl;
  late final TextEditingController _gapStartCtrl;
  late final TextEditingController _gapEndCtrl;
  late final TextEditingController _aiInstructionCtrl;
  late List<ConflictRung> _ladder;

  final _progress = StreamProgressTracker();
  CancelToken? _cancel;
  bool _generating = false;
  ReasoningEffort? _effort;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.volume.name);
    _outlineCtrl = TextEditingController(text: widget.volume.outline ?? '');
    _arcCtrl = TextEditingController(
      text: decodeStringList(widget.volume.emotionArcJson).join(' → '),
    );
    final gap = InfoGap.decode(widget.volume.infoGapJson);
    _gapStartCtrl = TextEditingController(text: gap?.start ?? '');
    _gapEndCtrl = TextEditingController(text: gap?.end ?? '');
    _aiInstructionCtrl = TextEditingController();
    _ladder = ConflictRung.decodeList(widget.volume.conflictLadderJson);
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _progress.dispose();
    _nameCtrl.dispose();
    _outlineCtrl.dispose();
    _arcCtrl.dispose();
    _gapStartCtrl.dispose();
    _gapEndCtrl.dispose();
    _aiInstructionCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateVolumeOutline() async {
    final provider = ref.read(defaultProviderProvider);
    if (provider == null) {
      showZmSnackBar(context, '请先配置模型提供商', isError: true);
      return;
    }
    final bundle = await ref
        .read(novelRepositoryProvider)
        .loadBundle(widget.novelId);
    if (bundle == null) return;
    final volBundle = bundle.volumes
        .where((v) => v.volume.id == widget.volume.id)
        .firstOrNull;
    if (volBundle == null) return;

    final budget = PromptTemplates.adjustedInputBudget(
      provider.contextBudgetChars,
      [provider.systemPromptExtra],
    );
    final ctx = ContextBuilder.buildOutlineContext(
      target: VolumeOutlineTarget(volBundle),
      bundle: bundle,
      budgetChars: budget,
    );
    var msgs = PromptTemplates.outline(
      library: ref.read(promptLibraryProvider),
      systemId: PromptID.volumeOutline,
      renderedContext: ctx.rendered,
      instruction: _aiInstructionCtrl.text,
    );
    msgs = PromptTemplates.applyingExtra(provider.systemPromptExtra, msgs);
    if (!mounted) return;
    if (!await PromptGuard.authorize(
      context,
      totalChars: msgs.totalContentChars,
    )) {
      return;
    }

    setState(() => _generating = true);
    _cancel = CancelToken();
    _progress.begin();
    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
        defaultReasoningEffort: _effort,
      );
      final buf = StringBuffer();
      await for (final ev in client.streamChat(
        msgs,
        config: GenerationConfig(
          temperature: provider.temperature,
          maxTokens: provider.maxTokens,
        ),
        cancelToken: _cancel,
      )) {
        _progress.handle(ev);
        if (ev is ContentDelta) buf.write(ev.text);
      }
      unawaited(
        ref
            .read(tokenUsageLedgerProvider.notifier)
            .recordUsage(
              usage: _progress.lastCompletedUsage,
              category: UsageCategory.outline,
              provider: provider,
              novelId: widget.novelId,
              effort: _effort,
            ),
      );
      _applyAiOutput(buf.toString());
    } catch (e) {
      if (mounted) showZmSnackBar(context, 'AI 生成失败：$e', isError: true);
    } finally {
      _progress.finish();
      if (mounted) setState(() => _generating = false);
    }
  }

  void _applyAiOutput(String raw) {
    final fenceRe = RegExp(r'```zm-dims\s*([\s\S]*?)```');
    final match = fenceRe.firstMatch(raw);
    var body = raw;
    if (match != null) {
      body = raw.replaceRange(match.start, match.end, '').trim();
      final payload = match.group(1) ?? '';
      try {
        final obj = LLMJSONParser.decodeAny(payload);
        if (obj is Map) {
          final arcRaw = obj['emotion_arc'];
          if (arcRaw is List && arcRaw.isNotEmpty) {
            _arcCtrl.text = arcRaw.map((e) => e.toString()).join(' → ');
          }
          final ladderRaw = obj['conflict_ladder'];
          if (ladderRaw is List && ladderRaw.isNotEmpty) {
            _ladder = [
              for (var i = 0; i < ladderRaw.length; i++)
                ConflictRung.fromJson(ladderRaw[i], fallbackLevel: i + 1),
            ];
          }
          final gapRaw = obj['info_gap'];
          if (gapRaw != null) {
            final gap = InfoGap.fromJson(gapRaw);
            if (!gap.isEmpty) {
              _gapStartCtrl.text = gap.start;
              _gapEndCtrl.text = gap.end;
            }
          }
        }
      } catch (_) {}
    }
    setState(() {
      _outlineCtrl.text = body.trim();
    });
  }

  Future<void> _save() async {
    final arc = _arcCtrl.text
        .split(RegExp(r'[→\->,，、\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await ref
        .read(novelRepositoryProvider)
        .updateVolumeOutline(
          novelId: widget.novelId,
          volumeId: widget.volume.id,
          name: _nameCtrl.text.trim().isEmpty
              ? widget.volume.name
              : _nameCtrl.text.trim(),
          outline: _outlineCtrl.text,
          emotionArc: arc,
          conflictLadder: _ladder,
          infoGap: InfoGap(
            start: _gapStartCtrl.text.trim(),
            end: _gapEndCtrl.text.trim(),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '编辑卷纲与四维结构',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: '卷名'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _aiInstructionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'AI 卷纲附加要求（可选）',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _generating ? null : _generateVolumeOutline,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('AI 生成'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    EffortSelectorBar(
                      value: _effort,
                      provider: ref.watch(defaultProviderProvider),
                      enabled: !_generating,
                      compact: true,
                      onChanged: (v) => setState(() => _effort = v),
                    ),
                    if (_generating) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StreamingStatusChip(tracker: _progress),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _cancel?.cancel(),
                            child: const Text('停止'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ThinkingProcessCard(
                        tracker: _progress,
                        maxExpandedHeight: 130,
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _outlineCtrl,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '卷纲正文',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _arcCtrl,
                      decoration: const InputDecoration(
                        labelText: '情绪走向（用 → 或逗号分隔节拍）',
                        hintText: '压抑 → 试探 → 反转 → 爆发',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gapStartCtrl,
                            decoration: const InputDecoration(
                              labelText: '信息差 · 卷初已知',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _gapEndCtrl,
                            decoration: const InputDecoration(
                              labelText: '信息差 · 卷末揭示',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '冲突阶梯',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _ladder.add(
                              ConflictRung(
                                level: _ladder.length + 1,
                                obstacle: '',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('加一级'),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _ladder.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text('L${i + 1} '),
                            Expanded(
                              child: TextFormField(
                                initialValue: _ladder[i].obstacle,
                                decoration: const InputDecoration(
                                  hintText: '阻力/对手',
                                  isDense: true,
                                ),
                                onChanged: (v) => _ladder[i] = ConflictRung(
                                  level: i + 1,
                                  obstacle: v,
                                  turningPoint: _ladder[i].turningPoint,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextFormField(
                                initialValue: _ladder[i].turningPoint ?? '',
                                decoration: const InputDecoration(
                                  hintText: '转折点（可选）',
                                  isDense: true,
                                ),
                                onChanged: (v) => _ladder[i] = ConflictRung(
                                  level: i + 1,
                                  obstacle: _ladder[i].obstacle,
                                  turningPoint: v,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _ladder.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('保存')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 章节细纲 + 场景卡编辑 + AI 生成细纲（支持解析 zm-scene 围栏）
class _ChapterOutlineEditDialog extends ConsumerStatefulWidget {
  const _ChapterOutlineEditDialog({
    required this.novelId,
    required this.chapter,
  });
  final String novelId;
  final Chapter chapter;

  @override
  ConsumerState<_ChapterOutlineEditDialog> createState() =>
      _ChapterOutlineEditDialogState();
}

class _ChapterOutlineEditDialogState
    extends ConsumerState<_ChapterOutlineEditDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _outlineCtrl;
  late final TextEditingController _aiInstrCtrl;
  late List<SceneCard> _cards;
  final _progress = StreamProgressTracker();
  CancelToken? _cancel;
  bool _generating = false;
  ReasoningEffort? _effort;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.chapter.title);
    _outlineCtrl = TextEditingController(
      text: widget.chapter.detailedOutline ?? '',
    );
    _aiInstrCtrl = TextEditingController();
    _cards = SceneCard.decodeList(widget.chapter.sceneCardsJson);
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _progress.dispose();
    _titleCtrl.dispose();
    _outlineCtrl.dispose();
    _aiInstrCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateChapterOutline() async {
    final provider = ref.read(defaultProviderProvider);
    if (provider == null) {
      showZmSnackBar(context, '请先配置模型提供商', isError: true);
      return;
    }
    final bundle = await ref
        .read(novelRepositoryProvider)
        .loadBundle(widget.novelId);
    if (bundle == null) return;
    final chBundle = bundle.allChaptersInOrder
        .where((c) => c.chapter.id == widget.chapter.id)
        .firstOrNull;
    if (chBundle == null) return;

    final budget = PromptTemplates.adjustedInputBudget(
      provider.contextBudgetChars,
      [provider.systemPromptExtra],
    );
    final ctx = ContextBuilder.buildOutlineContext(
      target: ChapterOutlineTarget(chBundle),
      bundle: bundle,
      budgetChars: budget,
    );
    var msgs = PromptTemplates.outline(
      library: ref.read(promptLibraryProvider),
      systemId: PromptID.chapterOutline,
      renderedContext: ctx.rendered,
      instruction: _aiInstrCtrl.text,
    );
    msgs = PromptTemplates.applyingExtra(provider.systemPromptExtra, msgs);
    if (!mounted) return;
    if (!await PromptGuard.authorize(
      context,
      totalChars: msgs.totalContentChars,
    )) {
      return;
    }

    setState(() => _generating = true);
    _cancel = CancelToken();
    _progress.begin();
    try {
      final client = await createClientForProvider(
        provider,
        ref.read(apiKeyVaultProvider),
        defaultReasoningEffort: _effort,
      );
      final buf = StringBuffer();
      await for (final ev in client.streamChat(
        msgs,
        config: GenerationConfig(
          temperature: provider.temperature,
          maxTokens: provider.maxTokens,
        ),
        cancelToken: _cancel,
      )) {
        _progress.handle(ev);
        if (ev is ContentDelta) buf.write(ev.text);
      }
      unawaited(
        ref
            .read(tokenUsageLedgerProvider.notifier)
            .recordUsage(
              usage: _progress.lastCompletedUsage,
              category: UsageCategory.outline,
              provider: provider,
              novelId: widget.novelId,
              effort: _effort,
            ),
      );
      final raw = buf.toString();
      final fenceRe = RegExp(r'```zm-scene\s*([\s\S]*?)```');
      final match = fenceRe.firstMatch(raw);
      var body = raw;
      if (match != null) {
        body = raw.replaceRange(match.start, match.end, '').trim();
        final list = LLMJSONParser.decodeList<SceneCard>(
          match.group(1) ?? '',
          SceneCard.fromJson,
        );
        if (list != null && list.isNotEmpty) {
          _cards = list.where((c) => !c.isEmpty).toList();
        }
      }
      setState(() => _outlineCtrl.text = body.trim());
    } catch (e) {
      if (mounted) showZmSnackBar(context, '生成细纲失败：$e', isError: true);
    } finally {
      _progress.finish();
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    await ref
        .read(novelRepositoryProvider)
        .updateChapterOutline(
          novelId: widget.novelId,
          chapterId: widget.chapter.id,
          title: _titleCtrl.text.trim().isEmpty
              ? widget.chapter.title
              : _titleCtrl.text.trim(),
          detailedOutline: _outlineCtrl.text,
          sceneCards: _cards,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '编辑章细纲与场景卡',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: '章节标题'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _aiInstrCtrl,
                            decoration: const InputDecoration(
                              labelText: 'AI 细纲附加要求（可选）',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _generating
                              ? null
                              : _generateChapterOutline,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('AI 生成'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    EffortSelectorBar(
                      value: _effort,
                      provider: ref.watch(defaultProviderProvider),
                      enabled: !_generating,
                      compact: true,
                      onChanged: (v) => setState(() => _effort = v),
                    ),
                    if (_generating) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StreamingStatusChip(tracker: _progress),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _cancel?.cancel(),
                            child: const Text('停止'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ThinkingProcessCard(
                        tracker: _progress,
                        maxExpandedHeight: 130,
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _outlineCtrl,
                      minLines: 5,
                      maxLines: 9,
                      decoration: const InputDecoration(
                        labelText: '本章细纲',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '场景卡（${_cards.length} 张）',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _cards.add(const SceneCard())),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('新增场景卡'),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _cards.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '场景卡 ${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () =>
                                        setState(() => _cards.removeAt(i)),
                                  ),
                                ],
                              ),
                              TextFormField(
                                initialValue: _cards[i].goal,
                                decoration: const InputDecoration(
                                  labelText: '目标 Goal',
                                  isDense: true,
                                ),
                                onChanged: (v) =>
                                    _cards[i] = _cards[i].copyWith(goal: v),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                initialValue: _cards[i].obstacle,
                                decoration: const InputDecoration(
                                  labelText: '阻力 Obstacle',
                                  isDense: true,
                                ),
                                onChanged: (v) =>
                                    _cards[i] = _cards[i].copyWith(obstacle: v),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                initialValue: _cards[i].hook,
                                decoration: const InputDecoration(
                                  labelText: '钩子 Hook',
                                  isDense: true,
                                ),
                                onChanged: (v) =>
                                    _cards[i] = _cards[i].copyWith(hook: v),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('保存')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForeshadowListPane extends ConsumerStatefulWidget {
  const _ForeshadowListPane({required this.novelId});
  final String novelId;

  @override
  ConsumerState<_ForeshadowListPane> createState() =>
      _ForeshadowListPaneState();
}

class _ForeshadowListPaneState extends ConsumerState<_ForeshadowListPane> {
  String _statusFilter = 'open'; // open | resolved | dropped | all

  Future<void> _editForeshadow([Foreshadowing? existing]) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final detailCtrl = TextEditingController(text: existing?.detail ?? '');
    final plannedCtrl = TextEditingController(
      text: existing?.plannedResolve ?? '',
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var status = existing?.status ?? 'open';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(existing == null ? '登记新伏笔' : '编辑伏笔'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    maxLength: PromptLimits.foreshadowTextFieldCap,
                    decoration: const InputDecoration(labelText: '伏笔标题 *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailCtrl,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '伏笔详情'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: plannedCtrl,
                    decoration: const InputDecoration(
                      labelText: '计划回收位置（如：第三卷末）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: '状态'),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('未回收')),
                      DropdownMenuItem(value: 'resolved', child: Text('已回收')),
                      DropdownMenuItem(value: 'dropped', child: Text('已废弃')),
                    ],
                    onChanged: (v) => setModal(() => status = v ?? 'open'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: '备注'),
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

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      await ref
          .read(appDatabaseProvider)
          .upsertForeshadowing(
            ForeshadowingsCompanion.insert(
              id: existing?.id ?? const Uuid().v4(),
              novelId: widget.novelId,
              title: titleCtrl.text.trim(),
              detail: Value(
                detailCtrl.text.trim().isEmpty ? null : detailCtrl.text.trim(),
              ),
              plantedVolumeIndex: Value(existing?.plantedVolumeIndex),
              plantedChapterOrder: Value(existing?.plantedChapterOrder),
              plannedResolve: Value(
                plannedCtrl.text.trim().isEmpty
                    ? null
                    : plannedCtrl.text.trim(),
              ),
              status: Value(status),
              note: Value(
                noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              ),
              suggestedResolved: Value(
                status == 'open' && (existing?.suggestedResolved ?? false),
              ),
              createdAt: existing?.createdAt ?? DateTime.now(),
            ),
          );
    }

    titleCtrl.dispose();
    detailCtrl.dispose();
    plannedCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editForeshadow(),
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('登记伏笔'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s4,
              vertical: 6,
            ),
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in const [
                  ('open', '未回收'),
                  ('partial', '部分推进'),
                  ('resolved', '已回收'),
                  ('dropped', '已废弃'),
                  ('all', '全部'),
                ])
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: _statusFilter == entry.$1,
                    onSelected: (_) => setState(() => _statusFilter = entry.$1),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Foreshadowing>>(
              stream: db.watchForeshadowings(widget.novelId),
              builder: (context, snap) {
                final all = snap.data ?? const [];
                final list = _statusFilter == 'all'
                    ? all
                    : all.where((f) => f.status == _statusFilter).toList();
                if (list.isEmpty) {
                  return const ZmEmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: '暂无伏笔记录',
                    description: '摘要建档时 AI 会自动提取新伏笔；埋设超过 8 章未回收时续写会自动提醒。',
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
                          const SizedBox(height: AppTokens.s2),
                      itemBuilder: (_, i) {
                        final fs = list[i];
                        return Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fs.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (fs.suggestedResolved && fs.status == 'open')
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () async {
                                      await (db.update(db.foreshadowings)
                                            ..where((t) => t.id.equals(fs.id)))
                                          .write(
                                            const ForeshadowingsCompanion(
                                              status: Value('resolved'),
                                              suggestedResolved: Value(false),
                                            ),
                                          );
                                    },
                                    child: const Text('疑似已回收 · 点此确认'),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((fs.detail ?? '').isNotEmpty)
                                  Text(fs.detail!),
                                Text(
                                  [
                                    if (fs.status == 'partial') '状态：部分推进',
                                    if (fs.status == 'resolved') '状态：已回收',
                                    if (fs.plantedChapterOrder != null)
                                      fs.resolvedChapterOrder != null
                                          ? '第${fs.plantedChapterOrder}章埋 → 第${fs.resolvedChapterOrder}章收'
                                          : '埋设：第${fs.plantedChapterOrder}章',
                                    if (decodeStringList(
                                      fs.involvedCharactersJson,
                                    ).isNotEmpty)
                                      '角色：${decodeStringList(fs.involvedCharactersJson).join('、')}',
                                    if ((fs.payoffDetail ?? '').isNotEmpty)
                                      '回收：${fs.payoffDetail}',
                                    if ((fs.plannedResolve ?? '').isNotEmpty)
                                      '计划回收：${fs.plannedResolve}',
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: cs.error,
                              ),
                              onPressed: () async {
                                final ok = await showZmConfirmDialog(
                                  context,
                                  title: '删除伏笔「${fs.title}」？',
                                  message: '删除后无法恢复。',
                                  confirmLabel: '删除',
                                  destructive: true,
                                );
                                if (ok) await db.deleteForeshadowing(fs.id);
                              },
                            ),
                            onTap: () => _editForeshadow(fs),
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

// 预留供大纲 JSON 解码辅助使用
String encodeOutlineJson(Object data) => jsonEncode(data);

class _TimelinePane extends ConsumerWidget {
  const _TimelinePane({required this.novelId, this.onJumpToChapter});

  final String novelId;
  final ValueChanged<String>? onJumpToChapter;

  Future<void> _editEvent(
    BuildContext context,
    WidgetRef ref, [
    TimelineEvent? existing,
  ]) async {
    final draft = await showDialog<_TimelineDraft>(
      context: context,
      builder: (_) => _EditTimelineEventDialog(existing: existing),
    );
    if (draft == null) return;
    await ref
        .read(appDatabaseProvider)
        .upsertTimelineEvent(
          TimelineEventsCompanion.insert(
            id: existing?.id ?? const Uuid().v4(),
            novelId: novelId,
            volumeId: Value(existing?.volumeId),
            chapterId: Value(existing?.chapterId),
            chapterOrder: Value(draft.chapterOrder),
            chapterRange: Value(draft.chapterRange),
            inWorldTime: Value(draft.inWorldTime),
            phase: Value(draft.phase),
            title: draft.title,
            summary: Value(draft.summary),
            location: Value(draft.location),
            participantsJson: Value(encodeStringList(draft.participants)),
            linkedForeshadowingIdsJson: Value(
              existing?.linkedForeshadowingIdsJson ?? '[]',
            ),
            importance: Value(draft.importance),
            sortOrder: Value(existing?.sortOrder ?? 0),
            createdAt: existing?.createdAt ?? DateTime.now(),
          ),
        );
    await ref.read(novelRepositoryProvider).touchNovel(novelId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return StreamBuilder<List<Foreshadowing>>(
      stream: db.watchForeshadowings(novelId),
      builder: (context, fsSnap) {
        final fsById = {for (final f in (fsSnap.data ?? const [])) f.id: f};
        return StreamBuilder<List<TimelineEvent>>(
          stream: db.watchTimelineEvents(novelId),
          builder: (context, evSnap) {
            final events = evSnap.data ?? const [];
            final evById = {for (final e in events) e.id: e};
            final items = [
              for (final e in events)
                TimelineEventItem(
                  id: e.id,
                  chapterId: e.chapterId,
                  chapterLabel: (e.chapterRange ?? '').isNotEmpty
                      ? e.chapterRange!
                      : (e.chapterOrder != null
                            ? '第${e.chapterOrder}章'
                            : '未定章'),
                  inWorldTime: e.inWorldTime,
                  phase: e.phase,
                  title: e.title,
                  summary: e.summary,
                  location: e.location,
                  participants: decodeStringList(e.participantsJson),
                  linkedClueBadges: [
                    for (final fid in decodeStringList(
                      e.linkedForeshadowingIdsJson,
                    ))
                      if (fsById[fid] != null)
                        '${fsById[fid]!.status == 'resolved' ? '[收]' : '[埋]'} ${fsById[fid]!.title}',
                  ],
                  importance: e.importance,
                ),
            ];
            return StoryTimelineView(
              events: items,
              onAddEvent: () => _editEvent(context, ref),
              onEditEvent: (item) => _editEvent(context, ref, evById[item.id]),
              onDeleteEvent: (item) async {
                final ok = await showZmConfirmDialog(
                  context,
                  title: '删除时间线事件「${item.title}」？',
                  message: '删除后无法恢复。',
                  confirmLabel: '删除',
                  destructive: true,
                );
                if (ok) {
                  await db.deleteTimelineEvent(item.id);
                  await ref.read(novelRepositoryProvider).touchNovel(novelId);
                }
              },
              onJumpToChapter: onJumpToChapter,
            );
          },
        );
      },
    );
  }
}

class _TimelineDraft {
  const _TimelineDraft({
    required this.title,
    required this.summary,
    this.chapterOrder,
    this.chapterRange,
    this.inWorldTime,
    this.phase,
    this.location,
    this.participants = const [],
    this.importance = 'normal',
  });

  final String title;
  final String summary;
  final int? chapterOrder;
  final String? chapterRange;
  final String? inWorldTime;
  final String? phase;
  final String? location;
  final List<String> participants;
  final String importance;
}

class _EditTimelineEventDialog extends StatefulWidget {
  const _EditTimelineEventDialog({this.existing});
  final TimelineEvent? existing;

  @override
  State<_EditTimelineEventDialog> createState() =>
      _EditTimelineEventDialogState();
}

class _EditTimelineEventDialogState extends State<_EditTimelineEventDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _chapterCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _phaseCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _partsCtrl;
  late String _importance;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _summaryCtrl = TextEditingController(text: e?.summary ?? '');
    _chapterCtrl = TextEditingController(
      text: e?.chapterOrder?.toString() ?? '',
    );
    _timeCtrl = TextEditingController(text: e?.inWorldTime ?? '');
    _phaseCtrl = TextEditingController(text: e?.phase ?? '');
    _locCtrl = TextEditingController(text: e?.location ?? '');
    _partsCtrl = TextEditingController(
      text: decodeStringList(e?.participantsJson).join('，'),
    );
    _importance = e?.importance ?? 'normal';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _chapterCtrl.dispose();
    _timeCtrl.dispose();
    _phaseCtrl.dispose();
    _locCtrl.dispose();
    _partsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增时间线事件' : '编辑时间线事件'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '事件标题'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chapterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '章序（数字）'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _timeCtrl,
                      decoration: const InputDecoration(labelText: '书内时间'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phaseCtrl,
                      decoration: const InputDecoration(labelText: '剧情阶段/篇名'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _importance,
                      decoration: const InputDecoration(labelText: '重要度'),
                      items: const [
                        DropdownMenuItem(value: 'major', child: Text('核心里程碑')),
                        DropdownMenuItem(value: 'normal', child: Text('普通事件')),
                        DropdownMenuItem(value: 'minor', child: Text('次要细节')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _importance = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locCtrl,
                decoration: const InputDecoration(labelText: '发生地点（可选）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _partsCtrl,
                decoration: const InputDecoration(labelText: '参与角色（逗号分隔）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _summaryCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '事件摘要与因果结果',
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
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) return;
            final chOrd = int.tryParse(_chapterCtrl.text.trim());
            final parts = _partsCtrl.text
                .split(RegExp(r'[,，、;；]+'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            Navigator.of(context).pop(
              _TimelineDraft(
                title: title,
                summary: _summaryCtrl.text.trim().isEmpty
                    ? title
                    : _summaryCtrl.text.trim(),
                chapterOrder: chOrd,
                chapterRange: chOrd != null ? '第$chOrd章' : null,
                inWorldTime: _timeCtrl.text.trim().isEmpty
                    ? null
                    : _timeCtrl.text.trim(),
                phase: _phaseCtrl.text.trim().isEmpty
                    ? null
                    : _phaseCtrl.text.trim(),
                location: _locCtrl.text.trim().isEmpty
                    ? null
                    : _locCtrl.text.trim(),
                participants: parts,
                importance: _importance,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
