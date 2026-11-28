import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../llm/llm_types.dart';
import '../llm/provider_client_factory.dart';
import '../security/api_key_vault.dart';
import '../theme/design_tokens.dart';

/// 通用「Effort（努力程度）」选择条：
/// - 自动探测当前模型端点是否返回可用努力程度（`/models` / `/models/{id}`）；
/// - 若端点明确返回可用列表，仅展示端点支持的档位；
/// - 若端点未返回，则显示全部 7 档（OFF / Low / Medium / High / Xhigh / Max / Ultra）并提示用户按 API 实际支持选用。
class EffortSelectorBar extends ConsumerStatefulWidget {
  const EffortSelectorBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.provider,
    this.rawBaseUrl,
    this.rawApiKey,
    this.rawModel,
    this.rawProxyUrl,
    this.enabled = true,
    this.allowFollowDefault = true,
    this.followDefaultLabel,
    this.title = 'Effort',
    this.compact = false,
  });

  /// 当前选中的 Effort；为 `null` 时表示跟随全局/提供商默认（当 [allowFollowDefault] 为 true）
  final ReasoningEffort? value;
  final ValueChanged<ReasoningEffort?> onChanged;

  /// 用于端点能力探测的提供商记录（优先于 raw* 字段）
  final ProviderRecord? provider;
  final String? rawBaseUrl;
  final String? rawApiKey;
  final String? rawModel;
  final String? rawProxyUrl;

  final bool enabled;
  final bool allowFollowDefault;
  final String? followDefaultLabel;
  final String title;
  final bool compact;

  @override
  ConsumerState<EffortSelectorBar> createState() => _EffortSelectorBarState();
}

class _EffortSelectorBarState extends ConsumerState<EffortSelectorBar> {
  String? _lastProbedKey;

  String get _effectiveUrl =>
      (widget.provider?.baseUrl ?? widget.rawBaseUrl ?? '').trim();

  String get _effectiveModel =>
      (widget.provider?.modelName ?? widget.rawModel ?? '').trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeProbe());
  }

  @override
  void didUpdateWidget(covariant EffortSelectorBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = EffortDiscoveryState.cacheKey(
      _effectiveUrl,
      _effectiveModel,
    );
    if (nextKey != _lastProbedKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeProbe());
    }
  }

  void _maybeProbe({bool force = false}) {
    if (!mounted) return;
    final url = _effectiveUrl;
    final model = _effectiveModel;
    if (url.isEmpty || model.isEmpty) return;
    final key = EffortDiscoveryState.cacheKey(url, model);
    if (!force && _lastProbedKey == key) return;
    _lastProbedKey = key;

    final notifier = ref.read(effortDiscoveryProvider.notifier);
    if (widget.provider != null) {
      unawaited(
        notifier.probeProvider(
          widget.provider!,
          ref.read(apiKeyVaultProvider),
          force: force,
        ),
      );
    } else if ((widget.rawApiKey ?? '').trim().isNotEmpty) {
      unawaited(
        notifier.probeRaw(
          baseUrl: url,
          apiKey: widget.rawApiKey!.trim(),
          model: model,
          proxyUrl: widget.rawProxyUrl,
          force: force,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final discovery = ref.watch(effortDiscoveryProvider);
    final globalPref = ref.watch(reasoningPreferenceProvider);
    final providerOverrides = ref.watch(providerEffortOverridesProvider);

    final url = _effectiveUrl;
    final model = _effectiveModel;
    final caps = (url.isNotEmpty && model.isNotEmpty)
        ? discovery.lookup(url, model)
        : null;
    final isProbing =
        url.isNotEmpty && model.isNotEmpty && discovery.isProbing(url, model);
    final effectiveCaps = caps ?? const EffortCapabilities.fallbackAll();
    final tiers = effectiveCaps.displayEfforts;

    final defaultText =
        widget.followDefaultLabel ??
        '默认 (${effectiveDefaultEffortLabel(globalPref: globalPref, providerOverride: widget.provider != null ? providerOverrides[widget.provider!.id] : null)})';

    final statusNote = isProbing
        ? '正在向端点探测可用 Effort 档位…'
        : effectiveCaps.fromEndpoint
        ? '端点声明支持：${tiers.map((e) => e.label).join(' · ')}'
        : '端点未返回可用 Effort 列表，已显示全部档位，请按该 API 实际支持选用';

    final canReprobe =
        widget.enabled &&
        url.isNotEmpty &&
        model.isNotEmpty &&
        (widget.provider != null || (widget.rawApiKey ?? '').trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.psychology_outlined,
              size: widget.compact ? 15 : 17,
              color: cs.primary,
            ),
            const SizedBox(width: 6),
            Text(
              widget.title,
              style:
                  (widget.compact
                          ? Theme.of(context).textTheme.labelMedium
                          : Theme.of(context).textTheme.labelLarge)
                      ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            if (effectiveCaps.fromEndpoint)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '端点已识别',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            const Spacer(),
            if (isProbing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (canReprobe)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _maybeProbe(force: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '探测档位',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (widget.allowFollowDefault)
              ChoiceChip(
                label: Text(
                  defaultText,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: widget.value == null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: widget.enabled
                    ? (_) => widget.onChanged(null)
                    : null,
              ),
            for (final tier in tiers)
              ChoiceChip(
                label: Text(
                  tier.label,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: widget.value == tier,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: widget.enabled
                    ? (_) => widget.onChanged(tier)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          statusNote,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// 顶栏紧凑型 Effort 胶囊按钮：用于编辑器顶栏、助手顶栏、审稿/体检面板顶栏等空间紧凑区域，
/// 点击后弹出完整 `EffortSelectorBar` 底部选择面板。
class EffortCompactChip extends ConsumerWidget {
  const EffortCompactChip({
    super.key,
    required this.value,
    required this.onChanged,
    this.provider,
    this.enabled = true,
  });

  final ReasoningEffort? value;
  final ValueChanged<ReasoningEffort?> onChanged;
  final ProviderRecord? provider;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final globalPref = ref.watch(reasoningPreferenceProvider);
    final providerOverrides = ref.watch(providerEffortOverridesProvider);

    final activeText = value != null
        ? value!.label
        : effectiveDefaultEffortLabel(
            globalPref: globalPref,
            providerOverride: provider != null
                ? providerOverrides[provider!.id]
                : null,
          );
    final isOverridden = value != null;

    return ActionChip(
      avatar: Icon(
        Icons.psychology_outlined,
        size: 15,
        color: isOverridden ? cs.primary : null,
      ),
      label: Text(
        'Effort: $activeText',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isOverridden ? FontWeight.w600 : null,
          color: isOverridden ? cs.primary : null,
        ),
      ),
      visualDensity: VisualDensity.compact,
      onPressed: enabled
          ? () => showEffortSelectorSheet(
              context,
              value: value,
              provider: provider,
              onChanged: onChanged,
            )
          : null,
    );
  }
}

/// 弹出底部 Effort 选择条面板（供紧凑工具栏胶囊复用）
Future<void> showEffortSelectorSheet(
  BuildContext context, {
  required ReasoningEffort? value,
  required ValueChanged<ReasoningEffort?> onChanged,
  ProviderRecord? provider,
}) async {
  var current = value;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.s4,
            AppTokens.s2,
            AppTokens.s4,
            AppTokens.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '调节模型努力程度（Effort）',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
              if (provider != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '当前模型：${provider.name} · ${provider.modelName}',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              EffortSelectorBar(
                value: current,
                provider: provider,
                onChanged: (next) {
                  setModal(() => current = next);
                  onChanged(next);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
