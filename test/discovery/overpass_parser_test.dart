import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/utils/geo.dart';
import 'package:pwestado/features/discovery/data/overpass_parser.dart';
import 'package:pwestado/features/discovery/data/overpass_query.dart';
import 'package:pwestado/features/discovery/data/sample_competitors.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

const _originLat = 15.0939;
const _originLon = 120.7681;

Object? _fixture() =>
    jsonDecode(File('test/fixtures/overpass_cafes.json').readAsStringSync());

OverpassParseResult _parse(Object? json) => parseOverpassResponse(
  json,
  originLatitude: _originLat,
  originLongitude: _originLon,
);

void main() {
  group('parseOverpassResponse', () {
    late OverpassParseResult parsed;
    setUp(() => parsed = _parse(_fixture()));

    test('reads node lat/lon and way/relation centers', () {
      final byKey = {for (final b in parsed.businesses) b.key: b};
      expect(byKey.keys, {
        'node:1001',
        'node:1002',
        'way:5001',
        'relation:9001',
      });
      expect(byKey['node:1001']!.latitude, 15.0941);
      expect(byKey['way:5001']!.latitude, 15.0960);
      expect(byKey['way:5001']!.longitude, 120.7690);
      expect(byKey['relation:9001']!.latitude, 15.0900);
    });

    test('de-duplicates by type and id, keeping the first record', () {
      final corner = parsed.businesses.where((b) => b.key == 'node:1001');
      expect(corner, hasLength(1));
      expect(corner.single.name, 'Corner Brew');
    });

    test('skips records without valid coordinates or identity', () {
      // way 5002 (no center), node 1003 (lat 95), "bad-id", type "area".
      expect(parsed.skippedCount, 4);
      expect(parsed.elementCount, 9);
    });

    test('keeps unnamed records unnamed instead of inventing a name', () {
      final unnamed = parsed.businesses.singleWhere(
        (b) => b.key == 'node:1002',
      );
      expect(unnamed.name, isNull);
      expect(unnamed.displayName, NearbyBusiness.unnamedLabel);
      expect(unnamed.displayName, 'Unnamed mapped business');
    });

    test('falls back to name:en, and trims names', () {
      final byKey = {for (final b in parsed.businesses) b.key: b};
      expect(byKey['relation:9001']!.name, 'Relation Cafe');
      expect(byKey['node:1001']!.name, 'Corner Brew');
    });

    test('sorts nearest first with real distances', () {
      final distances = parsed.businesses.map((b) => b.distanceMeters);
      expect(distances, orderedEquals([...distances]..sort()));
      expect(parsed.businesses.first.key, 'node:1001');
      // 0.0061 deg of latitude north is about 678 m.
      final north = parsed.businesses.singleWhere((b) => b.key == 'node:1002');
      expect(north.distanceMeters, closeTo(678, 3));
    });

    test('extracts only details present in the record', () {
      final corner = parsed.businesses.first;
      expect(corner.details, {
        'Address': 'Rizal Street, Santa Ana',
        'Cuisine': 'coffee shop, cake',
        'Phone': '+63 900 000 0000',
      });
      final way = parsed.businesses.singleWhere((b) => b.key == 'way:5001');
      expect(way.details, {'Opening hours': 'Mo-Su 07:00-21:00'});
      expect(way.osmUrl, 'https://www.openstreetmap.org/way/5001');
    });

    test('an empty element list is a valid, empty result', () {
      final empty = _parse({'elements': <Object>[]});
      expect(empty.businesses, isEmpty);
      expect(empty.skippedCount, 0);
      expect(empty.hasRuntimeError, isFalse);
    });

    test('flags Overpass runtime-error remarks', () {
      final result = _parse({
        'elements': <Object>[],
        'remark':
            'runtime error: Query timed out in "query" at line 1 after 26 '
            'seconds.',
      });
      expect(result.hasRuntimeError, isTrue);
    });

    test('rejects payloads that are not Overpass responses', () {
      expect(() => _parse('<html>busy</html>'), throwsFormatException);
      expect(() => _parse({'foo': 1}), throwsFormatException);
      expect(() => _parse(null), throwsFormatException);
    });
  });

  group('OverpassQuery', () {
    CompetitorQuery query({
      double lat = _originLat,
      double lon = _originLon,
      BusinessCategory category = BusinessCategory.coffeeShop,
      SearchRadius radius = SearchRadius.km1,
    }) => CompetitorQuery(
      latitude: lat,
      longitude: lon,
      category: category,
      radius: radius,
    );

    test('builds a bounded nwr around query with out center', () {
      expect(
        OverpassQuery.competitors(query()),
        '[out:json][timeout:25];'
        'nwr(around:1000,15.093900,120.768100)["amenity"="cafe"];'
        'out center 500;',
      );
    });

    test('uses the selected category tag and radius', () {
      final ql = OverpassQuery.competitors(
        query(category: BusinessCategory.laundry, radius: SearchRadius.km2),
      );
      expect(ql, contains('nwr(around:2000,'));
      expect(ql, contains('["shop"="laundry"]'));
    });

    test('every supported category produces a valid query', () {
      for (final category in BusinessCategory.all) {
        expect(
          () => OverpassQuery.competitors(query(category: category)),
          returnsNormally,
        );
      }
    });

    test('rejects tags that could inject Overpass QL', () {
      const evil = BusinessCategory(
        id: 'evil',
        label: 'Evil',
        osmTagKey: 'amenity',
        osmTagValue: 'cafe"];out;node(1',
        icon: Icons.store,
      );
      expect(
        () => OverpassQuery.competitors(query(category: evil)),
        throwsArgumentError,
      );
    });

    test('rejects invalid coordinates', () {
      expect(
        () => OverpassQuery.competitors(query(lat: double.nan)),
        throwsArgumentError,
      );
      expect(
        () => OverpassQuery.competitors(query(lon: 200)),
        throwsArgumentError,
      );
    });
  });

  group('CompetitorQuery cache key', () {
    test('equal for the same site to ~1 m, category and radius', () {
      const a = CompetitorQuery(
        latitude: 15.093901,
        longitude: 120.768101,
        category: BusinessCategory.coffeeShop,
        radius: SearchRadius.km1,
      );
      const b = CompetitorQuery(
        latitude: 15.093899,
        longitude: 120.768099,
        category: BusinessCategory.coffeeShop,
        radius: SearchRadius.km1,
      );
      expect(a, b);
      expect(
        a,
        isNot(
          const CompetitorQuery(
            latitude: 15.093901,
            longitude: 120.768101,
            category: BusinessCategory.bakery,
            radius: SearchRadius.km1,
          ),
        ),
      );
    });
  });

  group('SampleCompetitors', () {
    const query = CompetitorQuery(
      latitude: _originLat,
      longitude: _originLon,
      category: BusinessCategory.coffeeShop,
      radius: SearchRadius.km1,
    );

    test('is labeled as sample everywhere', () {
      final result = SampleCompetitors.forQuery(query, DateTime(2026));
      expect(result.source, DataSource.sample);
      expect(result.businesses, isNotEmpty);
      for (final b in result.businesses) {
        expect(b.isSample, isTrue);
        expect(b.osmUrl, isNull);
        expect(b.name, contains('Sample'));
        expect(b.name, contains('(demo)'));
      }
    });

    test('is deterministic and respects the radius', () {
      final a = SampleCompetitors.forQuery(query, DateTime(2026));
      final b = SampleCompetitors.forQuery(query, DateTime(2027));
      expect(
        a.businesses.map((x) => (x.latitude, x.longitude)),
        b.businesses.map((x) => (x.latitude, x.longitude)),
      );
      for (final x in a.businesses) {
        expect(x.distanceMeters, lessThanOrEqualTo(1000));
      }
      final wider = SampleCompetitors.forQuery(
        const CompetitorQuery(
          latitude: _originLat,
          longitude: _originLon,
          category: BusinessCategory.coffeeShop,
          radius: SearchRadius.km2,
        ),
        DateTime(2026),
      );
      expect(wider.count, greaterThan(a.count));
    });
  });

  group('geo helpers', () {
    test('destinationPoint and distanceMeters agree', () {
      final (lat, lon) = destinationPoint(_originLat, _originLon, 73, 1234);
      expect(
        distanceMeters(_originLat, _originLon, lat, lon),
        closeTo(1234, 1),
      );
    });

    test('formatDistance rounds honestly', () {
      expect(formatDistance(3), '<10 m');
      expect(formatDistance(84), '80 m');
      expect(formatDistance(994), '990 m');
      expect(formatDistance(1249), '1.2 km');
    });
  });
}
