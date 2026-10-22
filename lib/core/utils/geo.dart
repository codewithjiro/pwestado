import 'dart:math' as math;

/// Mean Earth radius used by the haversine formula, in meters.
const earthRadiusMeters = 6371008.8;

double _rad(double degrees) => degrees * math.pi / 180;
double _deg(double radians) => radians * 180 / math.pi;

/// Great-circle distance between two WGS84 points, in meters.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
}

/// The point [meters] away from a start point along [bearingDegrees]
/// (0 = north, clockwise). Returns `(latitude, longitude)`.
(double, double) destinationPoint(
  double latitude,
  double longitude,
  double bearingDegrees,
  double meters,
) {
  final angular = meters / earthRadiusMeters;
  final bearing = _rad(bearingDegrees);
  final lat1 = _rad(latitude);
  final lon1 = _rad(longitude);
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(angular) +
        math.cos(lat1) * math.sin(angular) * math.cos(bearing),
  );
  final lon2 =
      lon1 +
      math.atan2(
        math.sin(bearing) * math.sin(angular) * math.cos(lat1),
        math.cos(angular) - math.sin(lat1) * math.sin(lat2),
      );
  return (_deg(lat2), (_deg(lon2) + 540) % 360 - 180);
}

/// Shortest distance in meters from a point to a polyline of `(lat, lon)`
/// vertices. Uses a local flat projection around the point, which is
/// accurate to well under a meter at the few-hundred-meter scale it is used
/// for. Returns null for an empty polyline.
double? distanceToPolylineMeters(
  double latitude,
  double longitude,
  List<(double, double)> polyline,
) {
  if (polyline.isEmpty) return null;
  const metersPerDegree = earthRadiusMeters * math.pi / 180;
  final cosLat = math.cos(_rad(latitude));
  (double, double) project((double, double) p) => (
    (p.$2 - longitude) * cosLat * metersPerDegree,
    (p.$1 - latitude) * metersPerDegree,
  );

  var best = double.infinity;
  var previous = project(polyline.first);
  if (polyline.length == 1) {
    return math.sqrt(previous.$1 * previous.$1 + previous.$2 * previous.$2);
  }
  for (final vertex in polyline.skip(1)) {
    final current = project(vertex);
    best = math.min(best, _distanceToSegment(previous, current));
    previous = current;
  }
  return best;
}

/// Distance from the origin to segment [a]-[b] in projected meters.
double _distanceToSegment((double, double) a, (double, double) b) {
  final (ax, ay) = a;
  final dx = b.$1 - ax;
  final dy = b.$2 - ay;
  final lengthSquared = dx * dx + dy * dy;
  final t = lengthSquared == 0
      ? 0.0
      : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
  final x = ax + t * dx;
  final y = ay + t * dy;
  return math.sqrt(x * x + y * y);
}

bool isValidCoordinate(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;

/// "85 m", "990 m", "1.2 km". Rounded to 10 m: map coordinates and way
/// centers are not precise enough to justify single meters.
String formatDistance(double meters) {
  if (meters < 995) {
    final rounded = (meters / 10).round() * 10;
    return '${rounded < 10 ? '<10' : rounded} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
