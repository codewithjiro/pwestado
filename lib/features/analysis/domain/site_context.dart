import 'package:flutter/foundation.dart';

import '../../../core/models/business_category.dart';
import '../../discovery/domain/competitors.dart';
import 'suitability_scoring.dart';

/// The fixed, disclosed list of OSM tags counted as complementary
/// establishments: places that tend to bring people to an area. The
/// selected business's own tag is always excluded, so a competitor is never
/// counted as a complement.
abstract final class ComplementaryTags {
  static const amenity = [
    'school',
    'college',
    'university',
    'hospital',
    'clinic',
    'bank',
    'marketplace',
    'pharmacy',
    'place_of_worship',
    'townhall',
    'bus_station',
  ];

  static const shop = [
    'supermarket',
    'mall',
    'department_store',
    'convenience',
  ];

  /// `(key, value)` pairs used for [category].
  static List<(String, String)> forCategory(BusinessCategory category) => [
    for (final value in amenity) ('amenity', value),
    for (final value in shop) ('shop', value),
  ].where((t) => t != (category.osmTagKey, category.osmTagValue)).toList();

  /// "place_of_worship" -> "place of worship".
  static String label(String value) => value.replaceAll('_', ' ');
}

/// OSM `highway` values treated as roads a customer could arrive by.
/// Footpaths, tracks, and motorways are deliberately left out.
abstract final class RoadKinds {
  static const major = [
    'trunk',
    'trunk_link',
    'primary',
    'primary_link',
    'secondary',
    'secondary_link',
    'tertiary',
    'tertiary_link',
  ];

  static const all = [
    ...major,
    'unclassified',
    'residential',
    'living_street',
    'service',
    'pedestrian',
  ];
}

/// Complementary places and mapped roads around a site, from one Overpass
/// request. Successful even when it contains zero places or roads.
@immutable
class SiteContextResult {
  const SiteContextResult({
    required this.query,
    required this.complementary,
    required this.roads,
    required this.fetchedAt,
    required this.source,
    this.skippedCount = 0,
  });

  /// Same site/category/radius as the competitor search it belongs to.
  final CompetitorQuery query;
  final ComplementaryEvidence complementary;
  final RoadEvidence roads;
  final DateTime fetchedAt;
  final DataSource source;

  /// Records dropped because they had no usable coordinates.
  final int skippedCount;

  SiteContextResult withSource(DataSource source) => SiteContextResult(
    query: query,
    complementary: complementary,
    roads: roads,
    fetchedAt: fetchedAt,
    source: source,
    skippedCount: skippedCount,
  );
}

/// SAMPLE DEMO MODE context: fixed fictional evidence used only alongside
/// the sample competitor records, always labeled [DataSource.sample].
abstract final class SampleSiteContext {
  static SiteContextResult forQuery(CompetitorQuery query, DateTime now) =>
      SiteContextResult(
        query: query,
        complementary: ComplementaryEvidence(
          count: 7,
          radiusMeters: query.radius.meters,
          countsByKind: {
            'school': 2,
            'bank': 1,
            'marketplace': 1,
            'pharmacy': 1,
            'place of worship': 1,
            'supermarket': 1,
          },
        ),
        roads: const RoadEvidence(
          roadCount: 3,
          nearestRoadMeters: 35,
          nearestRoadKind: 'residential',
          nearestRoadName: 'Sample Street (demo)',
          nearestMajorRoadMeters: 120,
        ),
        fetchedAt: now,
        source: DataSource.sample,
      );
}
