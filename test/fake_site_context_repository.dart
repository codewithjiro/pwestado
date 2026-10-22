import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/analysis/domain/site_context.dart';
import 'package:pwestado/features/analysis/domain/suitability_scoring.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

/// Test double: every fetch waits on its own completer in [pending] unless
/// [respond] is set. Honors cancellation.
class FakeSiteContextRepository implements SiteContextRepository {
  FakeSiteContextRepository({this.respond});

  FutureOr<SiteContextResult> Function(CompetitorQuery query)? respond;

  final calls = <({CompetitorQuery query, bool forceRefresh})>[];
  final pending = <Completer<SiteContextResult>>[];

  @override
  Future<SiteContextResult> fetch(
    CompetitorQuery query, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    calls.add((query: query, forceRefresh: forceRefresh));
    final respond = this.respond;
    if (respond != null) return respond(query);

    final completer = Completer<SiteContextResult>();
    pending.add(completer);
    cancelToken?.whenCancel.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(const CompetitorSearchCancelled());
      }
    });
    return completer.future;
  }
}

/// 6 complementary places (12/100 at 1 km); residential road at 30 m,
/// major road at 120 m.
SiteContextResult contextFor(
  CompetitorQuery query, {
  int complementary = 6,
  DataSource source = DataSource.live,
}) => SiteContextResult(
  query: query,
  complementary: ComplementaryEvidence(
    count: complementary,
    radiusMeters: query.radius.meters,
    countsByKind: {if (complementary > 0) 'school': complementary},
  ),
  roads: const RoadEvidence(
    roadCount: 2,
    nearestRoadMeters: 30,
    nearestRoadKind: 'residential',
    nearestMajorRoadMeters: 120,
  ),
  fetchedAt: DateTime.now(),
  source: source,
);
