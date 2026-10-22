import 'package:flutter/foundation.dart';

import '../../../core/models/business_category.dart';
import '../../../core/models/search_radius.dart';
import '../../../core/utils/geo.dart';
import '../../analysis/domain/site_analysis.dart';
import '../../discovery/domain/competitors.dart';

/// The two comparison slots.
enum CompareSlot {
  a('A'),
  b('B');

  const CompareSlot(this.letter);

  final String letter;

  String get title => 'Site $letter';

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

/// The outcome of comparing Site A and Site B.
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
}) {
  final blockers = <ComparisonBlocker>[];
  final warnings = <String>[];

  if (a == null || b == null) {
    final missing = [
      if (a == null) CompareSlot.a.title,
      if (b == null) CompareSlot.b.title,
    ];
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.missingAnalysis,
        '${missing.join(' and ')} ${missing.length == 1 ? 'has' : 'have'} '
        'not been analyzed yet.',
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
        'Site A and Site B are the same location '
        '(${formatDistance(apart)} apart). Pick a different spot for one of '
        'them.',
      ),
    );
  }

  if (qa.category != qb.category || qa.radius != qb.radius) {
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.settingsMismatch,
        'The sites were analyzed with different settings '
        '(${settingsLabel(qa)} vs ${settingsLabel(qb)}). Re-analyze both '
        'with the same business type and radius.',
      ),
    );
  }

  final outdated = [
    for (final (slot, query) in [(CompareSlot.a, qa), (CompareSlot.b, qb)])
      if (query.category != category || query.radius != radius) slot.title,
  ];
  if (outdated.isNotEmpty) {
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.settingsChanged,
        'Search settings changed to ${category.label} · ${radius.label}. '
        '${outdated.join(' and ')} must be re-analyzed with these settings.',
      ),
    );
  }

  if (a.isSample != b.isSample) {
    final sample = a.isSample ? CompareSlot.a : CompareSlot.b;
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.mixedSources,
        '${sample.title} uses SAMPLE DEMO DATA and ${sample.other.title} uses '
        'OpenStreetMap data. Fictional and real evidence cannot be compared.',
      ),
    );
  }

  final insufficient = [
    if (!a.score.hasTotal) CompareSlot.a.title,
    if (!b.score.hasTotal) CompareSlot.b.title,
  ];
  if (insufficient.isNotEmpty) {
    blockers.add(
      ComparisonBlocker(
        ComparisonBlockerKind.insufficientData,
        '${insufficient.join(' and ')} ${insufficient.length == 1 ? 'has' : 'have'} '
        'insufficient data (no total score). Retry the failed evidence '
        'request.',
      ),
    );
  }

  if (a.score.lowConfidence || b.score.lowConfidence) {
    warnings.add(
      'Low confidence: OpenStreetMap coverage is sparse or incomplete for at '
      'least one site, so a score difference may reflect missing map data.',
    );
  }
  for (final (slot, analysis) in [(CompareSlot.a, a), (CompareSlot.b, b)]) {
    if (analysis.isSample) continue;
    final age = now.difference(oldestFetch(analysis));
    if (age > ComparisonRules.staleAfter) {
      warnings.add(
        '${slot.title} evidence was retrieved ${age.inMinutes} min ago. '
        'Refresh it for current OpenStreetMap data.',
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
