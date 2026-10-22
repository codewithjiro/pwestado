import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'shared/widgets/app_error_view.dart';

void main() {
  // Keep Flutter's detailed red error screen in debug; show a calm message in
  // release builds instead of a grey box.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const AppErrorView(
      title: 'Something went wrong',
      message: 'This part of the screen could not be displayed.',
    );
  }
  runApp(const ProviderScope(child: PwestadoApp()));
}
