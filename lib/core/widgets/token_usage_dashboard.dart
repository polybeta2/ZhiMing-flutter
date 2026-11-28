import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../llm/token_usage_ledger.dart';
import '../theme/design_tokens.dart';
import 'zm_widgets.dart';

/// Token 消耗与 KV 缓存账单仪表盘卡片（可嵌入「作品统计与导出」按书展示，也可在「设置」全站展示）
class TokenUsageDashboardCard extends ConsumerStatefulWidget {
  const TokenUsageDashboardCard({
    super.key,
    this.novelId,
    this.title,
  });

  /// 传入具体作品 ID 时仅统计该书；传 null 时统计全站（含原作扫描与文风蒸馏）
  final String? novelId;
  final String? title;

  @override
  ConsumerState<TokenUsageDashboardCard> createState() =>
      _TokenUsageDashboardCardState();
}

class _TokenUsageDashboardCardState
    extends ConsumerState<TokenUsageDashboardCard> {
  bool _showRecent = false;

  String _formatTime(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(tokenUsageLedgerProvider);
    final summary = ledger.summarize(novelId: widget.novelId);
    final pricing = ledger.pricing;
    final cs = Theme.of(context).colorScheme;
    final heading =
        widget.title ??
        (widget.novelId == null ? '全站 Token 与 KV 缓存账单' : '本书 Token 与 KV 缓存账单');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showTokenPricingDialog(context, ref),
                  icon: const Icon(Icons.tune_rounded, size: 15),
                  label: const Text('单价', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                if (summary.requests > 0)
                  IconButton(
                    tooltip: widget.novelId == null ? '清空全部账单' : '清空本书账单',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final ok = await showZmConfirmDialog(
                        context,
                        title: widget.novelId == null
                            ? '清空全部 Token 账单？'
                            : '清空本书 Token 账单？',
                        message: '仅清除本地统计记录，不影响作品内容与 API 设置。',
                        confirmLabel: '清空',
                        destructive: true,
                      );
                      if (!ok) return;
                      final notifier = ref.read(
                        tokenUsageLedgerProvider.notifier,
                      );
                      if (widget.novelId == null) {
                        await notifier.clearAll();
                      } else {
                        await notifier.clearForNovel(widget.novelId!);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (summary.requests == 0)
              Text(
                '暂无用量记录。使用 AI 撰写、审稿、建档、大纲、助手或原作扫描后将自动累计 Token、KV 缓存命中率与预估费用。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniKpi(
                    label: '累计消耗',
                    value: TokenUsageSummary.formatTokenCount(
                      summary.totalTokens,
                    ),
                    sub:
                        '${summary.requests} 次 · 入 ${TokenUsageSummary.formatTokenCount(summary.promptTokens)} / 出 ${TokenUsageSummary.formatTokenCount(summary.completionTokens)}',
                    color: cs.primary,
                  ),
                  _MiniKpi(
                    label: 'KV 缓存命中',
                    value: '${(summary.cacheHitRate * 100).toStringAsFixed(1)}%',
                    sub:
                        '命中 ${TokenUsageSummary.formatTokenCount(summary.cachedTokens)} tok',
                    color: Colors.teal,
                  ),
                  _MiniKpi(
                    label: '预估花费',
                    value: pricing.formatMoney(summary.estimatedCost),
                    sub: summary.estimatedSavings > 0
                        ? '缓存已省 ${pricing.formatMoney(summary.estimatedSavings)}'
                        : '按当前自定义单价估算',
                    color: Colors.orange.shade800,
                  ),
                  if (summary.reasoningTokens > 0)
                    _MiniKpi(
                      label: '思考 Token',
                      value: TokenUsageSummary.formatTokenCount(
                        summary.reasoningTokens,
                      ),
                      sub:
                          '占输出 ${(summary.reasoningShare * 100).round()}%',
                      color: Colors.indigo,
                    ),
                ],
              ),
              if (summary.byCategory.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '按功能分布',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final bucket in summary.byCategory)
                  _BucketRow(
                    bucket: bucket,
                    maxTokens: summary.byCategory.first.totalTokens.clamp(
                      1,
                      1 << 30,
                    ),
                    pricing: pricing,
                  ),
              ],
              if (summary.byChapter.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '章节消耗 Top ${summary.byChapter.length > 6 ? 6 : summary.byChapter.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final bucket in summary.byChapter.take(6))
                  _BucketRow(
                    bucket: bucket,
                    maxTokens: summary.byChapter.first.totalTokens.clamp(
                      1,
                      1 << 30,
                    ),
                    pricing: pricing,
                  ),
              ],
              if (summary.byModel.length > 1) ...[
                const SizedBox(height: 10),
                Text(
                  '按模型分布',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final bucket in summary.byModel.take(5))
                  _BucketRow(
                    bucket: bucket,
                    maxTokens: summary.byModel.first.totalTokens.clamp(
                      1,
                      1 << 30,
                    ),
                    pricing: pricing,
                  ),
              ],
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _showRecent = !_showRecent),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '最近调用明细（${summary.recentRecords.length} 条）',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: cs.primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showRecent
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showRecent)
                for (final r in summary.recentRecords.take(12))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.category.label}'
                                  '${r.chapterTitle != null && r.chapterTitle!.isNotEmpty ? " · ${r.chapterTitle}" : ""}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_formatTime(r.timestamp)} · ${r.modelName}'
                                  '${r.effort != null ? " · Effort:${r.effort}" : ""}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${TokenUsageSummary.formatTokenCount(r.promptTokens)} / ${TokenUsageSummary.formatTokenCount(r.completionTokens)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                '${r.cachedTokens > 0 ? "缓存 ${(r.cacheHitRate * 100).round()}% · " : ""}'
                                '${pricing.formatMoney(pricing.estimateActualCost(promptTokens: r.promptTokens, cachedTokens: r.cachedTokens, completionTokens: r.completionTokens))}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: r.cachedTokens > 0
                                      ? Colors.teal
                                      : cs.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppTokens.radiusInput),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.bucket,
    required this.maxTokens,
    required this.pricing,
  });

  final UsageBucketSummary bucket;
  final int maxTokens;
  final TokenPricingConfig pricing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${bucket.label}（${bucket.requests} 次）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '${TokenUsageSummary.formatTokenCount(bucket.totalTokens)}'
                '${bucket.cachedTokens > 0 ? " · 缓存 ${(bucket.cacheHitRate * 100).round()}%" : ""}'
                ' · ${pricing.formatMoney(bucket.estimatedCost)}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: (bucket.totalTokens / maxTokens).clamp(0.0, 1.0),
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

/// 弹出全站或单书 Token 账单底部面板（供「设置」页调用）
Future<void> showTokenUsageSheet(BuildContext context, {String? novelId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(AppTokens.s4),
        children: [
          TokenUsageDashboardCard(novelId: novelId),
        ],
      ),
    ),
  );
}

/// 自定义每百万 Token 单价弹窗（用于准确估算花费与 KV 缓存节省额）
Future<void> showTokenPricingDialog(BuildContext context, WidgetRef ref) async {
  final current = ref.read(tokenUsageLedgerProvider).pricing;
  var currency = current.currencySymbol;
  final inCtrl = TextEditingController(text: '${current.inputPerMillion}');
  final cacheCtrl = TextEditingController(
    text: '${current.cachedInputPerMillion}',
  );
  final outCtrl = TextEditingController(text: '${current.outputPerMillion}');

  final saved = await showDialog<TokenPricingConfig>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) => AlertDialog(
        title: const Text('Token 费率设置（每百万 Token）'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '快速套用参考费率：',
                  style: Theme.of(ctx).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in TokenPricingConfig.presets)
                      ActionChip(
                        label: Text(
                          p.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setModal(() {
                            currency = p.config.currencySymbol;
                            inCtrl.text = '${p.config.inputPerMillion}';
                            cacheCtrl.text =
                                '${p.config.cachedInputPerMillion}';
                            outCtrl.text = '${p.config.outputPerMillion}';
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '¥', label: Text('人民币 (¥)')),
                    ButtonSegment(value: r'$', label: Text(r'美元 ($)')),
                  ],
                  selected: {currency == r'$' ? r'$' : '¥'},
                  onSelectionChanged: (s) => setModal(() => currency = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: inCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '未命中缓存输入单价 ($currency / 1M tokens)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cacheCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'KV 缓存命中输入单价 ($currency / 1M tokens)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: outCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '输出单价 ($currency / 1M tokens)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final inP = double.tryParse(inCtrl.text.trim()) ?? 0;
              final cacheP = double.tryParse(cacheCtrl.text.trim()) ?? 0;
              final outP = double.tryParse(outCtrl.text.trim()) ?? 0;
              Navigator.of(ctx).pop(
                TokenPricingConfig(
                  currencySymbol: currency,
                  inputPerMillion: inP < 0 ? 0 : inP,
                  cachedInputPerMillion: cacheP < 0 ? 0 : cacheP,
                  outputPerMillion: outP < 0 ? 0 : outP,
                ),
              );
            },
            child: const Text('保存费率'),
          ),
        ],
      ),
    ),
  );
  inCtrl.dispose();
  cacheCtrl.dispose();
  outCtrl.dispose();
  if (saved != null) {
    await ref.read(tokenUsageLedgerProvider.notifier).setPricing(saved);
  }
}
