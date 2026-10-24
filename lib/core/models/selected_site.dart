import 'package:flutter/foundation.dart';

/// How the user chose a site.
enum SiteSource {
  mapPick('Pinned site'),
  gps('My location (GPS)'),
  gpsLastKnown('My location (last known GPS fix)'),

  /// Picked from "Search a place or address" results.
  search('Searched place');

  const SiteSource(this.label);

  final String label;

  bool get isGps => this == gps || this == gpsLastKnown;
}

/// A candidate business location chosen by the user. The coordinates are
/// the source of truth for analysis and storage. [displayLabel] only says
/// how the site was chosen; readable place names come from a separate,
/// display-only lookup and are never stored here.
@immutable
class SelectedSite {
  const SelectedSite({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.displayLabel,
    this.source = SiteSource.mapPick,
    this.accuracyMeters,
  });

  factory SelectedSite.at({
    required double latitude,
    required double longitude,
    SiteSource source = SiteSource.mapPick,
    double? accuracyMeters,
  }) {
    return SelectedSite(
      id: '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
      latitude: latitude,
      longitude: longitude,
      displayLabel: source.label,
      source: source,
      accuracyMeters: accuracyMeters,
    );
  }

  final String id;
  final double latitude;
  final double longitude;
  final String displayLabel;
  final SiteSource source;

  /// Horizontal GPS accuracy reported by the device, when from GPS.
  final double? accuracyMeters;

  /// About 1 m precision, enough to identify the spot without false detail.
  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is SelectedSite && other.id == id && other.source == source;

  @override
  int get hashCode => Object.hash(id, source);
}
