import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class ZhiMingApp extends ConsumerWidget {
  const ZhiMingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '织命',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: appearance.themeMode,
      theme: AppThemeBuilder.build(appearance.accentColor, Brightness.light),
      darkTheme: AppThemeBuilder.build(appearance.accentColor, Brightness.dark),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
