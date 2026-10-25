import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/comparison/domain/site_comparison.dart';
import 'package:pwestado/features/comparison/state/comparison_controller.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/saved/domain/saved_analysis.dart';

import '../fake_competitor_repository.dart';
import '../fake_site_context_repository.dart';
import 'comparison_fixtures.dart';

SavedAnalysis savedAt(
  ({double lat, double lon}) at, {
  SearchRadius radius = SearchRadius.km1,
  DateTime? when,
}) {
  final analysis = analysisAt(
    queryAt(at, radius: radius),
    fetchedAt: DateTime(2026, 10, 1, 9),
  );
  return SavedAnalysis(
    id: 1,
    savedAt: when ?? DateTime(2026, 10, 1, 10),
    site: SelectedSite.at(latitude: at.lat, longitude: at.lon),
    analysis: analysis,
    savedTotal: analysis.score.total,
  );
}

void main() {
  test('a saved slot adds a historical-data warning', () {
    final a = analysisAt(queryAt(siteA));
    final b = analysisAt(queryAt(siteB), businesses: const []);
    final fresh = compareSites(
      a: a,
      b: b,
      category: BusinessCategory.coffeeShop,
      radius: SearchRadius.km1,
      now: DateTime.now(),
    );
    final withSaved = compareSites(
      a: a,
      b: b,
      category: BusinessCategory.coffeeShop,
      radius: SearchRadius.km1,
      now: DateTime.now(),
      saved: {CompareSlot.a},
    );
    expect(fresh.warnings.where((w) => w.contains('historical')), isEmpty);
    expect(
      withSaved.warnings.where((w) => w.contains('First location is a saved')),
      hasLength(1),
    );
    expect(withSaved.isComparable, isTrue, reason: 'still comparable');
  });

  group('ComparisonController.loadSaved', () {
    late ProviderContainer container;
    late FakeCompetitorRepository competitors;

    setUp(() {
      competitors = FakeCompetitorRepository();
      container = ProviderContainer(
        overrides: [
          competitorRepositoryProvider.overrideWithValue(competitors),
          siteContextRepositoryProvider.overrideWithValue(
            FakeSiteContextRepository(respond: contextFor),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('stores the saved analysis without any request', () {
      final saved = savedAt(siteA);
      container
          .read(comparisonControllerProvider.notifier)
          .loadSaved(CompareSlot.a, saved);

      final slot = container.read(comparisonControllerProvider).a;
      expect(slot.status, SlotStatus.ready);
      expect(slot.isSaved, isTrue);
      expect(slot.savedAt, saved.savedAt);
      expect(identical(slot.analysis, saved.analysis), isTrue);
      expect(competitors.calls, isEmpty);
    });

    test('saved A and fresh B are ranked under the usual rules', () async {
      container
          .read(comparisonControllerProvider.notifier)
          .loadSaved(CompareSlot.a, savedAt(siteA));
      final controller = container.read(comparisonControllerProvider.notifier);
      container
          .read(exploreControllerProvider.notifier)
          .selectSite(latitude: siteB.lat, longitude: siteB.lon);
      competitors.respond = (q) => resultFor(q, const []);
      controller.assignCurrentSite(CompareSlot.b);
      await controller.analyze(CompareSlot.b);

      final comparison = container.read(siteComparisonProvider);
      expect(comparison.isComparable, isTrue);
      expect(comparison.higher, CompareSlot.b);
      expect(
        comparison.warnings.where((w) => w.contains('is a saved result')),
        hasLength(1),
      );
      expect(
        comparison.warnings.where((w) => w.contains('retrieved')),
        isNotEmpty,
        reason: 'old evidence is flagged as stale',
      );
    });

    test('a saved slot with other settings is not comparable', () {
      final controller = container.read(comparisonControllerProvider.notifier);
      controller.loadSaved(CompareSlot.a, savedAt(siteA));
      controller.loadSaved(
        CompareSlot.b,
        savedAt(siteB, radius: SearchRadius.km2),
      );

      final comparison = container.read(siteComparisonProvider);
      expect(comparison.isComparable, isFalse);
      expect(
        comparison.blockedBy(ComparisonBlockerKind.settingsMismatch),
        isTrue,
      );
    });

    test('a later main-screen analysis never overwrites a saved slot', () {
      final controller = container.read(comparisonControllerProvider.notifier);
      final saved = savedAt(siteA);
      controller.loadSaved(CompareSlot.a, saved);
      // Re-assigning the same pin keeps the saved snapshot.
      container
          .read(exploreControllerProvider.notifier)
          .selectSite(latitude: siteA.lat, longitude: siteA.lon);
      controller.assignCurrentSite(CompareSlot.a);

      final slot = container.read(comparisonControllerProvider).a;
      expect(identical(slot.analysis, saved.analysis), isTrue);
      expect(slot.isSaved, isTrue);
    });
  });
}
