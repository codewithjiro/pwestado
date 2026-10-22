import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

/// Test double: every fetch waits on its own completer in [pending] unless
/// [respond] is set. Honors cancellation unless [ignoreCancel].
class FakeCompetitorRepository implements CompetitorRepository {
  FakeCompetitorRepository({this.respond});

  FutureOr<CompetitorResult> Function(CompetitorQuery query)? respond;
  bool ignoreCancel = false;

  final calls = <({CompetitorQuery query, bool forceRefresh})>[];
  final pending = <Completer<CompetitorResult>>[];
  final tokens = <CancelToken?>[];

  @override
  Future<CompetitorResult> fetch(
    CompetitorQuery query, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    calls.add((query: query, forceRefresh: forceRefresh));
    tokens.add(cancelToken);
    final respond = this.respond;
    if (respond != null) return respond(query);

    final completer = Completer<CompetitorResult>();
    pending.add(completer);
    if (!ignoreCancel) {
      cancelToken?.whenCancel.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(const CompetitorSearchCancelled());
        }
      });
    }
    return completer.future;
  }
}

NearbyBusiness business(
  int id, {
  String? name,
  double distance = 100,
  String type = 'node',
}) => NearbyBusiness(
  osmType: type,
  osmId: id,
  name: name,
  latitude: 15.0939 + id / 100000,
  longitude: 120.7681,
  distanceMeters: distance,
);

CompetitorResult resultFor(
  CompetitorQuery query,
  List<NearbyBusiness> businesses, {
  DataSource source = DataSource.live,
  DateTime? fetchedAt,
}) => CompetitorResult(
  query: query,
  businesses: businesses,
  fetchedAt: fetchedAt ?? DateTime.now(),
  source: source,
);
