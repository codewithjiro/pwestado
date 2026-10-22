import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/selected_site.dart';
import '../../../core/utils/redact.dart';
import '../../analysis/data/site_context_repository.dart';
import '../../analysis/domain/site_analysis.dart';
import '../../analysis/domain/site_context.dart';
import '../../analysis/state/analysis_controller.dart';
import '../../discovery/data/competitor_repository.dart';
import '../../discovery/data/sample_competitors.dart';
import '../../discovery/domain/competitors.dart';
import '../../explore/state/explore_controller.dart';
import '../../saved/domain/saved_analysis.dart';
import '../domain/site_comparison.dart';

enum SlotStatus {
  /// No site assigned.
  empty,

  /// Site assigned, not analyzed (or settings changed while loading).
  pending,
  loading,

  /// [SlotState.analysis] is set; its total may still be "Insufficient data".
  ready,

  /// The competitor search for this slot failed; nothing to score.
  failed,
}

/// One comparison slot: its own site and its own analysis snapshot. Nothing
/// outside the slot's own actions can change it, so picking a new pin on
/// the map never overwrites a stored site.
@immutable
class SlotState {
  const SlotState({
    this.site,
    this.status = SlotStatus.empty,
    this.analysis,
    this.failure,
    this.statusCode,
    this.reused = false,
    this.savedAt,
  });

  final SelectedSite? site;
  final SlotStatus status;

  /// Set for [SlotStatus.ready].
  final SiteAnalysis? analysis;

  /// Set for [SlotStatus.failed].
  final CompetitorFailure? failure;
  final int? statusCode;

  /// True when [analysis] was taken over from the main screen's analysis
  /// instead of being requested again.
  final bool reused;

  /// Set when [analysis] was reopened from Saved Analyses: a historical
  /// result with its original evidence times, not a fresh request.
  final DateTime? savedAt;

  bool get isSaved => savedAt != null;

  bool get isLoading => status == SlotStatus.loading;
}

@immutable
class ComparisonState {
  const ComparisonState({
    this.a = const SlotState(),
    this.b = const SlotState(),
  });

  final SlotState a;
  final SlotState b;

  SlotState operator [](CompareSlot slot) => slot == CompareSlot.a ? a : b;

  ComparisonState withSlot(CompareSlot slot, SlotState value) =>
      slot == CompareSlot.a
      ? ComparisonState(a: value, b: b)
      : ComparisonState(a: a, b: value);

  /// The slot with a request in flight, if any.
  CompareSlot? get loadingSlot => a.isLoading
      ? CompareSlot.a
      : b.isLoading
      ? CompareSlot.b
      : null;

  bool get hasAnySite => a.site != null || b.site != null;
}

/// Holds Site A and Site B and analyzes each one independently with the
/// current business category and radius.
///
/// Requests go through the same cached repositories as the main screen, and
/// an analysis already on the main screen for the same site and settings is
/// reused without any request. Only one slot loads at a time, to stay
/// gentle with the shared Overpass server.
class ComparisonController extends Notifier<ComparisonState> {
  final _generation = {CompareSlot.a: 0, CompareSlot.b: 0};
  final _inFlight = <CompareSlot, CancelToken>{};

  @override
  ComparisonState build() {
    ref.listen(
      exploreControllerProvider.select((s) => (s.category, s.radius)),
      (previous, next) {
        if (previous != next) _onSettingsChanged();
      },
    );
    ref.listen(analysisControllerProvider.select((s) => s.analysis), (
      previous,
      next,
    ) {
      if (next != null && !identical(previous, next)) _adopt(next);
    });
    ref.onDispose(() {
      for (final token in _inFlight.values) {
        token.cancel();
      }
    });
    return const ComparisonState();
  }

  /// Stores the map's current pin in [slot]. The other slot is untouched.
  void assignCurrentSite(CompareSlot slot) {
    final site = ref.read(exploreControllerProvider).site;
    if (site == null) return;
    final current = state[slot];
    if (current.site == site && current.status != SlotStatus.empty) return;

    _cancel(slot);
    state = state.withSlot(
      slot,
      SlotState(site: site, status: SlotStatus.pending),
    );
    final mainAnalysis = ref.read(analysisControllerProvider).analysis;
    if (mainAnalysis != null) _adopt(mainAnalysis);
  }

  void clear(CompareSlot slot) {
    _cancel(slot);
    state = state.withSlot(slot, const SlotState());
  }

  /// Stops the request in flight for [slot]; the site stays assigned.
  void cancel(CompareSlot slot) {
    if (!state[slot].isLoading) return;
    _cancel(slot);
    state = state.withSlot(
      slot,
      SlotState(site: state[slot].site, status: SlotStatus.pending),
    );
  }

  /// Analyzes [slot]'s site with the current category and radius.
  ///
  /// Without [forceRefresh], an existing analysis for exactly this query is
  /// kept, and the repositories answer from their cache when they can. A
  /// no-op while the other slot is loading.
  Future<void> analyze(CompareSlot slot, {bool forceRefresh = false}) async {
    final current = state[slot];
    final site = current.site;
    if (site == null || current.isLoading) return;
    if (state[slot.other].isLoading) return;

    final query = _queryFor(site);
    if (!forceRefresh && current.analysis?.competitors.query == query) {
      if (current.status != SlotStatus.ready) {
        state = state.withSlot(
          slot,
          SlotState(
            site: site,
            status: SlotStatus.ready,
            analysis: current.analysis,
            reused: current.reused,
            savedAt: current.savedAt,
          ),
        );
      }
      return;
    }
    if (!forceRefresh && _tryReuseMain(slot, site, query)) return;

    _cancel(slot);
    final token = _inFlight[slot] = CancelToken();
    final generation = _generation[slot]!;
    state = state.withSlot(
      slot,
      SlotState(site: site, status: SlotStatus.loading),
    );

    bool isCurrent() => ref.mounted && _generation[slot] == generation;

    try {
      final competitors = await ref
          .read(competitorRepositoryProvider)
          .fetch(query, forceRefresh: forceRefresh, cancelToken: token);
      if (!isCurrent()) return;

      SiteAnalysis analysis;
      try {
        final context = await ref
            .read(siteContextRepositoryProvider)
            .fetch(query, forceRefresh: forceRefresh, cancelToken: token);
        analysis = SiteAnalysis.from(
          competitors: competitors,
          context: context,
        );
      } on CompetitorFetchException catch (e) {
        analysis = SiteAnalysis.from(
          competitors: competitors,
          contextFailure: e.failure,
          contextStatusCode: e.statusCode,
        );
      }
      if (!isCurrent()) return;
      state = state.withSlot(
        slot,
        SlotState(site: site, status: SlotStatus.ready, analysis: analysis),
      );
    } on CompetitorSearchCancelled {
      // Superseded by a reset, a cancel, or a settings change.
    } on CompetitorFetchException catch (e) {
      if (!isCurrent()) return;
      state = state.withSlot(
        slot,
        SlotState(
          site: site,
          status: SlotStatus.failed,
          failure: e.failure,
          statusCode: e.statusCode,
        ),
      );
    } catch (e) {
      if (!isCurrent()) return;
      debugPrint('Comparison analysis failed: ${describeError(e)}');
      state = state.withSlot(
        slot,
        SlotState(
          site: site,
          status: SlotStatus.failed,
          failure: CompetitorFailure.badResponse,
        ),
      );
    } finally {
      if (identical(_inFlight[slot], token)) _inFlight.remove(slot);
    }
  }

  /// Analyzes every assigned slot that lacks a current analysis, one after
  /// the other.
  Future<void> analyzeAll() async {
    for (final slot in CompareSlot.values) {
      final current = state[slot];
      final site = current.site;
      if (site == null) continue;
      if (current.analysis?.competitors.query == _queryFor(site)) continue;
      await analyze(slot);
      if (!ref.mounted) return;
    }
  }

  /// SAMPLE DEMO MODE for [slot], offered only after its search failed.
  void useSample(CompareSlot slot) {
    final site = state[slot].site;
    if (site == null) return;
    _cancel(slot);
    final query = _queryFor(site);
    final now = DateTime.now();
    state = state.withSlot(
      slot,
      SlotState(
        site: site,
        status: SlotStatus.ready,
        analysis: SiteAnalysis.from(
          competitors: SampleCompetitors.forQuery(query, now),
          context: SampleSiteContext.forQuery(query, now),
        ),
      ),
    );
  }

  /// Puts a reopened saved analysis in [slot], as it was saved. Nothing is
  /// requested; [loadSaved] callers align the search settings first so the
  /// usual comparison rules (same category and radius) apply.
  void loadSaved(CompareSlot slot, SavedAnalysis saved) {
    _cancel(slot);
    state = state.withSlot(
      slot,
      SlotState(
        site: saved.site,
        status: SlotStatus.ready,
        analysis: saved.analysis,
        savedAt: saved.savedAt,
      ),
    );
  }

  CompetitorQuery _queryFor(SelectedSite site) {
    final explore = ref.read(exploreControllerProvider);
    return CompetitorQuery.forSite(site, explore.category, explore.radius);
  }

  /// Takes over the main screen's analysis when it is for this exact query.
  bool _tryReuseMain(CompareSlot slot, SelectedSite site, CompetitorQuery q) {
    final main = ref.read(analysisControllerProvider).analysis;
    if (main == null || main.competitors.query != q) return false;
    state = state.withSlot(
      slot,
      SlotState(
        site: site,
        status: SlotStatus.ready,
        analysis: main,
        reused: true,
      ),
    );
    return true;
  }

  /// A finished main-screen analysis fills any idle slot for the same site
  /// and current settings, so the user never pays for the same request
  /// twice. Loading slots and slots already holding this query are left
  /// alone.
  void _adopt(SiteAnalysis analysis) {
    for (final slot in CompareSlot.values) {
      final current = state[slot];
      final site = current.site;
      if (site == null || current.isLoading) continue;
      final query = _queryFor(site);
      if (analysis.competitors.query != query) continue;
      if (current.analysis?.competitors.query == query && !current.reused) {
        continue;
      }
      _tryReuseMain(slot, site, query);
    }
  }

  /// A request for the old settings would describe the wrong search, so
  /// cancel it. Finished analyses stay visible; the comparison reports them
  /// as needing a re-run.
  void _onSettingsChanged() {
    for (final slot in CompareSlot.values) {
      if (!state[slot].isLoading) continue;
      _cancel(slot);
      state = state.withSlot(
        slot,
        SlotState(site: state[slot].site, status: SlotStatus.pending),
      );
    }
  }

  void _cancel(CompareSlot slot) {
    _inFlight.remove(slot)?.cancel();
    _generation[slot] = _generation[slot]! + 1;
  }
}

final comparisonControllerProvider =
    NotifierProvider<ComparisonController, ComparisonState>(
      ComparisonController.new,
    );

/// The comparison verdict for the current slots and settings.
final siteComparisonProvider = Provider<SiteComparison>((ref) {
  final slots = ref.watch(comparisonControllerProvider);
  final explore = ref.watch(exploreControllerProvider);
  return compareSites(
    a: slots.a.analysis,
    b: slots.b.analysis,
    category: explore.category,
    radius: explore.radius,
    now: DateTime.now(),
    saved: {
      for (final slot in CompareSlot.values)
        if (slots[slot].isSaved) slot,
    },
  );
});
