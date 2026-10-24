import 'package:dio/dio.dart';
import 'package:pwestado/features/places/data/place_repository.dart';
import 'package:pwestado/features/places/domain/place.dart';

/// In-memory places: fixed search results, a configurable reverse label,
/// and call counters. Never touches the network.
class FakePlaceRepository implements PlaceRepository {
  FakePlaceRepository({this.label = const PlaceLabel(title: 'Near Test Road')});

  static const sanFernando = PlaceResult(
    id: 'place.sf',
    name: 'San Fernando',
    placeFormatted: 'Pampanga, Philippines',
    featureType: 'place',
    latitude: 15.027807,
    longitude: 120.69343,
  );

  List<PlaceResult> results = [sanFernando];
  GeocodingFailure? failure;

  /// Returned by [labelFor] (unless [labelOf] is set); set [labelFailure]
  /// to make lookups fail.
  PlaceLabel label;
  PlaceLabel Function(GeoPoint point)? labelOf;
  GeocodingFailure? labelFailure;

  final searches = <String>[];
  int reverseLookups = 0;
  final _remembered = <String, PlaceLabel>{};

  static String _key(GeoPoint p) => '${p.latitude},${p.longitude}';

  @override
  Future<List<PlaceResult>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancelToken,
  }) async {
    searches.add(query);
    final failure = this.failure;
    if (failure != null) throw GeocodingException(failure);
    return results;
  }

  @override
  Future<PlaceLabel> labelFor(GeoPoint point) async {
    final remembered = _remembered[_key(point)];
    if (remembered != null) return remembered;
    reverseLookups++;
    final failure = labelFailure;
    if (failure != null) throw GeocodingException(failure);
    return labelOf?.call(point) ?? label;
  }

  @override
  void remember(GeoPoint point, PlaceLabel label) {
    _remembered[_key(point)] = label;
  }

  @override
  PlaceLabel? cachedLabel(GeoPoint point) => _remembered[_key(point)];
}
