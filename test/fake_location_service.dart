import 'dart:async';

import 'package:pwestado/features/explore/data/location_service.dart';

/// Test double: resolves with [fix], fails with [failure], throws the raw
/// [error], or waits for [pending] when set.
class FakeLocationService implements LocationService {
  FakeLocationService({this.fix, this.failure, this.pending});

  GeoFix? fix;
  LocationFailure? failure;

  /// Thrown as-is: an unexpected error that is not a documented failure.
  Object? error;
  Completer<GeoFix>? pending;
  bool permissionGranted = false;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<GeoFix> getCurrentFix() async {
    final pending = this.pending;
    if (pending != null) return pending.future;
    final failure = this.failure;
    if (failure != null) throw LocationFailureException(failure);
    final error = this.error;
    if (error != null) throw error;
    return fix!;
  }

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}
