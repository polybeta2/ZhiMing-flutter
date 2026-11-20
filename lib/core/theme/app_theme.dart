import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_tokens.dart';

class AppearanceState {
  const AppearanceState({
    this.accentIndex = 0,
    this.themeMode = ThemeMode.system,
    this.editorFontSize = 16.0,
    this.editorLineHeight = 1.75,
    this.editorPaperTheme = EditorPaperTheme.system,
  });

  final int accentIndex;
  final ThemeMode themeMode;
  final double editorFontSize;
  final double editorLineHeight;
  final EditorPaperTheme editorPaperTheme;

  Color get accentColor {
    final idx = accentIndex.clamp(0, AppTokens.accentPresets.length - 1);
    return AppTokens.accentPresets[idx].color;
  }

  String get themeModeLabel => switch (themeMode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };

  AppearanceState copyWith({
    int? accentIndex,
    ThemeMode? themeMode,
    double? editorFontSize,
    double? editorLineHeight,
    EditorPaperTheme? editorPaperTheme,
  }) {
    return AppearanceState(
      accentIndex: accentIndex ?? this.accentIndex,
      themeMode: themeMode ?? this.themeMode,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      editorLineHeight: editorLineHeight ?? this.editorLineHeight,
      editorPaperTheme: editorPaperTheme ?? this.editorPaperTheme,
    );
  }
}

class AppearanceNotifier extends Notifier<AppearanceState> {
  static const _kAccent = 'appearance.accentIndex';
  static const _kScheme = 'appearance.themeMode';
  static const _kFontSize = 'editor.fontSize';
  static const _kLineHeight = 'editor.lineHeight';
  static const _kPaperTheme = 'editor.paperTheme';

  @override
  AppearanceState build() {
    _load();
    return const AppearanceState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final accent = prefs.getInt(_kAccent) ?? 0;
    final schemeIdx = prefs.getInt(_kScheme) ?? 0;
    final fontSize = prefs.getDouble(_kFontSize) ?? 16.0;
    final lineHeight = prefs.getDouble(_kLineHeight) ?? 1.75;
    final paperIdx = prefs.getInt(_kPaperTheme) ?? 0;
    state = AppearanceState(
      accentIndex: accent.clamp(0, AppTokens.accentPresets.length - 1),
      themeMode: ThemeMode.values[schemeIdx.clamp(0, ThemeMode.values.length - 1)],
      editorFontSize: fontSize.clamp(12.0, 28.0),
      editorLineHeight: lineHeight.clamp(1.2, 2.4),
      editorPaperTheme: EditorPaperTheme
          .values[paperIdx.clamp(0, EditorPaperTheme.values.length - 1)],
    );
  }

  Future<void> setAccentIndex(int index) async {
    final clamped = index.clamp(0, AppTokens.accentPresets.length - 1);
    state = state.copyWith(accentIndex: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccent, clamped);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kScheme, mode.index);
  }

  Future<void> setEditorFontSize(double size) async {
    final clamped = size.clamp(12.0, 28.0);
    state = state.copyWith(editorFontSize: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, clamped);
  }

  Future<void> setEditorLineHeight(double height) async {
    final clamped = height.clamp(1.2, 2.4);
    state = state.copyWith(editorLineHeight: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLineHeight, clamped);
  }

  Future<void> setEditorPaperTheme(EditorPaperTheme paper) async {
    state = state.copyWith(editorPaperTheme: paper);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPaperTheme, paper.index);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
      AppearanceNotifier.new,
    );

abstract final class AppThemeBuilder {
  static ThemeData build(Color seedColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final scaffoldBg = isDark
        ? const Color(0xFF111318)
        : const Color(0xFFF3F4F8);
    final cardColor = isDark
        ? const Color(0xFF1A1D24)
        : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardColor,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 0.8,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
