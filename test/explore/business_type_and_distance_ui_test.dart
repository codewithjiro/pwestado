import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/app/theme_mode_controller.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/presentation/widgets/business_type_picker.dart';
import 'package:pwestado/features/explore/presentation/widgets/map_setup_card.dart';
import 'package:pwestado/features/explore/presentation/widgets/search_distance_picker.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/places/state/place_providers.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:pwestado/shared/widgets/category_art.dart';

import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
import '../fake_place_repository.dart';
import '../fake_saved_analysis_repository.dart';

late FakeCompetitorRepository competitors;

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  competitors = FakeCompetitorRepository(respond: (q) => resultFor(q, []));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themeModeStoreProvider.overrideWithValue(MemoryThemeModeStore(mode)),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository()),
        competitorRepositoryProvider.overrideWithValue(competitors),
        savedAnalysisRepositoryProvider.overrideWithValue(
          FakeSavedAnalysisRepository(),
        ),
      ],
      child: const PwestadoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PwestadoApp)));
}

ExploreState exploreOf(ProviderContainer c) =>
    c.read(exploreControllerProvider);

Finder get pickerSearch => find.descendant(
  of: find.byType(BusinessTypePicker),
  matching: find.byType(TextField),
);

Finder get distanceInput => find.descendant(
  of: find.byType(SearchDistanceSheet),
  matching: find.byType(TextField),
);

Future<void> openPicker(WidgetTester tester) async {
  final field = find.descendant(
    of: find.byType(MapSetupCard),
    matching: find.byType(CategoryArt),
  );
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  expect(find.text(BusinessTypePicker.title), findsOneWidget);
}

Future<void> openDistance(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(SearchDistanceField));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SearchDistanceField));
  await tester.pumpAndSettle();
  expect(find.byType(SearchDistanceSheet), findsOneWidget);
}

/// Fails with the framework's full overflow report.
void expectNoLayoutError(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error == null) return;
  fail('$where: ${error is FlutterError ? error.toStringDeep() : error}');
}

void main() {
  group('business type picker', () {
    testWidgets('groups every category into sections', (tester) async {
      await pumpApp(tester);
      await openPicker(tester);

      expect(find.text(BusinessGroup.food.label.toUpperCase()), findsOneWidget);
      final list = find
          .descendant(
            of: find.descendant(
              of: find.byType(BusinessTypePicker),
              matching: find.byType(ListView),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text(BusinessTypePicker.otherTitle),
        400,
        scrollable: list,
      );
      expect(find.text(BusinessTypePicker.otherTitle), findsOneWidget);
    });

    testWidgets('searching a Filipino term selects the category', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openPicker(tester);

      await tester.enterText(pickerSearch, 'botika');
      await tester.pumpAndSettle();
      expect(find.textContaining('Also called “botika”'), findsOneWidget);
      await tester.tap(find.text(BusinessCategory.pharmacy.label));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessTypePicker), findsNothing);
      expect(exploreOf(container).category, BusinessCategory.pharmacy);
      expect(competitors.calls, isEmpty, reason: 'choosing never searches');
    });

    testWidgets('clear search restores the full list', (tester) async {
      await pumpApp(tester);
      await openPicker(tester);
      await tester.enterText(pickerSearch, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text(BusinessTypePicker.noResults('zzzz')), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text(BusinessTypePicker.noResults('zzzz')), findsNothing);
      expect(find.text(BusinessCategory.coffeeShop.label), findsWidgets);
    });

    testWidgets('an other business type is confirmed before use', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openPicker(tester);

      await tester.enterText(pickerSearch, 'Motorcycle Parts Shop');
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(BusinessTypePicker.checkOther('Motorcycle Parts Shop')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Closest supported business type'), findsOneWidget);
      expect(
        exploreOf(container).category,
        BusinessCategory.coffeeShop,
        reason: 'nothing changes until confirmed',
      );
      await tester.tap(
        find.text('Use ${BusinessCategory.motorcycleShop.label}'),
      );
      await tester.pumpAndSettle();
      expect(exploreOf(container).category, BusinessCategory.motorcycleShop);
    });

    testWidgets('an unsupported type explains and offers related ones', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openPicker(tester);

      await tester.enterText(pickerSearch, 'bigasan');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text(BusinessTypePicker.unsupportedTitle), findsOneWidget);
      expect(find.textContaining('No search was run'), findsOneWidget);
      expect(find.text(BusinessTypePicker.relatedTitle), findsOneWidget);
      expect(competitors.calls, isEmpty);

      await tester.tap(find.text(BusinessCategory.convenience.label).last);
      await tester.pumpAndSettle();
      expect(exploreOf(container).category, BusinessCategory.convenience);
    });

    testWidgets('dismissing keeps the current type', (tester) async {
      final container = await pumpApp(tester);
      await openPicker(tester);
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessTypePicker), findsNothing);
      expect(exploreOf(container).category, BusinessCategory.coffeeShop);
    });
  });

  group('search distance', () {
    testWidgets('a preset applies in one tap', (tester) async {
      final container = await pumpApp(tester);
      await openDistance(tester);
      await tester.tap(find.text('250 m'));
      await tester.pumpAndSettle();
      expect(exploreOf(container).radius, SearchRadius.m250);
      expect(find.byType(SearchDistanceSheet), findsNothing);
    });

    testWidgets('invalid custom values explain the problem', (tester) async {
      final container = await pumpApp(tester);
      await openDistance(tester);

      for (final (text, error) in [
        ('abc', RadiusInputError.notANumber),
        ('-200', RadiusInputError.negative),
        ('1.5', RadiusInputError.decimal),
        ('50', RadiusInputError.tooSmall),
        ('5000', RadiusInputError.tooLarge),
        ('', RadiusInputError.empty),
      ]) {
        await tester.enterText(distanceInput, text);
        await tester.pumpAndSettle();
        expect(find.text(error.message), findsOneWidget, reason: text);
      }
      await tester.tap(find.text(SearchDistanceSheet.applyLabel));
      await tester.pumpAndSettle();
      expect(find.byType(SearchDistanceSheet), findsOneWidget);
      expect(exploreOf(container).radius, SearchRadius.km1);
    });

    testWidgets('a custom distance applies and reads back', (tester) async {
      final container = await pumpApp(tester);
      await openDistance(tester);

      await tester.enterText(distanceInput, '1500');
      await tester.pumpAndSettle();
      expect(find.textContaining('Will search within 1.5 km'), findsOneWidget);
      await tester.tap(find.text(SearchDistanceSheet.applyLabel));
      await tester.pumpAndSettle();

      expect(exploreOf(container).radius, SearchRadius.meters(1500));
      expect(
        find.descendant(
          of: find.byType(SearchDistanceField),
          matching: find.text('1.5 km'),
        ),
        findsOneWidget,
      );
      expect(competitors.calls, isEmpty, reason: 'no request until Find');

      // The search then uses exactly that distance.
      container
          .read(exploreControllerProvider.notifier)
          .selectSite(latitude: 15.0939, longitude: 120.7681);
      await tester.pumpAndSettle();
      await tester.tap(find.text(MapSetupCard.findLabel));
      await tester.pumpAndSettle();
      expect(competitors.calls.single.query.radius.meters, 1500);
      expect(find.textContaining('within 1.5 km'), findsWidgets);
    });

    testWidgets('an example fills the field; reopening shows the value', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openDistance(tester);
      await tester.tap(find.text('750'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SearchDistanceSheet.applyLabel));
      await tester.pumpAndSettle();
      expect(exploreOf(container).radius.meters, 750);

      await openDistance(tester);
      expect(tester.widget<TextField>(distanceInput).controller!.text, '750');
    });
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('small screen, large text, ${mode.name}: pickers fit', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await pumpApp(
        tester,
        size: const Size(320, 640),
        mode: mode,
      );
      expectNoLayoutError(tester, 'map card');

      await openPicker(tester);
      expectNoLayoutError(tester, 'picker');
      await tester.enterText(pickerSearch, 'water refilling station delivery');
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          BusinessTypePicker.checkOther('water refilling station delivery'),
        ),
      );
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, 'resolution card');
      final use = find.text('Use ${BusinessCategory.waterRefilling.label}');
      await tester.ensureVisible(use);
      await tester.pumpAndSettle();
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(exploreOf(container).category, BusinessCategory.waterRefilling);

      await openDistance(tester);
      await tester.enterText(distanceInput, '99999');
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, 'distance sheet with error');
      await tester.enterText(distanceInput, '300');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(SearchDistanceSheet.applyLabel));
      await tester.tap(find.text(SearchDistanceSheet.applyLabel));
      await tester.pumpAndSettle();
      expect(exploreOf(container).radius.meters, 300);
      expectNoLayoutError(tester, 'map card after changes');
    });
  }
}
