import '../../../core/models/search_radius.dart';
import '../../../core/utils/geo.dart';
import '../../discovery/domain/competitors.dart';
import '../domain/site_context.dart';
import '../domain/suitability_scoring.dart';

/// Builds the single bounded Overpass request for scoring evidence:
/// complementary places within the search radius plus qualifying `highway`
/// ways within [SuitabilityRules.roadSearchMeters] of the site.
abstract final class SiteContextQuery {
  static const serverTimeoutSeconds = 25;

  /// Caps on returned elements, to keep responses small.
  static const maxPlaces = 400;
  static const maxRoads = 200;
  static const maxRadiusMeters = SearchRadius.maxMeters;

  static final _tagPattern = RegExp(r'^[a-z][a-z0-9_:]*$');

  static String build(CompetitorQuery query) {
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

    final byKey = <String, List<String>>{};
    for (final (key, value) in ComplementaryTags.forCategory(query.category)) {
      byKey.putIfAbsent(key, () => []).add(value);
    }
    final places = [
      for (final MapEntry(:key, :value) in byKey.entries)
        'nwr(around:$radius,$lat,$lon)["$key"~"^(${_values(value)})\$"];',
    ].join();
    final roads = _values(RoadKinds.all);

    return '[out:json][timeout:$serverTimeoutSeconds];'
        '($places)->.places;'
        'way(around:${SuitabilityRules.roadSearchMeters},$lat,$lon)'
        '["highway"~"^($roads)\$"]->.roads;'
        '.places out center $maxPlaces;'
        '.roads out geom $maxRoads;';
  }

  static String _values(List<String> values) {
    for (final value in values) {
      if (!_tagPattern.hasMatch(value)) {
        throw ArgumentError('Unsupported OSM tag value "$value"');
      }
    }
    return values.join('|');
  }
}
