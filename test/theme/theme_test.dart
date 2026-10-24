import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/theme.dart';
import 'package:pwestado/app/theme_mode_controller.dart';
import 'package:pwestado/features/explore/presentation/widgets/about_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('palette contrast (WCAG AA)', () {
    for (final (name, p) in [
      ('light', AppPalette.light),
      ('dark', AppPalette.dark),
    ]) {
      test('$name text tokens are readable on their surfaces', () {
        for (final bg in [p.background, p.surface, p.surfaceElevated]) {
          expect(contrast(p.textPrimary, bg), greaterThanOrEqualTo(7));
          expect(contrast(p.textSecondary, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(p.heading, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(p.brand, bg), greaterThanOrEqualTo(4.5));
        }
        expect(
          contrast(p.warning, p.warningContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(p.sample, p.sampleContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(p.danger, p.dangerContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(p.ai, p.aiContainer), greaterThanOrEqualTo(4.5));
        expect(
          contrast(p.historical, p.historicalContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(p.onAccentContainer, p.accentContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(p.onBrandFill, p.brandFill), greaterThanOrEqualTo(4.5));
      });
    }

    test('primary buttons are readable in both themes', () {
      for (final b in Brightness.values) {
        final s = buildAppTheme(b).colorScheme;
        expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      }
    });
  });

  test('both themes use the bundled font families', () {
    for (final b in Brightness.values) {
      final t = buildAppTheme(b).textTheme;
      expect(t.headlineSmall?.fontFamily, AppFonts.display);
      expect(t.titleMedium?.fontFamily, AppFonts.display);
      expect(t.bodyMedium?.fontFamily, AppFonts.body);
      expect(t.labelLarge?.fontFamily, AppFonts.body);
    }
  });

  group('ThemeModeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to system and persists the choice', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsThemeModeStore(prefs);
      final container = ProviderContainer(
        overrides: [themeModeStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeControllerProvider), ThemeMode.system);

      await container
          .read(themeModeControllerProvider.notifier)
          .select(ThemeMode.dark);
      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      expect(prefs.getString(SharedPrefsThemeModeStore.key), 'dark');

      // A "restart": a new container over the same storage.
      final restarted = ProviderContainer(
        overrides: [
          themeModeStoreProvider.overrideWithValue(
            SharedPrefsThemeModeStore(prefs),
          ),
        ],
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(themeModeControllerProvider), ThemeMode.dark);
    });

    test('unknown stored values fall back to system', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsThemeModeStore.key: 'purple',
      });
      final store = SharedPrefsThemeModeStore(
        await SharedPreferences.getInstance(),
      );
      expect(store.read(), isNull);
    });
  });

  testWidgets('the appearance selector switches the theme', (tester) async {
    final store = MemoryThemeModeStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeModeStoreProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: ref.watch(themeModeControllerProvider),
            home: const Scaffold(body: AppearanceSelector()),
          ),
        ),
      ),
    );
    BuildContext ctx() => tester.element(find.byType(AppearanceSelector));
    expect(Theme.of(ctx()).brightness, Brightness.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    expect(ctx().palette.background, AppPalette.dark.background);
    expect(store.read(), ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.light);
  });
}
