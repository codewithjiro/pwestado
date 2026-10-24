import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business_category.dart';
import '../../../core/models/search_radius.dart';
import '../../../core/models/selected_site.dart';
import '../data/location_service.dart';

/// Progress of the most recent "Use my location" request.
enum LocationStatus {
  idle,
  locating,
  located,
  serviceDisabled,
  denied,
  deniedForever,
  unavailable;

  bool get isFailure => switch (this) {
    serviceDisabled || denied || deniedForever || unavailable => true,
    idle || locating || located => false,
  };

  static LocationStatus fromFailure(LocationFailure failure) =>
      switch (failure) {
        LocationFailure.serviceDisabled => serviceDisabled,
        LocationFailure.denied => denied,
        LocationFailure.deniedForever => deniedForever,
        LocationFailure.unavailable => unavailable,
      };
}

@immutable
class ExploreState {
  const ExploreState({
    this.category = BusinessCategory.coffeeShop,
    this.radius = SearchRadius.km1,
    this.site,
    this.locationStatus = LocationStatus.idle,
  });

  final BusinessCategory category;
  final SearchRadius radius;

  /// Null until the user picks a location on the map or uses GPS.
  final SelectedSite? site;

  final LocationStatus locationStatus;

  /// A competitor search needs a chosen site; category and radius always
  /// have a value.
  bool get canSearch => site != null;

  ExploreState copyWith({
    BusinessCategory? category,
    SearchRadius? radius,
    SelectedSite? site,
    bool clearSite = false,
    LocationStatus? locationStatus,
  }) {
    return ExploreState(
      category: category ?? this.category,
      radius: radius ?? this.radius,
      site: clearSite ? null : (site ?? this.site),
      locationStatus: locationStatus ?? this.locationStatus,
    );
  }
}

class ExploreController extends Notifier<ExploreState> {
  /// Bumped on every site change so a slow GPS fix cannot overwrite a site
  /// the user picked by hand while it was pending.
  int _siteGeneration = 0;

  @override
  ExploreState build() => const ExploreState();

  void selectCategory(BusinessCategory category) {
    state = state.copyWith(category: category);
  }

  void selectRadius(SearchRadius radius) {
    state = state.copyWith(radius: radius);
  }

  /// Switches to [category] and [radius] together, e.g. to match a saved
  /// analysis. Returns true if anything changed.
  bool applySettings(BusinessCategory category, SearchRadius radius) {
    if (state.category == category && state.radius == radius) return false;
    state = state.copyWith(category: category, radius: radius);
    return true;
  }

  /// Pins a site picked on the map (or, with [source], from place search).
  void selectSite({
    required double latitude,
    required double longitude,
    SiteSource source = SiteSource.mapPick,
  }) {
    _siteGeneration++;
    state = state.copyWith(
      site: SelectedSite.at(
        latitude: latitude,
        longitude: longitude,
        source: source,
      ),
      // A manual pick supersedes any pending GPS request.
      locationStatus: state.locationStatus == LocationStatus.locating
          ? LocationStatus.idle
          : null,
    );
  }

  void clearSite() {
    _siteGeneration++;
    state = state.copyWith(clearSite: true);
  }

  /// Sets the site to the device's current position. Failures are reported
  /// through [ExploreState.locationStatus]; manual picking keeps working.
  Future<void> useMyLocation() async {
    if (state.locationStatus == LocationStatus.locating) return;
    final generation = ++_siteGeneration;
    state = state.copyWith(locationStatus: LocationStatus.locating);

    try {
      final fix = await ref.read(locationServiceProvider).getCurrentFix();
      if (!ref.mounted || generation != _siteGeneration) return;
      state = state.copyWith(
        site: SelectedSite.at(
          latitude: fix.latitude,
          longitude: fix.longitude,
          source: fix.isLastKnown ? SiteSource.gpsLastKnown : SiteSource.gps,
          accuracyMeters: fix.accuracyMeters,
        ),
        locationStatus: LocationStatus.located,
      );
    } on LocationFailureException catch (e) {
      if (!ref.mounted || generation != _siteGeneration) return;
      state = state.copyWith(
        locationStatus: LocationStatus.fromFailure(e.reason),
      );
    }
  }
}

final exploreControllerProvider =
    NotifierProvider<ExploreController, ExploreState>(ExploreController.new);

/// "Pick on map" mode: a fixed pin at the map's center, which the user
/// moves the map under and then confirms. The map reads the coordinate.
class MapPickMode extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;

  void stop() => state = false;
}

final mapPickModeProvider = NotifierProvider<MapPickMode, bool>(
  MapPickMode.new,
);
