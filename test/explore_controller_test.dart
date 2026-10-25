import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/config/mapbox_config.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';

import 'fake_location_service.dart';

void main() {
  late FakeLocationService location;
  late ProviderContainer container;

  setUp(() {
    location = FakeLocationService();
    container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
  });
  tearDown(() => container.dispose());

  ExploreController controller() =>
      container.read(exploreControllerProvider.notifier);
  ExploreState state() => container.read(exploreControllerProvider);

  test('defaults to Coffee Shop, 1 km, no site, search disabled', () {
    expect(state().category, BusinessCategory.coffeeShop);
    expect(state().category.osmTag, 'amenity=cafe');
    expect(state().radius, SearchRadius.km1);
    expect(state().radius.meters, 1000);
    expect(state().site, isNull);
    expect(state().canSearch, isFalse);
    expect(state().locationStatus, LocationStatus.idle);
  });

  test('category and radius changes keep the other setting', () {
    controller().selectCategory(BusinessCategory.bakery);
    controller().selectRadius(SearchRadius.km2);

    expect(state().category, BusinessCategory.bakery);
    expect(state().radius, SearchRadius.km2);
  });

  test('the first release categories keep their ids and OSM tags', () {
    expect(
      [
        for (final id in [
          'coffee_shop',
          'restaurant',
          'convenience',
          'laundry',
          'bakery',
        ])
          BusinessCategory.byId(id)!.osmTag,
      ],
      [
        'amenity=cafe',
        'amenity=restaurant',
        'shop=convenience',
        'shop=laundry',
        'shop=bakery',
      ],
    );
  });

  group('site selection', () {
    test('a map pick sets the site and enables search', () {
      controller().selectSite(latitude: 15.0951, longitude: 120.7702);

      final site = state().site!;
      expect(site.latitude, 15.0951);
      expect(site.longitude, 120.7702);
      expect(site.source, SiteSource.mapPick);
      expect(site.displayLabel, 'Pinned site');
      expect(site.coordinatesLabel, '15.09510, 120.77020');
      expect(state().canSearch, isTrue);
    });

    test('picking again replaces the site', () {
      controller().selectSite(latitude: 15.0951, longitude: 120.7702);
      final first = state().site;
      controller().selectSite(latitude: 15.1000, longitude: 120.7600);

      expect(state().site, isNot(first));
      expect(state().site!.latitude, 15.1);
    });

    test('category and radius changes keep the site', () {
      controller().selectSite(latitude: 15.0951, longitude: 120.7702);
      final site = state().site;
      controller().selectCategory(BusinessCategory.laundry);
      controller().selectRadius(SearchRadius.m500);

      expect(state().site, same(site));
    });

    test('clearSite removes the site and disables search', () {
      controller().selectSite(latitude: 15.0951, longitude: 120.7702);
      controller().clearSite();

      expect(state().site, isNull);
      expect(state().canSearch, isFalse);
    });
  });

  group('use my location', () {
    test('a GPS fix becomes the site', () async {
      location.fix = const GeoFix(
        latitude: 15.09,
        longitude: 120.77,
        accuracyMeters: 8.4,
      );
      await controller().useMyLocation();

      expect(state().locationStatus, LocationStatus.located);
      expect(state().site!.source, SiteSource.gps);
      expect(state().site!.accuracyMeters, 8.4);
      expect(state().site!.latitude, 15.09);
    });

    test('a last-known fallback fix is labeled as such', () async {
      location.fix = const GeoFix(
        latitude: 15.09,
        longitude: 120.77,
        accuracyMeters: 40,
        isLastKnown: true,
      );
      await controller().useMyLocation();

      expect(state().site!.source, SiteSource.gpsLastKnown);
      expect(state().site!.displayLabel, contains('last known'));
    });

    for (final (failure, status) in [
      (LocationFailure.denied, LocationStatus.denied),
      (LocationFailure.deniedForever, LocationStatus.deniedForever),
      (LocationFailure.serviceDisabled, LocationStatus.serviceDisabled),
      (LocationFailure.unavailable, LocationStatus.unavailable),
    ]) {
      test('$failure is reported and keeps the existing site', () async {
        controller().selectSite(latitude: 15.0951, longitude: 120.7702);
        final site = state().site;
        location.failure = failure;
        await controller().useMyLocation();

        expect(state().locationStatus, status);
        expect(state().locationStatus.isFailure, isTrue);
        expect(state().site, same(site));
      });
    }

    test('a manual pick during a pending GPS request wins', () async {
      location.pending = Completer<GeoFix>();
      final request = controller().useMyLocation();
      expect(state().locationStatus, LocationStatus.locating);

      controller().selectSite(latitude: 15.0951, longitude: 120.7702);
      location.pending!.complete(
        const GeoFix(latitude: 1, longitude: 2, accuracyMeters: 5),
      );
      await request;

      expect(state().site!.source, SiteSource.mapPick);
      expect(state().site!.latitude, 15.0951);
      expect(state().locationStatus, LocationStatus.idle);
    });

    test('an unexpected error ends Locating with a failure', () async {
      location.error = StateError('plugin crashed');
      await controller().useMyLocation();
      expect(state().locationStatus, LocationStatus.unavailable);
    });

    test('clearing the site during a GPS request ends Locating', () async {
      location.pending = Completer<GeoFix>();
      final request = controller().useMyLocation();
      expect(state().locationStatus, LocationStatus.locating);

      controller().clearSite();
      expect(state().locationStatus, LocationStatus.idle);

      // The late answer must not bring a site back.
      location.pending!.complete(
        const GeoFix(latitude: 1, longitude: 2, accuracyMeters: 5),
      );
      await request;
      expect(state().site, isNull);
      expect(state().locationStatus, LocationStatus.idle);

      // And a new request is possible right away.
      location
        ..pending = null
        ..fix = const GeoFix(
          latitude: 15.1,
          longitude: 120.7,
          accuracyMeters: 5,
        );
      await controller().useMyLocation();
      expect(state().locationStatus, LocationStatus.located);
    });

    test('a second tap while locating is ignored', () async {
      location.pending = Completer<GeoFix>();
      final first = controller().useMyLocation();
      await controller().useMyLocation();
      expect(state().locationStatus, LocationStatus.locating);

      location.pending!.complete(
        const GeoFix(latitude: 15.09, longitude: 120.77, accuracyMeters: 5),
      );
      await first;
      expect(state().locationStatus, LocationStatus.located);
    });
  });

  group('Mapbox token check', () {
    // Shaped like a real public token (pk.<base64 JSON>.<signature>) but
    // made up for this test; it is not a working credential.
    const wellFormed =
        'pk.eyJ1IjoiZXhhbXBsZSIsImEiOiJjbGV4YW1wbGUwMDAwIn0.'
        'AbCdEfGhIjKlMnOpQrStUv';

    test('accepts only well-formed public pk. tokens', () {
      expect(MapboxConfig.checkToken(''), MapboxTokenStatus.missing);
      expect(MapboxConfig.checkToken('   '), MapboxTokenStatus.missing);
      expect(MapboxConfig.checkToken('sk.abc'), MapboxTokenStatus.secret);
      expect(MapboxConfig.checkToken('abc'), MapboxTokenStatus.invalid);
      expect(MapboxConfig.checkToken(wellFormed), MapboxTokenStatus.ok);
      expect(MapboxConfig.checkToken(' $wellFormed '), MapboxTokenStatus.ok);
    });

    test('rejects pk. values that Mapbox would call malformed', () {
      // The black-map APK was built with a 20-character "pk." value like
      // this; Mapbox answers TokenMalformed and every style request 401.
      expect(
        MapboxConfig.checkToken('pk.abcdefghij123456'),
        MapboxTokenStatus.malformed,
      );
      expect(MapboxConfig.checkToken('pk.abc'), MapboxTokenStatus.malformed);
      // Right prefix and parts, but the payload is not base64 JSON.
      expect(
        MapboxConfig.checkToken('pk.notjson.signature'),
        MapboxTokenStatus.malformed,
      );
    });

    test('tests run without a token built in', () {
      expect(MapboxConfig.tokenStatus, MapboxTokenStatus.missing);
    });
  });
}
