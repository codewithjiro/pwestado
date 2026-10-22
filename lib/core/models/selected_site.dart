import 'package:flutter/foundation.dart';

/// A candidate business location chosen by the user.
@immutable
class SelectedSite {
  const SelectedSite({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.displayLabel,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String displayLabel;
}
