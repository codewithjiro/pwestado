import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pwestado/features/explore/data/location_service.dart';

/// Scriptable plugin: each call returns its value or throws its error.
class FakeGeolocatorPlatform extends Fake implements GeolocatorPlatform {
  Object? serviceError;
  bool serviceEnabled = true;
  Object? checkError;
  LocationPermission permission = LocationPermission.whileInUse;
  Object? requestError;
  LocationPermission requested = LocationPermission.whileInUse;
  Object? positionError;
  Object? lastKnownError;
  Position? lastKnown;

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (serviceError != null) throw serviceError!;
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    if (checkError != null) throw checkError!;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    if (requestError != null) throw requestError!;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (positionError != null) throw positionError!;
    return position(15.0939, 120.7681);
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    if (lastKnownError != null) throw lastKnownError!;
    return lastKnown;
  }

  @override
  Future<bool> openAppSettings() async => throw PlatformException(code: 'x');
}

Position position(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime(2026, 10, 25),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late FakeGeolocatorPlatform platform;
  late GeolocatorLocationService service;

  setUp(() {
    platform = FakeGeolocatorPlatform();
    service = GeolocatorLocationService(platform: platform);
  });

  Future<LocationFailure?> failureOf(Future<GeoFix> request) async {
    try {
      await request;
      return null;
    } on LocationFailureException catch (e) {
      return e.reason;
    }
  }

  test('a normal fix is returned', () async {
    final fix = await service.getCurrentFix();
    expect(fix.latitude, 15.0939);
    expect(fix.isLastKnown, isFalse);
  });

  test('a failing service check is reported as unavailable', () async {
    platform.serviceError = PlatformException(code: 'ERROR');
    expect(
      await failureOf(service.getCurrentFix()),
      LocationFailure.unavailable,
    );
  });

  test('failing permission calls are reported, never thrown raw', () async {
    platform.checkError = PlatformException(code: 'ERROR');
    expect(
      await failureOf(service.getCurrentFix()),
      LocationFailure.unavailable,
    );

    platform
      ..checkError = null
      ..permission = LocationPermission.denied
      ..requestError = const PermissionRequestInProgressException('busy');
    expect(
      await failureOf(service.getCurrentFix()),
      LocationFailure.unavailable,
    );

    platform.requestError = const PermissionDeniedException('no');
    expect(await failureOf(service.getCurrentFix()), LocationFailure.denied);
  });

  test('a timeout falls back to the cached fix', () async {
    platform
      ..positionError = TimeoutException('slow')
      ..lastKnown = position(15.02, 120.68);
    final fix = await service.getCurrentFix();
    expect(fix.latitude, 15.02);
    expect(fix.isLastKnown, isTrue);
  });

  test('a failing cached-fix lookup after a timeout is unavailable', () async {
    platform
      ..positionError = TimeoutException('slow')
      ..lastKnownError = PlatformException(code: 'ERROR');
    expect(
      await failureOf(service.getCurrentFix()),
      LocationFailure.unavailable,
    );
  });

  test('a service switched off mid-request is reported as such', () async {
    platform.positionError = const LocationServiceDisabledException();
    expect(
      await failureOf(service.getCurrentFix()),
      LocationFailure.serviceDisabled,
    );
  });

  test('settings shortcuts never throw', () async {
    expect(await service.openAppSettings(), isFalse);
    platform.checkError = PlatformException(code: 'ERROR');
    expect(await service.hasPermission(), isFalse);
  });
}
