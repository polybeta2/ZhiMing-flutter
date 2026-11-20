import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/novel_domain.dart';
import '../theme/design_tokens.dart';
import 'zm_widgets.dart';

/// 唯一复用的 R18 增强开关组件（建书表单与作品设定页共用，告别原版 3 处重复免责卡片）
class R18ToggleTile extends StatelessWidget {
  const R18ToggleTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  static const _kConfirmed = 'r18.notice.confirmed.v1';

  Future<void> _handleChange(BuildContext context, bool next) async {
    if (!next) {
      onChanged(false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final alreadyConfirmed = prefs.getBool(_kConfirmed) ?? false;
    if (alreadyConfirmed) {
      onChanged(true);
      return;
    }
    if (!context.mounted) return;
    final agreed = await showZmConfirmDialog(
      context,
      title: '启用 R18 增强？',
      message: NovelBundle.r18NoticeText,
      confirmLabel: '同意并开启',
    );
    if (agreed) {
      await prefs.setBool(_kConfirmed, true);
      onChanged(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeTrackColor: AppTokens.r18Accent,
      title: const Text('R18 增强（虚构情色写作辅助）'),
      subtitle: Text(
        value
            ? '已开启：按输入主语言注入对应本地 R18 规范；作品强调色锁定血红'
            : '关闭中；开启后作品标识强制血红色并标注 R18',
        style: TextStyle(
          fontSize: 12,
          color: value
              ? AppTokens.r18Accent
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: (next) => _handleChange(context, next),
    );
  }
}
