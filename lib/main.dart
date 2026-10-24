import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/theme_mode_controller.dart';
import 'core/config/mapbox_config.dart';
import 'shared/widgets/app_error_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
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
  // Thumbnails are small; keep decoded images bounded on low-RAM phones.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;

  // A local read (no network), so the saved theme applies on the first
  // frame. Falls back to "follow system" if preferences are unavailable.
  ThemeModeStore themeStore;
  try {
    themeStore = SharedPrefsThemeModeStore(
      await SharedPreferences.getInstance(),
    );
  } catch (e) {
    debugPrint('Appearance preference unavailable: $e');
    themeStore = MemoryThemeModeStore();
  }

  runApp(
    ProviderScope(
      overrides: [themeModeStoreProvider.overrideWithValue(themeStore)],
      child: const PwestadoApp(),
    ),
  );
}

/// Bundled fonts are OFL-licensed; list them on the licenses page.
void _registerFontLicenses() {
  for (final (family, file) in [
    ('Inter', 'assets/fonts/Inter-OFL.txt'),
    ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-OFL.txt'),
  ]) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(file));
    });
  }
}
