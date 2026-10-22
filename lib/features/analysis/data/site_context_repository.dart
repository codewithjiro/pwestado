import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/redact.dart';
import '../../discovery/data/overpass_cache.dart';
import '../../discovery/data/overpass_client.dart';
import '../../discovery/domain/competitors.dart';
import '../domain/site_context.dart';
import 'site_context_parser.dart';
import 'site_context_query.dart';

abstract interface class SiteContextRepository {
  /// Complementary places and mapped roads around [query]'s site. Serves a
  /// fresh cached copy unless [forceRefresh]. Throws
  /// [CompetitorFetchException] or [CompetitorSearchCancelled].
  Future<SiteContextResult> fetch(
    CompetitorQuery query, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  });
}

class OverpassSiteContextRepository implements SiteContextRepository {
  OverpassSiteContextRepository({
    OverpassClient? client,
    DateTime Function()? clock,
    Duration cacheTtl = OverpassConfig.cacheTtl,
    this.refreshCooldown = const Duration(seconds: 30),
    int maxCacheEntries = 24,
  }) : _client = client ?? OverpassClient(),
       _clock = clock ?? DateTime.now {
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
  late final OverpassCache<SiteContextResult> _cache;

  /// A forced refresh this soon after a live fetch reuses the cached copy.
  final Duration refreshCooldown;

  /// Number of HTTP requests sent; for tests and diagnostics.
  int get requestCount => _client.requestCount;

  @override
  Future<SiteContextResult> fetch(
    CompetitorQuery query, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final cached = _cache.lookup(
      query.cacheKey,
      maxAge: forceRefresh ? refreshCooldown : null,
    );
    if (cached != null) return cached;

    final data = await _client.post(SiteContextQuery.build(query), cancelToken);

    final SiteContextParseResult parsed;
    try {
      parsed = parseSiteContextResponse(
        data,
        originLatitude: query.latitude,
        originLongitude: query.longitude,
        category: query.category,
        radiusMeters: query.radius.meters,
      );
    } on FormatException catch (e) {
      debugPrint('Overpass context parse failed: ${describeError(e)}');
      throw const CompetitorFetchException(CompetitorFailure.badResponse);
    }
    throwOnOverpassRuntimeError(parsed.remark);

    final result = SiteContextResult(
      query: query,
      complementary: parsed.complementary,
      roads: parsed.roads,
      fetchedAt: _clock(),
      source: DataSource.live,
      skippedCount: parsed.skippedCount,
    );
    _cache.store(query.cacheKey, result);
    return result;
  }
}

final siteContextRepositoryProvider = Provider<SiteContextRepository>(
  (ref) => OverpassSiteContextRepository(),
);
