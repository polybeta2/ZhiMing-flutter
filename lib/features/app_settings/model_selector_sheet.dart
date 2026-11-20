import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/theme/design_tokens.dart';

/// 会话级模型选择弹窗（编辑器与聊天页共用，null 表示跟随全局默认）
Future<ProviderRecord?> showModelSelectorSheet(
  BuildContext context, {
  required WidgetRef ref,
  ProviderRecord? currentSessionProvider,
}) async {
  final providers = ref.read(providersStreamProvider).valueOrNull ?? const [];
  final defaultProvider = ref.read(defaultProviderProvider);

  return showModalBottomSheet<ProviderRecord?>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.s4,
            0,
            AppTokens.s4,
            AppTokens.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '切换本次会话模型',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTokens.s2),
              if (providers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('尚未配置任何模型提供商，请先到「设置」添加。')),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(Icons.star_outline),
                        title: const Text('跟随全局默认'),
                        subtitle: Text(
                          defaultProvider != null
                              ? '${defaultProvider.name} · ${defaultProvider.modelName}'
                              : '未设置',
                        ),
                        trailing: currentSessionProvider == null
                            ? Icon(Icons.check, color: cs.primary)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(null),
                      ),
                      const Divider(height: 1),
                      for (final p in providers)
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: const Icon(Icons.memory_rounded),
                          title: Text(p.name),
                          subtitle: Text(p.modelName),
                          trailing: currentSessionProvider?.id == p.id
                              ? Icon(Icons.check, color: cs.primary)
                              : null,
                          onTap: () => Navigator.of(ctx).pop(p),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
