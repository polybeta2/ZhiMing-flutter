import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/dev/ios_preview_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: kIosPreviewEnabled
          ? IosPreviewShell(
              appBuilder: (platformOverride, mediaQueryTransform) => ZhiMingApp(
                platformOverride: platformOverride,
                mediaQueryTransform: mediaQueryTransform,
              ),
            )
          : const ZhiMingApp(),
    ),
  );
}
