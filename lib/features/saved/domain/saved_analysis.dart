import 'package:flutter/foundation.dart';

import '../../../core/models/business_category.dart';
import '../../../core/models/search_radius.dart';
import '../../../core/models/selected_site.dart';
import '../../analysis/domain/site_analysis.dart';
import '../../discovery/domain/competitors.dart';

/// How the evidence behind a saved analysis was obtained when it was saved.
/// Uses the same live / cached / sample split as the rest of the app, but
/// with labels that read as a historical record.
extension SavedSourceLabel on DataSource {
  String get savedLabel => switch (this) {
    DataSource.live => 'LIVE-SOURCED',
    DataSource.cached => 'CACHED',
    DataSource.sample => 'SAMPLE DEMO DATA',
  };
}

/// The overall source of [analysis]: sample if any evidence is fictional,
/// cached if any part came from the cache, otherwise live.
DataSource overallSource(SiteAnalysis analysis) {
  if (analysis.isSample) return DataSource.sample;
  final sources = [analysis.competitors.source, analysis.context?.source];
  if (sources.contains(DataSource.cached)) return DataSource.cached;
  return DataSource.live;
}

/// One row of the Saved Analyses list. Built from the summary columns only,
/// so a damaged evidence snapshot never hides the record or blocks deleting
/// it. [isReadable] is false when even the summary columns are unusable.
@immutable
class SavedAnalysisSummary {
  const SavedAnalysisSummary({
    required this.id,
    required this.savedAt,
    required this.latitude,
    required this.longitude,
    required this.siteLabel,
    required this.category,
    required this.radius,
    required this.source,
    required this.total,
    required this.retrievedAt,
  }) : isReadable = true;

  const SavedAnalysisSummary.unreadable({required this.id, this.savedAt})
    : latitude = null,
      longitude = null,
      siteLabel = null,
      category = null,
      radius = null,
      source = null,
      total = null,
      retrievedAt = null,
      isReadable = false;

  final int id;
  final DateTime? savedAt;
  final double? latitude;
  final double? longitude;
  final String? siteLabel;
  final BusinessCategory? category;
  final SearchRadius? radius;
  final DataSource? source;

  /// Total saved at the time, or null for "Insufficient data".
  final double? total;

  /// When the oldest piece of evidence was originally retrieved.
  final DateTime? retrievedAt;
  final bool isReadable;

  String? get coordinatesLabel => latitude == null || longitude == null
      ? null
      : '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
}

/// A fully reopened saved analysis, rebuilt offline from its stored
/// evidence. Nothing in it is refreshed: timestamps and sources are the
/// originals.
@immutable
class SavedAnalysis {
  const SavedAnalysis({
    required this.id,
    required this.savedAt,
    required this.site,
    required this.analysis,
    required this.savedTotal,
  });

  final int id;
  final DateTime savedAt;
  final SelectedSite site;

  /// Rebuilt with the app's scoring rules from the stored evidence.
  final SiteAnalysis analysis;

  /// The total shown when the record was saved.
  final double? savedTotal;

  DataSource get source => overallSource(analysis);

  /// False if the scoring rules changed since saving, so the rebuilt total
  /// differs from the stored one.
  bool get scoreMatchesSaved {
    final now = analysis.score.total;
    if (now == null || savedTotal == null) return now == savedTotal;
    return (now - savedTotal!).abs() < 0.05;
  }
}

/// A database or file-system problem. The message is safe to show.
class SavedAnalysisStorageException implements Exception {
  const SavedAnalysisStorageException(this.message);

  final String message;

  @override
  String toString() => 'SavedAnalysisStorageException($message)';
}

/// The record does not exist (for example it was deleted elsewhere).
class SavedAnalysisNotFoundException implements Exception {
  const SavedAnalysisNotFoundException(this.id);

  final int id;

  @override
  String toString() => 'SavedAnalysisNotFoundException($id)';
}

/// The stored evidence is malformed or from an unknown format version.
class SavedAnalysisCorruptException implements Exception {
  const SavedAnalysisCorruptException(this.id, this.reason);

  final int id;
  final String reason;

  @override
  String toString() => 'SavedAnalysisCorruptException($id: $reason)';
}
