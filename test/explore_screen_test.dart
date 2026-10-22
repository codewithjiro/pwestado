import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/presentation/widgets/map_unavailable.dart';
import 'package:pwestado/features/explore/presentation/widgets/search_panel.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';

import 'fake_saved_analysis_repository.dart';
import 'fake_location_service.dart';

// Widget tests run without --dart-define=ACCESS_TOKEN, so the map area shows
// the "Map unavailable" explanation instead of the native Mapbox view.

late FakeLocationService location;

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  location = FakeLocationService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
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

Finder get panelScrollable => find.descendant(
  of: find.byType(SearchPanel),
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets('phone layout shows branding, map status, controls', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));

    expect(find.text('PWESTADO'), findsOneWidget);
    expect(find.text('Ang tamang pwesto, simula ng negosyo.'), findsOneWidget);
    expect(find.text(MapUnavailable.title), findsOneWidget);
    expect(find.textContaining('--dart-define=ACCESS_TOKEN'), findsOneWidget);
    expect(find.byTooltip('Use my location'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Find competitors'),
      200,
      scrollable: panelScrollable,
    );
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Find competitors'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.enabled, isFalse, reason: 'no site selected yet');
    expect(find.text('No site selected'), findsOneWidget);
    expect(find.textContaining('Long-press the map'), findsOneWidget);
  });

  testWidgets('category and radius selections update the panel', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));

    expect(find.textContaining('amenity=cafe'), findsOneWidget);
    await tester.tap(find.text('Bakery'));
    await tester.pumpAndSettle();
    expect(find.textContaining('shop=bakery'), findsOneWidget);

    await tester.ensureVisible(find.text('2 km'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 km'));
    await tester.pumpAndSettle();
    final segmented = tester.widget<SegmentedButton<SearchRadius>>(
      find.byType(SegmentedButton<SearchRadius>),
    );
    expect(segmented.selected, {SearchRadius.km2});
  });

  testWidgets('a selected site shows coordinates and can be cleared', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));

    containerOf(tester)
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0951, longitude: 120.7702);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pinned site'),
      200,
      scrollable: panelScrollable,
    );
    expect(find.text('15.09510, 120.77020'), findsOneWidget);
    expect(
      find.byTooltip('Show selected site'),
      findsNothing,
      reason: 'no live map to move without a token',
    );

    await tester.ensureVisible(find.byTooltip('Clear site'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear site'));
    await tester.pumpAndSettle();
    expect(find.text('No site selected'), findsOneWidget);
  });

  testWidgets('GPS fix sets the site and reports success', (tester) async {
    await pumpApp(tester, const Size(412, 915));
    location.fix = const GeoFix(
      latitude: 15.0912,
      longitude: 120.7655,
      accuracyMeters: 12,
    );

    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();

    expect(find.text('Site set to your current location.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('My location (GPS)'),
      200,
      scrollable: panelScrollable,
    );
    expect(find.text('15.09120, 120.76550'), findsOneWidget);
    expect(find.text('GPS accuracy about ±12 m'), findsOneWidget);
  });

  testWidgets('GPS denial explains that manual picking still works', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));
    location.failure = LocationFailure.denied;

    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.textContaining('long-press the map'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No site selected'),
      200,
      scrollable: panelScrollable,
    );
    expect(find.text('No site selected'), findsOneWidget);
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

  testWidgets('wide layout uses a side panel instead of a sheet', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byType(SearchPanel), findsOneWidget);
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
