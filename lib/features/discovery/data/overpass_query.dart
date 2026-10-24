import '../../../core/models/search_radius.dart';
import '../../../core/utils/geo.dart';
import '../domain/competitors.dart';

/// Builds Overpass QL for a competitor search.
///
/// Every interpolated value is validated first: the tag key must be on
/// [allowedKeys], the value a plain OSM identifier, coordinates finite and
/// in range, and the radius within [SearchRadius.minMeters]..[maxRadiusMeters],
/// so no user input can change the shape of the query. Tags only ever come
/// from the verified business category catalog, never from typed text.
abstract final class OverpassQuery {
  /// Seconds the Overpass server may spend on the query.
  static const serverTimeoutSeconds = 25;

  /// Upper bound on returned elements, to keep responses small.
  static const maxResults = 500;

  static const maxRadiusMeters = SearchRadius.maxMeters;

  /// The only OSM keys a business category may use.
  static const allowedKeys = {'amenity', 'shop', 'leisure', 'craft'};

  static final _tagPattern = RegExp(r'^[a-z][a-z0-9_:]*$');

  static String competitors(CompetitorQuery query) {
    final key = query.category.osmTagKey;
    final value = query.category.osmTagValue;
    if (!allowedKeys.contains(key) || !_tagPattern.hasMatch(value)) {
      throw ArgumentError('Unsupported OSM tag "$key=$value"');
    }
    if (!isValidCoordinate(query.latitude, query.longitude)) {
      throw ArgumentError('Invalid coordinates');
    }
    final radius = query.radius.meters;
    if (radius < SearchRadius.minMeters || radius > maxRadiusMeters) {
      throw ArgumentError(
        'Radius must be ${SearchRadius.minMeters}..$maxRadiusMeters m',
      );
    }

    final lat = query.latitude.toStringAsFixed(6);
    final lon = query.longitude.toStringAsFixed(6);
    return '[out:json][timeout:$serverTimeoutSeconds];'
        'nwr(around:$radius,$lat,$lon)["$key"="$value"];'
        'out center $maxResults;';
  }
}
