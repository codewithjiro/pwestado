import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/app/router.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/analysis/domain/site_analysis.dart';
import 'package:pwestado/features/analysis/domain/site_context.dart';
import 'package:pwestado/features/analysis/presentation/analyze_screen.dart';
import 'package:pwestado/features/analysis/presentation/site_analysis_section.dart';
import 'package:pwestado/features/comparison/presentation/compare_screen.dart';
import 'package:pwestado/features/comparison/state/comparison_controller.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/data/sample_competitors.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/places/presentation/site_place_label.dart';
import 'package:pwestado/features/places/state/place_providers.dart';
import 'package:pwestado/features/saved/data/saved_analysis_codec.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:pwestado/features/saved/presentation/saved_analyses_screen.dart';
import 'package:pwestado/features/saved/presentation/saved_analysis_detail_screen.dart';

import '../comparison/comparison_fixtures.dart';
import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
import '../fake_place_repository.dart';
import '../fake_saved_analysis_repository.dart';
import '../fake_site_context_repository.dart';

late FakeSavedAnalysisRepository saved;
late FakeCompetitorRepository competitors;
late FakeSiteContextRepository contexts;

final _site = SelectedSite.at(latitude: siteA.lat, longitude: siteA.lon);

Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  competitors = FakeCompetitorRepository(
    respond: (q) => resultFor(q, threeCompetitors),
  );
  contexts = FakeSiteContextRepository(respond: contextFor);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository()),
        competitorRepositoryProvider.overrideWithValue(competitors),
        siteContextRepositoryProvider.overrideWithValue(contexts),
        savedAnalysisRepositoryProvider.overrideWithValue(saved),
      ],
      child: const PwestadoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PwestadoApp)));
}

Future<void> open(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Finder scrollableIn(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byType(Scrollable));

Future<void> scrollIn(WidgetTester tester, Type screen, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: scrollableIn(screen).first,
  );
  await tester.pumpAndSettle();
}

Future<int> seedLive({DateTime? when}) => saved.save(
  _site,
  analysisAt(queryAt(siteA), fetchedAt: DateTime(2026, 10, 21, 9)),
  when ?? DateTime(2026, 10, 21, 10),
);

void main() {
  setUp(() => saved = FakeSavedAnalysisRepository());

  testWidgets('empty list explains that nothing is saved without asking', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, 'SAVED');

    expect(find.text(SavedAnalysesScreen.emptyTitle), findsOneWidget);
    expect(find.byType(BackButton), findsNothing, reason: 'a tab, not a page');
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.textContaining('Nothing is saved unless you ask'), findsOne);
  });

  testWidgets('list shows summaries with their saved source labels', (
    tester,
  ) async {
    await seedLive();
    await saved.save(
      _site,
      analysisAt(queryAt(siteB), contextSource: DataSource.cached),
      DateTime(2026, 10, 21, 11),
    );
    final query = queryAt(siteB, category: BusinessCategory.bakery);
    final now = DateTime(2026, 10, 21, 12);
    await saved.save(
      SelectedSite.at(latitude: siteB.lat, longitude: siteB.lon),
      SiteAnalysis.from(
        competitors: SampleCompetitors.forQuery(query, now),
        context: SampleSiteContext.forQuery(query, now),
      ),
      now,
    );
    final container = await pumpApp(tester);
    await open(tester, container, AppRoutes.saved);

    expect(find.text(SavedAnalysesScreen.historicalNote), findsOneWidget);
    expect(find.text('Coffee Shop · within 1 km'), findsNWidgets(2));
    expect(find.text('Bakery · within 1 km'), findsOneWidget);
    expect(find.text('LIVE-SOURCED'), findsOneWidget);
    expect(find.text('CACHED'), findsOneWidget);
    expect(find.text('SAMPLE DEMO DATA'), findsOneWidget);
    expect(find.text('HISTORICAL'), findsNWidgets(3));
    expect(find.textContaining('Saved Oct 21, 2026'), findsNWidgets(3));
    expect(find.textContaining('data from'), findsNWidgets(3));
    expect(find.text('64'), findsNWidgets(2));
  });

  testWidgets('delete removes a record and Undo restores it', (tester) async {
    final id = await seedLive();
    final container = await pumpApp(tester);
    await open(tester, container, AppRoutes.saved);

    await tester.tap(find.byTooltip('Delete saved analysis'));
    await tester.pumpAndSettle();
    expect(saved.rows, isEmpty);
    expect(find.text(SavedAnalysesScreen.emptyTitle), findsOneWidget);
    expect(find.text('Saved analysis deleted.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(saved.rows.keys, [id]);
    expect(find.text('Coffee Shop · within 1 km'), findsOneWidget);
  });

  testWidgets('swipe to delete also works', (tester) async {
    await seedLive();
    final container = await pumpApp(tester);
    await open(tester, container, AppRoutes.saved);

    await tester.drag(
      find.text('Coffee Shop · within 1 km'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(saved.rows, isEmpty);
    expect(find.text('Saved analysis deleted.'), findsOneWidget);
  });

  testWidgets('a saved analysis reopens offline with its breakdown', (
    tester,
  ) async {
    final id = await seedLive();
    final container = await pumpApp(tester);
    await open(tester, container, AppRoutes.saved);
    await tester.tap(find.text('Coffee Shop · within 1 km'));
    await tester.pumpAndSettle();

    expect(find.byType(SavedAnalysisDetailScreen), findsOneWidget);
    expect(
      find.text(SavedAnalysisDetailScreen.historicalTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text('LIVE-SOURCED'), findsOneWidget);
    expect(find.textContaining('Saved Oct 21, 2026'), findsOneWidget);
    expect(find.textContaining('never refreshed'), findsOneWidget);
    // Readable label first; exact coordinates only under Technical details.
    expect(find.text('Near Test Road'), findsOneWidget);
    expect(find.text('15.093900'), findsNothing);
    await tester.tap(find.text(SiteTechnicalDetails.title));
    await tester.pumpAndSettle();
    expect(find.text('15.093900'), findsOneWidget);
    expect(find.text('120.768100'), findsOneWidget);

    await scrollIn(
      tester,
      SavedAnalysisDetailScreen,
      find.text(SiteAnalysisSection.title),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Suitability score 64 out of 100',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Refresh scoring evidence'), findsNothing);
    await scrollIn(
      tester,
      SavedAnalysisDetailScreen,
      find.text('How the score is calculated'),
    );
    await tester.tap(find.text('How the score is calculated'));
    await tester.pumpAndSettle();
    await scrollIn(
      tester,
      SavedAnalysisDetailScreen,
      find.text('Total = 0.40 × 75 + 0.30 × 12 + 0.30 × 100 = 63.6'),
    );
    await scrollIn(
      tester,
      SavedAnalysisDetailScreen,
      find.textContaining('Retrieved live on 10/21').first,
    );
    await scrollIn(
      tester,
      SavedAnalysisDetailScreen,
      find.text('3 businesses found'),
    );

    expect(competitors.calls, isEmpty, reason: 'no network request');
    expect(contexts.calls, isEmpty, reason: 'no network request');
    expect(saved.rows[id]![SavedColumns.savedAt], isNotNull);
  });

  testWidgets('Use as Site A aligns settings and loads the slot', (
    tester,
  ) async {
    final id = await seedLive();
    final container = await pumpApp(tester);
    container
        .read(exploreControllerProvider.notifier)
        .applySettings(BusinessCategory.bakery, SearchRadius.km2);
    await open(tester, container, AppRoutes.savedDetail(id));

    await tester.tap(find.text(SavedAnalysisDetailScreen.useAsA));
    await tester.pumpAndSettle();

    final explore = container.read(exploreControllerProvider);
    expect(explore.category, BusinessCategory.coffeeShop);
    expect(explore.radius, SearchRadius.km1);
    final slot = container.read(comparisonControllerProvider).a;
    expect(slot.isSaved, isTrue);
    expect(slot.analysis!.score.total, 63.6);
    expect(find.byType(CompareScreen), findsOneWidget, reason: 'on COMPARE');
    expect(find.textContaining('Search settings switched'), findsOneWidget);
    await scrollIn(tester, CompareScreen, find.text('HISTORICAL'));
    expect(
      find.textContaining('Shows information from then, not today'),
      findsOne,
    );
    expect(competitors.calls, isEmpty);
  });

  testWidgets('a damaged record is reported instead of shown', (tester) async {
    final id = await seedLive();
    saved.rows[id]![SavedColumns.evidence] = '{"v": 1}';
    final container = await pumpApp(tester);
    await open(tester, container, AppRoutes.savedDetail(id));

    expect(find.text('This saved record could not be read'), findsOneWidget);
    expect(find.textContaining('nothing is guessed'), findsOneWidget);
  });

  testWidgets('Save analysis stores the on-screen analysis once', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: siteA.lat, longitude: siteA.lon);
    await container.read(competitorControllerProvider.notifier).search();
    await tester.pumpAndSettle();
    await openTab(tester, 'ANALYZE');
    final panel = scrollableIn(AnalyzeScreen).first;
    await tester.scrollUntilVisible(
      find.text(SiteAnalysisSection.analyzeLabel),
      200,
      scrollable: panel,
    );
    await tester.ensureVisible(find.text(SiteAnalysisSection.analyzeLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SiteAnalysisSection.analyzeLabel));
    await tester.pumpAndSettle();
    expect(saved.rows, isEmpty, reason: 'never saved without asking');

    await tester.scrollUntilVisible(
      find.text(SaveAnalysisButton.label),
      200,
      scrollable: panel,
    );
    await tester.ensureVisible(find.text(SaveAnalysisButton.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SaveAnalysisButton.label));
    await tester.pumpAndSettle();

    expect(saved.rows, hasLength(1));
    final row = saved.rows.values.single;
    expect(row[SavedColumns.dataSource], 'live');
    expect(row[SavedColumns.totalScore], 63.6);
    // Mapbox place names are temporary results: never written to SQLite.
    expect(row[SavedColumns.siteLabel], 'Pinned site');
    expect(row.values.whereType<String>().join(), isNot(contains('Test Road')));
    expect(find.text(SaveAnalysisButton.savedLabel), findsOneWidget);
    expect(find.textContaining('Analysis saved on this phone'), findsOne);

    await tester.tap(find.text(SaveAnalysisButton.savedLabel));
    await tester.pumpAndSettle();
    expect(find.byType(SavedAnalysisDetailScreen), findsOneWidget);
    expect(saved.rows, hasLength(1));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
      reason: 'the SAVED tab is highlighted',
    );
  });
}
