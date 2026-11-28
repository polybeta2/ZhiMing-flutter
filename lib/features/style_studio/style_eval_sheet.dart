import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/llm/stream_progress.dart';
import '../../core/prompts/prompt_library.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/diff_preview_dialog.dart';
import '../../core/widgets/effort_selector_bar.dart';
import '../../core/widgets/streaming_status_chip.dart';
import '../../core/widgets/zm_widgets.dart';
import '../../domain/models/style_models.dart';
import '../../domain/style/style_distillation_service.dart';
import '../../domain/writing/prose_checker.dart';

/// 风格体检结果弹窗（修复原版 B9：本地 ProseChecker 只算一次缓存，不再每秒重跑；支持一键改写 + Diff 对比应用）
class StyleEvalSheet extends ConsumerStatefulWidget {
  const StyleEvalSheet({
    super.key,
    required this.draft,
    required this.chapterTitle,
    required this.evalCard,
    required this.provider,
    this.initialEffort,
    this.onApply,
  });

  final String draft;
  final String chapterTitle;
  final String evalCard;
  final ProviderRecord provider;
  final ReasoningEffort? initialEffort;
  final ValueChanged<String>? onApply;

  @override
  ConsumerState<StyleEvalSheet> createState() => _StyleEvalSheetState();
}

class _StyleEvalSheetState extends ConsumerState<StyleEvalSheet> {
  late final String _localReport;
  final _progress = StreamProgressTracker();
  final _fixProgress = StreamProgressTracker();
  CancelToken? _cancel;
  CancelToken? _fixCancel;

  StyleEvalResult? _result;
  ReasoningEffort? _effort;
  String? _error;
  bool _running = false;
  bool _fixing = false;

  @override
  void initState() {
    super.initState();
    _effort = widget.initialEffort;
    _localReport = ProseChecker.reportLines(widget.draft).join('\n');
    _runEval();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _fixCancel?.cancel();
    _progress.dispose();
    _fixProgress.dispose();
    super.dispose();
  }

  ProviderRecord _resolveProvider({required bool preferFastTool}) {
    final defaultProvider = ref.read(defaultProviderProvider);
    final hasExplicitOverride =
        defaultProvider != null && widget.provider.id != defaultProvider.id;
    if (hasExplicitOverride) return widget.provider;
    if (preferFastTool) {
      return ref.read(fastToolProviderProvider) ??
          defaultProvider ??
          widget.provider;
    }
    return defaultProvider ?? widget.provider;
  }

  Future<void> _runEval() async {
    _cancel?.cancel();
    _cancel = CancelToken();
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    _progress.begin();
    try {
      final evalProvider = _resolveProvider(preferFastTool: true);
      final client = await createClientForProvider(
        evalProvider,
        ref.read(apiKeyVaultProvider),
        defaultReasoningEffort: _effort,
      );
      final evaluator = StyleEvaluator(
        client: client,
        library: ref.read(promptLibraryProvider),
        providerExtra: evalProvider.systemPromptExtra,
      );
      final res = await evaluator.evaluate(
        draft: widget.draft,
        evalCard: widget.evalCard,
        localReport: _localReport,
        onEvent: _progress.handle,
        cancelToken: _cancel,
      );
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _progress.finish();
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _applyOneClickFix() async {
    final res = _result;
    if (res == null || widget.onApply == null) return;
    _fixCancel?.cancel();
    _fixCancel = CancelToken();
    setState(() => _fixing = true);
    _fixProgress.begin();
    try {
      final fixProvider = _resolveProvider(preferFastTool: false);
      final client = await createClientForProvider(
        fixProvider,
        ref.read(apiKeyVaultProvider),
        defaultReasoningEffort: _effort,
      );
      final evaluator = StyleEvaluator(
        client: client,
        library: ref.read(promptLibraryProvider),
        providerExtra: fixProvider.systemPromptExtra,
      );
      final rewritten = await evaluator.applyFixes(
        draft: widget.draft,
        evalResult: res,
        evalCard: widget.evalCard,
        maxTokens: fixProvider.maxTokens,
        onEvent: _fixProgress.handle,
        cancelToken: _fixCancel,
      );
      if (!mounted) return;
      if (rewritten.isEmpty) {
        showZmSnackBar(context, 'AI 未返回改写文本', isError: true);
        return;
      }
      final ok = await showDiffConfirmDialog(
        context,
        title: '确认应用体检改写（《${widget.chapterTitle}》）',
        before: widget.draft,
        after: rewritten,
        confirmLabel: '建快照并写回',
      );
      if (ok && mounted) {
        widget.onApply!(rewritten);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showZmSnackBar(context, '改写失败：$e', isError: true);
    } finally {
      _fixProgress.finish();
      if (mounted) setState(() => _fixing = false);
    }
  }

  Color _scoreColor(int s) =>
      s >= 7 ? Colors.green : (s >= 5 ? Colors.orange : Colors.red);

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
                    '风格体检 · ${widget.chapterTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                EffortCompactChip(
                  value: _effort,
                  provider: _resolveProvider(preferFastTool: true),
                  enabled: !_running && !_fixing,
                  onChanged: (v) => setState(() => _effort = v),
                ),
                TextButton(
                  onPressed: _running || _fixing ? null : _runEval,
                  child: const Text('重新体检'),
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
                          '正在按七维基准逐项体检…',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : _error != null
                ? ZmEmptyState(
                    icon: Icons.error_outline,
                    title: '体检失败',
                    description: _error,
                    action: FilledButton(
                      onPressed: _runEval,
                      child: const Text('重试'),
                    ),
                  )
                : _result == null
                ? const SizedBox.shrink()
                : ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(AppTokens.s4),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s4),
                          child: Row(
                            children: [
                              Text(
                                '${_result!.overall}',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: _scoreColor(_result!.overall),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '/ 10 总评',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const Spacer(),
                              if (widget.onApply != null)
                                FilledButton.icon(
                                  onPressed: _fixing ? null : _applyOneClickFix,
                                  icon: const Icon(
                                    Icons.auto_fix_high_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _fixing ? 'AI 改写中…' : '一键应用修改',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_fixing) ...[
                        const SizedBox(height: 8),
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
                      const SizedBox(height: AppTokens.s3),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '七维得分',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              for (final sc in _result!.scores)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            sc.dimension,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${sc.score} / 10',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: _scoreColor(sc.score),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (sc.note.isNotEmpty)
                                        Text(
                                          sc.note,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_result!.drifts.isNotEmpty)
                        _BulletCard('风格漂移', _result!.drifts),
                      if (_result!.aiFlavor.isNotEmpty)
                        _BulletCard('AI 腔问题', _result!.aiFlavor),
                      if (_result!.moves.isNotEmpty)
                        _BulletCard('建议修改动作', _result!.moves),
                      if (_localReport.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(top: AppTokens.s3),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTokens.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '本地快检（程序统计）',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _localReport,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard(this.title, this.items);
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: AppTokens.s3),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item', style: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
