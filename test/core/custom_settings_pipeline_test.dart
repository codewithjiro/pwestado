import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/ai/data/ai_payload.dart';
import 'package:pwestado/features/ai/data/gemini_request.dart';
import 'package:pwestado/features/analysis/data/site_context_query.dart';
import 'package:pwestado/features/analysis/domain/site_context.dart';
import 'package:pwestado/features/analysis/domain/suitability_scoring.dart';
import 'package:pwestado/features/comparison/domain/site_comparison.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/data/overpass_parser.dart';
import 'package:pwestado/features/discovery/data/overpass_query.dart';
import 'package:pwestado/features/discovery/data/sample_competitors.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/saved/data/saved_analysis_codec.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../comparison/comparison_fixtures.dart';
import '../discovery/competitor_repository_test.dart'
    show FakeAdapter, jsonBody;

final custom750 = SearchRadius.meters(750);

/// An evidence row exactly as the first SQLite release (839f1ac..51a6777)
/// wrote it: v1 layout, an original category id and a preset radius.
Map<String, Object?> previousReleaseRow({
  required int id,
  required String categoryId,
  required int radiusMeters,
}) {
  final evidence = {
    'v': 1,
    'site': {
      'latitude': 15.0939,
      'longitude': 120.7681,
      'source': 'mapPick',
      'accuracyMeters': null,
    },
    'query': {
      'latitude': 15.0939,
      'longitude': 120.7681,
      'category': categoryId,
      'radiusMeters': radiusMeters,
    },
    'competitors': {
      'source': 'live',
      'fetchedAt': DateTime(2026, 10, 22, 9).millisecondsSinceEpoch,
      'skippedCount': 0,
      'possiblyTruncated': false,
      'businesses': [
        {
          'osmType': 'node',
          'osmId': 1,
          'name': 'Kape Way',
          'latitude': 15.0940,
          'longitude': 120.7681,
          'distanceMeters': 100.0,
          'details': {'Opening hours': 'Mo-Su 07:00-21:00'},
        },
      ],
    },
    'context': {
      'source': 'live',
      'fetchedAt': DateTime(2026, 10, 22, 9).millisecondsSinceEpoch,
      'skippedCount': 0,
      'complementary': {
        'count': 6,
        'radiusMeters': radiusMeters,
        'countsByKind': {'school': 6},
        'possiblyTruncated': false,
      },
      'roads': {
        'roadCount': 2,
        'nearestRoadMeters': 30.0,
        'nearestRoadKind': 'residential',
        'nearestRoadName': null,
        'nearestMajorRoadMeters': 120.0,
      },
    },
    'contextFailure': null,
    'contextStatusCode': null,
  };
  return {
    SavedColumns.id: id,
    SavedColumns.savedAt: DateTime(2026, 10, 22, 10).millisecondsSinceEpoch,
    SavedColumns.latitude: 15.0939,
    SavedColumns.longitude: 120.7681,
    SavedColumns.siteLabel: 'Pinned site',
    SavedColumns.categoryId: categoryId,
    SavedColumns.radiusMeters: radiusMeters,
    SavedColumns.dataSource: 'live',
    SavedColumns.totalScore: 0.0,
    SavedColumns.retrievedAt: DateTime(2026, 10, 22, 9).millisecondsSinceEpoch,
    SavedColumns.evidence: jsonEncode(evidence),
  };
}

void main() {
  group('Overpass queries', () {
    test('competitor search uses custom meters and new tag keys', () {
      final gym = OverpassQuery.competitors(
        queryAt(siteA, category: BusinessCategory.gym, radius: custom750),
      );
      expect(gym, contains('nwr(around:750,'));
      expect(gym, contains('["leisure"="fitness_centre"]'));

      final repair = OverpassQuery.competitors(
        queryAt(siteA, category: BusinessCategory.electronicsRepair),
      );
      expect(repair, contains('["craft"="electronics_repair"]'));
    });

    test('every catalog category and preset builds both queries', () {
      for (final category in BusinessCategory.all) {
        for (final radius in [...SearchRadius.presets, custom750]) {
          final q = queryAt(siteA, category: category, radius: radius);
          expect(
            OverpassQuery.competitors(q),
            contains('around:${radius.meters},'),
          );
          expect(
            SiteContextQuery.build(q),
            contains('around:${radius.meters},'),
          );
        }
      }
    });

    test('a tag key outside the allowlist is refused', () {
      const odd = BusinessCategory(
        id: 'odd',
        label: 'Odd',
        osmTagKey: 'building',
        osmTagValue: 'yes',
        icon: Icons.store,
        group: BusinessGroup.services,
        description: 'test',
      );
      expect(
        () => OverpassQuery.competitors(queryAt(siteA, category: odd)),
        throwsArgumentError,
      );
    });

    test('context query never counts the chosen category as a complement', () {
      final pharmacy = SiteContextQuery.build(
        queryAt(siteA, category: BusinessCategory.pharmacy),
      );
      expect(pharmacy, isNot(contains('pharmacy')));
      final cafe = SiteContextQuery.build(queryAt(siteA));
      expect(cafe, contains('pharmacy'));
    });

    test('barber sub-tag is shown as a detail', () {
      final parsed = parseOverpassResponse(
        {
          'elements': [
            {
              'type': 'node',
              'id': 7,
              'lat': 15.0940,
              'lon': 120.7681,
              'tags': {'shop': 'hairdresser', 'hairdresser': 'barber'},
            },
          ],
        },
        originLatitude: siteA.lat,
        originLongitude: siteA.lon,
      );
      expect(parsed.businesses.single.details['Hair service'], 'barber');
    });
  });

  group('query identity', () {
    test('custom 1000 m and the 1 km preset are one cache entry', () async {
      final adapter = FakeAdapter((_) async => jsonBody({'elements': []}));
      final repo = OverpassCompetitorRepository(
        dio: createOverpassDio()..httpClientAdapter = adapter,
        retryDelay: Duration.zero,
      );
      final preset = queryAt(siteA, radius: SearchRadius.km1);
      final custom = queryAt(siteA, radius: SearchRadius.meters(1000));
      expect(custom, preset);
      expect(custom.cacheKey, preset.cacheKey);

      await repo.fetch(preset);
      await repo.fetch(custom);
      expect(adapter.requests, hasLength(1));

      await repo.fetch(queryAt(siteA, radius: custom750));
      await repo.fetch(queryAt(siteA, category: BusinessCategory.barbershop));
      expect(adapter.requests, hasLength(3));
    });
  });

  group('scoring across radii', () {
    test('complementary target scales with any radius', () {
      expect(SuitabilityRules.complementarySaturation(100), 5);
      expect(SuitabilityRules.complementarySaturation(250), 13);
      expect(SuitabilityRules.complementarySaturation(750), 38);
      expect(SuitabilityRules.complementarySaturation(1500), 75);
      expect(SuitabilityRules.complementarySaturation(2000), 100);
    });

    test('the 40/30/30 formula is unchanged for a custom radius', () {
      final score = scoreSuitability(
        const ScoringInput(
          competitors: CompetitorEvidence(
            distancesMeters: [100, 600],
            radiusMeters: 750,
          ),
          complementary: ComplementaryEvidence(count: 19, radiusMeters: 750),
          roads: RoadEvidence(
            roadCount: 1,
            nearestRoadMeters: 30,
            nearestMajorRoadMeters: 120,
          ),
        ),
      );
      // Weighted 1.5 -> 85; 19/38 -> 50; road 60 + 40 -> 100.
      expect(score.criteria.map((c) => c.score), [85, 50, 100]);
      expect(score.total, 79, reason: '0.4 × 85 + 0.3 × 50 + 0.3 × 100');
      expect(score.criteria.first.evidence, contains('within 750 m'));
      expect(score.criteria[1].rule, contains('N = 38 here'));
    });

    test('a small radius is disclosed, without changing the score', () {
      ScoringInput at(int meters) => ScoringInput(
        competitors: CompetitorEvidence(
          distancesMeters: const [100],
          radiusMeters: meters,
        ),
        complementary: ComplementaryEvidence(count: 6, radiusMeters: meters),
        roads: const RoadEvidence(roadCount: 1, nearestRoadMeters: 30),
      );
      final small = scoreSuitability(at(250));
      expect(
        small.warnings.where((w) => w.contains('search distance of 250 m')),
        hasLength(1),
      );
      expect(small.lowConfidence, isFalse);
      final normal = scoreSuitability(at(500));
      expect(
        normal.warnings.any((w) => w.contains('search distance')),
        isFalse,
      );
    });

    test('sample data respects a small custom radius', () {
      final result = SampleCompetitors.forQuery(
        queryAt(siteA, radius: SearchRadius.meters(400)),
        DateTime(2026),
      );
      expect(result.businesses.every((b) => b.distanceMeters <= 400), isTrue);
      expect(result.businesses, hasLength(2));
      expect(result.source, DataSource.sample);
    });
  });

  group('comparison settings parity', () {
    SiteComparison compare(
      CompetitorQuery qa,
      CompetitorQuery qb, {
      required BusinessCategory category,
      required SearchRadius radius,
    }) => compareSites(
      a: analysisAt(qa),
      b: analysisAt(qb, businesses: const []),
      category: category,
      radius: radius,
      now: DateTime.now(),
    );

    test('same custom radius and new category compare normally', () {
      final result = compare(
        queryAt(
          siteA,
          category: BusinessCategory.barbershop,
          radius: custom750,
        ),
        queryAt(
          siteB,
          category: BusinessCategory.barbershop,
          radius: custom750,
        ),
        category: BusinessCategory.barbershop,
        radius: SearchRadius.meters(750),
      );
      expect(result.isComparable, isTrue);
      expect(result.blockers, isEmpty);
    });

    test('custom 1000 m matches the 1 km preset', () {
      final result = compare(
        queryAt(siteA, radius: SearchRadius.meters(1000)),
        queryAt(siteB, radius: SearchRadius.km1),
        category: BusinessCategory.coffeeShop,
        radius: SearchRadius.km1,
      );
      expect(result.isComparable, isTrue);
    });

    test('750 m against 1 km is a settings mismatch', () {
      final result = compare(
        queryAt(siteA, radius: custom750),
        queryAt(siteB, radius: SearchRadius.km1),
        category: BusinessCategory.coffeeShop,
        radius: custom750,
      );
      expect(result.blockedBy(ComparisonBlockerKind.settingsMismatch), isTrue);
      expect(result.higher, isNull);
    });
  });

  group('saved analyses compatibility', () {
    test('records from the previous release still decode', () {
      for (final (i, id) in [
        'coffee_shop',
        'restaurant',
        'convenience',
        'laundry',
        'bakery',
      ].indexed) {
        for (final meters in [500, 1000, 2000]) {
          final row = previousReleaseRow(
            id: i * 10 + meters,
            categoryId: id,
            radiusMeters: meters,
          );
          final summary = SavedAnalysisCodec.summaryFromRow(row);
          expect(summary.isReadable, isTrue, reason: '$id $meters');
          expect(summary.category!.id, id);
          expect(summary.radius, SearchRadius.meters(meters));
          expect(summary.radius!.isPreset, isTrue);

          final saved = SavedAnalysisCodec.fromRow(row);
          final query = saved.analysis.competitors.query;
          expect(query.category.id, id);
          expect(query.radius.meters, meters);
          expect(saved.analysis.competitors.businesses.single.name, 'Kape Way');
          expect(saved.analysis.score.hasTotal, isTrue);
          expect(saved.site.source, SiteSource.mapPick);
        }
      }
    });

    test('new categories and custom radii round-trip', () {
      final site = SelectedSite.at(latitude: siteA.lat, longitude: siteA.lon);
      final analysis = analysisAt(
        queryAt(
          siteA,
          category: BusinessCategory.barbershop,
          radius: custom750,
        ),
      );
      final row = SavedAnalysisCodec.toRow(
        site,
        analysis,
        DateTime(2026, 10, 24),
      )..[SavedColumns.id] = 3;
      expect(row[SavedColumns.categoryId], 'barbershop_hairdresser');
      expect(row[SavedColumns.radiusMeters], 750);

      final summary = SavedAnalysisCodec.summaryFromRow(row);
      expect(summary.category, BusinessCategory.barbershop);
      expect(summary.radius!.label, '750 m');
      final saved = SavedAnalysisCodec.fromRow(row);
      expect(saved.analysis.competitors.query.radius, custom750);
      expect(saved.scoreMatchesSaved, isTrue);
    });

    test('out-of-range or unknown settings are reported, not guessed', () {
      final badRadius = previousReleaseRow(
        id: 1,
        categoryId: 'coffee_shop',
        radiusMeters: 5000,
      );
      expect(SavedAnalysisCodec.summaryFromRow(badRadius).isReadable, isFalse);
      final badCategory = previousReleaseRow(
        id: 2,
        categoryId: 'karaoke_bar',
        radiusMeters: 1000,
      );
      expect(
        SavedAnalysisCodec.summaryFromRow(badCategory).isReadable,
        isFalse,
      );
    });

    test('a previous-release database file opens and reopens', () async {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('pwestado_compat');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}saved.db';
      final repo = SqliteSavedAnalysisRepository(
        factory: databaseFactoryFfiNoIsolate,
        path: () async => path,
      );
      // restore() writes a raw row as-is, like an existing install.
      await repo.restore(
        previousReleaseRow(id: 7, categoryId: 'bakery', radiusMeters: 500),
      );
      final summaries = await repo.list();
      expect(summaries.single.category, BusinessCategory.bakery);
      expect(summaries.single.radius, SearchRadius.m500);
      final loaded = await repo.load(7);
      expect(loaded.analysis.competitors.query.radius.label, '500 m');
      await repo.close();
    });
  });

  group('AI Insights payload', () {
    test('carries the new category, its note and the custom radius', () {
      final analysis = analysisAt(
        queryAt(
          siteA,
          category: BusinessCategory.barbershop,
          radius: custom750,
        ),
      );
      final site = (AiPayload.site(analysis)['sites'] as List).single as Map;
      expect(site['businessType'], 'Barbershop / Hairdresser');
      expect(
        site['businessTypeIncludes'],
        BusinessCategory.barbershop.description,
      );
      expect(site['businessTypeNote'], contains('barbershops and hair salons'));
      expect(site['radiusMeters'], 750);
      expect(site['radiusLabel'], '750 m');
      expect(site['warnings'], isNot(contains('small_search_radius')));

      final body = GeminiRequest.build(AiPayload.site(analysis));
      final text = jsonEncode(body);
      expect(text, contains('Barbershop / Hairdresser'));
      expect(text, contains(r'\"radiusMeters\":750'));
    });

    test('categories without a note omit it; small radii are flagged', () {
      final analysis = analysisAt(
        queryAt(
          siteA,
          category: BusinessCategory.pharmacy,
          radius: SearchRadius.m250,
        ),
      );
      final site = (AiPayload.site(analysis)['sites'] as List).single as Map;
      expect(site.containsKey('businessTypeNote'), isFalse);
      expect(site['warnings'], contains('small_search_radius'));
    });

    test('compare payload keeps both sites on the same custom settings', () {
      final a = analysisAt(queryAt(siteA, radius: custom750));
      final b = analysisAt(
        queryAt(siteB, radius: custom750),
        businesses: const [],
      );
      final payload = AiPayload.comparison(a: a, b: b);
      final sites = payload['sites'] as List;
      expect(sites.map((s) => (s as Map)['radiusMeters']), [750, 750]);
      expect(() => GeminiRequest.build(payload), returnsNormally);
    });

    test(
      'the system instruction tells Gemini to use the settings as given',
      () {
        expect(GeminiRequest.systemInstruction, contains('radiusLabel'));
        expect(GeminiRequest.systemInstruction, contains('businessTypeNote'));
        expect(
          GeminiRequest.systemInstruction,
          contains('small_search_radius'),
        );
      },
    );
  });

  test('sample context uses the custom radius', () {
    final ctx = SampleSiteContext.forQuery(
      queryAt(siteA, radius: custom750),
      DateTime(2026),
    );
    expect(ctx.complementary.radiusMeters, 750);
  });
}
