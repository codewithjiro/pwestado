/// Whether the Mapbox token supplied at build time can be used.
enum MapboxTokenStatus {
  /// A public `pk.` token was supplied.
  ok,

  /// No `--dart-define=ACCESS_TOKEN=...` was passed to the build.
  missing,

  /// A secret `sk.` token was supplied. Secret tokens must never ship in a
  /// mobile app, so the app refuses to use it.
  secret,

  /// Something was supplied, but it is not a Mapbox public token.
  invalid,
}

abstract final class MapboxConfig {
  /// Public Mapbox token injected with
  /// `flutter run --dart-define="ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN"`.
  /// Never hardcode a token here and never log its value.
  static const accessToken = String.fromEnvironment('ACCESS_TOKEN');

  static MapboxTokenStatus get tokenStatus => checkToken(accessToken);

  static MapboxTokenStatus checkToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return MapboxTokenStatus.missing;
    if (trimmed.startsWith('sk.')) return MapboxTokenStatus.secret;
    if (!trimmed.startsWith('pk.')) return MapboxTokenStatus.invalid;
    return MapboxTokenStatus.ok;
  }
}

/// Default map view: approximate municipal reference center of Santa Ana,
/// Pampanga. It is a starting viewport, not a recommended business lot.
abstract final class MapDefaults {
  static const latitude = 15.0939;
  static const longitude = 120.7681;
  static const zoom = 14.5;

  /// Zoom used when jumping to the user's GPS position.
  static const siteZoom = 16.0;
}
