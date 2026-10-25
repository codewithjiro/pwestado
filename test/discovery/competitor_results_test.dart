import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/discovery/presentation/competitor_results.dart';
import 'package:pwestado/features/discovery/presentation/competitor_summary.dart';
import 'package:pwestado/features/discovery/presentation/source_labels.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/presentation/widgets/map_setup_card.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';

import '../fake_saved_analysis_repository.dart';
import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';

late FakeCompetitorRepository repo;

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  repo = FakeCompetitorRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        competitorRepositoryProvider.overrideWithValue(repo),
        savedAnalysisRepositoryProvider.overrideWithValue(
          FakeSavedAnalysisRepository(),
        ),
      ],
      child: const PwestadoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PwestadoApp)));
}

Finder get sheet => find.byType(DraggableScrollableSheet);

Finder get panelScrollable =>
    find.descendant(of: sheet, matching: find.byType(Scrollable)).first;

Finder inSheet(Finder finder) => find.descendant(of: sheet, matching: finder);

/// Opens the full list from the map card's "View list" / "Details" button.
Future<void> openList(WidgetTester tester, {String via = 'View list'}) async {
  // The map card scrolls on short screens.
  await tester.ensureVisible(find.text(via));
  await tester.pumpAndSettle();
  await tester.tap(find.text(via));
  await tester.pumpAndSettle();
}

/// Scrolls the list sheet until [finder] is built, then fully into view so taps
/// land on it.
/// Pass `settle: false` while a progress indicator is animating.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: panelScrollable);
  await tester.ensureVisible(finder.first);
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

Future<void> pickSiteAndSearch(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container
      .read(exploreControllerProvider.notifier)
      .selectSite(latitude: 15.0939, longitude: 120.7681);
  await tester.pumpAndSettle();
  await tester.tap(find.text(MapSetupCard.findLabel));
  await tester.pump();
}

void main() {
  testWidgets('search shows loading, then counts, source and sorted list', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await pickSiteAndSearch(tester, container);

    expect(find.text('Looking for nearby businesses…'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(repo.calls, hasLength(1));

    repo.pending.single.complete(
      resultFor(repo.calls.single.query, [
        business(1, name: 'Kape Uno', distance: 84),
        business(2, distance: 450),
        business(3, name: 'Kape Tres', distance: 1250),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('3 Coffee Shop businesses found within 1 km'),
      findsOneWidget,
    );
    expect(find.text(MapSetupCard.openAnalyze), findsOneWidget);
    await openList(tester);
    expect(find.text(CompetitorSummary.listTitle), findsOneWidget);

    await scrollTo(tester, find.text('3 businesses found'));
    expect(find.text('3 businesses found'), findsOneWidget);
    expect(inSheet(find.text('LIVE')), findsOneWidget);
    expect(find.textContaining('Updated at'), findsOneWidget);
    expect(
      find.textContaining('Coffee Shop · within 1 km · on OpenStreetMap'),
      findsOne,
    );

    await scrollTo(tester, find.text('3. Kape Tres'));
    expect(find.text('1. Kape Uno'), findsOneWidget);
    expect(find.text('80 m'), findsOneWidget);
    expect(find.text('2. ${NearbyBusiness.unnamedLabel}'), findsOneWidget);
    expect(find.text('1.3 km'), findsOneWidget);
    expect(find.text('1 has no name in OpenStreetMap.'), findsOneWidget);

    await scrollTo(tester, find.text(CompetitorResults.attribution));
    expect(find.text(CompetitorResults.coverageNote), findsOneWidget);
  });

  testWidgets('tapping a record opens its details and selects it', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await pickSiteAndSearch(tester, container);
    repo.pending.single.complete(
      resultFor(repo.calls.single.query, [
        const NearbyBusiness(
          osmType: 'way',
          osmId: 77,
          name: 'Kape Way',
          latitude: 15.094,
          longitude: 120.769,
          distanceMeters: 120,
          details: {'Opening hours': 'Mo-Su 07:00-21:00'},
        ),
      ]),
    );
    await tester.pumpAndSettle();
    await openList(tester);

    await scrollTo(tester, find.text('1. Kape Way'));
    await tester.tap(find.text('1. Kape Way'));
    await tester.pumpAndSettle();

    expect(find.text('Kape Way'), findsOneWidget);
    expect(find.text('Mo-Su 07:00-21:00'), findsOneWidget);
    expect(find.text('way 77'), findsOneWidget);
    expect(container.read(competitorControllerProvider).selectedKey, 'way:77');
  });

  testWidgets('an empty result says "No mapped records", not "none exist"', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await pickSiteAndSearch(tester, container);
    repo.pending.single.complete(resultFor(repo.calls.single.query, []));
    await tester.pumpAndSettle();
    expect(
      find.text('No Coffee Shop businesses listed on the map within 1 km'),
      findsOneWidget,
    );
    await openList(tester);

    await scrollTo(tester, find.text(CompetitorResults.emptyMessage));
    expect(
      find.text('None listed on the map within this distance.'),
      findsOneWidget,
    );
    expect(find.text('0 businesses found'), findsOneWidget);
    expect(find.textContaining('No competitors'), findsNothing);
    expect(
      find.textContaining('That doesn’t mean there are none'),
      findsOneWidget,
    );
  });

  testWidgets('cached results are labeled cached', (tester) async {
    final container = await pumpApp(tester);
    repo.respond = (q) => resultFor(
      q,
      [business(1, name: 'Kape Uno')],
      source: DataSource.cached,
      fetchedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    );
    await pickSiteAndSearch(tester, container);
    await tester.pumpAndSettle();
    await openList(tester);

    await scrollTo(tester, find.text('1 business found'));
    expect(inSheet(find.text('CACHED')), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    expect(find.textContaining('Saved copy from'), findsOneWidget);
    expect(find.textContaining('3 min ago'), findsOneWidget);
  });

  testWidgets('429 shows a rate-limit error with retry and sample options', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await pickSiteAndSearch(tester, container);
    repo.pending.single.completeError(
      const CompetitorFetchException(
        CompetitorFailure.rateLimited,
        statusCode: 429,
      ),
    );
    await tester.pumpAndSettle();
    // The map card names the failure and offers a retry right there.
    expect(find.text('Too many searches right now'), findsOneWidget);
    await openList(tester, via: 'Details');

    await scrollTo(tester, find.text('Use sample demo data'));
    expect(inSheet(find.text('Too many searches right now')), findsOne);
    expect(find.textContaining('no results came back'), findsOneWidget);

    await tester.tap(inSheet(find.text('Try again')));
    await tester.pump();
    expect(repo.calls, hasLength(2));
    expect(find.text('Looking for nearby businesses…'), findsWidgets);
  });

  testWidgets('sample mode is unmistakably labeled', (tester) async {
    final container = await pumpApp(tester);
    await pickSiteAndSearch(tester, container);
    repo.pending.single.completeError(
      const CompetitorFetchException(CompetitorFailure.network),
    );
    await tester.pumpAndSettle();
    await openList(tester, via: 'Details');

    await scrollTo(tester, find.text('Use sample demo data'));
    expect(inSheet(find.text('No internet connection')), findsOneWidget);
    await tester.tap(find.text('Use sample demo data'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('Fictional places'));
    // Banner title and source badge both read "SAMPLE DEMO DATA".
    expect(inSheet(find.text(SampleBanner.title)), findsNWidgets(2));
    expect(find.textContaining('not real businesses'), findsWidgets);
    expect(find.text('LIVE'), findsNothing);
    expect(find.textContaining('Sample Coffee Shop 1 (demo)'), findsOneWidget);
    expect(find.byTooltip('Search again'), findsNothing);
    await scrollTo(tester, find.text(CompetitorResults.sampleNote));
    expect(
      find.text(CompetitorResults.attribution),
      findsNothing,
      reason: 'OSM attribution under sample rows would imply they are OSM',
    );
  });

  testWidgets('changing the category clears results back to idle', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await pickSiteAndSearch(tester, container);
    repo.pending.single.complete(
      resultFor(repo.calls.single.query, [business(1, name: 'Kape Uno')]),
    );
    await tester.pumpAndSettle();
    await openList(tester);
    await scrollTo(tester, find.text('1. Kape Uno'));

    container
        .read(exploreControllerProvider.notifier)
        .selectCategory(BusinessCategory.bakery);
    await tester.pumpAndSettle();

    expect(find.text('1. Kape Uno'), findsNothing);
    expect(find.text('1 business found'), findsNothing);
    expect(find.text(MapSetupCard.findLabel), findsOneWidget);
    expect(
      container.read(competitorControllerProvider).status,
      CompetitorStatus.idle,
    );
    expect(repo.calls, hasLength(1), reason: 'no automatic re-query');
  });

  testWidgets('cancel returns to idle', (tester) async {
    final container = await pumpApp(tester);
    await pickSiteAndSearch(tester, container);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Looking for nearby businesses…'), findsNothing);
    expect(repo.tokens.single!.isCancelled, isTrue);
  });

  testWidgets('long lists render without overflow on a small phone', (
    tester,
  ) async {
    final container = await pumpApp(tester, size: const Size(320, 640));
    await pickSiteAndSearch(tester, container);
    repo.pending.single.complete(
      resultFor(repo.calls.single.query, [
        for (var i = 1; i <= 45; i++)
          business(
            i,
            name: i.isEven
                ? 'A very long mapped business name number $i that wraps'
                : null,
            distance: i * 40.0,
          ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'map card fits');
    await openList(tester);

    await scrollTo(tester, find.text('Show all 45'));
    await tester.tap(find.text('Show all 45'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining('45. '));
    expect(tester.takeException(), isNull);
  });
}
