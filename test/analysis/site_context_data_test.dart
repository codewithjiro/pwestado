import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/utils/geo.dart';
import 'package:pwestado/features/analysis/data/site_context_parser.dart';
import 'package:pwestado/features/analysis/data/site_context_query.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/discovery/data/overpass_client.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

const lat = 15.0939;
const lon = 120.7681;

const coffeeQuery = CompetitorQuery(
  latitude: lat,
  longitude: lon,
  category: BusinessCategory.coffeeShop,
  radius: SearchRadius.km1,
);

/// A horizontal road [northMeters] north of the site.
List<Map<String, double>> roadLine(double northMeters) {
  final dLat = northMeters / (earthRadiusMeters * 3.141592653589793 / 180);
  return [
    {'lat': lat + dLat, 'lon': lon - 0.001},
    {'lat': lat + dLat, 'lon': lon + 0.001},
  ];
}

/// Shaped like an `out center` + `out geom` Overpass response.
Map<String, Object?> contextResponse() => {
  'version': 0.6,
  'elements': [
    {
      'type': 'node',
      'id': 1,
      'lat': 15.0945,
      'lon': 120.7681,
      'tags': {'amenity': 'school', 'name': 'Elementary School'},
    },
    {
      'type': 'way',
      'id': 2,
      'center': {'lat': 15.0930, 'lon': 120.7690},
      'tags': {'amenity': 'school'},
    },
    {
      'type': 'node',
      'id': 3,
      'lat': 15.0950,
      'lon': 120.7700,
      'tags': {'shop': 'supermarket'},
    },
    {
      'type': 'node',
      'id': 5,
      'lat': 15.0920,
      'lon': 120.7670,
      'tags': {'shop': 'convenience'},
    },
    // Duplicate of node 1: counted once.
    {
      'type': 'node',
      'id': 1,
      'lat': 15.0945,
      'lon': 120.7681,
      'tags': {'amenity': 'school'},
    },
    // No coordinates: skipped, not counted.
    {
      'type': 'node',
      'id': 6,
      'tags': {'amenity': 'bank'},
    },
    {
      'type': 'way',
      'id': 10,
      'geometry': roadLine(30),
      'tags': {'highway': 'residential', 'name': 'Rizal Street'},
    },
    {
      'type': 'way',
      'id': 11,
      'geometry': roadLine(122),
      'tags': {'highway': 'primary'},
    },
    // Road without geometry: skipped.
    {
      'type': 'way',
      'id': 13,
      'tags': {'highway': 'service'},
    },
  ],
};

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object json, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  group('SiteContextQuery', () {
    test('is bounded and lists the disclosed complementary tags', () {
      final ql = SiteContextQuery.build(coffeeQuery);
      expect(ql, startsWith('[out:json][timeout:25];'));
      expect(
        ql,
        contains(
          'nwr(around:1000,15.093900,120.768100)["amenity"~"^(school|college|'
          'university|hospital|clinic|bank|marketplace|pharmacy|'
          'place_of_worship|townhall|bus_station)\$"];',
        ),
      );
      expect(
        ql,
        contains(
          '["shop"~"^(supermarket|mall|department_store|convenience)\$"]',
        ),
      );
      expect(ql, contains('way(around:150,15.093900,120.768100)["highway"~'));
      expect(ql, contains('.places out center 400;'));
      expect(ql, contains('.roads out geom 200;'));
    });

    test('excludes the selected business tag from complements', () {
      final ql = SiteContextQuery.build(
        const CompetitorQuery(
          latitude: lat,
          longitude: lon,
          category: BusinessCategory.convenience,
          radius: SearchRadius.m500,
        ),
      );
      expect(ql, contains('"shop"~"^(supermarket|mall|department_store)\$"'));
      expect(ql, isNot(contains('convenience')));
    });

    test('rejects invalid coordinates', () {
      expect(
        () => SiteContextQuery.build(
          const CompetitorQuery(
            latitude: 95,
            longitude: lon,
            category: BusinessCategory.coffeeShop,
            radius: SearchRadius.km1,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('parseSiteContextResponse', () {
    test('splits places and roads, de-duplicates, and counts skips', () {
      final parsed = parseSiteContextResponse(
        contextResponse(),
        originLatitude: lat,
        originLongitude: lon,
        category: BusinessCategory.coffeeShop,
        radiusMeters: 1000,
      );
      expect(parsed.complementary.count, 4);
      expect(parsed.complementary.countsByKind, {
        'school': 2,
        'supermarket': 1,
        'convenience': 1,
      });
      expect(parsed.complementary.possiblyTruncated, isFalse);
      expect(parsed.skippedCount, 2);

      expect(parsed.roads.roadCount, 2);
      expect(parsed.roads.nearestRoadMeters, closeTo(30, 0.5));
      expect(parsed.roads.nearestRoadKind, 'residential');
      expect(parsed.roads.nearestRoadName, 'Rizal Street');
      expect(parsed.roads.nearestMajorRoadMeters, closeTo(122, 0.5));
    });

    test('never counts a same-category business as a complement', () {
      final parsed = parseSiteContextResponse(
        contextResponse(),
        originLatitude: lat,
        originLongitude: lon,
        category: BusinessCategory.convenience,
        radiusMeters: 1000,
      );
      expect(parsed.complementary.count, 3);
      expect(
        parsed.complementary.countsByKind.containsKey('convenience'),
        isFalse,
      );
    });

    test('an empty response is valid zero evidence', () {
      final parsed = parseSiteContextResponse(
        {'elements': <Object>[]},
        originLatitude: lat,
        originLongitude: lon,
        category: BusinessCategory.coffeeShop,
        radiusMeters: 1000,
      );
      expect(parsed.complementary.count, 0);
      expect(parsed.roads.roadCount, 0);
      expect(parsed.roads.nearestRoadMeters, isNull);
    });

    test('rejects a non-Overpass payload', () {
      expect(
        () => parseSiteContextResponse(
          'nope',
          originLatitude: lat,
          originLongitude: lon,
          category: BusinessCategory.coffeeShop,
          radiusMeters: 1000,
        ),
        throwsFormatException,
      );
    });
  });

  group('OverpassSiteContextRepository', () {
    late FakeAdapter adapter;
    late DateTime now;
    late OverpassSiteContextRepository repo;

    setUp(() {
      now = DateTime(2026, 10, 22, 10);
      adapter = FakeAdapter((_) => jsonBody(contextResponse()));
      repo = OverpassSiteContextRepository(
        client: OverpassClient(
          dio: createOverpassDio()..httpClientAdapter = adapter,
          retryDelay: Duration.zero,
        ),
        clock: () => now,
      );
    });

    test('POSTs one bounded query and keeps source metadata', () async {
      final result = await repo.fetch(coffeeQuery);
      expect(adapter.requests, hasLength(1));
      final ql = (adapter.requests.single.data as Map)['data'] as String;
      expect(ql, contains('way(around:150,'));
      expect(result.source, DataSource.live);
      expect(result.fetchedAt, now);
      expect(result.query, coffeeQuery);
      expect(result.complementary.count, 4);
      expect(result.skippedCount, 2);
    });

    test('reuses a fresh response, labeled cached', () async {
      await repo.fetch(coffeeQuery);
      now = now.add(const Duration(minutes: 5));
      final again = await repo.fetch(coffeeQuery);
      expect(adapter.requests, hasLength(1));
      expect(again.source, DataSource.cached);
      expect(again.fetchedAt, DateTime(2026, 10, 22, 10));
    });

    test('an HTTP 429 is a failure, not an empty result', () async {
      adapter.handler = (_) => jsonBody({'error': 'busy'}, status: 429);
      await expectLater(
        repo.fetch(coffeeQuery),
        throwsA(
          isA<CompetitorFetchException>().having(
            (e) => e.failure,
            'failure',
            CompetitorFailure.rateLimited,
          ),
        ),
      );
    });

    test('a server runtime error remark is a failure', () async {
      adapter.handler = (_) => jsonBody({
        'elements': <Object>[],
        'remark': 'runtime error: Query timed out in "query" at line 1',
      });
      await expectLater(
        repo.fetch(coffeeQuery),
        throwsA(
          isA<CompetitorFetchException>().having(
            (e) => e.failure,
            'failure',
            CompetitorFailure.timeout,
          ),
        ),
      );
    });
  });

  test('distanceToPolylineMeters measures to the line, not its ends', () {
    // Endpoints are ~108 m east/west, but the line passes ~30 m north.
    final d = distanceToPolylineMeters(lat, lon, [
      for (final p in roadLine(30)) (p['lat']!, p['lon']!),
    ]);
    expect(d, closeTo(30, 0.5));
    expect(distanceToPolylineMeters(lat, lon, const []), isNull);
  });
}
