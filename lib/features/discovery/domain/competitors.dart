import 'package:flutter/foundation.dart';

import '../../../core/models/business_category.dart';
import '../../../core/models/search_radius.dart';
import '../../../core/models/selected_site.dart';
import 'business_image.dart';

/// Where a set of nearby business records came from.
enum DataSource {
  /// Retrieved from Overpass for this search.
  live('Live', 'Retrieved live from OpenStreetMap'),

  /// A copy of an earlier live response for the same query.
  cached('Cached', 'Saved copy of an earlier OpenStreetMap response'),

  /// Fictional, bundled demo records. Never real businesses.
  sample('Sample demo data', 'Fictional demo records, not real businesses');

  const DataSource(this.label, this.description);

  final String label;
  final String description;
}

/// The inputs of one competitor search: a site, a category, and a radius.
@immutable
class CompetitorQuery {
  const CompetitorQuery({
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.radius,
  });

  factory CompetitorQuery.forSite(
    SelectedSite site,
    BusinessCategory category,
    SearchRadius radius,
  ) => CompetitorQuery(
    latitude: site.latitude,
    longitude: site.longitude,
    category: category,
    radius: radius,
  );

  final double latitude;
  final double longitude;
  final BusinessCategory category;
  final SearchRadius radius;

  /// Identifies equivalent searches (coordinates to ~1 m).
  String get cacheKey =>
      '${category.osmTag}@${latitude.toStringAsFixed(5)},'
      '${longitude.toStringAsFixed(5)}/${radius.meters}';

  @override
  bool operator ==(Object other) =>
      other is CompetitorQuery && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;

  @override
  String toString() => 'CompetitorQuery($cacheKey)';
}

/// One mapped establishment near the selected site.
@immutable
class NearbyBusiness {
  const NearbyBusiness({
    required this.osmType,
    required this.osmId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.details = const {},
    this.imageRefs,
  });

  static const unnamedLabel = 'Unnamed mapped business';
  static const sampleType = 'sample';

  /// `node`, `way`, `relation`, or [sampleType] for demo records.
  final String osmType;
  final int osmId;

  /// The OSM `name` tag. Null when the record has no name; never invented.
  final String? name;
  final double latitude;
  final double longitude;

  /// Distance from the searched site to this point (way/relation center).
  final double distanceMeters;

  /// Optional human-readable tags (address, opening hours, ...), in display
  /// order. Only values present in the source record.
  final Map<String, String> details;

  /// Wikimedia/Wikidata image references from the record, if any. Not
  /// persisted with saved analyses (saved records show category art).
  final BusinessImageRefs? imageRefs;

  /// Stable identity used for de-duplication: `type:id`.
  String get key => '$osmType:$osmId';

  String get displayName => name ?? unnamedLabel;

  bool get isSample => osmType == sampleType;

  String? get osmUrl =>
      isSample ? null : 'https://www.openstreetmap.org/$osmType/$osmId';

  @override
  bool operator ==(Object other) => other is NearbyBusiness && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The outcome of a successful search (which may contain zero records).
@immutable
class CompetitorResult {
  const CompetitorResult({
    required this.query,
    required this.businesses,
    required this.fetchedAt,
    required this.source,
    this.skippedCount = 0,
    this.possiblyTruncated = false,
  });

  final CompetitorQuery query;

  /// Sorted nearest first, de-duplicated.
  final List<NearbyBusiness> businesses;

  /// When the underlying response was received (not when it was displayed).
  final DateTime fetchedAt;
  final DataSource source;

  /// Records dropped because they had no usable coordinates.
  final int skippedCount;

  /// True when the response hit the request's result cap.
  final bool possiblyTruncated;

  int get count => businesses.length;
  bool get isEmpty => businesses.isEmpty;

  CompetitorResult withSource(DataSource source) => CompetitorResult(
    query: query,
    businesses: businesses,
    fetchedAt: fetchedAt,
    source: source,
    skippedCount: skippedCount,
    possiblyTruncated: possiblyTruncated,
  );
}

/// Why a search did not produce a result.
enum CompetitorFailure {
  timeout,
  rateLimited,
  serverBusy,
  network,
  badResponse;

  /// Worth one automatic retry: transient gateway errors and dropped
  /// connections. A 429 is never retried automatically, and a timeout has
  /// already cost the user a long wait.
  bool get isRetryable => this == serverBusy || this == network;
}

class CompetitorFetchException implements Exception {
  const CompetitorFetchException(this.failure, {this.statusCode});

  final CompetitorFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'CompetitorFetchException(${failure.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}

/// Thrown when a newer search or a settings change cancels a request.
class CompetitorSearchCancelled implements Exception {
  const CompetitorSearchCancelled();
}
