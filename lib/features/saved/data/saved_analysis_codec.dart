import 'dart:convert';

import '../../../core/models/business_category.dart';
import '../../../core/models/search_radius.dart';
import '../../../core/models/selected_site.dart';
import '../../../core/utils/geo.dart';
import '../../analysis/domain/site_analysis.dart';
import '../../analysis/domain/site_context.dart';
import '../../analysis/domain/suitability_scoring.dart';
import '../../comparison/domain/site_comparison.dart';
import '../../discovery/domain/competitors.dart';
import '../domain/saved_analysis.dart';

/// Column names of the `saved_analyses` table.
abstract final class SavedColumns {
  static const table = 'saved_analyses';
  static const id = 'id';
  static const savedAt = 'saved_at';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const siteLabel = 'site_label';
  static const categoryId = 'category_id';
  static const radiusMeters = 'radius_meters';
  static const dataSource = 'data_source';
  static const totalScore = 'total_score';
  static const retrievedAt = 'retrieved_at';
  static const evidence = 'evidence_json';

  /// Everything except the evidence snapshot, for the list view.
  static const summary = [
    id,
    savedAt,
    latitude,
    longitude,
    siteLabel,
    categoryId,
    radiusMeters,
    dataSource,
    totalScore,
    retrievedAt,
  ];
}

/// Converts analyses to database rows and back.
///
/// A row keeps summary columns for the list plus a JSON snapshot of every
/// piece of evidence the score was computed from: competitor records,
/// complementary counts, mapped-road facts, a failed request's reason, data
/// sources and original retrieval times. Reopening rebuilds the analysis
/// from that snapshot with [SiteAnalysis.from], so no network request is
/// needed and nothing is invented for evidence that was missing.
///
/// Only analysis evidence is stored. No tokens, credentials, or device
/// identifiers ever pass through here.
abstract final class SavedAnalysisCodec {
  /// Version of the evidence JSON layout. Bump with a decoder branch.
  static const evidenceVersion = 1;

  static Map<String, Object?> toRow(
    SelectedSite site,
    SiteAnalysis analysis,
    DateTime savedAt,
  ) {
    final query = analysis.competitors.query;
    return {
      SavedColumns.savedAt: savedAt.millisecondsSinceEpoch,
      SavedColumns.latitude: query.latitude,
      SavedColumns.longitude: query.longitude,
      SavedColumns.siteLabel: site.displayLabel,
      SavedColumns.categoryId: query.category.id,
      SavedColumns.radiusMeters: query.radius.meters,
      SavedColumns.dataSource: overallSource(analysis).name,
      SavedColumns.totalScore: analysis.score.total,
      SavedColumns.retrievedAt: oldestFetch(analysis).millisecondsSinceEpoch,
      SavedColumns.evidence: jsonEncode(encodeEvidence(site, analysis)),
    };
  }

  /// Reads the summary columns. Never throws: a damaged row becomes an
  /// unreadable summary the user can still delete.
  static SavedAnalysisSummary summaryFromRow(Map<String, Object?> row) {
    final id = row[SavedColumns.id];
    if (id is! int) {
      throw const FormatException('Saved analysis row without an id');
    }
    final savedAt = _optTime(row[SavedColumns.savedAt]);
    try {
      final latitude = _double(row[SavedColumns.latitude], 'latitude');
      final longitude = _double(row[SavedColumns.longitude], 'longitude');
      if (!isValidCoordinate(latitude, longitude)) {
        throw const FormatException('coordinates out of range');
      }
      return SavedAnalysisSummary(
        id: id,
        savedAt: savedAt ?? (throw const FormatException('saved_at')),
        latitude: latitude,
        longitude: longitude,
        siteLabel: _string(row[SavedColumns.siteLabel], 'site_label'),
        category: _category(row[SavedColumns.categoryId]),
        radius: _radius(row[SavedColumns.radiusMeters]),
        source: _source(row[SavedColumns.dataSource]),
        total: _optDouble(row[SavedColumns.totalScore], 'total_score'),
        retrievedAt: _time(row[SavedColumns.retrievedAt], 'retrieved_at'),
      );
    } on FormatException {
      return SavedAnalysisSummary.unreadable(id: id, savedAt: savedAt);
    }
  }

  /// Rebuilds the full analysis. Throws [SavedAnalysisCorruptException]
  /// for anything malformed rather than guessing a value.
  static SavedAnalysis fromRow(Map<String, Object?> row) {
    final id = row[SavedColumns.id];
    if (id is! int) {
      throw const FormatException('Saved analysis row without an id');
    }
    try {
      final raw = row[SavedColumns.evidence];
      if (raw is! String) throw const FormatException('evidence missing');
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) {
        throw const FormatException('evidence is not an object');
      }
      final (site, analysis) = decodeEvidence(json);
      return SavedAnalysis(
        id: id,
        savedAt: _time(row[SavedColumns.savedAt], 'saved_at'),
        site: site,
        analysis: analysis,
        savedTotal: _optDouble(row[SavedColumns.totalScore], 'total_score'),
      );
    } on FormatException catch (e) {
      throw SavedAnalysisCorruptException(id, e.message);
    }
  }

  static Map<String, Object?> encodeEvidence(
    SelectedSite site,
    SiteAnalysis analysis,
  ) {
    final competitors = analysis.competitors;
    final query = competitors.query;
    final context = analysis.context;
    return {
      'v': evidenceVersion,
      'site': {
        'latitude': site.latitude,
        'longitude': site.longitude,
        'source': site.source.name,
        'accuracyMeters': site.accuracyMeters,
      },
      'query': {
        'latitude': query.latitude,
        'longitude': query.longitude,
        'category': query.category.id,
        'radiusMeters': query.radius.meters,
      },
      'competitors': {
        'source': competitors.source.name,
        'fetchedAt': competitors.fetchedAt.millisecondsSinceEpoch,
        'skippedCount': competitors.skippedCount,
        'possiblyTruncated': competitors.possiblyTruncated,
        'businesses': [
          for (final b in competitors.businesses)
            {
              'osmType': b.osmType,
              'osmId': b.osmId,
              'name': b.name,
              'latitude': b.latitude,
              'longitude': b.longitude,
              'distanceMeters': b.distanceMeters,
              'details': b.details,
            },
        ],
      },
      'context': context == null
          ? null
          : {
              'source': context.source.name,
              'fetchedAt': context.fetchedAt.millisecondsSinceEpoch,
              'skippedCount': context.skippedCount,
              'complementary': {
                'count': context.complementary.count,
                'radiusMeters': context.complementary.radiusMeters,
                'countsByKind': context.complementary.countsByKind,
                'possiblyTruncated': context.complementary.possiblyTruncated,
              },
              'roads': {
                'roadCount': context.roads.roadCount,
                'nearestRoadMeters': context.roads.nearestRoadMeters,
                'nearestRoadKind': context.roads.nearestRoadKind,
                'nearestRoadName': context.roads.nearestRoadName,
                'nearestMajorRoadMeters': context.roads.nearestMajorRoadMeters,
              },
            },
      'contextFailure': analysis.contextFailure?.name,
      'contextStatusCode': analysis.contextStatusCode,
    };
  }

  static (SelectedSite, SiteAnalysis) decodeEvidence(
    Map<String, Object?> json,
  ) {
    final version = json['v'];
    if (version != evidenceVersion) {
      throw FormatException('unsupported evidence version $version');
    }

    final siteJson = _map(json['site'], 'site');
    final siteLat = _double(siteJson['latitude'], 'site.latitude');
    final siteLon = _double(siteJson['longitude'], 'site.longitude');
    if (!isValidCoordinate(siteLat, siteLon)) {
      throw const FormatException('site coordinates out of range');
    }
    final siteSource = SiteSource.values.asNameMap()[siteJson['source']];
    if (siteSource == null) throw const FormatException('site.source');
    final site = SelectedSite.at(
      latitude: siteLat,
      longitude: siteLon,
      source: siteSource,
      accuracyMeters: _optDouble(
        siteJson['accuracyMeters'],
        'site.accuracyMeters',
      ),
    );

    final queryJson = _map(json['query'], 'query');
    final queryLat = _double(queryJson['latitude'], 'query.latitude');
    final queryLon = _double(queryJson['longitude'], 'query.longitude');
    if (!isValidCoordinate(queryLat, queryLon)) {
      throw const FormatException('query coordinates out of range');
    }
    final query = CompetitorQuery(
      latitude: queryLat,
      longitude: queryLon,
      category: _category(queryJson['category']),
      radius: _radius(queryJson['radiusMeters']),
    );

    final compJson = _map(json['competitors'], 'competitors');
    final businessesJson = compJson['businesses'];
    if (businessesJson is! List) {
      throw const FormatException('competitors.businesses');
    }
    final competitors = CompetitorResult(
      query: query,
      businesses: [for (final b in businessesJson) _business(b)],
      fetchedAt: _time(compJson['fetchedAt'], 'competitors.fetchedAt'),
      source: _source(compJson['source']),
      skippedCount: _int(compJson['skippedCount'], 'competitors.skipped'),
      possiblyTruncated: _bool(
        compJson['possiblyTruncated'],
        'competitors.possiblyTruncated',
      ),
    );

    final contextRaw = json['context'];
    SiteContextResult? context;
    if (contextRaw != null) {
      final c = _map(contextRaw, 'context');
      final comp = _map(c['complementary'], 'context.complementary');
      final kindsRaw = _map(comp['countsByKind'], 'countsByKind');
      final roads = _map(c['roads'], 'context.roads');
      context = SiteContextResult(
        query: query,
        complementary: ComplementaryEvidence(
          count: _int(comp['count'], 'complementary.count'),
          radiusMeters: _int(comp['radiusMeters'], 'complementary.radius'),
          countsByKind: {
            for (final e in kindsRaw.entries)
              e.key: _int(e.value, 'countsByKind'),
          },
          possiblyTruncated: _bool(
            comp['possiblyTruncated'],
            'complementary.possiblyTruncated',
          ),
        ),
        roads: RoadEvidence(
          roadCount: _int(roads['roadCount'], 'roads.roadCount'),
          nearestRoadMeters: _optDouble(
            roads['nearestRoadMeters'],
            'roads.nearestRoadMeters',
          ),
          nearestRoadKind: _optString(roads['nearestRoadKind'], 'roadKind'),
          nearestRoadName: _optString(roads['nearestRoadName'], 'roadName'),
          nearestMajorRoadMeters: _optDouble(
            roads['nearestMajorRoadMeters'],
            'roads.nearestMajorRoadMeters',
          ),
        ),
        fetchedAt: _time(c['fetchedAt'], 'context.fetchedAt'),
        source: _source(c['source']),
        skippedCount: _int(c['skippedCount'], 'context.skippedCount'),
      );
    }

    final failureName = json['contextFailure'];
    final failure = failureName == null
        ? null
        : CompetitorFailure.values.asNameMap()[failureName] ??
              (throw const FormatException('contextFailure'));
    if (context == null && failure == null) {
      throw const FormatException('neither context nor its failure stored');
    }

    final analysis = SiteAnalysis.from(
      competitors: competitors,
      context: context,
      contextFailure: failure,
      contextStatusCode: _optInt(json['contextStatusCode'], 'statusCode'),
    );
    return (site, analysis);
  }

  static NearbyBusiness _business(Object? raw) {
    final b = _map(raw, 'business');
    final latitude = _double(b['latitude'], 'business.latitude');
    final longitude = _double(b['longitude'], 'business.longitude');
    if (!isValidCoordinate(latitude, longitude)) {
      throw const FormatException('business coordinates out of range');
    }
    final details = _map(b['details'], 'business.details');
    return NearbyBusiness(
      osmType: _string(b['osmType'], 'business.osmType'),
      osmId: _int(b['osmId'], 'business.osmId'),
      name: _optString(b['name'], 'business.name'),
      latitude: latitude,
      longitude: longitude,
      distanceMeters: _double(b['distanceMeters'], 'business.distance'),
      details: {
        for (final e in details.entries)
          e.key: _string(e.value, 'business.details'),
      },
    );
  }
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    if (value.keys.any((k) => k is! String)) throw FormatException(field);
    return {for (final e in value.entries) e.key as String: e.value};
  }
  throw FormatException(field);
}

String _string(Object? value, String field) =>
    value is String ? value : throw FormatException(field);

String? _optString(Object? value, String field) =>
    value == null ? null : _string(value, field);

int _int(Object? value, String field) =>
    value is int ? value : throw FormatException(field);

int? _optInt(Object? value, String field) =>
    value == null ? null : _int(value, field);

bool _bool(Object? value, String field) =>
    value is bool ? value : throw FormatException(field);

double _double(Object? value, String field) {
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException(field);
}

double? _optDouble(Object? value, String field) =>
    value == null ? null : _double(value, field);

DateTime _time(Object? value, String field) =>
    _optTime(value) ?? (throw FormatException(field));

DateTime? _optTime(Object? value) =>
    value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;

/// Category ids are stable across releases: records from the first release
/// (coffee_shop, restaurant, convenience, laundry, bakery) keep decoding.
BusinessCategory _category(Object? id) =>
    (id is String ? BusinessCategory.byId(id) : null) ??
    (throw const FormatException('unknown category'));

/// Any whole-meter radius in the supported range, so both the first
/// release's presets (500/1000/2000) and later custom distances decode.
SearchRadius _radius(Object? meters) =>
    (meters is int ? SearchRadius.tryMeters(meters) : null) ??
    (throw const FormatException('unsupported radius'));

DataSource _source(Object? name) =>
    DataSource.values.asNameMap()[name] ??
    (throw const FormatException('unknown data source'));
