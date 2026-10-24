import 'dart:convert';

import '../../analysis/domain/site_analysis.dart';
import '../../analysis/domain/suitability_scoring.dart';
import '../../comparison/domain/site_comparison.dart';
import '../../discovery/domain/competitors.dart';

/// Builds the minimal, evidence-only request for PWESTADO AI Insights.
///
/// Deliberately excluded: coordinates, device/user identifiers, business
/// names, road names and any other free text from OpenStreetMap. Names are
/// untrusted third-party data (a prompt-injection vector) and are not
/// needed to explain counts and distances. The only free text is the
/// general area label (town/barangay), which is length-limited and
/// marked as data on the server.
abstract final class AiPayload {
  static const version = 1;
  static const maxDistances = 10;
  static const maxAreaLength = 80;

  /// Whether [analysis] has enough evidence for an evidence-based
  /// explanation: a complete deterministic score.
  static bool canExplain(SiteAnalysis analysis) => analysis.score.hasTotal;

  static Map<String, Object?> site(SiteAnalysis analysis, {String? area}) => {
    'version': version,
    'mode': 'site',
    'sites': [_site(analysis, label: 'Selected location', area: area)],
  };

  static Map<String, Object?> comparison({
    required SiteAnalysis a,
    required SiteAnalysis b,
    String? areaA,
    String? areaB,
    SiteComparison? verdict,
  }) => {
    'version': version,
    'mode': 'compare',
    'sites': [
      _site(a, label: CompareSlot.a.title, area: areaA),
      _site(b, label: CompareSlot.b.title, area: areaB),
    ],
    if (verdict != null)
      'comparison': {
        'comparable': verdict.blockers.isEmpty,
        'higher': verdict.higher?.title,
        'differencePoints': _round(verdict.difference),
        'blockers': [for (final b in verdict.blockers.take(4)) b.kind.name],
      },
  };

  static bool isDemo(Map<String, Object?> payload) => [
    for (final s in payload['sites'] as List) (s as Map)['source'],
  ].contains(DataSource.sample.name);

  /// Stable identity of a request: the same evidence maps to the same key,
  /// so the UI can keep one answer per analysis.
  static String keyOf(Map<String, Object?> payload) =>
      jsonEncode(payload).hashCode.toRadixString(36);

  static Map<String, Object?> _site(
    SiteAnalysis analysis, {
    required String label,
    String? area,
  }) {
    final competitors = analysis.competitors;
    final query = competitors.query;
    final distances = [
      for (final b in competitors.businesses) b.distanceMeters.round(),
    ];
    final context = analysis.context;
    final complementary = context?.complementary;
    final roads = context?.roads;
    final score = analysis.score;
    final sources = {competitors.source, ?context?.source};
    final source = sources.contains(DataSource.sample)
        ? DataSource.sample
        : sources.contains(DataSource.cached)
        ? DataSource.cached
        : DataSource.live;

    return {
      'label': label,
      'area': ?_area(area),
      'businessType': query.category.label,
      'businessTypeIncludes': query.category.description,
      'businessTypeNote': ?query.category.coverageNote,
      'radiusMeters': query.radius.meters,
      'radiusLabel': query.radius.label,
      'source': source.name,
      'retrievedAt': competitors.fetchedAt.toUtc().toIso8601String(),
      'score': {
        'total': _round(score.total),
        'lowConfidence': score.lowConfidence,
        'criteria': [
          for (final c in score.criteria)
            {
              'id': _criterionId(c.criterion),
              'weightPercent': c.criterion.weightPercent,
              'score': _round(c.score),
            },
        ],
      },
      'competitors': {
        'count': competitors.count,
        'within250m': distances
            .where((d) => d <= SuitabilityRules.competitorNearMeters)
            .length,
        'nearestMeters': distances.isEmpty ? null : distances.first,
        'distancesMeters': distances.take(maxDistances).toList(),
        'possiblyTruncated': competitors.possiblyTruncated,
      },
      'complementary': complementary == null
          ? null
          : {
              'count': complementary.count,
              'byKind': {
                for (final e
                    in (complementary.countsByKind.entries.toList()
                          ..sort((x, y) => y.value.compareTo(x.value)))
                        .take(8))
                  e.key: e.value,
              },
            },
      'roads': roads == null
          ? null
          : {
              'count': roads.roadCount,
              'nearestMeters': roads.nearestRoadMeters?.round(),
              'nearestKind': roads.nearestRoadKind,
              'nearestMajorMeters': roads.nearestMajorRoadMeters?.round(),
            },
      'missingEvidence': [
        if (context == null) 'complementary_places_and_roads',
      ],
      'warnings': [
        if (score.lowConfidence) 'sparse_map_coverage',
        if (query.radius.meters <= SuitabilityRules.smallRadiusMeters)
          'small_search_radius',
        if (competitors.possiblyTruncated) 'competitor_list_may_be_cut_off',
        if (source == DataSource.sample) 'sample_demo_data',
        if (source == DataSource.cached) 'cached_copy',
      ],
    };
  }

  static String? _area(String? area) {
    final a = area
        ?.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (a == null || a.isEmpty) return null;
    return a.length <= maxAreaLength ? a : a.substring(0, maxAreaLength);
  }

  static String _criterionId(Criterion c) => switch (c) {
    Criterion.competitorProximity => 'competition',
    Criterion.complementary => 'complementary_places',
    Criterion.roadAccess => 'mapped_road_access',
  };

  static num? _round(double? v) =>
      v == null ? null : (v * 10).roundToDouble() / 10;
}
