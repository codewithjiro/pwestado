import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/comparison/presentation/compare_screen.dart';
import 'package:pwestado/features/comparison/presentation/comparison_section.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/places/domain/place.dart';
import 'package:pwestado/features/places/state/place_providers.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';

import '../fake_saved_analysis_repository.dart';
import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
import '../fake_place_repository.dart';
import '../fake_site_context_repository.dart';
import 'comparison_fixtures.dart';

late FakeCompetitorRepository competitors;
late FakeSiteContextRepository contexts;

Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  competitors = FakeCompetitorRepository(
    respond: (q) =>
        resultFor(q, q.latitude == siteA.lat ? threeCompetitors : const []),
  );
  contexts = FakeSiteContextRepository(respond: (q) => contextFor(q));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        placeRepositoryProvider.overrideWithValue(
          FakePlaceRepository()
            ..labelOf = (p) => PlaceLabel(
              title: p.latitude == siteA.lat ? 'Near Road A' : 'Near Road B',
            ),
        ),
        competitorRepositoryProvider.overrideWithValue(competitors),
        siteContextRepositoryProvider.overrideWithValue(contexts),
        savedAnalysisRepositoryProvider.overrideWithValue(
          FakeSavedAnalysisRepository(),
        ),
      ],
      child: const PwestadoApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('COMPARE'),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PwestadoApp)));
}

Finder get panelScrollable => find
    .descendant(
      of: find.byType(CompareScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: panelScrollable);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  // Several slots can show the same label, so scroll until one is built.
  final finder = find.text(text);
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.drag(panelScrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Pins site A and site B through the panel's "Use current pin" buttons.
Future<void> assignBoth(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final explore = container.read(exploreControllerProvider.notifier);
  explore.selectSite(latitude: siteA.lat, longitude: siteA.lon);
  await tester.pumpAndSettle();
  await tapText(tester, ComparisonSection.useCurrentPin);

  explore.selectSite(latitude: siteB.lat, longitude: siteB.lon);
  await tester.pumpAndSettle();
  // Site A now offers "Move to current pin"; only B offers "Use".
  expect(find.text(ComparisonSection.useCurrentPin), findsOneWidget);
  await tapText(tester, ComparisonSection.useCurrentPin);
}

void main() {
  testWidgets('explains how to start before any site is chosen', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Start with a location on MAPA'), findsOneWidget);
    await scrollTo(tester, find.text(ComparisonSection.title));
    expect(find.text('No location chosen yet.'), findsNWidgets(2));
    expect(find.textContaining('tap "Use map location" for Site A'), findsOne);
    expect(find.text(ComparisonSection.analyzeBoth), findsNothing);
  });

  testWidgets('compares two analyzed sites side by side', (tester) async {
    final container = await pumpApp(tester);
    await assignBoth(tester, container);
    expect(find.text('Ready to analyze.'), findsNWidgets(2));

    await tapText(tester, ComparisonSection.analyzeBoth);

    expect(competitors.calls.map((c) => c.query), [
      queryAt(siteA),
      queryAt(siteB),
    ]);
    await scrollTo(tester, find.text('Competitors mapped'));
    // Readable place names, not coordinates, label each site.
    expect(find.text('Near Road A'), findsWidgets);
    expect(find.text('Near Road B'), findsWidgets);
    expect(find.text('15.09390, 120.76810'), findsNothing);
    expect(find.text('Coffee Shop · 1 km'), findsNWidgets(2));
    expect(find.text('3 (2 within 250 m)'), findsOneWidget);
    expect(find.text('0 (0 within 250 m)'), findsOneWidget);
    expect(find.text('Road 30 m; major 120 m'), findsNWidgets(2));

    await scrollTo(tester, find.text('Suitability score'));
    expect(find.text('64 / 100'), findsOneWidget);
    expect(find.text('74 / 100'), findsOneWidget);
    expect(find.text('Higher suitability score'), findsOneWidget);

    await scrollTo(
      tester,
      find.text('Site B has the higher suitability score'),
    );
    expect(find.textContaining('(+10.0 points)'), findsOneWidget);
    expect(find.text(ComparisonSection.disclaimer), findsOneWidget);
    expect(find.text(ComparisonSection.notComparable), findsNothing);
  });

  testWidgets('mixed sample and live data is shown but never ranked', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    competitors.respond = (q) => q.latitude == siteB.lat
        ? throw const CompetitorFetchException(CompetitorFailure.network)
        : resultFor(q, threeCompetitors);
    await assignBoth(tester, container);
    await tapText(tester, ComparisonSection.analyzeBoth);

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Search failed'), findsWidgets);
    await tapText(tester, 'Use sample demo data');

    await scrollTo(tester, find.text(ComparisonSection.notComparable));
    expect(
      find.textContaining('Site B uses SAMPLE DEMO DATA and Site A uses'),
      findsOneWidget,
    );
    expect(find.text('SAMPLE DEMO DATA'), findsWidgets);
    expect(find.text('Higher suitability score'), findsNothing);
    expect(
      find.textContaining('has the higher suitability score'),
      findsNothing,
    );
  });

  testWidgets('a settings change blocks the ranking until re-analyzed', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await assignBoth(tester, container);
    await tapText(tester, ComparisonSection.analyzeBoth);
    expect(find.text('Higher suitability score'), findsOneWidget);

    container
        .read(exploreControllerProvider.notifier)
        .selectRadius(SearchRadius.km2);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(ComparisonSection.notComparable));
    expect(find.textContaining('Search settings changed'), findsOneWidget);
    expect(find.text('Higher suitability score'), findsNothing);
    expect(
      find.text('Uses different search settings. Update it to compare.'),
      findsNWidgets(2),
    );

    await tapText(tester, ComparisonSection.analyzeBoth);
    expect(competitors.calls.skip(2).map((c) => c.query.radius), [
      SearchRadius.km2,
      SearchRadius.km2,
    ]);
    expect(find.text(ComparisonSection.notComparable), findsNothing);
  });
}
