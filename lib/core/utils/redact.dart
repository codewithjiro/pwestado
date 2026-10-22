/// Helpers for logging errors without leaking secrets.
///
/// SDK and HTTP error messages can embed request URLs that carry the Mapbox
/// access token (`?access_token=pk...`). Everything that reaches a log goes
/// through [redactSecrets] first.
library;

final _urlQuery = RegExp(r'''(https?://[^\s?#"'<>]+)\?[^\s"'<>]*''');
final _tokenParam = RegExp(
  r'''((?:access_)?token|api_?key|key|secret|sku)=[^&\s"'<>]+''',
  caseSensitive: false,
);
final _mapboxToken = RegExp(r'\b(pk|sk|tk)\.[A-Za-z0-9_\-.]{8,}');

/// Removes URL query strings, `token=`-style parameters, and anything shaped
/// like a Mapbox token, then caps the length. Keeps the rest (status codes,
/// hosts, paths, error kinds) because that is what makes a log useful.
String redactSecrets(Object? value, {int maxLength = 300}) {
  var text = '$value';
  text = text.replaceAllMapped(_urlQuery, (m) => '${m[1]}?<query redacted>');
  text = text.replaceAllMapped(_tokenParam, (m) => '${m[1]}=<redacted>');
  text = text.replaceAllMapped(_mapboxToken, (m) => '${m[1]}.<redacted>');
  if (text.length > maxLength) text = '${text.substring(0, maxLength)}…';
  return text;
}

/// `Type: redacted message`, for debug logs.
String describeError(Object error) =>
    '${error.runtimeType}: ${redactSecrets(error)}';
