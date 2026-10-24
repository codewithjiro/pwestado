import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/redact.dart';
import '../domain/place.dart';

abstract final class GeocodingConfig {
  static const endpoint = 'https://api.mapbox.com/search/geocode/v6';

  /// Results are limited to the Philippines, where the pitch takes place.
  static const country = 'ph';

  static const timeout = Duration(seconds: 12);
  static const maxResults = 5;
}

/// Mapbox Geocoding v6 (temporary results) with the app's public token.
/// Called only on explicit actions: submitting a search, or choosing a site.
class GeocodingClient {
  GeocodingClient({Dio? dio, required this.accessToken})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: GeocodingConfig.endpoint,
              connectTimeout: GeocodingConfig.timeout,
              receiveTimeout: GeocodingConfig.timeout,
              sendTimeout: GeocodingConfig.timeout,
            ),
          );

  final Dio _dio;
  final String accessToken;

  /// Number of HTTP requests sent; for tests.
  int requestCount = 0;

  /// Places matching [query], nearest to [near] first when given.
  Future<List<PlaceResult>> forward(
    String query, {
    ({double latitude, double longitude})? near,
    CancelToken? cancelToken,
  }) async {
    final json = await _get('/forward', {
      'q': query,
      'country': GeocodingConfig.country,
      'limit': GeocodingConfig.maxResults,
      'language': 'en',
      if (near != null) 'proximity': '${near.longitude},${near.latitude}',
    }, cancelToken);
    return parseGeocodingFeatures(json);
  }

  /// The nearest address, street or area to a point, or null if Mapbox has
  /// nothing there.
  Future<PlaceResult?> reverse(
    double latitude,
    double longitude, {
    CancelToken? cancelToken,
  }) async {
    final json = await _get('/reverse', {
      'latitude': latitude,
      'longitude': longitude,
      'limit': 1,
      'language': 'en',
    }, cancelToken);
    final places = parseGeocodingFeatures(json);
    return places.isEmpty ? null : places.first;
  }

  Future<Object?> _get(
    String path,
    Map<String, Object> query,
    CancelToken? cancelToken,
  ) async {
    try {
      requestCount++;
      final response = await _dio.get<Object?>(
        path,
        queryParameters: {...query, 'access_token': accessToken},
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw const GeocodingCancelled();
      final failure = classifyGeocodingError(e);
      // Never log the request URL: it carries the token.
      debugPrint(
        'Geocoding request failed: ${failure.name}'
        '${e.response?.statusCode == null ? '' : ' HTTP ${e.response?.statusCode}'}'
        ' (${describeError(e.error ?? e.type)})',
      );
      throw GeocodingException(failure, statusCode: e.response?.statusCode);
    }
  }
}

GeocodingFailure classifyGeocodingError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return GeocodingFailure.timeout;
    case DioExceptionType.badResponse:
      return switch (e.response?.statusCode) {
        401 || 403 => GeocodingFailure.unauthorized,
        429 => GeocodingFailure.rateLimited,
        _ => GeocodingFailure.badResponse,
      };
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return GeocodingFailure.network;
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      final cause = e.error;
      return cause is SocketException || cause is HttpException
          ? GeocodingFailure.network
          : GeocodingFailure.badResponse;
  }
}

/// Reads a Geocoding v6 FeatureCollection. Features without a name or
/// coordinates are skipped rather than guessed at.
List<PlaceResult> parseGeocodingFeatures(Object? json) {
  if (json is! Map || json['features'] is! List) {
    throw const GeocodingException(GeocodingFailure.badResponse);
  }
  final places = <PlaceResult>[];
  for (final feature in json['features'] as List) {
    if (feature is! Map) continue;
    final props = feature['properties'];
    if (props is! Map) continue;
    final name = (props['name_preferred'] ?? props['name']);
    final coords = props['coordinates'];
    if (name is! String || name.trim().isEmpty || coords is! Map) continue;
    final lat = coords['latitude'];
    final lon = coords['longitude'];
    if (lat is! num || lon is! num) continue;
    final formatted = props['place_formatted'];
    places.add(
      PlaceResult(
        id: '${props['mapbox_id'] ?? feature['id'] ?? '$lat,$lon'}',
        name: name.trim(),
        placeFormatted: formatted is String && formatted.trim().isNotEmpty
            ? formatted.trim()
            : null,
        featureType: props['feature_type'] as String?,
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
      ),
    );
  }
  return places;
}
