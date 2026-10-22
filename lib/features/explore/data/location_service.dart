import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// A device position fix.
@immutable
class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.isLastKnown = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;

  /// True when a fresh fix timed out and the device's cached fix was used.
  final bool isLastKnown;
}

enum LocationFailure { serviceDisabled, denied, deniedForever, unavailable }

class LocationFailureException implements Exception {
  const LocationFailureException(this.reason);

  final LocationFailure reason;

  @override
  String toString() => 'LocationFailureException($reason)';
}

abstract interface class LocationService {
  /// Asks for permission if needed, then returns the current position.
  /// Throws [LocationFailureException] when a position cannot be obtained.
  Future<GeoFix> getCurrentFix();

  /// Whether location permission is already granted, without prompting.
  Future<bool> hasPermission();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const _fixTimeout = Duration(seconds: 20);

  @override
  Future<GeoFix> getCurrentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailureException(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.deniedForever:
        throw const LocationFailureException(LocationFailure.deniedForever);
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        throw const LocationFailureException(LocationFailure.denied);
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
      return _toFix(position);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return _toFix(last, isLastKnown: true);
      throw const LocationFailureException(LocationFailure.unavailable);
    } on LocationServiceDisabledException {
      throw const LocationFailureException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationFailureException(LocationFailure.denied);
    } on LocationFailureException {
      rethrow;
    } catch (_) {
      throw const LocationFailureException(LocationFailure.unavailable);
    }
  }

  GeoFix _toFix(Position p, {bool isLastKnown = false}) => GeoFix(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: p.accuracy,
    isLastKnown: isLastKnown,
  );

  @override
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);
