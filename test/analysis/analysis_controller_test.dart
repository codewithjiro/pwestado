import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/analysis/data/site_context_repository.dart';
import 'package:pwestado/features/analysis/state/analysis_controller.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';

import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';
import '../fake_site_context_repository.dart';

void main() {
  late FakeCompetitorRepository competitors;
  late FakeSiteContextRepository contexts;
  late ProviderContainer container;

  setUp(() {
    competitors = FakeCompetitorRepository(
      respond: (q) => resultFor(q, [
        business(1, distance: 100),
        business(2, distance: 200),
        business(3, distance: 600),
      ]),
    );
    contexts = FakeSiteContextRepository();
    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        competitorRepositoryProvider.overrideWithValue(competitors),
        siteContextRepositoryProvider.overrideWithValue(contexts),
      ],
    );
    container.listen(competitorControllerProvider, (_, _) {});
    container.listen(analysisControllerProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  AnalysisController controller() =>
      container.read(analysisControllerProvider.notifier);
  AnalysisState state() => container.read(analysisControllerProvider);

  Future<void> searchCompetitors() async {
    container
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0939, longitude: 120.7681);
    await container.read(competitorControllerProvider.notifier).search();
  }

  test('does nothing before a competitor result exists', () async {
    await controller().analyze();
    expect(contexts.calls, isEmpty);
    expect(state().status, AnalysisStatus.idle);
  });

  test('fetches context for the same query and scores it', () async {
    await searchCompetitors();
    final analyzing = controller().analyze();
    expect(state().status, AnalysisStatus.loading);
    final query = contexts.calls.single.query;
    expect(query, container.read(competitorControllerProvider).query);

    contexts.pending.single.complete(contextFor(query));
    await analyzing;

    final analysis = state().analysis!;
    expect(state().status, AnalysisStatus.ready);
    // 0.40 × 75 + 0.30 × 12 + 0.30 × 100
    expect(analysis.score.total, 63.6);
    expect(analysis.isSample, isFalse);
  });

  test('a failed context query gives Insufficient data, not zeros', () async {
    await searchCompetitors();
    final analyzing = controller().analyze();
    contexts.pending.single.completeError(
      const CompetitorFetchException(
        CompetitorFailure.serverBusy,
        statusCode: 504,
      ),
    );
    await analyzing;

    final analysis = state().analysis!;
    expect(analysis.score.total, isNull);
    expect(analysis.contextFailure, CompetitorFailure.serverBusy);
    expect(analysis.contextStatusCode, 504);
    expect(analysis.score.criteria.first.score, 75);
    expect(analysis.score.criteria[1].score, isNull);
    expect(analysis.score.criteria[2].score, isNull);
  });

  test('sample competitors get sample context without any request', () async {
    container
        .read(exploreControllerProvider.notifier)
        .selectSite(latitude: 15.0939, longitude: 120.7681);
    container.read(competitorControllerProvider.notifier).showSample();

    await controller().analyze();

    expect(contexts.calls, isEmpty);
    final analysis = state().analysis!;
    expect(analysis.isSample, isTrue);
    expect(analysis.context!.source, DataSource.sample);
    expect(analysis.score.total, isNotNull);
  });

  test('changing settings cancels and clears the analysis', () async {
    await searchCompetitors();
    final analyzing = controller().analyze();
    final pending = contexts.pending.single;

    container
        .read(exploreControllerProvider.notifier)
        .selectRadius(SearchRadius.km2);
    await analyzing;

    expect(state().status, AnalysisStatus.idle);
    expect(pending.isCompleted, isTrue); // cancelled
  });

  test('a stale response cannot overwrite a newer analysis', () async {
    await searchCompetitors();
    final first = controller().analyze();
    final second = controller().analyze(forceRefresh: true);
    expect(contexts.calls.last.forceRefresh, isTrue);

    contexts.pending.last.complete(
      contextFor(contexts.calls.last.query, complementary: 50),
    );
    await Future.wait([first, second]);

    expect(state().analysis!.score.criteria[1].score, 100);
  });
}
