import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/app.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/explore/presentation/widgets/search_panel.dart';
import 'package:pwestado/features/explore/presentation/widgets/map_placeholder.dart';

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: PwestadoApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone layout shows branding, labeled placeholder, controls', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915));

    expect(find.text('PWESTADO'), findsOneWidget);
    expect(find.text('Ang tamang pwesto, simula ng negosyo.'), findsOneWidget);
    expect(find.text(MapPlaceholder.title), findsOneWidget);
    expect(find.text('PLACEHOLDER — NOT A MAP'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Find competitors'),
      200,
      scrollable: find.descendant(
        of: find.byType(SearchPanel),
        matching: find.byType(Scrollable),
      ),
    );
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Find competitors'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.enabled, isFalse, reason: 'no site selected yet');
    expect(find.text('No site selected'), findsOneWidget);
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

  testWidgets('wide layout uses a side panel instead of a sheet', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byType(SearchPanel), findsOneWidget);
    expect(find.text(MapPlaceholder.title), findsOneWidget);
  });

  testWidgets('about sheet explains data sources', (tester) async {
    await pumpApp(tester, const Size(412, 915));

    await tester.tap(find.byTooltip('About PWESTADO and its data'));
    await tester.pumpAndSettle();
    expect(find.text('About PWESTADO'), findsOneWidget);
    expect(find.text('Business listings'), findsOneWidget);
  });
}
