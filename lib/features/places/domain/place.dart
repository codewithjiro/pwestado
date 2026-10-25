import 'package:flutter/foundation.dart';

/// One Mapbox Geocoding v6 feature: a searched place or the nearest known
/// address/street/area to a chosen point.
///
/// Mapbox's temporary geocoding results "may not be retained", so these
/// live in memory only and are never written to SQLite. Saved analyses keep
/// the original coordinates and a generic site label instead.
@immutable
class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.placeFormatted,
    this.featureType,
  });

  final String id;

  /// Feature name, e.g. "Baliwag-Candaba-Santa Ana Road" or "San Fernando".
  final String name;

  /// The surrounding area, e.g. "Santa Lucia, Santa Ana, Pampanga,
  /// Philippines".
  final String? placeFormatted;

  /// Mapbox `feature_type`: address, street, neighborhood, locality,
  /// place, district, postcode, region, country, ...
  final String? featureType;

  final double latitude;
  final double longitude;

  /// Street-level matches name the nearest address or road, not the exact
  /// lot, so reverse-geocoded labels say "Near ...".
  bool get isStreetLevel => const {
    'address',
    'secondary_address',
    'street',
    'block',
  }.contains(featureType);

  @override
  bool operator ==(Object other) =>
      other is PlaceResult &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(id, latitude, longitude);
}

/// Human-readable label for a chosen site.
@immutable
class PlaceLabel {
  const PlaceLabel({required this.title, this.subtitle, this.approximate});

  /// Label from a reverse lookup at the site's coordinates.
  factory PlaceLabel.near(PlaceResult place) => PlaceLabel(
    title: place.isStreetLevel ? 'Near ${place.name}' : place.name,
    subtitle: place.placeFormatted,
    approximate: true,
  );

  /// Label for a place the user picked from search results; the site is at
  /// that result's own coordinates.
  factory PlaceLabel.searched(PlaceResult place) => PlaceLabel(
    title: place.name,
    subtitle: place.placeFormatted,
    approximate: false,
  );

  /// Honest fallback when no address can be retrieved.
  static const fallback = PlaceLabel(title: 'Selected location');

  final String title;
  final String? subtitle;

  /// True for reverse-geocoded labels, which describe the surroundings.
  /// Null for [fallback].
  final bool? approximate;

  @override
  bool operator ==(Object other) =>
      other is PlaceLabel &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.approximate == approximate;

  @override
  int get hashCode => Object.hash(title, subtitle, approximate);
}

enum GeocodingFailure {
  /// The build has no usable Mapbox token.
  noToken,
  network,
  timeout,
  rateLimited,

  /// HTTP 401/403: the token was rejected or lacks access.
  unauthorized,
  badResponse;

  String get message => switch (this) {
    noToken => 'Place search isn’t available in this version of the app.',
    network => 'No internet connection. Check your connection and try again.',
    timeout => 'The place search took too long. Try again.',
    rateLimited => 'Too many searches right now. Wait a moment and try again.',
    unauthorized => 'Place search is unavailable right now.',
    badResponse => 'The place search returned an unexpected answer.',
  };
}

class GeocodingException implements Exception {
  const GeocodingException(this.failure, {this.statusCode});

  final GeocodingFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'GeocodingException(${failure.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}

class GeocodingCancelled implements Exception {
  const GeocodingCancelled();
}
