import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/redact.dart';
import '../../explore/state/explore_controller.dart';
import '../data/competitor_repository.dart';
import '../data/sample_competitors.dart';
import '../domain/competitors.dart';

enum CompetitorStatus { idle, loading, success, empty, error, sample }

@immutable
class CompetitorSearchState {
  const CompetitorSearchState({
    this.status = CompetitorStatus.idle,
    this.query,
    this.result,
    this.failure,
    this.statusCode,
    this.notice,
    this.selectedKey,
  });

  final CompetitorStatus status;

  /// The search the current status belongs to.
  final CompetitorQuery? query;

  /// Set for [CompetitorStatus.success], `empty`, and `sample`.
  final CompetitorResult? result;

  /// Set for [CompetitorStatus.error].
  final CompetitorFailure? failure;
  final int? statusCode;

  /// One-off explanation, e.g. why a refresh returned the cached copy.
  final String? notice;

  /// The business highlighted on the map / opened in details.
  final String? selectedKey;

  bool get isLoading => status == CompetitorStatus.loading;

  /// Records to draw and list; empty unless a result is showing.
  List<NearbyBusiness> get businesses => result?.businesses ?? const [];

  NearbyBusiness? get selected {
    final key = selectedKey;
    if (key == null) return null;
    for (final business in businesses) {
      if (business.key == key) return business;
    }
    return null;
  }

  CompetitorSearchState withSelection(String? key) => CompetitorSearchState(
    status: status,
    query: query,
    result: result,
    failure: failure,
    statusCode: statusCode,
    notice: notice,
    selectedKey: key,
  );
}

/// Runs competitor searches on explicit request only.
///
/// Each search gets a generation number and a [CancelToken]. Starting a new
/// search, cancelling, or changing the site/category/radius bumps the
/// generation and cancels the request in flight, so an older response can
/// never overwrite a newer view.
class CompetitorController extends Notifier<CompetitorSearchState> {
  static const throttledNotice =
      'Fetched moments ago. Showing that copy to avoid overloading the '
      'public Overpass server; refresh again in a minute.';

  int _generation = 0;
  CancelToken? _inFlight;

  @override
  CompetitorSearchState build() {
    ref.listen(
      exploreControllerProvider.select((s) => (s.site, s.category, s.radius)),
      (previous, next) {
        if (previous != next) _reset();
      },
    );
    ref.onDispose(() => _inFlight?.cancel());
    return const CompetitorSearchState();
  }

  /// Searches around the selected site. A no-op without a site.
  Future<void> search({bool forceRefresh = false}) async {
    final explore = ref.read(exploreControllerProvider);
    final site = explore.site;
    if (site == null) return;
    final query = CompetitorQuery.forSite(
      site,
      explore.category,
      explore.radius,
    );

    _inFlight?.cancel();
    final token = _inFlight = CancelToken();
    final generation = ++_generation;
    state = CompetitorSearchState(
      status: CompetitorStatus.loading,
      query: query,
    );

    try {
      final result = await ref
          .read(competitorRepositoryProvider)
          .fetch(query, forceRefresh: forceRefresh, cancelToken: token);
      if (!_isCurrent(generation)) return;
      state = CompetitorSearchState(
        status: result.isEmpty
            ? CompetitorStatus.empty
            : CompetitorStatus.success,
        query: query,
        result: result,
        notice: forceRefresh && result.source == DataSource.cached
            ? throttledNotice
            : null,
      );
    } on CompetitorSearchCancelled {
      // Superseded by a newer search or a settings change.
    } on CompetitorFetchException catch (e) {
      if (!_isCurrent(generation)) return;
      state = CompetitorSearchState(
        status: CompetitorStatus.error,
        query: query,
        failure: e.failure,
        statusCode: e.statusCode,
      );
    } catch (e) {
      if (!_isCurrent(generation)) return;
      debugPrint('Competitor search failed: ${describeError(e)}');
      state = CompetitorSearchState(
        status: CompetitorStatus.error,
        query: query,
        failure: CompetitorFailure.badResponse,
      );
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
    }
  }

  /// Stops a running search and returns to idle.
  void cancel() {
    if (!state.isLoading) return;
    _reset();
  }

  /// Shows the fictional sample dataset for the current settings. Only
  /// offered after a failed live search.
  void showSample() {
    final explore = ref.read(exploreControllerProvider);
    final site = explore.site;
    if (site == null) return;
    _inFlight?.cancel();
    _generation++;
    final query = CompetitorQuery.forSite(
      site,
      explore.category,
      explore.radius,
    );
    state = CompetitorSearchState(
      status: CompetitorStatus.sample,
      query: query,
      result: SampleCompetitors.forQuery(query, DateTime.now()),
    );
  }

  void selectBusiness(String? key) {
    if (key == state.selectedKey) return;
    if (key != null && !state.businesses.any((b) => b.key == key)) return;
    state = state.withSelection(key);
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  /// Results describe one site/category/radius; once any of them changes the
  /// old pins and counts would be misleading, so drop them.
  void _reset() {
    _inFlight?.cancel();
    _inFlight = null;
    _generation++;
    if (state.status != CompetitorStatus.idle) {
      state = const CompetitorSearchState();
    }
  }
}

final competitorControllerProvider =
    NotifierProvider<CompetitorController, CompetitorSearchState>(
      CompetitorController.new,
    );
