import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../llm/llm_types.dart';
import '../llm/stream_progress.dart';
import '../llm/token_usage_ledger.dart';
import '../theme/design_tokens.dart';

/// 实时思考链（Thinking）可折叠抽屉：
/// - 传入 [tracker] 时自动监听流式 `ReasoningDelta`，思考中可实时查看末尾预览或展开阅读全文；
/// - 也可传入静态 [staticText] / [staticElapsedSeconds] 用于已完成消息气泡的思考回看；
/// - 若本次调用未产生任何思考内容（如 Effort = OFF），自动隐藏不占空间。
class ThinkingProcessCard extends StatefulWidget {
  const ThinkingProcessCard({
    super.key,
    this.tracker,
    this.staticText,
    this.staticElapsedSeconds = 0,
    this.staticUsage,
    this.initiallyExpanded = false,
    this.maxExpandedHeight = 168,
    this.showUsageBadge = true,
  });

  final StreamProgressTracker? tracker;
  final String? staticText;
  final double staticElapsedSeconds;
  final UsageReport? staticUsage;
  final bool initiallyExpanded;
  final double maxExpandedHeight;
  final bool showUsageBadge;

  @override
  State<ThinkingProcessCard> createState() => _ThinkingProcessCardState();
}

class _ThinkingProcessCardState extends State<ThinkingProcessCard> {
  late bool _expanded;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottomIfNeeded() {
    if (!_expanded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  static String _tailPreview(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    final last = lines.last;
    return last.length > 80 ? '…${last.substring(last.length - 80)}' : last;
  }

  @override
  Widget build(BuildContext context) {
    final tracker = widget.tracker;
    if (tracker != null) {
      return ValueListenableBuilder<StreamProgressState>(
        valueListenable: tracker,
        builder: (context, state, _) {
          final isThinkingNow = state.stage == StreamStage.thinking;
          if (!state.hasReasoning && !isThinkingNow) {
            return const SizedBox.shrink();
          }
          if (isThinkingNow) _scrollToBottomIfNeeded();
          return _buildCard(
            context,
            isLiveThinking: isThinkingNow,
            reasoningChars: state.reasoningChars,
            reasoningText: state.reasoningText,
            elapsedSeconds: isThinkingNow
                ? state.elapsedSeconds
                : state.thinkingElapsedSeconds,
            usage: state.lastUsage,
          );
        },
      );
    }

    final text = widget.staticText?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return _buildCard(
      context,
      isLiveThinking: false,
      reasoningChars: text.length,
      reasoningText: text,
      elapsedSeconds: widget.staticElapsedSeconds,
      usage: widget.staticUsage,
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required bool isLiveThinking,
    required int reasoningChars,
    required String reasoningText,
    required double elapsedSeconds,
    required UsageReport? usage,
  }) {
    final cs = Theme.of(context).colorScheme;
    final secLabel = elapsedSeconds > 0
        ? ' · ${elapsedSeconds.toStringAsFixed(1)}s'
        : '';
    final title = isLiveThinking
        ? '深度思考中 · $reasoningChars 字$secLabel'
        : '思考过程 · $reasoningChars 字$secLabel';
    final tail = !(_expanded) && isLiveThinking
        ? _tailPreview(reasoningText)
        : '';

    String? usageTag;
    if (widget.showUsageBadge && usage != null && usage.promptTokens > 0) {
      final cachePct = (usage.cacheHitRate * 100).round();
      final totalStr = TokenUsageSummary.formatTokenCount(
        usage.promptTokens + usage.completionTokens,
      );
      usageTag = usage.cachedTokens > 0
          ? '$totalStr tok · 缓存 $cachePct%'
          : '$totalStr tok';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppTokens.radiusInput),
        border: Border.all(
          color: isLiveThinking
              ? cs.primary.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusInput),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  if (isLiveThinking)
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.psychology_outlined,
                      size: 15,
                      color: cs.primary,
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isLiveThinking ? cs.primary : cs.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (usageTag != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        usageTag,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onPrimaryContainer,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                  if (_expanded && reasoningText.isNotEmpty)
                    IconButton(
                      tooltip: '复制思考过程',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: reasoningText),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('思考过程已复制'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (tail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
              child: Text(
                tail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxExpandedHeight),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: SelectableText(
                  reasoningText.isEmpty ? '正在等待思考内容…' : reasoningText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
