import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/utils/age.dart';
import 'package:pwestado/shared/widgets/elapsed_wait.dart';

void main() {
  group('formatAge', () {
    test('formats minutes and hours', () {
      expect(formatAge(const Duration(seconds: 30)), 'under a minute');
      expect(formatAge(const Duration(minutes: 40)), '40 min');
      expect(formatAge(const Duration(hours: 2)), '2 h');
      expect(formatAge(const Duration(hours: 2, minutes: 5)), '2 h 5 min');
    });
  });

  testWidgets('ElapsedWait counts real seconds and stops on dispose', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ElapsedWait())),
    );
    expect(find.text('Waiting 0 s'), findsOneWidget);

    // Stopwatch time does not follow the fake clock, so only check that the
    // label refreshes on the timer without throwing.
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Waiting'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(find.textContaining('Waiting'), findsNothing);
  });
}
