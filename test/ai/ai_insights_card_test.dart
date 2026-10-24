import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/app/theme.dart';
import 'package:pwestado/features/ai/data/ai_insights_client.dart';
import 'package:pwestado/features/ai/data/ai_payload.dart';
import 'package:pwestado/features/ai/domain/ai_insight.dart';
import 'package:pwestado/features/ai/presentation/ai_insights_card.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

import '../comparison/comparison_fixtures.dart';

/// Answers from a queue; counts calls. Never touches the network.
class FakeAiClient extends AiInsightsClient {
  FakeAiClient(this.answers, {this.configured = true})
    : super(dio: Dio(), apiKey: 'test-key-not-real-0123456789');

  final List<Object> answers;
  final bool configured;
  int calls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<AiInsight> fetch(
    Map<String, Object?> payload, {
    required bool isDemo,
    CancelToken? cancelToken,
  }) async {
    calls++;
    final next = answers.removeAt(0);
    if (next is AiFailure) throw AiInsightException(next);
    return AiInsight.parse(next, requestWasDemo: isDemo);
  }
}

const answer = {
  'model': 'gemini-3.1-flash-lite',
  'insight': {
    'quickAssessment': 'May ilang naka-map na coffee shop malapit dito.',
    'promising': ['Maraming paaralan sa paligid.'],
    'watchOuts': ['Tatlong competitor sa loob ng 1 km.'],
    'nextSteps': ['Bisitahin ang lugar sa umaga at gabi.'],
    'limitations': ['Hindi kumpleto ang OpenStreetMap.'],
  },
};

Future<void> pumpCard(
  WidgetTester tester, {
  required AiInsightsClient client,
  Map<String, Object?>? payload,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [aiInsightsClientProvider.overrideWithValue(client)],
      child: MaterialApp(
        theme: buildAppTheme(brightness),
        home: Scaffold(
          body: SingleChildScrollView(child: AiInsightsCard(payload: payload)),
        ),
      ),
    ),
  );
}

void main() {
  final live = AiPayload.site(analysisAt(queryAt(siteA)));
  final sample = AiPayload.site(
    analysisAt(queryAt(siteA), source: DataSource.sample),
  );

  testWidgets('nothing is requested until the user taps', (tester) async {
    final client = FakeAiClient([answer]);
    await pumpCard(tester, client: client, payload: live);
    expect(find.text(AiCopy.title), findsOneWidget);
    expect(find.text(AiCopy.privacy), findsOneWidget);
    expect(client.calls, 0);

    await tester.tap(find.text(AiCopy.ask));
    await tester.pumpAndSettle();
    expect(client.calls, 1);
    expect(find.text('What looks promising'), findsOneWidget);
    expect(find.text('What to watch out for'), findsOneWidget);
    expect(find.text('Practical next steps'), findsOneWidget);
    expect(find.text('Data limitations'), findsOneWidget);
    expect(find.text(AiCopy.label), findsOneWidget);
    expect(find.text(AiCopy.demo), findsNothing);
  });

  testWidgets('sample evidence is labeled as a DEMO insight', (tester) async {
    await pumpCard(tester, client: FakeAiClient([answer]), payload: sample);
    await tester.tap(find.text(AiCopy.ask));
    await tester.pumpAndSettle();
    expect(find.text(AiCopy.demo), findsOneWidget);
  });

  testWidgets('unconfigured builds explain and disable the action', (
    tester,
  ) async {
    final client = FakeAiClient([], configured: false);
    await pumpCard(tester, client: client, payload: live);
    expect(find.text(AiFailure.notConfigured.title), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(AiCopy.ask),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    expect(client.calls, 0);
  });

  testWidgets('missing evidence disables AI instead of guessing', (
    tester,
  ) async {
    final client = FakeAiClient([]);
    await pumpCard(tester, client: client, payload: null);
    expect(find.text(AiCopy.insufficient), findsOneWidget);
    expect(find.text(AiCopy.ask), findsNothing);
  });

  testWidgets('retryable errors offer Try again; quota does not', (
    tester,
  ) async {
    final client = FakeAiClient([AiFailure.timeout, answer]);
    await pumpCard(tester, client: client, payload: live);
    await tester.tap(find.text(AiCopy.ask));
    await tester.pumpAndSettle();
    expect(find.text(AiFailure.timeout.title), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('What looks promising'), findsOneWidget);
    expect(client.calls, 2);

    final quota = FakeAiClient([AiFailure.quotaExhausted]);
    await pumpCard(
      tester,
      client: quota,
      payload: AiPayload.site(analysisAt(queryAt(siteB))),
    );
    await tester.tap(find.text(AiCopy.ask));
    await tester.pumpAndSettle();
    expect(find.text(AiFailure.quotaExhausted.title), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('renders in dark mode with large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiInsightsClientProvider.overrideWithValue(FakeAiClient([answer])),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: SingleChildScrollView(child: AiInsightsCard(payload: live)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(AiCopy.ask));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
