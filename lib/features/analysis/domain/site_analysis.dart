import 'package:flutter/foundation.dart';

import '../../discovery/domain/competitors.dart';
import 'site_context.dart';
import 'suitability_scoring.dart';

/// One scored site: the evidence it used and the resulting score.
@immutable
class SiteAnalysis {
  const SiteAnalysis._({
    required this.competitors,
    required this.context,
    required this.contextFailure,
    required this.contextStatusCode,
    required this.score,
  });

  /// Scores [competitors] plus [context]. Pass [contextFailure] instead of a
  /// context when that request failed; the affected criteria then have no
  /// score and the total is "Insufficient data".
  factory SiteAnalysis.from({
    required CompetitorResult competitors,
    SiteContextResult? context,
    CompetitorFailure? contextFailure,
    int? contextStatusCode,
  }) {
    final input = ScoringInput(
      competitors: CompetitorEvidence(
        distancesMeters: [
          for (final b in competitors.businesses) b.distanceMeters,
        ],
        radiusMeters: competitors.query.radius.meters,
        possiblyTruncated: competitors.possiblyTruncated,
      ),
      complementary: context?.complementary,
      roads: context?.roads,
    );
    return SiteAnalysis._(
      competitors: competitors,
      context: context,
      contextFailure: context == null ? contextFailure : null,
      contextStatusCode: context == null ? contextStatusCode : null,
      score: scoreSuitability(input),
    );
  }

  final CompetitorResult competitors;
  final SiteContextResult? context;
  final CompetitorFailure? contextFailure;
  final int? contextStatusCode;
  final SuitabilityScore score;

  /// True when any evidence is fictional; the score is then a sample result.
  bool get isSample =>
      competitors.source == DataSource.sample ||
      context?.source == DataSource.sample;
}
