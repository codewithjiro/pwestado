import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/redact.dart';
import '../domain/competitors.dart';
import 'overpass_cache.dart';
import 'overpass_client.dart';
import 'overpass_parser.dart';
import 'overpass_query.dart';

export 'overpass_client.dart'
    show OverpassConfig, classifyDioException, createOverpassDio;

abstract interface class CompetitorRepository {
  /// Mapped businesses for [query]. Serves a fresh cached copy unless
  /// [forceRefresh]. Throws [CompetitorFetchException] or
  /// [CompetitorSearchCancelled].
  Future<CompetitorResult> fetch(
    CompetitorQuery query, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  });
}

class OverpassCompetitorRepository implements CompetitorRepository {
  OverpassCompetitorRepository({
    Dio? dio,
    String endpoint = OverpassConfig.endpoint,
    DateTime Function()? clock,
    Duration retryDelay = const Duration(seconds: 3),
    Duration cacheTtl = OverpassConfig.cacheTtl,
    this.refreshCooldown = const Duration(seconds: 30),
    int maxCacheEntries = 24,
    int maxAttempts = 2,
    int maxServerBusyAttempts = 3,
  }) : _clock = clock ?? DateTime.now,
       _client = OverpassClient(
         dio: dio,
         endpoint: endpoint,
         retryDelay: retryDelay,
         maxAttempts: maxAttempts,
         maxServerBusyAttempts: maxServerBusyAttempts,
       ) {
    _cache = OverpassCache(
      ttl: cacheTtl,
      maxEntries: maxCacheEntries,
      clock: _clock,
      fetchedAt: (r) => r.fetchedAt,
      relabel: (r) => r.withSource(DataSource.cached),
    );
  }

  final OverpassClient _client;
  final DateTime Function() _clock;
  late final OverpassCache<CompetitorResult> _cache;

  /// A forced refresh within this window of the last live fetch returns the
  /// cached copy instead of hitting the shared server again.
  final Duration refreshCooldown;

  /// Number of HTTP requests sent; for tests and diagnostics.
  int get requestCount => _client.requestCount;

  @override
  Future<CompetitorResult> fetch(
    CompetitorQuery query, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final cached = _cache.lookup(
      query.cacheKey,
      maxAge: forceRefresh ? refreshCooldown : null,
    );
    if (cached != null) return cached;

    final ql = OverpassQuery.competitors(query);
    final data = await _client.post(ql, cancelToken);

    final OverpassParseResult parsed;
    try {
      parsed = parseOverpassResponse(
        data,
        originLatitude: query.latitude,
        originLongitude: query.longitude,
      );
    } on FormatException catch (e) {
      debugPrint('Overpass parse failed: ${describeError(e)}');
      throw const CompetitorFetchException(CompetitorFailure.badResponse);
    }
    throwOnOverpassRuntimeError(parsed.remark);

    final result = CompetitorResult(
      query: query,
      businesses: parsed.businesses,
      fetchedAt: _clock(),
      source: DataSource.live,
      skippedCount: parsed.skippedCount,
      possiblyTruncated: parsed.elementCount >= OverpassQuery.maxResults,
    );
    _cache.store(query.cacheKey, result);
    return result;
  }
}

final competitorRepositoryProvider = Provider<CompetitorRepository>(
  (ref) => OverpassCompetitorRepository(),
);
