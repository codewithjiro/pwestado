import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/redact.dart';
import '../domain/competitors.dart';
import 'overpass_parser.dart';
import 'overpass_query.dart';

abstract final class OverpassConfig {
  /// Public Overpass interpreter. Override at build time with
  /// `--dart-define=OVERPASS_ENDPOINT=https://...`.
  static const endpoint = String.fromEnvironment(
    'OVERPASS_ENDPOINT',
    defaultValue: 'https://overpass-api.de/api/interpreter',
  );

  /// Overpass rejects requests without a User-Agent (HTTP 406) and asks
  /// clients to identify themselves.
  static const userAgent =
      'PWESTADO/1.0 (student pitch prototype; Flutter/Dio; '
      '+https://github.com/codewithjiro/pwestado)';

  static const connectTimeout = Duration(seconds: 15);

  /// Public servers often queue requests; 40 s responses are common.
  static const receiveTimeout = Duration(seconds: 60);
}

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
    this.endpoint = OverpassConfig.endpoint,
    DateTime Function()? clock,
    this.retryDelay = const Duration(seconds: 3),
    this.cacheTtl = const Duration(minutes: 15),
    this.refreshCooldown = const Duration(seconds: 30),
    this.maxCacheEntries = 24,
    this.maxAttempts = 2,
    this.maxServerBusyAttempts = 3,
  }) : _dio = dio ?? createOverpassDio(),
       _clock = clock ?? DateTime.now;

  final Dio _dio;
  final String endpoint;
  final DateTime Function() _clock;
  final Duration retryDelay;

  /// How long a live response is reused for the same query.
  final Duration cacheTtl;

  /// A forced refresh within this window of the last live fetch returns the
  /// cached copy instead of hitting the shared server again.
  final Duration refreshCooldown;
  final int maxCacheEntries;

  /// Total tries for a dropped connection (one retry).
  final int maxAttempts;

  /// Total tries for 502/503/504. The public gateway often rejects requests
  /// within a second under load and accepts them moments later, so these
  /// cheap failures get one extra retry. 429 is never retried.
  final int maxServerBusyAttempts;

  /// Insertion-ordered (Dart's default map), oldest first, for eviction.
  final _cache = <String, CompetitorResult>{};

  /// Number of HTTP requests sent; for tests and diagnostics.
  int requestCount = 0;

  @override
  Future<CompetitorResult> fetch(
    CompetitorQuery query, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final cached = _cached(
      query,
      maxAge: forceRefresh ? refreshCooldown : null,
    );
    if (cached != null) return cached;

    final ql = OverpassQuery.competitors(query);
    final data = await _post(ql, cancelToken);

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
    if (parsed.hasRuntimeError) {
      // Overpass answers 200 with a remark when the query itself timed out
      // or ran out of memory; the element list is then incomplete.
      debugPrint('Overpass runtime error: ${redactSecrets(parsed.remark)}');
      throw CompetitorFetchException(
        parsed.remark!.contains('timed out')
            ? CompetitorFailure.timeout
            : CompetitorFailure.serverBusy,
      );
    }

    final result = CompetitorResult(
      query: query,
      businesses: parsed.businesses,
      fetchedAt: _clock(),
      source: DataSource.live,
      skippedCount: parsed.skippedCount,
      possiblyTruncated: parsed.elementCount >= OverpassQuery.maxResults,
    );
    _store(query, result);
    return result;
  }

  /// The cached result for [query] if younger than [maxAge] (default
  /// [cacheTtl]), labeled [DataSource.cached].
  CompetitorResult? _cached(CompetitorQuery query, {Duration? maxAge}) {
    final entry = _cache[query.cacheKey];
    if (entry == null) return null;
    final age = _clock().difference(entry.fetchedAt);
    if (age > cacheTtl) {
      _cache.remove(query.cacheKey);
      return null;
    }
    if (age > (maxAge ?? cacheTtl)) return null;
    return entry.withSource(DataSource.cached);
  }

  void _store(CompetitorQuery query, CompetitorResult result) {
    _cache
      ..remove(query.cacheKey)
      ..[query.cacheKey] = result;
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<Object?> _post(String ql, CancelToken? cancelToken) async {
    for (var attempt = 1; ; attempt++) {
      try {
        requestCount++;
        final response = await _dio.post<Object?>(
          endpoint,
          data: {'data': ql},
          cancelToken: cancelToken,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.json,
          ),
        );
        final data = response.data;
        // Some servers label JSON as text; decode it ourselves.
        if (data is String) {
          try {
            return jsonDecode(data);
          } on FormatException {
            throw const CompetitorFetchException(CompetitorFailure.badResponse);
          }
        }
        return data;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) throw const CompetitorSearchCancelled();
        final failure = classifyDioException(e);
        final status = e.response?.statusCode;
        debugPrint(
          'Overpass request failed (attempt $attempt): ${failure.name}'
          '${status == null ? '' : ' HTTP $status'} '
          '(${describeError(e.error ?? e.type)})',
        );
        final limit = failure == CompetitorFailure.serverBusy
            ? maxServerBusyAttempts
            : maxAttempts;
        if (attempt < limit && failure.isRetryable) {
          // Linear backoff: 3 s, then 6 s.
          await Future<void>.delayed(retryDelay * attempt);
          if (cancelToken?.isCancelled ?? false) {
            throw const CompetitorSearchCancelled();
          }
          continue;
        }
        throw CompetitorFetchException(
          failure,
          statusCode: e.response?.statusCode,
        );
      }
    }
  }
}

/// Maps a Dio error to a user-facing failure kind.
CompetitorFailure classifyDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return CompetitorFailure.timeout;
    case DioExceptionType.badResponse:
      return switch (e.response?.statusCode) {
        429 => CompetitorFailure.rateLimited,
        502 || 503 || 504 => CompetitorFailure.serverBusy,
        _ => CompetitorFailure.badResponse,
      };
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return CompetitorFailure.network;
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      final cause = e.error;
      return cause is SocketException ||
              cause is HttpException ||
              cause is HandshakeException
          ? CompetitorFailure.network
          : CompetitorFailure.badResponse;
  }
}

Dio createOverpassDio() => Dio(
  BaseOptions(
    connectTimeout: OverpassConfig.connectTimeout,
    sendTimeout: OverpassConfig.connectTimeout,
    receiveTimeout: OverpassConfig.receiveTimeout,
    headers: {
      HttpHeaders.userAgentHeader: OverpassConfig.userAgent,
      HttpHeaders.acceptHeader: 'application/json',
    },
  ),
);

final competitorRepositoryProvider = Provider<CompetitorRepository>(
  (ref) => OverpassCompetitorRepository(),
);
