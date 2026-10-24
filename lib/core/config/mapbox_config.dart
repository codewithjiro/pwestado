import 'dart:convert';

/// Whether the Mapbox token supplied at build time can be used.
enum MapboxTokenStatus {
  /// A well-formed public `pk.` token was supplied.
  ok,

  /// No `--dart-define=ACCESS_TOKEN=...` was passed to the build.
  missing,

  /// A secret `sk.` token was supplied. Secret tokens must never ship in a
  /// mobile app, so the app refuses to use it.
  secret,

  /// Something was supplied, but it is not a Mapbox public token.
  invalid,

  /// Starts with `pk.` but is not shaped like a Mapbox token
  /// (`pk.<base64 JSON>.<signature>`). Mapbox rejects such values with
  /// "TokenMalformed" and every style request fails with HTTP 401, which
  /// leaves the native map black. Caught here so the app explains it instead.
  malformed,
}

abstract final class MapboxConfig {
  /// Public Mapbox token injected with
  /// `flutter run --dart-define="ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN"`.
  /// Never hardcode a token here and never log its value.
  static const accessToken = String.fromEnvironment('ACCESS_TOKEN');

  static MapboxTokenStatus get tokenStatus => checkToken(accessToken);

  /// Offline shape check only; it cannot tell whether Mapbox still accepts
  /// the token. Runtime rejection is caught by the map's load watchdog.
  static MapboxTokenStatus checkToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return MapboxTokenStatus.missing;
    if (trimmed.startsWith('sk.')) return MapboxTokenStatus.secret;
    if (!trimmed.startsWith('pk.')) return MapboxTokenStatus.invalid;
    final parts = trimmed.split('.');
    if (parts.length != 3 || parts[2].isEmpty || !_isJsonPayload(parts[1])) {
      return MapboxTokenStatus.malformed;
    }
    return MapboxTokenStatus.ok;
  }

  static bool _isJsonPayload(String part) {
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(part))),
      );
      return decoded is Map;
    } on FormatException {
      return false;
    }
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
