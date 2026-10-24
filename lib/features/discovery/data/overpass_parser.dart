import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import '../domain/business_image.dart';
import '../domain/competitors.dart';

@immutable
class OverpassParseResult {
  const OverpassParseResult({
    required this.businesses,
    required this.skippedCount,
    required this.elementCount,
    this.remark,
  });

  /// De-duplicated, sorted nearest first.
  final List<NearbyBusiness> businesses;

  /// Elements dropped for missing/invalid coordinates or identity.
  final int skippedCount;

  /// Raw element count before de-duplication and skipping.
  final int elementCount;

  /// Overpass's `remark` field; set when the server hit a runtime error.
  final String? remark;

  bool get hasRuntimeError => remark?.contains('runtime error') ?? false;
}

/// Parses an Overpass `[out:json]` response with `out center`.
///
/// Nodes carry `lat`/`lon`; ways and relations carry `center.lat/lon`.
/// Records are keyed by `type:id`, so a business returned twice is shown
/// once. Names come only from the record's tags; a missing name stays null.
///
/// Throws [FormatException] when the payload is not an Overpass response.
OverpassParseResult parseOverpassResponse(
  Object? json, {
  required double originLatitude,
  required double originLongitude,
}) {
  if (json is! Map) {
    throw const FormatException('Overpass response is not a JSON object');
  }
  final elements = json['elements'];
  if (elements is! List) {
    throw const FormatException('Overpass response has no "elements" list');
  }
  final remark = json['remark'];

  final byKey = <String, NearbyBusiness>{};
  var skipped = 0;
  for (final element in elements) {
    final business = _parseElement(element, originLatitude, originLongitude);
    if (business == null) {
      skipped++;
    } else {
      byKey.putIfAbsent(business.key, () => business);
    }
  }

  final businesses = byKey.values.toList()
    ..sort((a, b) {
      final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
      return byDistance != 0 ? byDistance : a.key.compareTo(b.key);
    });

  return OverpassParseResult(
    businesses: List.unmodifiable(businesses),
    skippedCount: skipped,
    elementCount: elements.length,
    remark: remark is String ? remark : null,
  );
}

const _osmTypes = {'node', 'way', 'relation'};

NearbyBusiness? _parseElement(
  Object? element,
  double originLatitude,
  double originLongitude,
) {
  if (element is! Map) return null;
  final type = element['type'];
  final id = element['id'];
  if (type is! String || !_osmTypes.contains(type) || id is! int) return null;

  final center = element['center'];
  final (lat, lon) = type == 'node'
      ? (_toDouble(element['lat']), _toDouble(element['lon']))
      : center is Map
      ? (_toDouble(center['lat']), _toDouble(center['lon']))
      : (null, null);
  if (!isValidCoordinate(lat, lon)) return null;

  final rawTags = element['tags'];
  final tags = <String, String>{
    if (rawTags is Map)
      for (final MapEntry(:key, :value) in rawTags.entries)
        if (key is String && value is String && value.trim().isNotEmpty)
          key: value.trim(),
  };

  return NearbyBusiness(
    osmType: type,
    osmId: id,
    name: tags['name'] ?? tags['name:en'],
    latitude: lat!,
    longitude: lon!,
    distanceMeters: distanceMeters(originLatitude, originLongitude, lat, lon),
    details: _details(tags),
    imageRefs: BusinessImageRefs.fromTags(tags),
  );
}

double? _toDouble(Object? value) => value is num ? value.toDouble() : null;

/// Selected tags worth showing, labeled, in display order.
Map<String, String> _details(Map<String, String> tags) {
  final address = [
    tags['addr:housenumber'],
    tags['addr:street'],
    tags['addr:barangay'] ?? tags['addr:suburb'],
    tags['addr:city'],
  ].whereType<String>().join(', ');

  String? first(List<String> keys) {
    for (final key in keys) {
      final value = tags[key];
      if (value != null) return value;
    }
    return null;
  }

  final entries = <String, String?>{
    'Address': address.isEmpty ? tags['addr:full'] : address,
    'Brand': tags['brand'],
    'Operator': tags['operator'],
    'Cuisine': tags['cuisine']?.replaceAll(';', ', ').replaceAll('_', ' '),
    'Opening hours': tags['opening_hours'],
    'Phone': first(['phone', 'contact:phone']),
    'Website': first(['website', 'contact:website']),
  };
  return {for (final MapEntry(:key, :value) in entries.entries) key: ?value};
}
