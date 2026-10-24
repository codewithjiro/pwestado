import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/gemini_local_key.dart';
import '../../discovery/data/overpass_client.dart';
import '../domain/ai_insight.dart';
import 'gemini_request.dart';

/// PRIVATE-DEMO AI configuration: the app calls the Gemini API directly
/// with a key compiled in from the untracked `gemini_local_key.dart`
/// (template: `gemini_local_key.example.dart`). Anyone holding an APK built
/// this way can extract the key, so such APKs must not be shared.
abstract final class AiConfig {
  static const apiKey = geminiApiKey;

  /// Stable model; Google recommends 3.5 Flash-Lite for new projects
  /// (checked against ai.google.dev on 2026-10-24). Override with
  /// `--dart-define=GEMINI_MODEL=...` if Google retires it.
  static const model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash-lite',
  );

  static bool get isConfigured => isUsableKey(apiKey);

  /// Shape check only; Gemini itself decides whether the key is valid.
  static bool isUsableKey(String key) =>
      key.length >= 20 && !RegExp(r'\s').hasMatch(key);

  static bool isValidModel(String model) =>
      RegExp(r'^[a-z0-9.\-]{3,64}$').hasMatch(model);
}

/// Calls Gemini `generateContent` directly. One request per explicit tap;
/// no automatic retries (each call uses quota). The key travels only in the
/// `x-goog-api-key` header, never in the URL, and is never logged.
class AiInsightsClient {
  AiInsightsClient({
    Dio? dio,
    this.apiKey = AiConfig.apiKey,
    this.model = AiConfig.model,
  }) : _dio = dio ?? createAiDio();

  static const baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  final Dio _dio;
  final String apiKey;
  final String model;

  bool get isConfigured =>
      AiConfig.isUsableKey(apiKey) && AiConfig.isValidModel(model);

  Future<AiInsight> fetch(
    Map<String, Object?> payload, {
    required bool isDemo,
    CancelToken? cancelToken,
  }) async {
    if (!isConfigured) {
      throw const AiInsightException(AiFailure.notConfigured);
    }
    final Map<String, Object?> body;
    try {
      body = GeminiRequest.build(payload);
    } on FormatException {
      throw const AiInsightException(AiFailure.badRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        '$baseUrl/models/$model:generateContent',
        data: body,
        cancelToken: cancelToken,
        options: Options(headers: {'x-goog-api-key': apiKey}),
      );
      try {
        final answer = GeminiRequest.extractAnswer(response.data);
        return AiInsight.parse({
          'insight': answer,
          'model': model,
          'demo': isDemo,
        }, requestWasDemo: isDemo);
      } on FormatException catch (e) {
        debugPrint('AI response rejected: ${e.message}');
        throw const AiInsightException(AiFailure.invalidResponse);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      final failure = classifyAiError(e);
      debugPrint(
        'Gemini request failed: ${failure.name} '
        '(HTTP ${e.response?.statusCode ?? '-'})',
      );
      throw AiInsightException(failure, statusCode: e.response?.statusCode);
    }
  }
}

/// Maps transport and Gemini HTTP errors to user-facing failure kinds.
/// Only the error's status/code/reason fields are inspected.
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
      final signals = _errorSignals(e.response?.data);
      bool has(String s) => signals.contains(s.toLowerCase());
      return switch (status) {
        400 when has('api_key_invalid') || has('api key not valid') =>
          AiFailure.unauthorized,
        400 when has('failed_precondition') => AiFailure.unauthorized,
        401 || 403 => AiFailure.unauthorized,
        402 => AiFailure.quotaExhausted,
        404 => AiFailure.modelUnavailable,
        429 when has('quota_exceeded') || has('perday') =>
          AiFailure.quotaExhausted,
        429 => AiFailure.rateLimited,
        400 || 413 || 422 => AiFailure.badRequest,
        408 || 504 => AiFailure.timeout,
        _ => AiFailure.unavailable,
      };
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return AiFailure.unavailable;
  }
}

/// Lower-cased error status, code, reasons, quota ids and message from a
/// Google API error body, joined for simple `contains` checks.
String _errorSignals(Object? body) {
  final error = body is Map ? body['error'] : null;
  if (error is! Map) return '';
  final parts = <Object?>[error['status'], error['code'], error['message']];
  final details = error['details'];
  if (details is List) {
    for (final d in details.whereType<Map>()) {
      parts.add(d['reason']);
      final violations = d['violations'];
      if (violations is List) {
        for (final v in violations.whereType<Map>()) {
          parts.add(v['quotaId']);
        }
      }
    }
  }
  return parts.whereType<Object>().join(' ').toLowerCase();
}

Dio createAiDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {'User-Agent': OverpassConfig.userAgent},
  ),
);

final aiInsightsClientProvider = Provider<AiInsightsClient>(
  (ref) => AiInsightsClient(),
);
