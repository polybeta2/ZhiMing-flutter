import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/zm_widgets.dart';

class ProviderListPage extends ConsumerWidget {
  const ProviderListPage({super.key});

  Future<void> _deleteProvider(
    BuildContext context,
    WidgetRef ref,
    ProviderRecord provider,
  ) async {
    final ok = await showZmConfirmDialog(
      context,
      title: '删除提供商「${provider.name}」？',
      message: '将同时从系统安全存储中删除其 API Key，无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(appDatabaseProvider)
        .deleteProviderWithKey(provider.id, ref.read(apiKeyVaultProvider));
    if (context.mounted) {
      showZmSnackBar(context, '已删除 ${provider.name}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProviders = ref.watch(providersStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('模型提供商'),
        actions: [
          FilledButton.icon(
            onPressed: () => context.push('/settings/providers/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增'),
          ),
          const SizedBox(width: AppTokens.s3),
        ],
      ),
      body: asyncProviders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ZmEmptyState(
          icon: Icons.error_outline,
          title: '加载失败',
          description: '$e',
        ),
        data: (list) {
          if (list.isEmpty) {
            return ZmEmptyState(
              icon: Icons.dns_outlined,
              title: '还没有模型提供商',
              description: '添加任意 OpenAI 兼容接口（DeepSeek / OpenAI / 通义千问 / 自定义中转）即可开启 AI 创作。',
              action: FilledButton.icon(
                onPressed: () => context.push('/settings/providers/new'),
                icon: const Icon(Icons.add),
                label: const Text('添加模型提供商'),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppTokens.s4),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppTokens.s3),
                itemBuilder: (context, index) {
                  final p = list[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s4,
                        vertical: AppTokens.s2,
                      ),
                      leading: ZmSettingsIcon(
                        icon: p.isDefault ? Icons.star_rounded : Icons.dns_outlined,
                        tint: p.isDefault ? cs.primary : Colors.blueGrey,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (p.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '默认',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '${p.modelName} · 预算 ${p.contextBudgetChars} 字 / 输出 ${p.maxTokens}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.baseUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'default') {
                            await ref
                                .read(appDatabaseProvider)
                                .makeDefaultProvider(p.id);
                          } else if (action == 'edit') {
                            if (context.mounted) {
                              context.push('/settings/providers/${p.id}');
                            }
                          } else if (action == 'delete') {
                            if (context.mounted) {
                              await _deleteProvider(context, ref, p);
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          if (!p.isDefault)
                            const PopupMenuItem(
                              value: 'default',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.star_outline),
                                title: Text('设为默认'),
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('编辑'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.delete_outline, color: cs.error),
                              title: Text(
                                '删除',
                                style: TextStyle(color: cs.error),
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => context.push('/settings/providers/${p.id}'),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
