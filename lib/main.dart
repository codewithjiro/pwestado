import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/app.dart';
import 'core/config/mapbox_config.dart';
import 'shared/widgets/app_error_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Only a public pk. token is ever handed to the SDK. Without one the map
  // area explains how to rebuild instead of rendering a broken map.
  if (MapboxConfig.tokenStatus == MapboxTokenStatus.ok) {
    MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  }

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
