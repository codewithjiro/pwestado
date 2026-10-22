import 'dart:math' as math;

import '../../../core/utils/geo.dart';

// PWESTADO location suitability heuristic.
//
// Pure Dart: no Flutter, network, or clock access, so identical evidence
// always produces an identical score.
//
//   total = 0.40 × competitorProximity
//         + 0.30 × complementaryEstablishments
//         + 0.30 × mappedRoadAccessProxy
//
// Every criterion is normalized to 0..100 by the rules in [SuitabilityRules].
// Those thresholds are developer heuristic assumptions chosen to be easy to
// explain in a pitch, not research-backed ground truth. The total is not a
// probability of success, measured demand, foot traffic, or profit.
//
// A criterion whose evidence query failed has no score (null), never a
// made-up zero; the total is then null and shown as "Insufficient data".

/// Fixed normalization thresholds. Shown verbatim in the app.
abstract final class SuitabilityRules {
  /// A mapped competitor this close counts fully.
  static const competitorNearMeters = 250;
  static const competitorNearWeight = 1.0;

  /// Competitors farther away (but inside the search radius) count half.
  static const competitorFarWeight = 0.5;

  /// Weighted competitor count at which the criterion reaches 0.
  static const competitorSaturation = 10.0;

  /// Complementary places per 500 m of search radius at which the
  /// criterion reaches 100 (25 / 50 / 100 for 500 m / 1 km / 2 km). Scaled
  /// with the radius so a larger search does not max out automatically; a
  /// live 1 km test in central Santa Ana returned 61 such places.
  static const complementaryPer500m = 25;

  static int complementarySaturation(int radiusMeters) =>
      math.max(1, (complementaryPer500m * radiusMeters / 500).round());

  /// Road ways are searched within this distance of the site.
  static const roadSearchMeters = 150;

  /// A mapped road at or inside this distance earns full proximity points.
  static const roadNearMeters = 50;
  static const roadProximityPoints = 60.0;
  static const majorRoadPoints = 40.0;

  /// Below this many mapped places (competitors + complementary) the result
  /// is flagged as low confidence: OSM is probably just sparse here.
  static const sparseCoverageThreshold = 5;
}

enum Criterion {
  competitorProximity(
    'Competitor proximity',
    0.40,
    'Fewer mapped same-category businesses nearby scores higher. A high '
        'count can also mean proven demand; this does not measure market '
        'saturation.',
  ),
  complementary(
    'Complementary establishments',
    0.30,
    'More mapped schools, markets, banks, clinics, supermarkets and similar '
        'places nearby scores higher. It counts mapped places only, not '
        'customers or demand.',
  ),
  roadAccess(
    'Mapped road access (proxy)',
    0.30,
    'A mapped road close to the site, and a mapped major road nearby, score '
        'higher. Rough OpenStreetMap proxy only: not travel time, '
        'walkability, traffic, or parking.',
  );

  const Criterion(this.label, this.weight, this.meaning);

  final String label;
  final double weight;

  /// What the criterion does and does not mean, for the breakdown card.
  final String meaning;

  int get weightPercent => (weight * 100).round();
}

/// Same-category businesses from a successful search.
class CompetitorEvidence {
  const CompetitorEvidence({
    required this.distancesMeters,
    required this.radiusMeters,
    this.possiblyTruncated = false,
  });

  final List<double> distancesMeters;
  final int radiusMeters;
  final bool possiblyTruncated;

  int get count => distancesMeters.length;
  int get nearCount => distancesMeters
      .where((d) => d <= SuitabilityRules.competitorNearMeters)
      .length;
}

/// Complementary mapped places from a successful search.
class ComplementaryEvidence {
  const ComplementaryEvidence({
    required this.count,
    required this.radiusMeters,
    this.countsByKind = const {},
    this.possiblyTruncated = false,
  });

  final int count;
  final int radiusMeters;

  /// Readable kind (e.g. "school") to count, for the evidence line.
  final Map<String, int> countsByKind;
  final bool possiblyTruncated;
}

/// Mapped `highway` ways within [SuitabilityRules.roadSearchMeters], from a
/// successful search. Zero roads is valid evidence, not a failure.
class RoadEvidence {
  const RoadEvidence({
    required this.roadCount,
    this.nearestRoadMeters,
    this.nearestRoadKind,
    this.nearestRoadName,
    this.nearestMajorRoadMeters,
  });

  final int roadCount;
  final double? nearestRoadMeters;

  /// The OSM `highway` value of the nearest road, e.g. `residential`.
  final String? nearestRoadKind;
  final String? nearestRoadName;

  /// Nearest trunk/primary/secondary/tertiary road, if any was found.
  final double? nearestMajorRoadMeters;
}

/// The evidence one score is computed from. A null field means that query
/// failed or was not available.
class ScoringInput {
  const ScoringInput({this.competitors, this.complementary, this.roads});

  final CompetitorEvidence? competitors;
  final ComplementaryEvidence? complementary;
  final RoadEvidence? roads;
}

class CriterionResult {
  const CriterionResult({
    required this.criterion,
    required this.score,
    required this.evidence,
    required this.rule,
  });

  final Criterion criterion;

  /// 0..100, or null when the evidence is unavailable.
  final double? score;

  /// What was observed, e.g. "3 mapped within 1 km (1 within 250 m)".
  final String evidence;

  /// The normalization formula used.
  final String rule;

  bool get isAvailable => score != null;

  /// Points added to the total: weight × score.
  double? get contribution =>
      score == null ? null : _round1(score! * criterion.weight);
}

class SuitabilityScore {
  const SuitabilityScore({
    required this.total,
    required this.criteria,
    required this.warnings,
    required this.lowConfidence,
  });

  /// 0..100, or null ("Insufficient data") when any criterion is missing.
  final double? total;
  final List<CriterionResult> criteria;
  final List<String> warnings;
  final bool lowConfidence;

  bool get hasTotal => total != null;

  CriterionResult operator [](Criterion criterion) =>
      criteria.firstWhere((c) => c.criterion == criterion);

  /// "0.40 × 80 + 0.30 × 40 + 0.30 × 100 = 74", or null without a total.
  String? get formula {
    if (total == null) return null;
    final terms = criteria
        .map(
          (c) =>
              '${c.criterion.weight.toStringAsFixed(2)} × '
              '${_fmt(c.score!)}',
        )
        .join(' + ');
    return '$terms = ${_fmt(total!)}';
  }
}

/// Competitor proximity, 0..100.
double competitorCriterion(CompetitorEvidence evidence) {
  final near = evidence.nearCount;
  final far = evidence.count - near;
  final weighted =
      near * SuitabilityRules.competitorNearWeight +
      far * SuitabilityRules.competitorFarWeight;
  final capped = math.min(weighted, SuitabilityRules.competitorSaturation);
  return _round1(100 * (1 - capped / SuitabilityRules.competitorSaturation));
}

/// Complementary establishments, 0..100.
double complementaryCriterion(ComplementaryEvidence evidence) {
  final saturation = SuitabilityRules.complementarySaturation(
    evidence.radiusMeters,
  );
  final capped = math.min(evidence.count, saturation);
  return _round1(100 * capped / saturation);
}

/// Mapped road access proxy, 0..100.
double roadCriterion(RoadEvidence evidence) {
  final nearest = evidence.nearestRoadMeters;
  if (evidence.roadCount == 0 || nearest == null) return 0;
  const near = SuitabilityRules.roadNearMeters;
  const far = SuitabilityRules.roadSearchMeters;
  final proximityShare = nearest <= near
      ? 1.0
      : (1 - (nearest - near) / (far - near)).clamp(0.0, 1.0);
  final major = evidence.nearestMajorRoadMeters;
  final majorPoints = major != null && major <= far
      ? SuitabilityRules.majorRoadPoints
      : 0.0;
  return _round1(
    SuitabilityRules.roadProximityPoints * proximityShare + majorPoints,
  );
}

/// Scores [input] with the fixed 40/30/30 weights.
SuitabilityScore scoreSuitability(ScoringInput input) {
  final competitors = input.competitors;
  final complementary = input.complementary;
  final roads = input.roads;

  final criteria = [
    CriterionResult(
      criterion: Criterion.competitorProximity,
      score: competitors == null ? null : competitorCriterion(competitors),
      evidence: competitors == null
          ? 'Not available: the competitor search did not succeed.'
          : _competitorEvidence(competitors),
      rule:
          'Each mapped competitor within '
          '${SuitabilityRules.competitorNearMeters} m counts 1.0, farther ones '
          'in the radius count 0.5. Score = 100 × (1 − min(weighted, '
          '${_fmt(SuitabilityRules.competitorSaturation)}) / '
          '${_fmt(SuitabilityRules.competitorSaturation)}).',
    ),
    CriterionResult(
      criterion: Criterion.complementary,
      score: complementary == null
          ? null
          : complementaryCriterion(complementary),
      evidence: complementary == null
          ? 'Not available: the complementary-places query did not succeed.'
          : _complementaryEvidence(complementary),
      rule:
          'Score = 100 × min(count, N) / N, where N = '
          '${SuitabilityRules.complementaryPer500m} places per 500 m of '
          'search radius${_saturationNote(complementary)}.',
    ),
    CriterionResult(
      criterion: Criterion.roadAccess,
      score: roads == null ? null : roadCriterion(roads),
      evidence: roads == null
          ? 'Not available: the mapped-road query did not succeed.'
          : _roadEvidence(roads),
      rule:
          '${_fmt(SuitabilityRules.roadProximityPoints)} pts if the nearest '
          'mapped road is within ${SuitabilityRules.roadNearMeters} m, falling '
          'linearly to 0 at ${SuitabilityRules.roadSearchMeters} m; '
          '+${_fmt(SuitabilityRules.majorRoadPoints)} pts if a mapped trunk, '
          'primary, secondary or tertiary road is within '
          '${SuitabilityRules.roadSearchMeters} m.',
    ),
  ];

  final complete = criteria.every((c) => c.isAvailable);
  final total = complete
      ? _round1(criteria.fold(0.0, (sum, c) => sum + c.contribution!))
      : null;

  final warnings = <String>[];
  var lowConfidence = false;
  final missing = criteria.where((c) => !c.isAvailable).toList();
  if (missing.isNotEmpty) {
    warnings.add(
      'Insufficient data: ${missing.map((c) => c.criterion.label).join(', ')} '
      '${missing.length == 1 ? 'is' : 'are'} unavailable, so no total score '
      'is calculated.',
    );
  }
  if (competitors != null && complementary != null) {
    final mapped = competitors.count + complementary.count;
    if (mapped < SuitabilityRules.sparseCoverageThreshold) {
      lowConfidence = true;
      warnings.add(
        'Low confidence: only $mapped mapped '
        '${mapped == 1 ? 'place was' : 'places were'} found. OpenStreetMap '
        'coverage looks sparse here, so few mapped competitors may not mean '
        'few real ones.',
      );
    }
  }
  if ((competitors?.possiblyTruncated ?? false) ||
      (complementary?.possiblyTruncated ?? false)) {
    lowConfidence = true;
    warnings.add(
      'Some results hit the server limit, so counts may be understated.',
    );
  }
  if (roads != null && roads.roadCount == 0) {
    lowConfidence = true;
    warnings.add(
      'No qualifying road is mapped within '
      '${SuitabilityRules.roadSearchMeters} m. Roads may exist but be '
      'unmapped.',
    );
  }

  return SuitabilityScore(
    total: total,
    criteria: List.unmodifiable(criteria),
    warnings: List.unmodifiable(warnings),
    lowConfidence: lowConfidence,
  );
}

String _competitorEvidence(CompetitorEvidence e) {
  final m = e.radiusMeters;
  final radius = m >= 1000 && m % 1000 == 0 ? '${m ~/ 1000} km' : '$m m';
  final near = e.nearCount;
  final far = e.count - near;
  final weighted =
      near * SuitabilityRules.competitorNearWeight +
      far * SuitabilityRules.competitorFarWeight;
  return '${e.count} mapped within $radius ($near within '
      '${SuitabilityRules.competitorNearMeters} m); weighted count '
      '${_fmt(weighted)}.';
}

String _complementaryEvidence(ComplementaryEvidence e) {
  if (e.count == 0) return 'No complementary places mapped in the radius.';
  final kinds = e.countsByKind.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  final listed = kinds.take(4).map((k) => '${k.value} ${k.key}').join(', ');
  final more = kinds.length > 4 ? ', …' : '';
  return '${e.count} mapped ${e.count == 1 ? 'place' : 'places'}'
      '${listed.isEmpty ? '' : ': $listed$more'}.';
}

String _roadEvidence(RoadEvidence e) {
  final nearest = e.nearestRoadMeters;
  if (e.roadCount == 0 || nearest == null) {
    return 'No qualifying mapped road within '
        '${SuitabilityRules.roadSearchMeters} m.';
  }
  final name = e.nearestRoadName == null ? '' : ' "${e.nearestRoadName}"';
  final kind = e.nearestRoadKind == null ? '' : ' (${e.nearestRoadKind})';
  final major = e.nearestMajorRoadMeters;
  final majorText = major == null
      ? 'no mapped major road within ${SuitabilityRules.roadSearchMeters} m'
      : 'mapped major road about ${formatDistance(major)} away';
  return 'Nearest mapped road$name$kind about ${formatDistance(nearest)} '
      'away; $majorText.';
}

String _saturationNote(ComplementaryEvidence? evidence) => evidence == null
    ? ''
    : ' (N = ${SuitabilityRules.complementarySaturation(evidence.radiusMeters)} '
          'here)';

double _round1(double value) => (value * 10).round() / 10;

/// "40", "2.5": drops a trailing ".0".
String _fmt(double value) {
  final rounded = _round1(value);
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
