import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/analysis/domain/site_analysis.dart';
import 'package:pwestado/features/comparison/domain/site_comparison.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

import '../fake_competitor_repository.dart';
import '../fake_site_context_repository.dart';
import 'comparison_fixtures.dart';

void main() {
  final now = DateTime.now();

  SiteComparison compare(
    SiteAnalysis? a,
    SiteAnalysis? b, {
    BusinessCategory category = BusinessCategory.coffeeShop,
    SearchRadius radius = SearchRadius.km1,
  }) => compareSites(a: a, b: b, category: category, radius: radius, now: now);

  group('ranking', () {
    test('ranks the higher total when both are comparable', () {
      // A: 3 competitors -> 63.6; B: none -> 73.6.
      final a = analysisAt(queryAt(siteA));
      final b = analysisAt(queryAt(siteB), businesses: const []);
      expect(a.score.total, 63.6);
      expect(b.score.total, 73.6);

      final result = compare(a, b);
      expect(result.isComparable, isTrue);
      expect(result.higher, CompareSlot.b);
      expect(result.difference, -10);
      expect(result.sampleOnly, isFalse);
    });

    test('is deterministic and symmetric when A and B swap', () {
      final a = analysisAt(queryAt(siteA));
      final b = analysisAt(queryAt(siteB), businesses: const []);
      expect(compare(a, b).higher, compare(a, b).higher);
      expect(compare(b, a).higher, CompareSlot.a);
      expect(compare(b, a).difference, 10);
    });

    test('scores within 5 points are reported as similar, not ranked', () {
      // B: one far competitor -> 95 -> 71.6 vs 73.6.
      final a = analysisAt(queryAt(siteA), businesses: const []);
      final b = analysisAt(
        queryAt(siteB),
        businesses: [business(9, distance: 600)],
      );
      expect(b.score.total, 71.6);

      final result = compare(a, b);
      expect(result.isComparable, isTrue);
      expect(result.isSimilar, isTrue);
      expect(result.higher, isNull);
      expect(result.difference, 2);
    });

    test('live and cached OpenStreetMap evidence are comparable', () {
      final a = analysisAt(queryAt(siteA), source: DataSource.cached);
      final b = analysisAt(queryAt(siteB), businesses: const []);
      expect(compare(a, b).isComparable, isTrue);
    });

    test('two sample analyses compare only as a labeled demo', () {
      final a = analysisAt(queryAt(siteA), source: DataSource.sample);
      final b = analysisAt(
        queryAt(siteB),
        businesses: const [],
        source: DataSource.sample,
      );
      final result = compare(a, b);
      expect(result.isComparable, isTrue);
      expect(result.sampleOnly, isTrue);
    });
  });

  group('rejects invalid comparisons', () {
    test('a missing analysis is never ranked', () {
      final result = compare(analysisAt(queryAt(siteA)), null);
      expect(result.isComparable, isFalse);
      expect(result.higher, isNull);
      expect(result.blockedBy(ComparisonBlockerKind.missingAnalysis), isTrue);
      expect(result.blockers.single.message, contains('Second location'));
    });

    test('the same location twice is rejected', () {
      final a = analysisAt(queryAt(siteA));
      // About 11 m north of A.
      final b = analysisAt(
        queryAt((lat: siteA.lat + 0.0001, lon: siteA.lon)),
        businesses: const [],
      );
      final result = compare(a, b);
      expect(result.blockedBy(ComparisonBlockerKind.sameSite), isTrue);
      expect(result.higher, isNull);
    });

    test('different categories between A and B are rejected', () {
      final a = analysisAt(queryAt(siteA));
      final b = analysisAt(
        queryAt(siteB, category: BusinessCategory.bakery),
        businesses: const [],
      );
      final result = compare(a, b);
      expect(result.blockedBy(ComparisonBlockerKind.settingsMismatch), isTrue);
      expect(result.blockedBy(ComparisonBlockerKind.settingsChanged), isTrue);
      expect(result.higher, isNull);
    });

    test('different radii between A and B are rejected', () {
      final a = analysisAt(queryAt(siteA, radius: SearchRadius.m500));
      final b = analysisAt(queryAt(siteB), businesses: const []);
      final result = compare(a, b);
      expect(result.blockedBy(ComparisonBlockerKind.settingsMismatch), isTrue);
      expect(result.higher, isNull);
    });

    test('analyses made before a settings change are rejected', () {
      final a = analysisAt(queryAt(siteA));
      final b = analysisAt(queryAt(siteB), businesses: const []);
      final result = compare(a, b, radius: SearchRadius.km2);
      expect(result.blockedBy(ComparisonBlockerKind.settingsMismatch), isFalse);
      expect(result.blockedBy(ComparisonBlockerKind.settingsChanged), isTrue);
      expect(
        result.blockers.single.message,
        contains('Check both locations again'),
      );
      expect(result.higher, isNull);
    });

    test('mixed sample and live evidence is rejected', () {
      final a = analysisAt(queryAt(siteA), source: DataSource.sample);
      final b = analysisAt(queryAt(siteB), businesses: const []);
      final result = compare(a, b);
      expect(result.blockedBy(ComparisonBlockerKind.mixedSources), isTrue);
      expect(result.blockers.single.message, contains('SAMPLE DEMO DATA'));
      expect(result.higher, isNull);
    });

    test('sample context mixed into a live site counts as sample', () {
      final a = analysisAt(queryAt(siteA), contextSource: DataSource.sample);
      final b = analysisAt(queryAt(siteB), businesses: const []);
      expect(
        compare(a, b).blockedBy(ComparisonBlockerKind.mixedSources),
        isTrue,
      );
    });

    test('insufficient data on either site is never ranked', () {
      final a = analysisAt(queryAt(siteA), contextFailed: true);
      final b = analysisAt(queryAt(siteB), businesses: const []);
      expect(a.score.total, isNull);

      final result = compare(a, b);
      expect(result.blockedBy(ComparisonBlockerKind.insufficientData), isTrue);
      expect(result.blockers.single.message, contains('First location'));
      expect(result.higher, isNull);
      expect(result.difference, isNull);
    });
  });

  group('warnings', () {
    test('old evidence is flagged without blocking', () {
      final a = analysisAt(
        queryAt(siteA),
        fetchedAt: now.subtract(const Duration(minutes: 40)),
      );
      final b = analysisAt(queryAt(siteB), businesses: const []);
      final result = compare(a, b);
      expect(result.isComparable, isTrue);
      expect(
        result.warnings.single,
        contains('Map data for the first location'),
      );
      expect(result.warnings.single, contains('40 min ago'));
    });

    test('sparse coverage is flagged as low confidence', () {
      final a = analysisAt(queryAt(siteA), businesses: const []);
      final query = queryAt(siteB);
      final b = SiteAnalysis.from(
        competitors: resultFor(query, const []),
        context: contextFor(query, complementary: 0),
      );
      expect(b.score.lowConfidence, isTrue);
      expect(
        compare(a, b).warnings.single,
        contains('may not be listed on the map'),
      );
    });
  });
}
