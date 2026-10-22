import '../../../core/models/business_category.dart';
import '../../../core/utils/geo.dart';
import '../../discovery/data/overpass_parser.dart';
import '../domain/site_context.dart';
import '../domain/suitability_scoring.dart';
import 'site_context_query.dart';

/// Parsed evidence from a [SiteContextQuery] response.
class SiteContextParseResult {
  const SiteContextParseResult({
    required this.complementary,
    required this.roads,
    required this.skippedCount,
    this.remark,
  });

  final ComplementaryEvidence complementary;
  final RoadEvidence roads;

  /// Places dropped for missing coordinates, plus roads without geometry.
  final int skippedCount;
  final String? remark;
}

/// Splits a site-context response into complementary places (elements with
/// `out center` coordinates) and roads (ways with `geometry` and a
/// qualifying `highway` tag).
///
/// Places are de-duplicated by `type:id` through [parseOverpassResponse];
/// any record carrying the selected business's own tag is dropped so a
/// competitor is never counted as a complement. Road distance is measured
/// to the road's mapped line, not its center.
///
/// Throws [FormatException] when the payload is not an Overpass response.
SiteContextParseResult parseSiteContextResponse(
  Object? json, {
  required double originLatitude,
  required double originLongitude,
  required BusinessCategory category,
  required int radiusMeters,
}) {
  if (json is! Map) {
    throw const FormatException('Overpass response is not a JSON object');
  }
  final elements = json['elements'];
  if (elements is! List) {
    throw const FormatException('Overpass response has no "elements" list');
  }
  final remark = json['remark'];

  final placeElements = <Object?>[];
  final kindByKey = <String, String>{};
  final roadKeys = <String>{};
  var placesReturned = 0;
  var roadCount = 0;
  var skippedRoads = 0;
  double? nearest;
  String? nearestKind;
  String? nearestName;
  double? nearestMajor;

  for (final element in elements) {
    final tags = element is Map && element['tags'] is Map
        ? element['tags'] as Map
        : const {};
    final highway = tags['highway'];
    if (element is Map &&
        element['type'] == 'way' &&
        highway is String &&
        RoadKinds.all.contains(highway)) {
      if (!roadKeys.add('way:${element['id']}')) continue;
      final distance = distanceToPolylineMeters(
        originLatitude,
        originLongitude,
        _geometry(element['geometry']),
      );
      if (distance == null) {
        skippedRoads++;
        continue;
      }
      roadCount++;
      if (nearest == null || distance < nearest) {
        final name = tags['name'];
        nearest = distance;
        nearestKind = highway;
        nearestName = name is String && name.trim().isNotEmpty
            ? name.trim()
            : null;
      }
      if (RoadKinds.major.contains(highway) &&
          (nearestMajor == null || distance < nearestMajor)) {
        nearestMajor = distance;
      }
      continue;
    }

    placesReturned++;
    if (tags[category.osmTagKey] == category.osmTagValue) continue;
    final kind = _kind(tags);
    if (kind == null || element is! Map) continue;
    placeElements.add(element);
    kindByKey['${element['type']}:${element['id']}'] = kind;
  }

  final places = parseOverpassResponse(
    {'elements': placeElements},
    originLatitude: originLatitude,
    originLongitude: originLongitude,
  );
  final countsByKind = <String, int>{};
  for (final place in places.businesses) {
    final kind = kindByKey[place.key]!;
    countsByKind[kind] = (countsByKind[kind] ?? 0) + 1;
  }

  return SiteContextParseResult(
    complementary: ComplementaryEvidence(
      count: places.businesses.length,
      radiusMeters: radiusMeters,
      countsByKind: Map.unmodifiable(countsByKind),
      possiblyTruncated: placesReturned >= SiteContextQuery.maxPlaces,
    ),
    roads: RoadEvidence(
      roadCount: roadCount,
      nearestRoadMeters: nearest,
      nearestRoadKind: nearestKind?.replaceAll('_', ' '),
      nearestRoadName: nearestName,
      nearestMajorRoadMeters: nearestMajor,
    ),
    skippedCount: places.skippedCount + skippedRoads,
    remark: remark is String ? remark : null,
  );
}

/// The readable complementary kind for a record's tags, e.g. "school".
String? _kind(Map tags) {
  final amenity = tags['amenity'];
  if (amenity is String && ComplementaryTags.amenity.contains(amenity)) {
    return ComplementaryTags.label(amenity);
  }
  final shop = tags['shop'];
  if (shop is String && ComplementaryTags.shop.contains(shop)) {
    return ComplementaryTags.label(shop);
  }
  return null;
}

List<(double, double)> _geometry(Object? raw) {
  if (raw is! List) return const [];
  final points = <(double, double)>[];
  for (final point in raw) {
    if (point is! Map) continue;
    final lat = point['lat'];
    final lon = point['lon'];
    if (lat is! num || lon is! num) continue;
    if (!isValidCoordinate(lat.toDouble(), lon.toDouble())) continue;
    points.add((lat.toDouble(), lon.toDouble()));
  }
  return points;
}
