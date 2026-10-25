import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/theme.dart';
import 'package:pwestado/features/explore/presentation/widgets/map_load_problem.dart';

void main() {
  group('classifyMapLoadError', () {
    MapLoadProblem classify(
      String message, {
      bool style = false,
      int tileErrors = 0,
    }) => classifyMapLoadError(
      isStyleError: style,
      message: message,
      tileErrorsBeforeFirstRender: tileErrors,
    );

    test('HTTP 401/403 and token wording mean the token was rejected', () {
      // The black-map APK's malformed token fails exactly like this.
      expect(
        classify('Failed to load style: HTTP status code 401', style: true),
        MapLoadProblem.tokenRejected,
      );
      expect(classify('HTTP 403 Forbidden'), MapLoadProblem.tokenRejected);
      expect(
        classify('Not Authorized - Invalid Token'),
        MapLoadProblem.tokenRejected,
      );
    });

    test('other style errors are style failures', () {
      expect(
        classify('Unable to resolve host "api.mapbox.com"', style: true),
        MapLoadProblem.styleFailed,
      );
    });

    test('a few tile errors are ignored; many before any render are not', () {
      expect(classify('timeout', tileErrors: 1), MapLoadProblem.none);
      expect(
        classify('timeout', tileErrors: MapLoadWatchdog.tileErrorLimit),
        MapLoadProblem.tilesFailed,
      );
    });
  });

  testWidgets('the overlay explains the problem and retries', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MapProblemOverlay(
            problem: MapLoadProblem.tokenRejected,
            onRetry: () => retried++,
          ),
        ),
      ),
    );

    expect(find.text(MapLoadProblem.tokenRejected.title), findsOneWidget);
    // Users never see token or rebuild instructions.
    expect(find.textContaining('pk.'), findsNothing);
    expect(find.textContaining('token'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });
}
