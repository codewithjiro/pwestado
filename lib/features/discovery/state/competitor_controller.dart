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
    this.clearedNotice,
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

  /// Set on an idle state when earlier results were dropped because the
  /// location, business type or distance changed: tells the user why the
  /// results disappeared and that they need to search again.
  final String? clearedNotice;

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
      'Fetched moments ago, so these are the same results. Refresh again '
      'in a minute for an update.';

  int _generation = 0;
  CancelToken? _inFlight;

  /// "You changed the business type, so the earlier results were cleared…"
  static String clearedNoticeFor({
    required bool location,
    required bool businessType,
    required bool distance,
  }) {
    final changed = [
      if (location) 'location',
      if (businessType) 'business type',
      if (distance) 'search distance',
    ];
    final what = changed.length <= 1
        ? (changed.isEmpty ? 'settings' : changed.single)
        : '${changed.sublist(0, changed.length - 1).join(', ')} and '
              '${changed.last}';
    return 'You changed the $what, so the earlier results were cleared. '
        'Search again to see results for your new choice.';
  }

  @override
  CompetitorSearchState build() {
    ref.listen(
      exploreControllerProvider.select((s) => (s.site, s.category, s.radius)),
      (previous, next) {
        if (previous == next) return;
        final hadResults =
            state.status != CompetitorStatus.idle ||
            state.clearedNotice != null;
        _reset();
        // Without a location there is nothing to search again; the card
        // already asks for one.
        if (hadResults && previous != null && next.$1 != null) {
          state = CompetitorSearchState(
            clearedNotice: clearedNoticeFor(
              location: previous.$1 != next.$1,
              businessType: previous.$2 != next.$2,
              distance: previous.$3 != next.$3,
            ),
          );
        } else if (state.clearedNotice != null) {
          state = const CompetitorSearchState();
        }
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
