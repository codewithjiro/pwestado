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
  /// [platform] is injectable for tests; the app uses the plugin instance.
  GeolocatorLocationService({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  static const _fixTimeout = Duration(seconds: 20);

  /// Any plugin call can throw (a platform error, a permission request
  /// already running, a failing cached-fix lookup). Everything that is not
  /// already a [LocationFailureException] becomes one here, so callers only
  /// ever see the documented failure type.
  @override
  Future<GeoFix> getCurrentFix() async {
    try {
      return await _getCurrentFix();
    } on LocationFailureException {
      rethrow;
    } on LocationServiceDisabledException {
      throw const LocationFailureException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationFailureException(LocationFailure.denied);
    } catch (e) {
      debugPrint('Location request failed: ${e.runtimeType}');
      throw const LocationFailureException(LocationFailure.unavailable);
    }
  }

  Future<GeoFix> _getCurrentFix() async {
    if (!await _platform.isLocationServiceEnabled()) {
      throw const LocationFailureException(LocationFailure.serviceDisabled);
    }

    var permission = await _platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
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
      final position = await _platform.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
      return _toFix(position);
    } on TimeoutException {
      // The cached fix is a fallback only; its own failure means "no fix".
      Position? last;
      try {
        last = await _platform.getLastKnownPosition();
      } catch (e) {
        debugPrint('Last known location unavailable: ${e.runtimeType}');
      }
      if (last != null) return _toFix(last, isLastKnown: true);
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
    try {
      final permission = await _platform.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await _platform.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await _platform.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);
