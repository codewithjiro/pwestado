import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import 'theme_mode_controller.dart';

class PwestadoApp extends ConsumerWidget {
  const PwestadoApp({super.key});

  static final _light = buildAppTheme(Brightness.light);
  static final _dark = buildAppTheme(Brightness.dark);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PWESTADO',
      debugShowCheckedModeBanner: false,
      theme: _light,
      darkTheme: _dark,
      themeMode: ref.watch(themeModeControllerProvider),
      // A short cross-fade instead of a hard cut when the theme changes.
      themeAnimationDuration: const Duration(milliseconds: 200),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
