import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final previewBg =
        state.editorPaperTheme.background ?? cs.surfaceContainerLowest;
    final previewFg = state.editorPaperTheme.foreground ?? cs.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('外观与编辑器排版')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.s4),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '主题模式',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s3),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('跟随系统'),
                              icon: Icon(Icons.brightness_auto_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('浅色'),
                              icon: Icon(Icons.light_mode_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('深色'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                          ],
                          selected: {state.themeMode},
                          onSelectionChanged: (s) =>
                              notifier.setThemeMode(s.first),
                        ),
                      ),
                      const SizedBox(height: AppTokens.s5),
                      Text(
                        '强调色',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s3),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < AppTokens.accentPresets.length; i++)
                            _AccentDot(
                              preset: AppTokens.accentPresets[i],
                              selected: state.accentIndex == i,
                              onTap: () => notifier.setAccentIndex(i),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s4),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '章节编辑器纸感与排版',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final paper in EditorPaperTheme.values)
                            ChoiceChip(
                              label: Text(paper.label),
                              selected: state.editorPaperTheme == paper,
                              onSelected: (_) =>
                                  notifier.setEditorPaperTheme(paper),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.s4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('正文字号'),
                          Text('${state.editorFontSize.round()} pt'),
                        ],
                      ),
                      Slider(
                        value: state.editorFontSize,
                        min: 13,
                        max: 24,
                        divisions: 11,
                        onChanged: notifier.setEditorFontSize,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('行距倍数'),
                          Text(state.editorLineHeight.toStringAsFixed(2)),
                        ],
                      ),
                      Slider(
                        value: state.editorLineHeight,
                        min: 1.3,
                        max: 2.3,
                        divisions: 10,
                        onChanged: notifier.setEditorLineHeight,
                      ),
                      const SizedBox(height: AppTokens.s3),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTokens.s4),
                        decoration: BoxDecoration(
                          color: previewBg,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusInput,
                          ),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '雾港的钟声响到第四下，沈屿放下手中的火漆信封，望向窗外浓得化不开的夜雾。远处的灯塔忽明忽暗，像一句尚未说完的旧约。',
                          style: TextStyle(
                            color: previewFg,
                            fontSize: state.editorFontSize,
                            height: state.editorLineHeight,
                          ),
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

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? preset.color
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
          color: selected ? preset.color.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: preset.color,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(preset.name, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
