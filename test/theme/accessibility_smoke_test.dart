import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/app/theme.dart';
import 'package:pwestado/app/theme_mode_controller.dart';
import 'package:pwestado/features/ai/presentation/ai_insights_card.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/analysis/presentation/analyze_screen.dart';
import 'package:pwestado/features/analysis/state/analysis_controller.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';

import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
import '../fake_saved_analysis_repository.dart';
import '../fake_site_context_repository.dart';

/// A small phone (320 x 640 dp), 1.5x system font size, for each theme:
/// walks all four tabs through a full analysis and fails on any layout
/// overflow or exception.
/// Fails with the full diagnostics (which widget overflowed, and where).
void expectNoLayoutError(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error == null) return;
  fail('$where: ${error is FlutterError ? error.toStringDeep() : error}');
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('small screen, large text, ${mode.name} mode', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeStoreProvider.overrideWithValue(
              MemoryThemeModeStore(mode),
            ),
            locationServiceProvider.overrideWithValue(FakeLocationService()),
            competitorRepositoryProvider.overrideWithValue(
              FakeCompetitorRepository(
                respond: (q) => resultFor(q, [
                  business(
                    1,
                    name: 'Kapihan sa Kanto ng Barangay San Isidro Labrador',
                    distance: 100,
                  ),
                  business(2, distance: 200),
                  business(3, name: 'Kape Tres', distance: 600),
                ]),
              ),
            ),
            siteContextRepositoryProvider.overrideWithValue(
              FakeSiteContextRepository(respond: contextFor),
            ),
            savedAnalysisRepositoryProvider.overrideWithValue(
              FakeSavedAnalysisRepository(),
            ),
          ],
          child: const PwestadoApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PwestadoApp)),
      );
      final context = tester.element(find.byType(NavigationBar));
      expect(
        Theme.of(context).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(
        context.palette.background,
        mode == ThemeMode.dark
            ? AppPalette.dark.background
            : AppPalette.light.background,
      );

      container
          .read(exploreControllerProvider.notifier)
          .selectSite(latitude: 15.0939, longitude: 120.7681);
      await container.read(competitorControllerProvider.notifier).search();
      await container.read(analysisControllerProvider.notifier).analyze();
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, 'MAPA');

      for (final tab in ['ANALYZE', 'COMPARE', 'SAVED', 'MAPA']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expectNoLayoutError(tester, tab);
      }

      // Scroll ANALYZE to the bottom so every card (score, AI) is laid out.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('ANALYZE'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(AiCopy.title),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AnalyzeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, 'ANALYZE scrolled');
    });
  }
}
