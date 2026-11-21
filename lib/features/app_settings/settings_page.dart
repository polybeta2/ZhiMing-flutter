import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/provider_client_factory.dart';
import '../../core/prompts/prompt_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/zm_widgets.dart';

/// 设置页：Kelivo 分组卡片（模型与服务 / 外观与编辑器 / 开发者工坊 / 关于）
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _openDeveloperTools(BuildContext context) async {
    final ok = await showZmConfirmDialog(
      context,
      title: '进入开发者工坊？',
      message:
          '此处可修改全部 ${PromptDefaults.builtInPrompts.length} 套内置系统提示词与示例标签库，保存后立即全局生效。\n'
          '若非熟悉提示词工程，误改可能导致蓝图 JSON 解析失败或成文质量下降（随时可一键恢复出厂默认）。',
      confirmLabel: '确认进入',
    );
    if (ok && context.mounted) {
      context.push('/settings/developer');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultProvider = ref.watch(defaultProviderProvider);
    final appearance = ref.watch(appearanceProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.s4),
            children: [
              _SectionTitle('模型与服务'),
              Card(
                child: ListTile(
                  leading: const ZmSettingsIcon(
                    icon: Icons.dns_rounded,
                    tint: Color(0xFF4D5C91),
                  ),
                  title: const Text('模型提供商'),
                  subtitle: defaultProvider != null
                      ? Text(
                          '当前默认：${defaultProvider.name} · ${defaultProvider.modelName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          '尚未配置，AI 写作与立项功能暂不可用',
                          style: TextStyle(color: cs.error),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/providers'),
                ),
              ),
              const SizedBox(height: AppTokens.s5),
              _SectionTitle('外观与阅读排版'),
              Card(
                child: ListTile(
                  leading: const ZmSettingsIcon(
                    icon: Icons.palette_rounded,
                    tint: Colors.purple,
                  ),
                  title: const Text('强调色、深浅模式与编辑器排版'),
                  subtitle: Text(
                    '${appearance.themeModeLabel} · 编辑器 ${appearance.editorPaperTheme.label} · ${appearance.editorFontSize.round()}pt',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: appearance.accentColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push('/settings/appearance'),
                ),
              ),
              const SizedBox(height: AppTokens.s5),
              _SectionTitle('高级'),
              Card(
                child: ListTile(
                  leading: const ZmSettingsIcon(
                    icon: Icons.build_rounded,
                    tint: Colors.deepOrange,
                  ),
                  title: const Text('开发者工坊'),
                  subtitle: const Text('内置系统提示词覆写与示例标签库管理'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDeveloperTools(context),
                ),
              ),
              const SizedBox(height: AppTokens.s5),
              _SectionTitle('关于'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  appearance.accentColor,
                                  appearance.accentColor.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: AppTokens.s3),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '织命 ZhiMing',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '本地优先的跨平台 AI 长篇小说创作工作台',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.s3),
                      Text(
                        '版本 3.0.0 (Flutter) · SQLite 本地事务存储 · API Key 仅存系统安全密钥库',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '功能理念参考开源项目「司命 siming-ai」，界面气质延续 Kelivo。',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
