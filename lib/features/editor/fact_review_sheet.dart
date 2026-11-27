import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/diff_preview_dialog.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/writing/fact_review_service.dart';

/// 5 维客观事实与连续性审稿结果面板：
/// - 展示 5 维核查状态胶囊（设定/时间空间/衔接物品/人设信息壁垒/因果逻辑）
/// - 展示带原文引用与档案依据的冲突证据卡片，支持逐条勾选
/// - 一键定点修订 → Diff 对比确认 → 自动建快照后写回正文
class FactReviewSheet extends ConsumerStatefulWidget {
  const FactReviewSheet({
    super.key,
    required this.draft,
    required this.chapterTitle,
    required this.truthArchive,
    required this.provider,
    this.onApply,
  });

  final String draft;
  final String chapterTitle;
  final String truthArchive;
  final ProviderRecord provider;
  final Future<void> Function(String fixedText)? onApply;

  @override
  ConsumerState<FactReviewSheet> createState() => _FactReviewSheetState();
}

class _FactReviewSheetState extends ConsumerState<FactReviewSheet> {
  final _progress = StreamProgressTracker();
  final _fixProgress = StreamProgressTracker();
  CancelToken? _cancel;
  CancelToken? _fixCancel;

  FactReviewResult? _result;
  final Set<int> _selectedIssueIndices = {};
  String? _error;
  bool _running = false;
  bool _fixing = false;

  @override
  void initState() {
    super.initState();
    _runReview();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _fixCancel?.cancel();
    _progress.dispose();
    _fixProgress.dispose();
    super.dispose();
  }

  Future<void> _runReview() async {
    _cancel?.cancel();
    _cancel = CancelToken();
    setState(() {
      _running = true;
      _error = null;
      _result = null;
      _selectedIssueIndices.clear();
    });
    _progress.begin();
    try {
      final client = await createClientForProvider(
        widget.provider,
        ref.read(apiKeyVaultProvider),
      );
      final service = FactReviewService(
        client: client,
        library: ref.read(promptLibraryProvider),
        providerExtra: widget.provider.systemPromptExtra,
      );
      final res = await service.review(
        truthArchive: widget.truthArchive,
        chapterTitle: widget.chapterTitle,
        draftContent: widget.draft,
        maxTokens: widget.provider.maxTokens,
        onEvent: _progress.handle,
        cancelToken: _cancel,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _selectedIssueIndices
            ..clear()
            ..addAll(List.generate(res.issues.length, (i) => i));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _progress.finish();
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _applySelectedFixes() async {
    final res = _result;
    if (res == null || widget.onApply == null) return;
    final picked = [
      for (var i = 0; i < res.issues.length; i++)
        if (_selectedIssueIndices.contains(i)) res.issues[i],
    ];
    if (picked.isEmpty) {
      showZmSnackBar(context, '请至少勾选一条待修复的问题', isError: true);
      return;
    }

    _fixCancel?.cancel();
    _fixCancel = CancelToken();
    setState(() => _fixing = true);
    _fixProgress.begin();
    try {
      final client = await createClientForProvider(
        widget.provider,
        ref.read(apiKeyVaultProvider),
      );
      final service = FactReviewService(
        client: client,
        library: ref.read(promptLibraryProvider),
        providerExtra: widget.provider.systemPromptExtra,
      );
      final fixed = await service.applyFixes(
        truthArchive: widget.truthArchive,
        chapterTitle: widget.chapterTitle,
        draftContent: widget.draft,
        issues: picked,
        priorReviewReply: res.rawJsonReply,
        maxTokens: widget.provider.maxTokens,
        onEvent: _fixProgress.handle,
        cancelToken: _fixCancel,
      );
      if (!mounted) return;
      if (fixed.isEmpty) {
        showZmSnackBar(context, 'AI 未返回修订正文', isError: true);
        return;
      }
      final ok = await showDiffConfirmDialog(
        context,
        title: '确认应用事实勘误（《${widget.chapterTitle}》）',
        before: widget.draft,
        after: fixed,
        confirmLabel: '建快照并写回',
      );
      if (ok && mounted) {
        await widget.onApply!(fixed);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showZmSnackBar(context, '定点修复失败：$e', isError: true);
    } finally {
      _fixProgress.finish();
      if (mounted) setState(() => _fixing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '5 维事实审稿 · ${widget.chapterTitle}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _running || _fixing ? null : _runReview,
                  child: const Text('重新审稿'),
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
            child: _running
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamingStatusChip(tracker: _progress),
                        const SizedBox(height: 10),
                        Text(
                          '正在对照真相档案核查 5 维事实与连续性…',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : _error != null
                ? ZmEmptyState(
                    icon: Icons.error_outline,
                    title: '审稿失败',
                    description: _error,
                    action: FilledButton(
                      onPressed: _runReview,
                      child: const Text('重试'),
                    ),
                  )
                : _result == null
                ? const SizedBox.shrink()
                : _buildResultBody(cs, scrollCtrl, _result!),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBody(
    ColorScheme cs,
    ScrollController scrollCtrl,
    FactReviewResult res,
  ) {
    final statusColor = res.overallPass
        ? Colors.green
        : (res.hasBlocking ? cs.error : Colors.orange);
    final statusIcon = res.overallPass
        ? Icons.verified_outlined
        : (res.hasBlocking
              ? Icons.gpp_bad_outlined
              : Icons.warning_amber_rounded);
    final statusTitle = res.overallPass
        ? '事实核查通过'
        : (res.hasBlocking
              ? '发现 ${res.blockingIssues.length} 处阻断性矛盾'
              : '发现 ${res.warningIssues.length} 处轻微疑点');

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(AppTokens.s4),
      children: [
        // 1) 总览卡
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            res.summary,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (res.issues.isNotEmpty && widget.onApply != null)
                      FilledButton.icon(
                        onPressed: _fixing || _selectedIssueIndices.isEmpty
                            ? null
                            : _applySelectedFixes,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                        label: Text(
                          _fixing
                              ? '定点修订中…'
                              : '一键修复 (${_selectedIssueIndices.length})',
                        ),
                      ),
                  ],
                ),
                if (_fixing) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      StreamingStatusChip(tracker: _fixProgress),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _fixCancel?.cancel(),
                        child: const Text('停止'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.s3),

        // 2) 5 维状态胶囊卡
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '五维客观核查明细',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final dim in res.dimensionResults)
                      Chip(
                        avatar: Icon(
                          dim.pass
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 16,
                          color: dim.pass ? Colors.green : cs.error,
                        ),
                        label: Text(
                          dim.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final dim in res.dimensionResults)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${dim.label}：',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: dim.pass ? Colors.green : cs.error,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            dim.note,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3) 冲突证据清单
        if (res.issues.isEmpty)
          Card(
            margin: const EdgeInsets.only(top: AppTokens.s3),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.s4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '未检出设定、时间线、衔接、信息壁垒或逻辑硬伤，可直接建档或继续下一章。',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          const SizedBox(height: AppTokens.s3),
          for (var i = 0; i < res.issues.length; i++)
            _buildIssueCard(cs, i, res.issues[i]),
        ],
      ],
    );
  }

  Widget _buildIssueCard(ColorScheme cs, int index, FactReviewIssue issue) {
    final checked = _selectedIssueIndices.contains(index);
    final badgeColor = issue.isBlocking ? cs.error : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.s2),
      child: CheckboxListTile(
        value: checked,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: _fixing
            ? null
            : (v) {
                setState(() {
                  if (v == true) {
                    _selectedIssueIndices.add(index);
                  } else {
                    _selectedIssueIndices.remove(index);
                  }
                });
              },
        title: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                issue.isBlocking ? '阻断' : '警告',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                issue.categoryLabel,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
            Text(
              issue.location,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.description, style: const TextStyle(fontSize: 13)),
              if (issue.evidence.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '证据：${issue.evidence}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              if (issue.fixHint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '建议修复：${issue.fixHint}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.primary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
