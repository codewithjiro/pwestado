/// A search distance in whole meters, from [minMeters] to [maxMeters].
///
/// Value-based: two radii with the same meters are equal, so a custom
/// "1000" and the "1 km" preset are the same query, cache entry and saved
/// setting. Capped at 2 km to keep Overpass queries small. Pure Dart, so
/// the scoring rules can format distances with it.
class SearchRadius {
  const SearchRadius._(this.meters);

  /// Throws [ArgumentError] outside [minMeters]..[maxMeters]. Use
  /// [tryMeters] or [parse] for values that come from a user or a file.
  factory SearchRadius.meters(int meters) =>
      tryMeters(meters) ??
      (throw ArgumentError.value(
        meters,
        'meters',
        'must be $minMeters..$maxMeters',
      ));

  static const minMeters = 100;
  static const maxMeters = 2000;

  static const m250 = SearchRadius._(250);
  static const m500 = SearchRadius._(500);
  static const km1 = SearchRadius._(1000);
  static const km2 = SearchRadius._(2000);

  /// Quick choices shown before "Custom".
  static const presets = [m250, m500, km1, km2];

  /// Example values shown under the custom distance field.
  static const examples = [300, 750, 1500];

  final int meters;

  bool get isPreset => presets.contains(this);

  /// "750 m", "1 km", "1.5 km", "1,250 m".
  String get label => format(meters);

  static SearchRadius? tryMeters(int meters) =>
      meters < minMeters || meters > maxMeters ? null : SearchRadius._(meters);

  /// Readable distance for whole [meters]: kilometers when that is exact to
  /// one decimal, otherwise meters with a thousands separator.
  static String format(int meters) {
    if (meters >= 1000 && meters % 100 == 0) {
      final km = meters / 1000;
      return km == km.roundToDouble()
          ? '${km.toStringAsFixed(0)} km'
          : '${km.toStringAsFixed(1)} km';
    }
    final digits = meters.abs().toString();
    final grouped = digits.length <= 3
        ? digits
        : '${digits.substring(0, digits.length - 3)},'
              '${digits.substring(digits.length - 3)}';
    return '${meters < 0 ? '-' : ''}$grouped m';
  }

  /// Validates text typed into the "Distance in meters" field.
  static RadiusInput parse(String text) {
    final t = text.trim().replaceAll(RegExp(r'[\s,_]'), '');
    if (t.isEmpty) return const RadiusInput._error(RadiusInputError.empty);
    if (t.startsWith('-')) {
      return const RadiusInput._error(RadiusInputError.negative);
    }
    if (RegExp(r'^\+?\d*[.]\d*$').hasMatch(t) && RegExp(r'\d').hasMatch(t)) {
      return const RadiusInput._error(RadiusInputError.decimal);
    }
    if (!RegExp(r'^\+?\d+$').hasMatch(t)) {
      return const RadiusInput._error(RadiusInputError.notANumber);
    }
    // Very long digit strings overflow int; they are out of range anyway.
    final value = t.length > 6 ? null : int.parse(t.replaceFirst('+', ''));
    if (value == null || value > maxMeters) {
      return const RadiusInput._error(RadiusInputError.tooLarge);
    }
    if (value < minMeters) {
      return const RadiusInput._error(RadiusInputError.tooSmall);
    }
    return RadiusInput._ok(SearchRadius._(value));
  }

  @override
  bool operator ==(Object other) =>
      other is SearchRadius && other.meters == meters;

  @override
  int get hashCode => meters.hashCode;

  @override
  String toString() => 'SearchRadius($meters m)';
}

enum RadiusInputError {
  empty('Enter a distance in meters.'),
  notANumber('Use numbers only, for example 750.'),
  negative('Distance can’t be negative.'),
  decimal('Use whole meters, without decimals.'),
  tooSmall('That’s too short. Use at least ${SearchRadius.minMeters} m.'),
  tooLarge(
    'That’s too far. The maximum is 2,000 m (2 km), to keep searches '
    'quick and polite to the free map server.',
  );

  const RadiusInputError(this.message);

  final String message;
}

/// The outcome of [SearchRadius.parse]: a radius or a reason.
class RadiusInput {
  const RadiusInput._ok(SearchRadius this.radius) : error = null;
  const RadiusInput._error(RadiusInputError this.error) : radius = null;

  final SearchRadius? radius;
  final RadiusInputError? error;

  bool get isValid => radius != null;
}
