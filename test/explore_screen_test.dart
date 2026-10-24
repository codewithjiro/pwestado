import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/analysis/presentation/analyze_screen.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/presentation/widgets/explore_map.dart';
import 'package:pwestado/features/explore/presentation/widgets/map_setup_card.dart';
import 'package:pwestado/features/explore/presentation/widgets/map_unavailable.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/places/domain/place.dart';
import 'package:pwestado/features/places/presentation/place_search_bar.dart';
import 'package:pwestado/features/places/presentation/site_place_label.dart';
import 'package:pwestado/features/places/state/place_providers.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';

import 'fake_location_service.dart';
import 'fake_place_repository.dart';
import 'fake_saved_analysis_repository.dart';

// Widget tests run without --dart-define=ACCESS_TOKEN, so the map area shows
// the "Map unavailable" explanation instead of the native Mapbox view.

late FakeLocationService location;
late FakePlaceRepository places;

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  location = FakeLocationService();
  places = FakePlaceRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        placeRepositoryProvider.overrideWithValue(places),
        savedAnalysisRepositoryProvider.overrideWithValue(
          FakeSavedAnalysisRepository(),
        ),
      ],
      child: const PwestadoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PwestadoApp)));

ButtonStyleButton buttonWithText(WidgetTester tester, String text) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on MAPA with search, setup card and four tabs', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));

    for (final label in ['MAPA', 'ANALYZE', 'COMPARE', 'SAVED']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.text(PlaceSearchBar.hint), findsOneWidget);
    expect(find.text(MapUnavailable.title), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    expect(find.text(MapSetupCard.noSiteTitle), findsOneWidget);
    expect(
      buttonWithText(tester, MapSetupCard.findLabel).enabled,
      isFalse,
      reason: 'no site selected yet',
    );
    expect(find.text(MapSetupCard.needSiteReason), findsOneWidget);
    expect(
      buttonWithText(tester, MapSetupCard.pickOnMap).enabled,
      isFalse,
      reason: 'picking needs the live map, which tests do not have',
    );
  });

  testWidgets('business type and radius update the settings', (tester) async {
    await pumpApp(tester, const Size(412, 915));

    await tester.tap(find.text(BusinessCategory.coffeeShop.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(BusinessCategory.bakery.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 km'));
    await tester.pumpAndSettle();

    final state = containerOf(tester).read(exploreControllerProvider);
    expect(state.category, BusinessCategory.bakery);
    expect(state.radius, SearchRadius.km2);
    final segmented = tester.widget<SegmentedButton<SearchRadius>>(
      find.byType(SegmentedButton<SearchRadius>),
    );
    expect(segmented.selected, {SearchRadius.km2});
  });

  testWidgets('a chosen site shows a readable label, not coordinates', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));

    containerOf(tester)
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0951, longitude: 120.7702);
    await tester.pumpAndSettle();

    expect(find.text('Near Test Road'), findsOneWidget);
    expect(find.text('Pinned site'), findsOneWidget);
    expect(find.textContaining('15.0951'), findsNothing);
    expect(buttonWithText(tester, MapSetupCard.findLabel).enabled, isTrue);

    await tester.tap(find.byTooltip('Clear location'));
    await tester.pumpAndSettle();
    expect(find.text(MapSetupCard.noSiteTitle), findsOneWidget);
  });

  testWidgets('a failed address lookup falls back honestly with Retry', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));
    places.labelFailure = GeocodingFailure.network;

    containerOf(tester)
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0951, longitude: 120.7702);
    await tester.pumpAndSettle();
    expect(find.text('Selected location'), findsOneWidget);
    expect(find.text(SitePlaceLabel.unavailableNote), findsOneWidget);

    places.labelFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Near Test Road'), findsOneWidget);
    expect(places.reverseLookups, 2);
  });

  testWidgets('searching on submit lists places; choosing one sets the site', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));

    await tester.enterText(find.byType(TextField), 'San Fernando');
    await tester.pump();
    expect(places.searches, isEmpty, reason: 'no search per keystroke');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(places.searches, ['San Fernando']);
    expect(find.text('Pampanga, Philippines'), findsOneWidget);
    expect(find.textContaining('Search by Mapbox'), findsOneWidget);

    await tester.tap(find.text('Pampanga, Philippines'));
    await tester.pumpAndSettle();
    final site = containerOf(tester).read(exploreControllerProvider).site!;
    expect(site.source, SiteSource.search);
    expect(site.latitude, FakePlaceRepository.sanFernando.latitude);
    expect(find.text('Searched place'), findsOneWidget);
    expect(places.reverseLookups, 0);
  });

  testWidgets('search shows no-result and failure states', (tester) async {
    await pumpApp(tester, const Size(412, 915));

    places.results = [];
    await tester.enterText(find.byType(TextField), 'zzqx');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No places found for "zzqx"'), findsOneWidget);

    places.failure = GeocodingFailure.network;
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text(GeocodingFailure.network.message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text(GeocodingFailure.network.message), findsNothing);
  });

  testWidgets('GPS fix sets the site and reports success', (tester) async {
    await pumpApp(tester, const Size(412, 915));
    location.fix = const GeoFix(
      latitude: 15.0912,
      longitude: 120.7655,
      accuracyMeters: 12,
    );

    await tester.tap(find.text(MapSetupCard.useMyLocation));
    await tester.pumpAndSettle();

    expect(find.text('Site set to your current location.'), findsOneWidget);
    expect(find.text('My location (GPS)'), findsOneWidget);
    expect(find.text('Near Test Road'), findsOneWidget);
  });

  testWidgets('GPS denial points to search instead', (tester) async {
    await pumpApp(tester, const Size(412, 915));
    location.failure = LocationFailure.denied;

    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.textContaining('search for a place'), findsOneWidget);
    expect(find.text(MapSetupCard.noSiteTitle), findsOneWidget);
  });

  testWidgets('permanent denial offers app settings', (tester) async {
    await pumpApp(tester, const Size(412, 915));
    location.failure = LocationFailure.deniedForever;

    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(location.appSettingsOpened, 1);
  });

  testWidgets('location services off offers to turn them on', (tester) async {
    await pumpApp(tester, const Size(412, 915));
    location.failure = LocationFailure.serviceDisabled;

    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Device location is turned off'), findsOne);
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(location.locationSettingsOpened, 1);
  });

  testWidgets('tabs keep state and the map widget across switches', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));
    final mapState = tester.state(find.byType(ExploreMap));

    await openTab(tester, 'ANALYZE');
    expect(find.text(AnalyzeScreen.noSiteTitle), findsOneWidget);
    await tester.tap(find.text('Go to MAPA'));
    await tester.pumpAndSettle();
    expect(find.text(MapSetupCard.noSiteTitle), findsOneWidget);

    containerOf(tester)
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0951, longitude: 120.7702);
    await openTab(tester, 'COMPARE');
    expect(find.text('Current map location'.toUpperCase()), findsOneWidget);
    await openTab(tester, 'ANALYZE');
    expect(find.text('Step 1 · ${AnalyzeScreen.findFirstTitle}'), findsOne);
    expect(find.text('Near Test Road'), findsOneWidget);

    await openTab(tester, 'MAPA');
    expect(find.text('Near Test Road'), findsOneWidget);
    expect(
      tester.state(find.byType(ExploreMap)),
      same(mapState),
      reason: 'the map is never rebuilt from scratch by tab switches',
    );
  });

  testWidgets('wide layout uses a side panel and keeps the tabs', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    expect(find.byType(MapSetupCard), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(MapUnavailable.title), findsOneWidget);
  });

  testWidgets('about sheet explains data sources', (tester) async {
    await pumpApp(tester, const Size(412, 915));

    await tester.tap(find.byTooltip('About PWESTADO and its data'));
    await tester.pumpAndSettle();
    expect(find.text('About PWESTADO'), findsOneWidget);
    expect(find.text('Business listings'), findsOneWidget);
  });
}
