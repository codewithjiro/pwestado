import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/analysis/presentation/analyze_screen.dart';
import 'package:pwestado/features/analysis/presentation/site_analysis_section.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/discovery/presentation/competitor_results.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';

import '../fake_saved_analysis_repository.dart';
import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
import '../fake_site_context_repository.dart';

late FakeCompetitorRepository competitors;
late FakeSiteContextRepository contexts;

Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  competitors = FakeCompetitorRepository(
    respond: (q) => resultFor(q, [
      business(1, name: 'Kape Uno', distance: 100),
      business(2, distance: 200),
      business(3, name: 'Kape Tres', distance: 600),
    ]),
  );
  contexts = FakeSiteContextRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
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
  return ProviderScope.containerOf(tester.element(find.byType(PwestadoApp)));
}

Finder get panelScrollable => find
    .descendant(
      of: find.byType(AnalyzeScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> openAnalyzeTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('ANALYZE'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: panelScrollable);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> searchAndAnalyze(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container
      .read(exploreControllerProvider.notifier)
      .selectSite(latitude: 15.0939, longitude: 120.7681);
  await tester.pumpAndSettle();
  await openAnalyzeTab(tester);
  await tester.tap(
    find.widgetWithText(FilledButton, AnalyzeScreen.findFirstTitle),
  );
  await tester.pumpAndSettle();

  await scrollTo(tester, find.text(SiteAnalysisSection.analyzeLabel));
  // Keep the whole card in view: the loading state is shorter than the
  // intro, and more content (the comparison card) follows below.
  await tester.ensureVisible(find.byType(SiteAnalysisSection));
  await tester.pumpAndSettle();
  await tester.tap(find.text(SiteAnalysisSection.analyzeLabel));
  await tester.pump();
}

void main() {
  testWidgets('hidden until a competitor search finishes', (tester) async {
    final container = await pumpApp(tester);
    await openAnalyzeTab(tester);
    expect(find.text(AnalyzeScreen.noSiteTitle), findsOneWidget);
    container
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0939, longitude: 120.7681);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 · ${AnalyzeScreen.findFirstTitle}'), findsOne);
    expect(find.text(SiteAnalysisSection.title), findsNothing);
  });

  testWidgets('shows total, weighted breakdown, sources and limits', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await searchAndAnalyze(tester, container);

    expect(
      find.text('Checking helpful places and roads nearby…'),
      findsOneWidget,
    );
    contexts.pending.single.complete(contextFor(contexts.calls.single.query));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(SiteAnalysisSection.title));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Suitability score 64 out of 100',
      ),
      findsOneWidget,
    );
    expect(find.textContaining(SiteAnalysisSection.disclaimer), findsOne);

    await scrollTo(tester, find.text('Nearby competition · 40%'));
    expect(find.text('75 / 100'), findsOneWidget);
    expect(find.text('Adds 30.0 of 40 possible points.'), findsOneWidget);
    await scrollTo(tester, find.text('Helpful places nearby · 30%'));
    expect(find.text('12 / 100'), findsOneWidget);
    expect(find.text('6 mapped places: 6 school.'), findsOneWidget);
    await scrollTo(tester, find.text('Mapped road access · 30%'));
    expect(find.textContaining('not travel time'), findsOneWidget);

    await scrollTo(tester, find.text('How the score is calculated'));
    await tester.tap(find.text('How the score is calculated'));
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.text('Total = 0.40 × 75 + 0.30 × 12 + 0.30 × 100 = 63.6'),
    );
    await scrollTo(tester, find.text(SiteAnalysisSection.assumptionsNote));
    expect(find.textContaining('Complementary tags counted'), findsOneWidget);

    await scrollTo(tester, find.text('Evidence sources'));
    expect(find.text('Complementary places & roads'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ScoreBreakdown),
        matching: find.textContaining('Retrieved live at'),
      ),
      findsNWidgets(2),
    );
    expect(find.text(CompetitorResults.attribution), findsWidgets);
    expect(find.text(SiteAnalysisSection.sampleLabel), findsNothing);
    expect(find.text(SiteAnalysisSection.lowConfidenceLabel), findsNothing);
  });

  testWidgets('a failed evidence query shows Insufficient data', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await searchAndAnalyze(tester, container);
    contexts.pending.single.completeError(
      const CompetitorFetchException(CompetitorFailure.rateLimited),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(SiteAnalysisSection.insufficientData));
    expect(find.textContaining(' / 100 '), findsNothing);
    expect(find.textContaining('so no total score'), findsOneWidget);
    await scrollTo(tester, find.text('No data').first);
    expect(find.text('No data'), findsNWidgets(2));
    await scrollTo(
      tester,
      find.textContaining('Nothing was substituted for the missing evidence'),
    );
    expect(find.textContaining('Too many searches right now'), findsOne);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(contexts.calls, hasLength(2));
  });

  testWidgets('sparse evidence is flagged low confidence', (tester) async {
    final container = await pumpApp(tester);
    competitors.respond = (q) => resultFor(q, []);
    await searchAndAnalyze(tester, container);
    contexts.pending.single.complete(
      contextFor(contexts.calls.single.query, complementary: 1),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(SiteAnalysisSection.lowConfidenceLabel));
    expect(find.textContaining('may not be listed on the map'), findsOneWidget);
  });

  testWidgets('sample data is labeled as a sample heuristic result', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0939, longitude: 120.7681);
    container.read(competitorControllerProvider.notifier).showSample();
    await tester.pumpAndSettle();
    await openAnalyzeTab(tester);

    await scrollTo(tester, find.text(SiteAnalysisSection.analyzeLabel));
    await tester.tap(find.text(SiteAnalysisSection.analyzeLabel));
    await tester.pumpAndSettle();

    expect(contexts.calls, isEmpty);
    await scrollTo(tester, find.text(SiteAnalysisSection.sampleLabel));
    await scrollTo(tester, find.text('Evidence sources'));
    expect(
      find.descendant(
        of: find.byType(ScoreBreakdown),
        matching: find.text('SAMPLE DEMO DATA'),
      ),
      findsNWidgets(2),
    );
    expect(find.text(CompetitorResults.sampleNote), findsWidgets);
  });

  testWidgets('a failed competitor search shows Insufficient data', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    competitors.respond = (_) =>
        throw const CompetitorFetchException(CompetitorFailure.timeout);
    container
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0939, longitude: 120.7681);
    await container.read(competitorControllerProvider.notifier).search();
    await tester.pumpAndSettle();
    await openAnalyzeTab(tester);

    expect(find.text('Use sample demo data'), findsOneWidget);
    await scrollTo(tester, find.text(SiteAnalysisSection.insufficientData));
    expect(find.text(SiteAnalysisSection.analyzeLabel), findsNothing);
    expect(contexts.calls, isEmpty);
  });
}
