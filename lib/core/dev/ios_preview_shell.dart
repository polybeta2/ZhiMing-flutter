import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 编译期开关：仅当 `--dart-define=IOS_PREVIEW=true` 时启用桌面端 iOS 预览外壳。
const bool kIosPreviewEnabled = bool.fromEnvironment(
  'IOS_PREVIEW',
  defaultValue: false,
);

/// 常见 iOS / iPadOS 真机逻辑分辨率与安全区预设。
enum IosDevicePreset {
  iphoneSe(
    label: 'iPhone SE',
    shortLabel: 'SE',
    logicalSize: Size(375, 667),
    topPadding: 20,
    bottomPadding: 0,
    cornerRadius: 20,
    hasDynamicIsland: false,
    hasHomeIndicator: false,
    keyboardHeight: 260,
  ),
  iphone15Pro(
    label: 'iPhone 15 Pro',
    shortLabel: '15 Pro',
    logicalSize: Size(393, 852),
    topPadding: 59,
    bottomPadding: 34,
    cornerRadius: 44,
    hasDynamicIsland: true,
    hasHomeIndicator: true,
    keyboardHeight: 336,
  ),
  iphone16ProMax(
    label: 'iPhone 16 Pro Max',
    shortLabel: '16 Pro Max',
    logicalSize: Size(440, 956),
    topPadding: 62,
    bottomPadding: 34,
    cornerRadius: 48,
    hasDynamicIsland: true,
    hasHomeIndicator: true,
    keyboardHeight: 346,
  ),
  ipadMini(
    label: 'iPad mini',
    shortLabel: 'iPad mini',
    logicalSize: Size(744, 1133),
    topPadding: 24,
    bottomPadding: 20,
    cornerRadius: 24,
    hasDynamicIsland: false,
    hasHomeIndicator: true,
    keyboardHeight: 320,
  );

  const IosDevicePreset({
    required this.label,
    required this.shortLabel,
    required this.logicalSize,
    required this.topPadding,
    required this.bottomPadding,
    required this.cornerRadius,
    required this.hasDynamicIsland,
    required this.hasHomeIndicator,
    required this.keyboardHeight,
  });

  final String label;
  final String shortLabel;
  final Size logicalSize;
  final double topPadding;
  final double bottomPadding;
  final double cornerRadius;
  final bool hasDynamicIsland;
  final bool hasHomeIndicator;
  final double keyboardHeight;
}

typedef IosPreviewAppBuilder =
    Widget Function(
      TargetPlatform platformOverride,
      MediaQueryData Function(MediaQueryData base) mediaQueryTransform,
    );

/// 零外部依赖的 Windows/桌面端 iOS 真机尺寸与交互预览外壳：
/// - 伪装 `TargetPlatform.iOS`（Cupertino 滚动回弹、iOS 路由转场、居中导航栏）；
/// - 将精确的设备逻辑宽高、灵动岛/刘海 SafeArea 与虚拟键盘 `viewInsets.bottom`
///   注入到内层 `MaterialApp.router(builder: ...)` 中，确保页面、弹窗与 BottomSheet 全链路一致；
/// - 可通过顶栏快速切换 iPhone SE / 15 Pro / 16 Pro Max / iPad mini、横竖屏、安全区与大字号（1.25x）。
class IosPreviewShell extends StatefulWidget {
  const IosPreviewShell({
    super.key,
    required this.appBuilder,
    this.initialPreset = IosDevicePreset.iphone15Pro,
    this.initialLandscape = false,
    this.initialSimulateKeyboard = false,
    this.initialShowSafeArea = true,
    this.initialTextScale = 1.0,
    this.showToolbar = true,
  });

  final IosPreviewAppBuilder appBuilder;
  final IosDevicePreset initialPreset;
  final bool initialLandscape;
  final bool initialSimulateKeyboard;
  final bool initialShowSafeArea;
  final double initialTextScale;
  final bool showToolbar;

  @override
  State<IosPreviewShell> createState() => _IosPreviewShellState();
}

class _IosPreviewShellState extends State<IosPreviewShell> {
  late IosDevicePreset _preset = widget.initialPreset;
  late bool _landscape = widget.initialLandscape;
  late bool _simulateKeyboard = widget.initialSimulateKeyboard;
  late bool _showSafeArea = widget.initialShowSafeArea;
  late double _textScale = widget.initialTextScale;
  TargetPlatform? _previousPlatformOverride;

  @override
  void initState() {
    super.initState();
    _previousPlatformOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  }

  @override
  void dispose() {
    debugDefaultTargetPlatformOverride = _previousPlatformOverride;
    super.dispose();
  }

  Size get _effectiveSize => _landscape
      ? Size(_preset.logicalSize.height, _preset.logicalSize.width)
      : _preset.logicalSize;

  double get _effectiveKeyboardHeight => _simulateKeyboard
      ? (_landscape
            ? math.min(180, _preset.keyboardHeight * 0.55)
            : _preset.keyboardHeight)
      : 0.0;

  MediaQueryData _transformMediaQuery(MediaQueryData base) {
    final size = _effectiveSize;
    final topPad = _showSafeArea && !_landscape ? _preset.topPadding : 0.0;
    final bottomViewPad = _showSafeArea
        ? (_landscape ? (_preset.hasHomeIndicator ? 21.0 : 0.0) : _preset.bottomPadding)
        : 0.0;
    final sidePad = _showSafeArea && _landscape && _preset.hasDynamicIsland
        ? _preset.topPadding
        : 0.0;
    final kb = _effectiveKeyboardHeight;

    final viewPadding = EdgeInsets.only(
      left: sidePad,
      right: sidePad,
      top: topPad,
      bottom: bottomViewPad,
    );
    final padding = EdgeInsets.only(
      left: sidePad,
      right: sidePad,
      top: topPad,
      bottom: kb > 0 ? math.max(0.0, bottomViewPad - kb) : bottomViewPad,
    );
    final viewInsets = EdgeInsets.only(bottom: kb);

    return base.copyWith(
      size: size,
      devicePixelRatio: 3.0,
      padding: padding,
      viewPadding: viewPadding,
      viewInsets: viewInsets,
      textScaler: TextScaler.linear(_textScale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _effectiveSize;
    final kbHeight = _effectiveKeyboardHeight;
    final topPad = _showSafeArea && !_landscape ? _preset.topPadding : 0.0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0E1117),
        child: Column(
          children: [
            if (widget.showToolbar) _buildToolbar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          _preset.cornerRadius + 6,
                        ),
                        border: Border.all(
                          color: const Color(0xFF2D3548),
                          width: 6,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88000000),
                            blurRadius: 36,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            _preset.cornerRadius,
                          ),
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: widget.appBuilder(
                                    TargetPlatform.iOS,
                                    _transformMediaQuery,
                                  ),
                                ),
                                if (kbHeight > 0)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: kbHeight,
                                    child: IgnorePointer(
                                      child: _SimulatedIosKeyboard(
                                        height: kbHeight,
                                      ),
                                    ),
                                  ),
                                if (_showSafeArea && topPad > 0)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    height: topPad,
                                    child: IgnorePointer(
                                      child: _SimulatedIosStatusBar(
                                        hasDynamicIsland:
                                            _preset.hasDynamicIsland,
                                        height: topPad,
                                      ),
                                    ),
                                  ),
                                if (_showSafeArea && _preset.hasHomeIndicator)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 8,
                                    child: IgnorePointer(
                                      child: Center(
                                        child: Container(
                                          width: _landscape ? 180 : 134,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(
                                              alpha: 0.48,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final size = _effectiveSize;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161B26),
        border: Border(bottom: BorderSide(color: Color(0xFF262E3F))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF283552),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'iOS PREVIEW',
                style: TextStyle(
                  color: Color(0xFF93C5FD),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            for (final preset in IosDevicePreset.values) ...[
              _ToolbarChip(
                label: preset.shortLabel,
                selected: _preset == preset,
                onTap: () => setState(() => _preset = preset),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 8),
            _ToolbarChip(
              label: _landscape ? '横屏' : '竖屏',
              selected: _landscape,
              onTap: () => setState(() => _landscape = !_landscape),
            ),
            const SizedBox(width: 6),
            _ToolbarChip(
              label: '键盘',
              selected: _simulateKeyboard,
              onTap: () =>
                  setState(() => _simulateKeyboard = !_simulateKeyboard),
            ),
            const SizedBox(width: 6),
            _ToolbarChip(
              label: '安全区',
              selected: _showSafeArea,
              onTap: () => setState(() => _showSafeArea = !_showSafeArea),
            ),
            const SizedBox(width: 6),
            _ToolbarChip(
              label: '${_textScale.toStringAsFixed(2)}x 字号',
              selected: _textScale > 1.01,
              onTap: () => setState(
                () => _textScale = _textScale > 1.01 ? 1.0 : 1.25,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${size.width.toInt()}×${size.height.toInt()} pt · TargetPlatform.iOS',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF3B82F6)
                : const Color(0xFF212838),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFF334155),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulatedIosStatusBar extends StatelessWidget {
  const _SimulatedIosStatusBar({
    required this.hasDynamicIsland,
    required this.height,
  });

  final bool hasDynamicIsland;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 20,
        top: hasDynamicIsland ? 14 : 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '9:41',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          if (hasDynamicIsland)
            Container(
              width: 112,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.signal_cellular_alt,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(width: 4),
              Icon(Icons.wifi, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Icon(
                Icons.battery_full_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimulatedIosKeyboard extends StatelessWidget {
  const _SimulatedIosKeyboard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFFD1D5DB),
        border: Border(top: BorderSide(color: Color(0xFF9CA3AF))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    '中文拼音 · 模拟 iOS 键盘',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'viewInsets = ${height.toInt()}pt',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final row in const [
            ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
            ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
            ['⇧', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '⌫'],
          ]) ...[
            Expanded(
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          key,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 64,
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFACB3BF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '123',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF111827),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '空格',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 78,
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '换行',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
