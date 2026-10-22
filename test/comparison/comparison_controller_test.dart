import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/analysis/state/analysis_controller.dart';
import 'package:pwestado/features/comparison/domain/site_comparison.dart';
import 'package:pwestado/features/comparison/state/comparison_controller.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';

import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
import '../fake_site_context_repository.dart';
import 'comparison_fixtures.dart';

void main() {
  late FakeCompetitorRepository competitors;
  late FakeSiteContextRepository contexts;
  late ProviderContainer container;

  /// Site A gets three competitors, any other site none.
  List<NearbyBusiness> businessesFor(CompetitorQuery q) =>
      q.latitude == siteA.lat ? threeCompetitors : const [];

  setUp(() {
    competitors = FakeCompetitorRepository(
      respond: (q) => resultFor(q, businessesFor(q)),
    );
    contexts = FakeSiteContextRepository(respond: (q) => contextFor(q));
    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        competitorRepositoryProvider.overrideWithValue(competitors),
        siteContextRepositoryProvider.overrideWithValue(contexts),
      ],
    );
    container.listen(comparisonControllerProvider, (_, _) {});
    container.listen(siteComparisonProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  ExploreController explore() =>
      container.read(exploreControllerProvider.notifier);
  ComparisonController controller() =>
      container.read(comparisonControllerProvider.notifier);
  ComparisonState state() => container.read(comparisonControllerProvider);
  SiteComparison verdict() => container.read(siteComparisonProvider);

  void pin(({double lat, double lon}) site) =>
      explore().selectSite(latitude: site.lat, longitude: site.lon);

  void assign(CompareSlot slot, ({double lat, double lon}) site) {
    pin(site);
    controller().assignCurrentSite(slot);
  }

  test('does nothing without a pin on the map', () {
    controller().assignCurrentSite(CompareSlot.a);
    expect(state().a.status, SlotStatus.empty);
  });

  test('A and B are analyzed independently with the same settings', () async {
    explore().selectCategory(BusinessCategory.restaurant);
    explore().selectRadius(SearchRadius.km2);
    assign(CompareSlot.a, siteA);
    assign(CompareSlot.b, siteB);
    expect(state().a.site!.latitude, siteA.lat);
    expect(state().b.site!.latitude, siteB.lat);

    await controller().analyze(CompareSlot.a);
    await controller().analyze(CompareSlot.b);

    final queries = competitors.calls.map((c) => c.query).toList();
    expect(queries, [
      queryAt(
        siteA,
        category: BusinessCategory.restaurant,
        radius: SearchRadius.km2,
      ),
      queryAt(
        siteB,
        category: BusinessCategory.restaurant,
        radius: SearchRadius.km2,
      ),
    ]);
    expect(contexts.calls.map((c) => c.query), queries);

    final a = state().a.analysis!;
    final b = state().b.analysis!;
    expect(a.competitors.query, queries[0]);
    expect(b.competitors.query, queries[1]);
    expect(a.competitors.count, 3);
    expect(b.competitors.count, 0);
    // Restaurant at 2 km: complementary saturation is 100 places.
    expect(verdict().isComparable, isTrue);
    expect(verdict().higher, CompareSlot.b);
  });

  test('picking and analyzing Site B never overwrites Site A', () async {
    assign(CompareSlot.a, siteA);
    await controller().analyze(CompareSlot.a);
    final siteBefore = state().a.site;
    final analysisBefore = state().a.analysis;

    assign(CompareSlot.b, siteB);
    await controller().analyze(CompareSlot.b);
    // A new map pin elsewhere does not touch either slot.
    pin((lat: 15.2, lon: 120.9));

    expect(state().a.site, siteBefore);
    expect(identical(state().a.analysis, analysisBefore), isTrue);
    expect(state().a.analysis!.competitors.query, queryAt(siteA));
    expect(state().b.analysis!.competitors.query, queryAt(siteB));
  });

  test('re-analyzing an analyzed slot sends no request', () async {
    assign(CompareSlot.a, siteA);
    await controller().analyze(CompareSlot.a);
    await controller().analyze(CompareSlot.a);
    await controller().analyzeAll();
    expect(competitors.calls, hasLength(1));
    expect(contexts.calls, hasLength(1));
  });

  test('refresh forces a new request for that slot only', () async {
    assign(CompareSlot.a, siteA);
    assign(CompareSlot.b, siteB);
    await controller().analyzeAll();
    await controller().analyze(CompareSlot.b, forceRefresh: true);

    expect(competitors.calls, hasLength(3));
    expect(competitors.calls.last.query, queryAt(siteB));
    expect(competitors.calls.last.forceRefresh, isTrue);
  });

  test('reuses the main-screen analysis without any extra request', () async {
    container.listen(analysisControllerProvider, (_, _) {});
    pin(siteA);
    await container.read(competitorControllerProvider.notifier).search();
    await container.read(analysisControllerProvider.notifier).analyze();
    final main = container.read(analysisControllerProvider).analysis!;
    expect(competitors.calls, hasLength(1));
    expect(contexts.calls, hasLength(1));

    controller().assignCurrentSite(CompareSlot.a);

    expect(state().a.status, SlotStatus.ready);
    expect(state().a.reused, isTrue);
    expect(identical(state().a.analysis, main), isTrue);
    expect(competitors.calls, hasLength(1));
    expect(contexts.calls, hasLength(1));
  });

  test(
    'a main-screen analysis finished later fills the pending slot',
    () async {
      container.listen(analysisControllerProvider, (_, _) {});
      assign(CompareSlot.a, siteA);
      expect(state().a.status, SlotStatus.pending);

      await container.read(competitorControllerProvider.notifier).search();
      await container.read(analysisControllerProvider.notifier).analyze();

      expect(state().a.status, SlotStatus.ready);
      expect(state().a.reused, isTrue);
      expect(state().b.status, SlotStatus.empty);
    },
  );

  test(
    'a main-screen analysis of another site leaves the slot alone',
    () async {
      container.listen(analysisControllerProvider, (_, _) {});
      assign(CompareSlot.a, siteA);
      pin(siteB);
      await container.read(competitorControllerProvider.notifier).search();
      await container.read(analysisControllerProvider.notifier).analyze();

      expect(state().a.status, SlotStatus.pending);
      expect(state().a.analysis, isNull);
    },
  );

  test('only one slot loads at a time', () async {
    competitors.respond = null;
    assign(CompareSlot.a, siteA);
    assign(CompareSlot.b, siteB);

    final analyzingA = controller().analyze(CompareSlot.a);
    await controller().analyze(CompareSlot.b);
    expect(state().a.status, SlotStatus.loading);
    expect(state().b.status, SlotStatus.pending);
    expect(competitors.calls, hasLength(1));

    competitors.pending.single.complete(resultFor(queryAt(siteA), []));
    await analyzingA;
    expect(state().a.status, SlotStatus.ready);
  });

  test('analyze both runs A then B sequentially', () async {
    competitors.respond = null;
    assign(CompareSlot.a, siteA);
    assign(CompareSlot.b, siteB);

    final all = controller().analyzeAll();
    await pumpEventQueue();
    expect(competitors.calls.single.query, queryAt(siteA));

    competitors.pending[0].complete(resultFor(queryAt(siteA), []));
    await pumpEventQueue();
    expect(competitors.calls, hasLength(2));
    expect(competitors.calls[1].query, queryAt(siteB));

    competitors.pending[1].complete(resultFor(queryAt(siteB), []));
    await all;
    expect(state().a.status, SlotStatus.ready);
    expect(state().b.status, SlotStatus.ready);
  });

  test('a failed competitor search fails that slot only', () async {
    assign(CompareSlot.a, siteA);
    await controller().analyze(CompareSlot.a);

    competitors.respond = (_) => throw const CompetitorFetchException(
      CompetitorFailure.serverBusy,
      statusCode: 504,
    );
    assign(CompareSlot.b, siteB);
    await controller().analyze(CompareSlot.b);

    expect(state().b.status, SlotStatus.failed);
    expect(state().b.failure, CompetitorFailure.serverBusy);
    expect(state().b.statusCode, 504);
    expect(state().b.analysis, isNull);
    expect(state().a.status, SlotStatus.ready);
    expect(verdict().blockedBy(ComparisonBlockerKind.missingAnalysis), isTrue);
    expect(verdict().higher, isNull);
  });

  test(
    'a failed context request gives Insufficient data, never a rank',
    () async {
      contexts.respond = (q) => q.latitude == siteB.lat
          ? throw const CompetitorFetchException(CompetitorFailure.rateLimited)
          : contextFor(q);
      assign(CompareSlot.a, siteA);
      assign(CompareSlot.b, siteB);
      await controller().analyzeAll();

      expect(state().b.status, SlotStatus.ready);
      expect(state().b.analysis!.score.total, isNull);
      expect(state().b.analysis!.contextFailure, CompetitorFailure.rateLimited);
      expect(
        verdict().blockedBy(ComparisonBlockerKind.insufficientData),
        isTrue,
      );
      expect(verdict().higher, isNull);
    },
  );

  test('sample fallback for one slot blocks a mixed comparison', () async {
    assign(CompareSlot.a, siteA);
    await controller().analyze(CompareSlot.a);
    competitors.respond = (_) =>
        throw const CompetitorFetchException(CompetitorFailure.network);
    assign(CompareSlot.b, siteB);
    await controller().analyze(CompareSlot.b);

    controller().useSample(CompareSlot.b);

    expect(state().b.analysis!.isSample, isTrue);
    expect(state().a.analysis!.isSample, isFalse);
    expect(verdict().blockedBy(ComparisonBlockerKind.mixedSources), isTrue);
    expect(verdict().higher, isNull);
  });

  test('both slots in sample mode compare as a labeled demo', () {
    assign(CompareSlot.a, siteA);
    assign(CompareSlot.b, siteB);
    controller().useSample(CompareSlot.a);
    controller().useSample(CompareSlot.b);

    expect(competitors.calls, isEmpty);
    expect(verdict().isComparable, isTrue);
    expect(verdict().sampleOnly, isTrue);
  });

  test('the same site in both slots is rejected', () async {
    assign(CompareSlot.a, siteA);
    controller().assignCurrentSite(CompareSlot.b);
    await controller().analyzeAll();

    expect(verdict().blockedBy(ComparisonBlockerKind.sameSite), isTrue);
    expect(verdict().higher, isNull);
  });

  test('changing settings keeps sites but invalidates the ranking', () async {
    assign(CompareSlot.a, siteA);
    assign(CompareSlot.b, siteB);
    await controller().analyzeAll();
    expect(verdict().isComparable, isTrue);

    explore().selectRadius(SearchRadius.m500);

    expect(state().a.site!.latitude, siteA.lat);
    expect(state().b.site!.latitude, siteB.lat);
    expect(verdict().blockedBy(ComparisonBlockerKind.settingsChanged), isTrue);
    expect(verdict().higher, isNull);

    await controller().analyzeAll();
    expect(competitors.calls.skip(2).map((c) => c.query.radius), [
      SearchRadius.m500,
      SearchRadius.m500,
    ]);
    expect(verdict().isComparable, isTrue);
  });

  test('changing settings cancels a slot request in flight', () async {
    competitors.respond = null;
    assign(CompareSlot.a, siteA);
    final analyzing = controller().analyze(CompareSlot.a);
    final pending = competitors.pending.single;

    explore().selectCategory(BusinessCategory.bakery);
    await analyzing;

    expect(pending.isCompleted, isTrue); // cancelled
    expect(state().a.status, SlotStatus.pending);
    expect(state().a.analysis, isNull);
  });

  test('a late response cannot land in a cleared or replaced slot', () async {
    competitors.respond = null;
    competitors.ignoreCancel = true;
    assign(CompareSlot.a, siteA);
    final analyzing = controller().analyze(CompareSlot.a);

    assign(CompareSlot.a, siteB);
    competitors.pending.single.complete(resultFor(queryAt(siteA), []));
    await analyzing;

    expect(state().a.site!.latitude, siteB.lat);
    expect(state().a.status, SlotStatus.pending);
    expect(state().a.analysis, isNull);
  });

  test('cancel keeps the site and returns the slot to pending', () async {
    competitors.respond = null;
    assign(CompareSlot.a, siteA);
    final analyzing = controller().analyze(CompareSlot.a);
    controller().cancel(CompareSlot.a);
    await analyzing;

    expect(state().a.status, SlotStatus.pending);
    expect(state().a.site!.latitude, siteA.lat);
  });

  test('clear empties one slot only', () async {
    assign(CompareSlot.a, siteA);
    assign(CompareSlot.b, siteB);
    await controller().analyzeAll();
    controller().clear(CompareSlot.a);

    expect(state().a.status, SlotStatus.empty);
    expect(state().a.site, isNull);
    expect(state().b.status, SlotStatus.ready);
  });
}
