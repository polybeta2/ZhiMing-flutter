import 'package:flutter/material.dart';

import '../../domain/writing/text_diff.dart';
import '../theme/design_tokens.dart';

/// 红绿行内 Diff 对比视图（改写精修 / 风格体检一键应用 / 版本快照共用）
class DiffPreviewView extends StatelessWidget {
  const DiffPreviewView({
    super.key,
    required this.before,
    required this.after,
  });

  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final lines = TextDiff.diffLines(before, after);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final removeBg = isDark
        ? Colors.red.withValues(alpha: 0.22)
        : Colors.red.withValues(alpha: 0.11);
    final addBg = isDark
        ? Colors.green.withValues(alpha: 0.22)
        : Colors.green.withValues(alpha: 0.11);

    return ListView.builder(
      shrinkWrap: true,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final item = lines[index];
        final bg = switch (item.kind) {
          DiffKind.removed => removeBg,
          DiffKind.added => addBg,
          DiffKind.unchanged => Colors.transparent,
        };
        final prefix = switch (item.kind) {
          DiffKind.removed => '- ',
          DiffKind.added => '+ ',
          DiffKind.unchanged => '  ',
        };
        final fg = switch (item.kind) {
          DiffKind.removed => isDark ? Colors.red.shade200 : Colors.red.shade900,
          DiffKind.added =>
            isDark ? Colors.green.shade200 : Colors.green.shade900,
          DiffKind.unchanged => Theme.of(context).colorScheme.onSurface,
        };
        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: SelectableText(
            '$prefix${item.text}',
            style: TextStyle(fontSize: 13.5, height: 1.55, color: fg),
          ),
        );
      },
    );
  }
}

/// 弹窗展示改写 Diff 对比并确认应用
Future<bool> showDiffConfirmDialog(
  BuildContext context, {
  required String title,
  required String before,
  required String after,
  String confirmLabel = '确认替换',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '原文 ${before.length} 字 → 新稿 ${after.length} 字',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.s3),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTokens.radiusInput),
                    border: Border.all(
                      color: Theme.of(
                        ctx,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: DiffPreviewView(before: before, after: after),
                ),
              ),
              const SizedBox(height: AppTokens.s3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}
