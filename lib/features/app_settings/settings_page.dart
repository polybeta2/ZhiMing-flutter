import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/provider_client_factory.dart';
import '../../core/platform/background_keep_alive.dart';
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

  Future<void> _openKeepAliveSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var perm = await BackgroundKeepAliveService.instance
        .getLocationPermission();
    var nativeStatus = await BackgroundKeepAliveService.instance.getStatus();
    var selfTesting = false;
    String? selfTestHint;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, dialogRef, _) {
          final current = dialogRef.watch(backgroundKeepAliveProvider);
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              return AlertDialog(
                title: const Text('后台保活（iOS）'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '用于 iOS 设备在锁屏或切换其他应用期间继续完成原作扫描、自动撰写与文风蒸馏（桌面端无需额外保活）。',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RadioGroup<BackgroundKeepAliveMode>(
                        groupValue: current,
                        onChanged: (val) async {
                          if (val == null) return;
                          await dialogRef
                              .read(backgroundKeepAliveProvider.notifier)
                              .setMode(val);
                          if (val == BackgroundKeepAliveMode.lowPowerLocation) {
                            final nextPerm = await BackgroundKeepAliveService
                                .instance
                                .requestLocationPermission();
                            if (ctx.mounted) {
                              setLocalState(() => perm = nextPerm);
                            }
                          }
                          final nextStatus = await BackgroundKeepAliveService
                              .instance
                              .getStatus();
                          if (ctx.mounted) {
                            setLocalState(() {
                              nativeStatus = nextStatus;
                              selfTestHint = null;
                            });
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final m in BackgroundKeepAliveMode.values)
                              RadioListTile<BackgroundKeepAliveMode>(
                                value: m,
                                contentPadding: EdgeInsets.zero,
                                title: Text(m.label),
                                subtitle: Text(
                                  m.description,
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (current == BackgroundKeepAliveMode.lowPowerLocation &&
                          perm != LocationPermissionState.unknown) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: perm.isDenied
                                ? Theme.of(ctx).colorScheme.errorContainer
                                      .withValues(alpha: 0.45)
                                : Theme.of(
                                    ctx,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusInput,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '定位权限：${perm.displayLabel}',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ),
                              if (perm.isDenied)
                                TextButton(
                                  onPressed: () => BackgroundKeepAliveService
                                      .instance
                                      .openAppSettings(),
                                  child: const Text('去设置'),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (current != BackgroundKeepAliveMode.none) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: nativeStatus.active
                                ? Theme.of(ctx).colorScheme.primaryContainer
                                      .withValues(alpha: 0.45)
                                : Theme.of(
                                    ctx,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusInput,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '原生状态：${nativeStatus.summaryLabel}',
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (selfTestHint != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  selfTestHint!,
                                  style: Theme.of(ctx).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                onPressed: selfTesting
                                    ? null
                                    : () async {
                                        setLocalState(() {
                                          selfTesting = true;
                                          selfTestHint = '正在请求原生通道启动 6 秒保活自检…';
                                        });
                                        final finalStatus =
                                            await BackgroundKeepAliveService
                                                .instance
                                                .runSelfTest(
                                                  onStarted: (started) {
                                                    if (!ctx.mounted) return;
                                                    setLocalState(() {
                                                      nativeStatus = started;
                                                      selfTestHint =
                                                          started.blueIndicatorExpected
                                                          ? '已启动 6 秒自检：现在可按 Home 键回到桌面观察蓝色位置指示条，6 秒后自动结束。'
                                                          : '已启动 6 秒自检：可切到后台或观察原生音频/定位状态，6 秒后自动结束。';
                                                    });
                                                  },
                                                );
                                        if (!ctx.mounted) return;
                                        setLocalState(() {
                                          selfTesting = false;
                                          nativeStatus = finalStatus;
                                          selfTestHint =
                                              finalStatus.active
                                              ? '自检完成：原生保活工作正常（已自动停止，仅长任务运行期间开启）。'
                                              : '自检结束（${finalStatus.summaryLabel}）；如在桌面端请用真机或开启对应权限后重试。';
                                        });
                                      },
                                icon: Icon(
                                  selfTesting
                                      ? Icons.hourglass_top_rounded
                                      : Icons.play_circle_outline_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  selfTesting ? '正在自检（6 秒）…' : '试运行 6 秒验证保活',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('完成'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openFastToolModelDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, dialogRef, _) {
          final providers =
              dialogRef.watch(providersStreamProvider).valueOrNull ?? const [];
          final defaultProvider = dialogRef.watch(defaultProviderProvider);
          final rawSelectedId = dialogRef.watch(fastToolProviderIdProvider);
          final selectedId =
              rawSelectedId != null &&
                  providers.any((p) => p.id == rawSelectedId)
              ? rawSelectedId
              : null;
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('选择极速工具模型'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '用于精扫、审稿、活体建档与体检等高频工具任务；未单独指定时跟随默认主力模型。',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      selected: selectedId == null,
                      leading: Icon(
                        selectedId == null
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selectedId == null
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      title: const Text(
                        '跟随默认主力模型',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: defaultProvider != null
                          ? Text(
                              '${defaultProvider.name} · ${defaultProvider.modelName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () async {
                        await dialogRef
                            .read(fastToolProviderIdProvider.notifier)
                            .setProviderId(null);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                    for (final p in providers)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        selected: selectedId == p.id,
                        leading: Icon(
                          selectedId == p.id
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selectedId == p.id
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        title: Text(
                          '${p.name} · ${p.modelName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await dialogRef
                              .read(fastToolProviderIdProvider.notifier)
                              .setProviderId(p.id);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
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
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultProvider = ref.watch(defaultProviderProvider);
    final providers =
        ref.watch(providersStreamProvider).valueOrNull ?? const [];
    final fastToolProviderId = ref.watch(fastToolProviderIdProvider);
    final fastProvider = ref.watch(fastToolProviderProvider);
    final hasCustomFastTool =
        fastToolProviderId != null &&
        providers.any((p) => p.id == fastToolProviderId) &&
        fastProvider != null;
    final appearance = ref.watch(appearanceProvider);
    final keepAliveMode = ref.watch(backgroundKeepAliveProvider);
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
              const SizedBox(height: AppTokens.s2),
              Card(
                child: ListTile(
                  leading: const ZmSettingsIcon(
                    icon: Icons.flash_on_rounded,
                    tint: Colors.amber,
                  ),
                  title: const Text(
                    '极速工具模型（可选）',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    hasCustomFastTool
                        ? '当前：${fastProvider.name} · ${fastProvider.modelName}'
                        : '跟随默认主力模型（用于精扫、审稿、活体建档与体检）',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openFastToolModelDialog(context, ref),
                ),
              ),
              const SizedBox(height: AppTokens.s5),
              _SectionTitle('后台运行与保活'),
              Card(
                child: ListTile(
                  leading: const ZmSettingsIcon(
                    icon: Icons.bolt_rounded,
                    tint: Colors.teal,
                  ),
                  title: const Text('后台保活（iOS）'),
                  subtitle: Text(
                    '当前方案：${keepAliveMode.label}（可选不保活 / 静音音频 / 持续位置获取）',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openKeepAliveSheet(context, ref),
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/icons/app_icon.png',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
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
                                          appearance.accentColor.withValues(
                                            alpha: 0.72,
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.menu_book_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.s3),
                          Expanded(
                            child: Column(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.s3),
                      Text(
                        '版本 3.1.0 (Flutter) · SQLite 本地事务存储 · API Key 仅存系统安全密钥库',
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
