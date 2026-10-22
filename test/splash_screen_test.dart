import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/app/router.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/presentation/explore_screen.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:pwestado/features/saved/presentation/saved_analyses_screen.dart';
import 'package:pwestado/features/splash/presentation/splash_screen.dart';

import 'fake_location_service.dart';
import 'fake_saved_analysis_repository.dart';

Widget app() => ProviderScope(
  overrides: [
    locationServiceProvider.overrideWithValue(FakeLocationService()),
    savedAnalysisRepositoryProvider.overrideWithValue(
      FakeSavedAnalysisRepository(),
    ),
  ],
  child: const PwestadoApp(),
);

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PwestadoApp)),
).read(routerProvider);

void main() {
  testWidgets('cold start shows the splash, then Explore exactly once', (
    tester,
  ) async {
    setSize(tester, const Size(412, 915));
    await tester.pumpWidget(app());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(ExploreScreen), findsNothing);
    expect(find.text('PWESTADO'), findsOneWidget);
    expect(find.text(SplashScreen.tagline), findsOneWidget);

    // Mid-sequence: still on the splash, nothing has navigated yet.
    await tester.pump(SplashScreen.duration ~/ 2);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(ExploreScreen), findsNothing);

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);

    final router = routerOf(tester);
    expect(router.state.matchedLocation, AppRoutes.explore);
    expect(router.canPop(), isFalse, reason: 'splash is not on the stack');
  });

  testWidgets('moving between Explore and Saved never re-shows the splash', (
    tester,
  ) async {
    setSize(tester, const Size(412, 915));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final router = routerOf(tester);
    router.push(AppRoutes.saved);
    await tester.pumpAndSettle();
    expect(find.byType(SavedAnalysesScreen), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);

    router.go(AppRoutes.explore);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(router.canPop(), isFalse);
  });

  testWidgets('reduced motion shows the settled splash and still leaves', (
    tester,
  ) async {
    setSize(tester, const Size(412, 915));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    final word = tester.widget<Opacity>(
      find.ancestor(of: find.text('PWESTADO'), matching: find.byType(Opacity)),
    );
    expect(word.opacity, 1, reason: 'no fade when animations are disabled');

    await tester.pump(SplashScreen.reducedMotionDuration);
    await tester.pumpAndSettle();
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  testWidgets('fits a compact screen without overflow', (tester) async {
    setSize(tester, const Size(320, 568));
    await tester.pumpWidget(app());
    await tester.pump(SplashScreen.duration * 0.8);
    expect(tester.takeException(), isNull);
    expect(find.text(SplashScreen.tagline), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('disposing mid-animation does not navigate or throw', (
    tester,
  ) async {
    setSize(tester, const Size(412, 915));
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(SplashScreen.duration);
    expect(tester.takeException(), isNull);
  });
}
