import '../../../core/utils/geo.dart';
import '../domain/competitors.dart';

/// Builds Overpass QL for a competitor search.
///
/// Every interpolated value is validated first: tag keys/values must be plain
/// OSM identifiers, coordinates must be finite and in range, and the radius
/// is capped, so no user input can change the shape of the query.
abstract final class OverpassQuery {
  /// Seconds the Overpass server may spend on the query.
  static const serverTimeoutSeconds = 25;

  /// Upper bound on returned elements, to keep responses small.
  static const maxResults = 500;

  static const maxRadiusMeters = 2000;

  static final _tagPattern = RegExp(r'^[a-z][a-z0-9_:]*$');

  static String competitors(CompetitorQuery query) {
    final key = query.category.osmTagKey;
    final value = query.category.osmTagValue;
    if (!_tagPattern.hasMatch(key) || !_tagPattern.hasMatch(value)) {
      throw ArgumentError('Unsupported OSM tag "$key=$value"');
    }
    if (!isValidCoordinate(query.latitude, query.longitude)) {
      throw ArgumentError('Invalid coordinates');
    }
    final radius = query.radius.meters;
    if (radius <= 0 || radius > maxRadiusMeters) {
      throw ArgumentError('Radius must be 1..$maxRadiusMeters m');
    }

    final lat = query.latitude.toStringAsFixed(6);
    final lon = query.longitude.toStringAsFixed(6);
    return '[out:json][timeout:$serverTimeoutSeconds];'
        'nwr(around:$radius,$lat,$lon)["$key"="$value"];'
        'out center $maxResults;';
  }
}
