import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/discovery/state/competitor_controller.dart';
import 'package:pwestado/features/explore/data/location_service.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';

import '../fake_competitor_repository.dart';
import '../fake_location_service.dart';

void main() {
  late FakeCompetitorRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeCompetitorRepository();
    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        competitorRepositoryProvider.overrideWithValue(repo),
      ],
    );
    // Start listening, as the screen does.
    container.listen(competitorControllerProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  ExploreController explore() =>
      container.read(exploreControllerProvider.notifier);
  CompetitorController controller() =>
      container.read(competitorControllerProvider.notifier);
  CompetitorSearchState state() => container.read(competitorControllerProvider);

  void pickSite() =>
      explore().selectSite(latitude: 15.0939, longitude: 120.7681);

  test('starts idle and does nothing without a site', () async {
    expect(state().status, CompetitorStatus.idle);
    await controller().search();
    expect(repo.calls, isEmpty);
    expect(state().status, CompetitorStatus.idle);
  });

  test('uses the selected site, category and radius', () async {
    pickSite();
    explore()
      ..selectCategory(BusinessCategory.bakery)
      ..selectRadius(SearchRadius.km2);
    final search = controller().search();

    expect(state().status, CompetitorStatus.loading);
    final query = repo.calls.single.query;
    expect(query.category, BusinessCategory.bakery);
    expect(query.radius, SearchRadius.km2);
    expect(query.latitude, 15.0939);
    expect(query.longitude, 120.7681);

    repo.pending.single.complete(resultFor(query, [business(1)]));
    await search;
  });

  test('loading → success with the response records', () async {
    pickSite();
    final search = controller().search();
    final query = repo.calls.single.query;
    repo.pending.single.complete(
      resultFor(query, [business(1, name: 'A'), business(2)]),
    );
    await search;

    expect(state().status, CompetitorStatus.success);
    expect(state().businesses.map((b) => b.key), ['node:1', 'node:2']);
    expect(state().result!.source, DataSource.live);
    expect(state().query, query);
  });

  test('loading → empty when the server returns no records', () async {
    pickSite();
    final search = controller().search();
    repo.pending.single.complete(resultFor(repo.calls.single.query, []));
    await search;

    expect(state().status, CompetitorStatus.empty);
    expect(state().businesses, isEmpty);
  });

  for (final failure in CompetitorFailure.values) {
    test('loading → error (${failure.name}) keeps no records', () async {
      pickSite();
      final search = controller().search();
      repo.pending.single.completeError(
        CompetitorFetchException(failure, statusCode: 429),
      );
      await search;

      expect(state().status, CompetitorStatus.error);
      expect(state().failure, failure);
      expect(state().statusCode, 429);
      expect(state().businesses, isEmpty);
    });
  }

  test('an unexpected exception becomes a bad-response error', () async {
    pickSite();
    final search = controller().search();
    repo.pending.single.completeError(StateError('boom'));
    await search;

    expect(state().status, CompetitorStatus.error);
    expect(state().failure, CompetitorFailure.badResponse);
  });

  test('a newer search cancels the older request', () async {
    pickSite();
    final first = controller().search();
    final second = controller().search();

    expect(repo.tokens.first!.isCancelled, isTrue);
    repo.pending.last.complete(resultFor(repo.calls.last.query, [business(2)]));
    await Future.wait([first, second]);
    expect(state().status, CompetitorStatus.success);
    expect(state().businesses.single.key, 'node:2');
  });

  test('a stale response that ignores cancellation is discarded', () async {
    repo.ignoreCancel = true;
    pickSite();
    final first = controller().search();
    explore().selectCategory(BusinessCategory.restaurant);
    final second = controller().search();

    // Newer answers first, older answers last: the older one must not win.
    repo.pending[1].complete(
      resultFor(repo.calls[1].query, [business(2, name: 'Restaurant')]),
    );
    await second;
    repo.pending[0].complete(
      resultFor(repo.calls[0].query, [business(1, name: 'Old cafe')]),
    );
    await first;

    expect(state().businesses.single.name, 'Restaurant');
    expect(state().query!.category, BusinessCategory.restaurant);
  });

  test('a stale error does not replace newer results', () async {
    repo.ignoreCancel = true;
    pickSite();
    final first = controller().search();
    final second = controller().search();
    repo.pending[1].complete(resultFor(repo.calls[1].query, [business(2)]));
    await second;
    repo.pending[0].completeError(
      const CompetitorFetchException(CompetitorFailure.timeout),
    );
    await first;

    expect(state().status, CompetitorStatus.success);
  });

  group('settings changes clear results and cancel requests', () {
    Future<void> showResults() async {
      pickSite();
      final search = controller().search();
      repo.pending.single.complete(
        resultFor(repo.calls.single.query, [business(1)]),
      );
      await search;
      expect(state().status, CompetitorStatus.success);
    }

    test('category change', () async {
      await showResults();
      explore().selectCategory(BusinessCategory.laundry);
      expect(state().status, CompetitorStatus.idle);
      expect(state().businesses, isEmpty);
    });

    test('radius change', () async {
      await showResults();
      explore().selectRadius(SearchRadius.m500);
      expect(state().status, CompetitorStatus.idle);
    });

    test('new site', () async {
      await showResults();
      explore().selectSite(latitude: 15.1, longitude: 120.77);
      expect(state().status, CompetitorStatus.idle);
    });

    test('cleared site', () async {
      await showResults();
      explore().clearSite();
      expect(state().status, CompetitorStatus.idle);
    });

    test('re-selecting the same category keeps results', () async {
      await showResults();
      explore().selectCategory(BusinessCategory.coffeeShop);
      expect(state().status, CompetitorStatus.success);
    });

    test('a change while loading cancels the request', () async {
      pickSite();
      final search = controller().search();
      explore().selectRadius(SearchRadius.km2);
      await search;

      expect(repo.tokens.single!.isCancelled, isTrue);
      expect(state().status, CompetitorStatus.idle);
    });
  });

  test('cancel stops loading and returns to idle', () async {
    pickSite();
    final search = controller().search();
    controller().cancel();
    await search;
    expect(repo.tokens.single!.isCancelled, isTrue);
    expect(state().status, CompetitorStatus.idle);
  });

  test('refresh passes forceRefresh and explains a throttled copy', () async {
    pickSite();
    repo.respond = (q) =>
        resultFor(q, [business(1)], source: DataSource.cached);
    await controller().search(forceRefresh: true);

    expect(repo.calls.single.forceRefresh, isTrue);
    expect(state().result!.source, DataSource.cached);
    expect(state().notice, CompetitorController.throttledNotice);
  });

  test('a normal cached hit has no notice', () async {
    pickSite();
    repo.respond = (q) =>
        resultFor(q, [business(1)], source: DataSource.cached);
    await controller().search();
    expect(state().notice, isNull);
  });

  group('sample mode', () {
    test('is labeled sample and is never live', () {
      pickSite();
      controller().showSample();

      expect(state().status, CompetitorStatus.sample);
      expect(state().result!.source, DataSource.sample);
      expect(state().businesses, isNotEmpty);
      expect(state().businesses.every((b) => b.isSample), isTrue);
      expect(repo.calls, isEmpty, reason: 'no network for sample data');
    });

    test('is cleared by a settings change', () {
      pickSite();
      controller().showSample();
      explore().selectRadius(SearchRadius.km2);
      expect(state().status, CompetitorStatus.idle);
    });

    test('a live search replaces it', () async {
      pickSite();
      controller().showSample();
      final search = controller().search();
      expect(state().status, CompetitorStatus.loading);
      expect(state().businesses, isEmpty);
      repo.pending.single.complete(
        resultFor(repo.calls.single.query, [business(1)]),
      );
      await search;
      expect(state().result!.source, DataSource.live);
    });
  });

  test('selection only accepts records in the current result', () async {
    pickSite();
    repo.respond = (q) => resultFor(q, [business(1), business(2)]);
    await controller().search();

    controller().selectBusiness('node:2');
    expect(state().selected!.osmId, 2);
    controller().selectBusiness('node:999');
    expect(state().selectedKey, 'node:2');
    controller().selectBusiness(null);
    expect(state().selected, isNull);
  });
}
