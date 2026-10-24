import 'package:dio/dio.dart';

import '../../../core/config/mapbox_config.dart';
import '../domain/place.dart';
import 'geocoding_client.dart';

typedef GeoPoint = ({double latitude, double longitude});

abstract interface class PlaceRepository {
  /// Places matching [query]. Throws [GeocodingException] or
  /// [GeocodingCancelled].
  Future<List<PlaceResult>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancelToken,
  });

  /// Readable label for a chosen point; [PlaceLabel.fallback] when Mapbox
  /// knows nothing there. Throws [GeocodingException] on request failures
  /// so the UI can offer a retry.
  Future<PlaceLabel> labelFor(GeoPoint point);

  /// Records the label of a search result the user picked, so choosing it
  /// does not cost a second (reverse) request.
  void remember(GeoPoint point, PlaceLabel label);

  /// A label already looked up this session, without any request.
  PlaceLabel? cachedLabel(GeoPoint point);
}

/// Mapbox-backed places with a session-only memory cache. Nothing here is
/// persisted: Mapbox's temporary geocoding results may not be retained.
class MapboxPlaceRepository implements PlaceRepository {
  MapboxPlaceRepository(this._client);

  factory MapboxPlaceRepository.fromConfig() => MapboxPlaceRepository(
    MapboxConfig.tokenStatus == MapboxTokenStatus.ok
        ? GeocodingClient(accessToken: MapboxConfig.accessToken)
        : null,
  );

  /// Null when the build has no usable token.
  final GeocodingClient? _client;

  final _labels = <String, PlaceLabel>{};

  static String _key(GeoPoint p) =>
      '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

  @override
  Future<List<PlaceResult>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancelToken,
  }) {
    final client = _client;
    if (client == null) {
      throw const GeocodingException(GeocodingFailure.noToken);
    }
    return client.forward(query, near: near, cancelToken: cancelToken);
  }

  @override
  Future<PlaceLabel> labelFor(GeoPoint point) async {
    final cached = _labels[_key(point)];
    if (cached != null) return cached;
    final client = _client;
    // Without a token there is nothing to ask; the honest fallback is final.
    if (client == null) return PlaceLabel.fallback;
    final place = await client.reverse(point.latitude, point.longitude);
    final label = place == null ? PlaceLabel.fallback : PlaceLabel.near(place);
    _labels[_key(point)] = label;
    return label;
  }

  @override
  void remember(GeoPoint point, PlaceLabel label) {
    _labels[_key(point)] = label;
  }

  @override
  PlaceLabel? cachedLabel(GeoPoint point) => _labels[_key(point)];
}
