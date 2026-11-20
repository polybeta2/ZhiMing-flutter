import 'package:flutter/material.dart';

/// 织命设计令牌：延续 Kelivo / Apple 极简圆角卡片气质，适配桌面与移动端。
abstract final class AppTokens {
  static const double radiusCapsule = 28;
  static const double radiusBubble = 18;
  static const double radiusTail = 4;
  static const double radiusCard = 16;
  static const double radiusInput = 12;

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;

  static const Color r18Accent = Color(0xFFCC0000);
  static const String r18AccentHex = '#CC0000';

  /// 五套强调色预设（首位为 Kelivo 经典蓝紫）
  static const List<AccentPreset> accentPresets = [
    AccentPreset(name: '织命蓝紫', color: Color(0xFF4D5C91), hex: '#4D5C91'),
    AccentPreset(name: '晴空蓝', color: Color(0xFF2563EB), hex: '#2563EB'),
    AccentPreset(name: '松林绿', color: Color(0xFF16A34A), hex: '#16A34A'),
    AccentPreset(name: '暮色紫', color: Color(0xFF7C3AED), hex: '#7C3AED'),
    AccentPreset(name: '琥珀橙', color: Color(0xFFEA580C), hex: '#EA580C'),
  ];

  /// 响应式断点
  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1024;

  /// 解析形如 "#4D5C91" 或 "4D5C91" 的颜色字符串
  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length != 6) return null;
    final val = int.tryParse(s, radix: 16);
    if (val == null) return null;
    return Color(0xFF000000 | val);
  }

  static String toHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }
}

class AccentPreset {
  const AccentPreset({
    required this.name,
    required this.color,
    required this.hex,
  });

  final String name;
  final Color color;
  final String hex;
}

/// 编辑器沉浸护眼主题预设
enum EditorPaperTheme {
  system('跟随主题', null, null),
  parchment('羊皮米黄', Color(0xFFF7F2E7), Color(0xFF2C261E)),
  sage('护眼浅绿', Color(0xFFEBF3EC), Color(0xFF1E2B22)),
  slate('深灰夜间', Color(0xFF1B1D21), Color(0xFFDCE0E6)),
  oled('纯黑夜间', Color(0xFF000000), Color(0xFFD0D4DC));

  const EditorPaperTheme(this.label, this.background, this.foreground);
  final String label;
  final Color? background;
  final Color? foreground;
}
