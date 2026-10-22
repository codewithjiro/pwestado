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
