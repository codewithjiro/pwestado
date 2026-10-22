import '../../../core/utils/geo.dart';
import '../domain/competitors.dart';

/// SAMPLE DEMO MODE: a fixed, fictional dataset for showing the flow when
/// Overpass is unreachable during a pitch.
///
/// These are not real businesses. Every record is typed
/// [NearbyBusiness.sampleType], named "Sample ... (demo)", and returned with
/// [DataSource.sample], so the UI can never present them as OSM data. Points
/// are placed at fixed bearings/distances from the chosen site so the demo
/// is deterministic wherever it runs.
abstract final class SampleCompetitors {
  /// (bearing in degrees, distance in meters).
  static const _layout = [
    (35.0, 180.0),
    (160.0, 340.0),
    (250.0, 470.0),
    (300.0, 720.0),
    (95.0, 880.0),
    (205.0, 1350.0),
    (20.0, 1720.0),
  ];

  static CompetitorResult forQuery(CompetitorQuery query, DateTime now) {
    final businesses = <NearbyBusiness>[];
    for (final (index, (bearing, meters)) in _layout.indexed) {
      if (meters > query.radius.meters) continue;
      final (lat, lon) = destinationPoint(
        query.latitude,
        query.longitude,
        bearing,
        meters,
      );
      businesses.add(
        NearbyBusiness(
          osmType: NearbyBusiness.sampleType,
          osmId: index + 1,
          name: 'Sample ${query.category.label} ${index + 1} (demo)',
          latitude: lat,
          longitude: lon,
          distanceMeters: distanceMeters(
            query.latitude,
            query.longitude,
            lat,
            lon,
          ),
          details: const {'Note': 'Fictional demo record, not a real business'},
        ),
      );
    }
    return CompetitorResult(
      query: query,
      businesses: List.unmodifiable(businesses),
      fetchedAt: now,
      source: DataSource.sample,
    );
  }
}
