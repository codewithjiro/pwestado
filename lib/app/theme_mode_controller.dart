import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the appearance choice is stored. Only this one small preference
/// lives in SharedPreferences; analyses stay in SQLite.
abstract interface class ThemeModeStore {
  ThemeMode? read();
  Future<void> write(ThemeMode mode);
}

class SharedPrefsThemeModeStore implements ThemeModeStore {
  SharedPrefsThemeModeStore(this._prefs);

  static const key = 'appearance.themeMode';

  final SharedPreferences _prefs;

  @override
  ThemeMode? read() => switch (_prefs.getString(key)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => null,
  };

  @override
  Future<void> write(ThemeMode mode) => _prefs.setString(key, mode.name);
}

/// In-memory store: tests, and the fallback when preferences cannot load.
class MemoryThemeModeStore implements ThemeModeStore {
  MemoryThemeModeStore([this._mode]);

  ThemeMode? _mode;

  @override
  ThemeMode? read() => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}

/// Overridden in main() with the loaded store, so the first frame already
/// uses the saved theme (no light-to-dark flash at startup).
final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => MemoryThemeModeStore(),
);

/// System, light or dark. Defaults to following the phone's setting.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ref.read(themeModeStoreProvider).read() ?? ThemeMode.system;

  Future<void> select(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      await ref.read(themeModeStoreProvider).write(mode);
    } catch (e) {
      // The choice still applies for this session; it just won't persist.
      debugPrint('Could not save appearance preference: $e');
    }
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
