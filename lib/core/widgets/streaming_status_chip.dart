import 'package:flutter/material.dart';

import '../llm/stream_progress.dart';
import '../theme/design_tokens.dart';

/// 流式生成状态胶囊：「正在等待首 Token · 1.2s / 深度思考 342 字 · 4.1s / 正在输出 820 字 · 6.5s」
class StreamingStatusChip extends StatelessWidget {
  const StreamingStatusChip({
    super.key,
    required this.tracker,
    this.hideWhenOutputting = false,
  });

  final StreamProgressTracker tracker;
  final bool hideWhenOutputting;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreamProgressState>(
      valueListenable: tracker,
      builder: (context, state, _) {
        if (!state.isActive) return const SizedBox.shrink();
        if (hideWhenOutputting && state.stage == StreamStage.outputting) {
          return const SizedBox.shrink();
        }
        final cs = Theme.of(context).colorScheme;
        final icon = switch (state.stage) {
          StreamStage.waitingFirstToken => Icons.hourglass_top_rounded,
          StreamStage.thinking => Icons.psychology_outlined,
          StreamStage.outputting => Icons.auto_awesome_outlined,
          StreamStage.idle => Icons.circle,
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppTokens.radiusCapsule),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 15, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                state.statusText,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
