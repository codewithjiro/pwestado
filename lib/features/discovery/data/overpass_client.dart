import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/redact.dart';
import '../domain/competitors.dart';

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

/// Sends Overpass QL with a small, polite retry policy. Shared by every
/// Overpass-backed repository so they fail and retry the same way.
class OverpassClient {
  OverpassClient({
    Dio? dio,
    this.endpoint = OverpassConfig.endpoint,
    this.retryDelay = const Duration(seconds: 3),
    this.maxAttempts = 2,
    this.maxServerBusyAttempts = 3,
  }) : _dio = dio ?? createOverpassDio();

  final Dio _dio;
  final String endpoint;
  final Duration retryDelay;

  /// Total tries for a dropped connection (one retry).
  final int maxAttempts;

  /// Total tries for 502/503/504. The public gateway often rejects requests
  /// within a second under load and accepts them moments later, so these
  /// cheap failures get one extra retry. 429 is never retried.
  final int maxServerBusyAttempts;

  /// Number of HTTP requests sent; for tests and diagnostics.
  int requestCount = 0;

  /// POSTs [ql] as form data and returns the decoded JSON body. Throws
  /// [CompetitorFetchException] or [CompetitorSearchCancelled].
  Future<Object?> post(String ql, CancelToken? cancelToken) async {
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

/// Throws when an Overpass payload reports a server-side runtime error.
/// Overpass answers 200 with a remark when the query itself timed out or ran
/// out of memory; the element list is then incomplete.
void throwOnOverpassRuntimeError(String? remark) {
  if (remark == null || !remark.contains('runtime error')) return;
  debugPrint('Overpass runtime error: ${redactSecrets(remark)}');
  throw CompetitorFetchException(
    remark.contains('timed out')
        ? CompetitorFailure.timeout
        : CompetitorFailure.serverBusy,
  );
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
