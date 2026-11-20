import 'package:flutter/material.dart';

import '../prompts/prompt_limits.dart';
import '../widgets/zm_widgets.dart';

/// 发送前提示词体量护栏：总字符超过 [PromptLimits.requestWarnChars]（80K）时弹窗确认。
abstract final class PromptGuard {
  static Future<bool> authorize(
    BuildContext context, {
    required int totalChars,
  }) async {
    if (totalChars <= PromptLimits.requestWarnChars) return true;
    if (!context.mounted) return false;
    return showZmConfirmDialog(
      context,
      title: '本次提示词较大',
      message:
          '请求合计约 $totalChars 字，超过 ${PromptLimits.requestWarnChars} 字告警线。\n'
          '可能触发上游上下文上限、显著拖慢首字响应或增加费用，仍要发送吗？',
      confirmLabel: '仍然发送',
      cancelLabel: '取消',
    );
  }
}
