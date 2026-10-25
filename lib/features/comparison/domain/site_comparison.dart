import 'package:flutter/foundation.dart';

import '../../../core/models/business_category.dart';
import '../../../core/models/search_radius.dart';
import '../../../core/utils/age.dart';
import '../../../core/utils/geo.dart';
import '../../analysis/domain/site_analysis.dart';
import '../../analysis/domain/suitability_scoring.dart';
import '../../discovery/domain/competitors.dart';

/// The two comparison slots, shown to users as the first and second
/// location.
enum CompareSlot {
  a('1', 'First location'),
  b('2', 'Second location');

  const CompareSlot(this.badge, this.title);

  /// Short marker on the map pin and the slot badge.
  final String badge;

  /// "First location" / "Second location".
  final String title;

  /// [title] for use inside a sentence: "the first location".
  String get inSentence => 'the ${title.toLowerCase()}';

  CompareSlot get other => this == a ? b : a;
}

/// Why two analyses cannot be ranked against each other.
enum ComparisonBlockerKind {
  missingAnalysis,
  sameSite,
  settingsMismatch,
  settingsChanged,
  mixedSources,
  insufficientData,
}

@immutable
class ComparisonBlocker {
  const ComparisonBlocker(this.kind, this.message);

  final ComparisonBlockerKind kind;
  final String message;

  @override
  String toString() => 'ComparisonBlocker(${kind.name})';
}

/// Fixed comparison rules. Like the scoring thresholds, these are
/// developer assumptions for the prototype, shown in the app.
abstract final class ComparisonRules {
  /// Sites closer than this are treated as the same location.
  static const sameSiteMeters = 25.0;

  /// Score gaps below this many points are reported as "similar": the
  /// heuristic is too coarse for small differences to mean anything.
  static const similarScorePoints = 5.0;

  /// Evidence older than this is flagged so the user can refresh it.
  static const staleAfter = Duration(minutes: 15);
}

/// The outcome of comparing the first and second location.
@immutable
class SiteComparison {
  const SiteComparison({
    required this.blockers,
    required this.warnings,
    this.higher,
    this.difference,
    this.sampleOnly = false,
  });

  /// Reasons the scores must not be ranked. Empty when comparable.
  final List<ComparisonBlocker> blockers;

  /// Caveats that do not block the comparison (sparse data, old evidence).
  final List<String> warnings;

  /// The slot with the higher heuristic score, or null when not comparable
  /// or the scores are within [ComparisonRules.similarScorePoints].
  final CompareSlot? higher;

  /// A's total minus B's total, only when comparable.
  final double? difference;

  /// Both sites use fictional sample data: comparable as a demo only.
  final bool sampleOnly;

  bool get isComparable => blockers.isEmpty;

  /// Comparable, but the gap is too small to call.
  bool get isSimilar => isComparable && higher == null;

  bool blockedBy(ComparisonBlockerKind kind) =>
      blockers.any((b) => b.kind == kind);
}

/// Compares two analyses under the current search [category] and [radius].
///
/// Scores are ranked only when both analyses exist, describe different
/// locations, used the same category and radius (and those are still the
/// current settings), come from the same kind of data (both OpenStreetMap,
/// or both sample), and both have a total score.
SiteComparison compareSites({
  required SiteAnalysis? a,
  required SiteAnalysis? b,
  required BusinessCategory category,
  required SearchRadius radius,
  required DateTime now,
  Set<CompareSlot> saved = const {},
}) {
  final blockers = <ComparisonBlocker>[];
  final warnings = <String>[];

  if (a == null || b == null) {
    final missing = [
      if (a == null) CompareSlot.a,
      if (b == null) CompareSlot.b,
    ];
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.missingAnalysis,
        missing.length == 2
            ? 'Neither location has been checked yet.'
            : '${missing.single.title} hasn’t been checked yet.',
      ),
    );
    return SiteComparison(blockers: blockers, warnings: warnings);
  }

  final qa = a.competitors.query;
  final qb = b.competitors.query;

  final apart = distanceMeters(
    qa.latitude,
    qa.longitude,
    qb.latitude,
    qb.longitude,
  );
  if (apart < ComparisonRules.sameSiteMeters) {
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.sameSite,
        'The first and second locations are the same spot '
        '(${formatDistance(apart)} apart). Choose a different spot for one of '
        'them.',
      ),
    );
  }

  if (qa.category != qb.category || qa.radius != qb.radius) {
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.settingsMismatch,
        'The two locations were checked with different settings '
        '(${settingsLabel(qa)} vs ${settingsLabel(qb)}). Check both again '
        'with the same business type and search distance.',
      ),
    );
  }

  final outdated = [
    for (final (slot, query) in [(CompareSlot.a, qa), (CompareSlot.b, qb)])
      if (query.category != category || query.radius != radius) slot,
  ];
  if (outdated.isNotEmpty) {
    final which = outdated.length == 2
        ? 'both locations'
        : outdated.single.inSentence;
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.settingsChanged,
        'Search settings changed to ${category.label} · ${radius.label}. '
        'Check $which again with these settings.',
      ),
    );
  }

  if (a.isSample != b.isSample) {
    final sample = a.isSample ? CompareSlot.a : CompareSlot.b;
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.mixedSources,
        '${sample.title} uses SAMPLE DEMO DATA and ${sample.other.inSentence} '
        'uses real OpenStreetMap data. Sample and real results can’t be '
        'compared.',
      ),
    );
  }

  final insufficient = [
    if (!a.score.hasTotal) CompareSlot.a,
    if (!b.score.hasTotal) CompareSlot.b,
  ];
  if (insufficient.isNotEmpty) {
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.insufficientData,
        insufficient.length == 2
            ? 'Neither location has a total score yet, because some map '
                  'information couldn’t be retrieved. Try checking them again.'
            : '${insufficient.single.title} has no total score yet, because '
                  'some map information couldn’t be retrieved. Try checking '
                  'it again.',
      ),
    );
  }

  if (a.score.lowConfidence || b.score.lowConfidence) {
    warnings.add(
      'Some nearby businesses may not be listed on the map for at least one '
      'location, so a score difference may come from missing map data.',
    );
  }
  for (final slot in CompareSlot.values) {
    if (saved.contains(slot)) {
      warnings.add(
        '${slot.title} is a saved result. Its information is from when it '
        'was saved, not today.',
      );
    }
  }
  for (final (slot, analysis) in [(CompareSlot.a, a), (CompareSlot.b, b)]) {
    if (analysis.isSample) continue;
    final age = now.difference(oldestFetch(analysis));
    if (age > ComparisonRules.staleAfter) {
      warnings.add(
        'Map data for ${slot.inSentence} was retrieved ${formatAge(age)} ago. '
        'Refresh it for the latest OpenStreetMap data.',
      );
    }
  }

  if (blockers.isNotEmpty) {
    return SiteComparison(blockers: blockers, warnings: warnings);
  }

  final difference = a.score.total! - b.score.total!;
  final CompareSlot? higher;
  if (difference.abs() < ComparisonRules.similarScorePoints) {
    higher = null;
  } else {
    higher = difference > 0 ? CompareSlot.a : CompareSlot.b;
  }
  return SiteComparison(
    blockers: const [],
    warnings: warnings,
    higher: higher,
    difference: (difference * 10).round() / 10,
    sampleOnly: a.isSample && b.isSample,
  );
}

/// How much one criterion adds to one location's total compared with the
/// other's, in points of the 0..100 total. Positive: the first-named
/// location gains points there.
@immutable
class CriterionDifference {
  const CriterionDifference(this.criterion, this.points);

  final Criterion criterion;
  final double points;
}

/// The per-criterion reasons behind a score gap between [from] and
/// [other], largest first. Criteria without data on either side, and gaps
/// under half a point, are left out: they explain nothing.
List<CriterionDifference> criterionDifferences(
  SiteAnalysis from,
  SiteAnalysis other,
) {
  final differences = <CriterionDifference>[];
  for (final result in from.score.criteria) {
    final mine = result.contribution;
    final theirs = other.score.criteria
        .firstWhere((c) => c.criterion == result.criterion)
        .contribution;
    if (mine == null || theirs == null) continue;
    final points = ((mine - theirs) * 10).round() / 10;
    if (points.abs() < 0.5) continue;
    differences.add(CriterionDifference(result.criterion, points));
  }
  differences.sort((x, y) => y.points.abs().compareTo(x.points.abs()));
  return differences;
}

/// "Coffee Shop · 1 km".
String settingsLabel(CompetitorQuery query) =>
    '${query.category.label} · ${query.radius.label}';

/// When the oldest piece of evidence behind [analysis] was retrieved.
DateTime oldestFetch(SiteAnalysis analysis) {
  final context = analysis.context;
  final competitors = analysis.competitors.fetchedAt;
  if (context == null || competitors.isBefore(context.fetchedAt)) {
    return competitors;
  }
  return context.fetchedAt;
}
