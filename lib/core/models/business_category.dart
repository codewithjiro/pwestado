import 'package:flutter/material.dart';

/// A business type the user can plan for, mapped to a single OSM tag.
@immutable
class BusinessCategory {
  const BusinessCategory({
    required this.id,
    required this.label,
    required this.osmTagKey,
    required this.osmTagValue,
    required this.icon,
  });

  final String id;
  final String label;
  final String osmTagKey;
  final String osmTagValue;
  final IconData icon;

  String get osmTag => '$osmTagKey=$osmTagValue';

  static const coffeeShop = BusinessCategory(
    id: 'coffee_shop',
    label: 'Coffee Shop',
    osmTagKey: 'amenity',
    osmTagValue: 'cafe',
    icon: Icons.local_cafe_outlined,
  );

  static const restaurant = BusinessCategory(
    id: 'restaurant',
    label: 'Restaurant',
    osmTagKey: 'amenity',
    osmTagValue: 'restaurant',
    icon: Icons.restaurant_outlined,
  );

  static const convenience = BusinessCategory(
    id: 'convenience',
    label: 'Sari-Sari / Convenience',
    osmTagKey: 'shop',
    osmTagValue: 'convenience',
    icon: Icons.storefront_outlined,
  );

  static const laundry = BusinessCategory(
    id: 'laundry',
    label: 'Laundry Shop',
    osmTagKey: 'shop',
    osmTagValue: 'laundry',
    icon: Icons.local_laundry_service_outlined,
  );

  static const bakery = BusinessCategory(
    id: 'bakery',
    label: 'Bakery',
    osmTagKey: 'shop',
    osmTagValue: 'bakery',
    icon: Icons.bakery_dining_outlined,
  );

  static const all = [coffeeShop, restaurant, convenience, laundry, bakery];

  @override
  bool operator ==(Object other) => other is BusinessCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
