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
import 'package:pwestado/features/analysis/presentation/site_analysis_section.dart';
import 'package:pwestado/features/comparison/state/comparison_controller.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/data/sample_competitors.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/presentation/widgets/search_panel.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/saved/data/saved_analysis_codec.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:pwestado/features/saved/presentation/saved_analyses_screen.dart';
import 'package:pwestado/features/saved/presentation/saved_analysis_detail_screen.dart';

import '../comparison/comparison_fixtures.dart';
import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
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
  container.read(routerProvider).push(location);
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
    final container = await pumpApp(tester);
    await open(tester, container, AppRoutes.saved);

    expect(find.text(SavedAnalysesScreen.emptyTitle), findsOneWidget);
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
    expect(find.text('Coffee Shop · 1 km'), findsNWidgets(2));
    expect(find.text('Bakery · 1 km'), findsOneWidget);
    expect(find.text('LIVE-SOURCED'), findsOneWidget);
    expect(find.text('CACHED'), findsOneWidget);
    expect(find.text('SAMPLE DEMO DATA'), findsOneWidget);
    expect(find.text('HISTORICAL'), findsNWidgets(3));
    expect(find.textContaining('Saved Oct 21, 2026'), findsNWidgets(3));
    expect(find.textContaining('Evidence retrieved'), findsNWidgets(3));
    expect(find.text('64/100', findRichText: true), findsNWidgets(2));
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
    expect(find.text('Coffee Shop · 1 km'), findsOneWidget);
  });

  testWidgets('swipe to delete also works', (tester) async {
    await seedLive();
    final container = await pumpApp(tester);
    await open(tester, container, AppRoutes.saved);

    await tester.drag(find.text('Coffee Shop · 1 km'), const Offset(-500, 0));
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
    await tester.tap(find.text('Coffee Shop · 1 km'));
    await tester.pumpAndSettle();

    expect(find.byType(SavedAnalysisDetailScreen), findsOneWidget);
    expect(
      find.text(SavedAnalysisDetailScreen.historicalTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text('LIVE-SOURCED'), findsOneWidget);
    expect(find.textContaining('Saved Oct 21, 2026'), findsOneWidget);
    expect(find.textContaining('never refreshed'), findsOneWidget);

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
      find.text('3 mapped competitors'),
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
    expect(find.byType(SearchPanel), findsOneWidget, reason: 'back on map');
    expect(find.textContaining('Search settings switched'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('HISTORICAL'),
      200,
      scrollable: find.descendant(
        of: find.byType(SearchPanel),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('Historical evidence, not refreshed'), findsOne);
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
    final panel = find.descendant(
      of: find.byType(SearchPanel),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text(SiteAnalysisSection.analyzeLabel),
      200,
      scrollable: panel,
    );
    await tester.tap(find.text(SiteAnalysisSection.analyzeLabel));
    await tester.pumpAndSettle();
    expect(saved.rows, isEmpty, reason: 'never saved without asking');

    await tester.scrollUntilVisible(
      find.text(SaveAnalysisButton.label),
      200,
      scrollable: panel,
    );
    await tester.tap(find.text(SaveAnalysisButton.label));
    await tester.pumpAndSettle();

    expect(saved.rows, hasLength(1));
    final row = saved.rows.values.single;
    expect(row[SavedColumns.dataSource], 'live');
    expect(row[SavedColumns.totalScore], 63.6);
    expect(find.text(SaveAnalysisButton.savedLabel), findsOneWidget);
    expect(find.textContaining('Analysis saved on this device'), findsOne);

    await tester.tap(find.text(SaveAnalysisButton.savedLabel));
    await tester.pumpAndSettle();
    expect(find.byType(SavedAnalysisDetailScreen), findsOneWidget);
    expect(saved.rows, hasLength(1));
  });
}
