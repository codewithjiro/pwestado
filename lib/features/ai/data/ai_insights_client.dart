import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/data/overpass_client.dart';
import '../domain/ai_insight.dart';

/// Build-time AI configuration. Neither value is a secret:
///
/// * `AI_INSIGHTS_URL` is the public address of the PWESTADO AI proxy
///   (see `backend/ai-insights-worker`). The Gemini API key lives only in
///   that server's secret store and is never sent to or stored on phones.
/// * `AI_CLIENT_ID` is an optional app identifier the proxy can require and
///   rotate to cut off abuse. Anything inside an APK can be extracted, so
///   real protection comes from the proxy's rate and spending limits.
abstract final class AiConfig {
  static const endpoint = String.fromEnvironment('AI_INSIGHTS_URL');
  static const clientId = String.fromEnvironment('AI_CLIENT_ID');

  static bool get isConfigured => isValidEndpoint(endpoint);

  /// Only HTTPS endpoints are accepted, so evidence never travels in clear.
  static bool isValidEndpoint(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}

/// Talks to the PWESTADO AI proxy. One request per explicit tap; no
/// automatic retries (each call can cost money).
class AiInsightsClient {
  AiInsightsClient({
    Dio? dio,
    this.endpoint = AiConfig.endpoint,
    this.clientId = AiConfig.clientId,
  }) : _dio = dio ?? createAiDio();

  static const path = '/v1/insights';

  final Dio _dio;
  final String endpoint;
  final String clientId;

  bool get isConfigured => AiConfig.isValidEndpoint(endpoint);

  Future<AiInsight> fetch(
    Map<String, Object?> payload, {
    required bool isDemo,
    CancelToken? cancelToken,
  }) async {
    if (!isConfigured) {
      throw const AiInsightException(AiFailure.notConfigured);
    }
    final base = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final response = await _dio.post<Object?>(
        '$base$path',
        data: payload,
        cancelToken: cancelToken,
        options: Options(
          headers: {'X-Pwestado-Client': ?(clientId.isEmpty ? null : clientId)},
        ),
      );
      try {
        return AiInsight.parse(response.data, requestWasDemo: isDemo);
      } on FormatException catch (e) {
        debugPrint('AI response rejected: ${e.message}');
        throw const AiInsightException(AiFailure.invalidResponse);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw AiInsightException(
        classifyAiError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }
}

/// Maps transport and HTTP errors to user-facing failure kinds. Response
/// bodies are only inspected for the proxy's own `error.code` field.
@visibleForTesting
AiFailure classifyAiError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return AiFailure.timeout;
    case DioExceptionType.connectionError:
      return AiFailure.offline;
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      final code = body is Map && body['error'] is Map
          ? (body['error'] as Map)['code']
          : null;
      return switch (status) {
        401 || 403 => AiFailure.unauthorized,
        429 when code == 'daily_limit' || code == 'quota' =>
          AiFailure.quotaExhausted,
        429 => AiFailure.rateLimited,
        400 || 413 || 422 => AiFailure.badRequest,
        504 => AiFailure.timeout,
        502 when code == 'invalid_output' => AiFailure.invalidResponse,
        _ => AiFailure.unavailable,
      };
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return AiFailure.unavailable;
  }
}

Dio createAiDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    // The proxy gives the model 20 s; allow for the round trip.
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {'User-Agent': OverpassConfig.userAgent},
  ),
);

final aiInsightsClientProvider = Provider<AiInsightsClient>(
  (ref) => AiInsightsClient(),
);
