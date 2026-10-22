import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/redact.dart';
import '../../discovery/domain/competitors.dart';
import '../../discovery/state/competitor_controller.dart';
import '../data/site_context_repository.dart';
import '../domain/site_analysis.dart';
import '../domain/site_context.dart';

enum AnalysisStatus { idle, loading, ready }

@immutable
class AnalysisState {
  const AnalysisState({this.status = AnalysisStatus.idle, this.analysis});

  final AnalysisStatus status;

  /// Set for [AnalysisStatus.ready]; may carry "Insufficient data".
  final SiteAnalysis? analysis;

  bool get isLoading => status == AnalysisStatus.loading;
}

/// Scores the site of the current competitor result, on explicit request.
///
/// Fetches one extra Overpass request (complementary places + nearby roads)
/// for the same site, category, and radius. A failed request still yields
/// an analysis, with the affected criteria unavailable and no total. Any
/// change to the competitor result (new search, settings change) cancels
/// the request in flight and clears the analysis, so a score never
/// describes a different site than the one on screen.
class AnalysisController extends Notifier<AnalysisState> {
  int _generation = 0;
  CancelToken? _inFlight;

  @override
  AnalysisState build() {
    ref.listen(competitorControllerProvider.select((s) => s.result), (
      previous,
      next,
    ) {
      if (!identical(previous, next)) _reset();
    });
    ref.onDispose(() => _inFlight?.cancel());
    return const AnalysisState();
  }

  /// Analyzes the competitor result on screen. A no-op without one.
  Future<void> analyze({bool forceRefresh = false}) async {
    final competitors = ref.read(competitorControllerProvider).result;
    if (competitors == null) return;

    _inFlight?.cancel();
    _inFlight = null;
    final generation = ++_generation;

    if (competitors.source == DataSource.sample) {
      // Sample records get sample context; never mix fiction with live data.
      state = AnalysisState(
        status: AnalysisStatus.ready,
        analysis: SiteAnalysis.from(
          competitors: competitors,
          context: SampleSiteContext.forQuery(
            competitors.query,
            DateTime.now(),
          ),
        ),
      );
      return;
    }

    final token = _inFlight = CancelToken();
    state = const AnalysisState(status: AnalysisStatus.loading);
    try {
      final context = await ref
          .read(siteContextRepositoryProvider)
          .fetch(
            competitors.query,
            forceRefresh: forceRefresh,
            cancelToken: token,
          );
      if (!_isCurrent(generation)) return;
      state = AnalysisState(
        status: AnalysisStatus.ready,
        analysis: SiteAnalysis.from(competitors: competitors, context: context),
      );
    } on CompetitorSearchCancelled {
      // Superseded by a newer request or a reset.
    } on CompetitorFetchException catch (e) {
      if (!_isCurrent(generation)) return;
      state = AnalysisState(
        status: AnalysisStatus.ready,
        analysis: SiteAnalysis.from(
          competitors: competitors,
          contextFailure: e.failure,
          contextStatusCode: e.statusCode,
        ),
      );
    } catch (e) {
      if (!_isCurrent(generation)) return;
      debugPrint('Site analysis failed: ${describeError(e)}');
      state = AnalysisState(
        status: AnalysisStatus.ready,
        analysis: SiteAnalysis.from(
          competitors: competitors,
          contextFailure: CompetitorFailure.badResponse,
        ),
      );
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
    }
  }

  /// Stops a running analysis and returns to idle.
  void cancel() {
    if (!state.isLoading) return;
    _reset();
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _reset() {
    _inFlight?.cancel();
    _inFlight = null;
    _generation++;
    if (state.status != AnalysisStatus.idle) state = const AnalysisState();
  }
}

final analysisControllerProvider =
    NotifierProvider<AnalysisController, AnalysisState>(AnalysisController.new);
