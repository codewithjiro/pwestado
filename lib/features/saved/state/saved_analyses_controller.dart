import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/selected_site.dart';
import '../../analysis/domain/site_analysis.dart';
import '../data/saved_analysis_repository.dart';
import '../domain/saved_analysis.dart';

@immutable
class SavedAnalysesState {
  const SavedAnalysesState({
    this.items = const [],
    this.loading = true,
    this.error,
    this.savedIds = const {},
    this.saving = const {},
  });

  /// Newest first.
  final List<SavedAnalysisSummary> items;
  final bool loading;

  /// A storage problem while listing; safe to display.
  final String? error;

  /// Analyses saved in this session, by identity, mapped to their record
  /// id, so the same on-screen analysis is not saved twice by accident.
  final Map<SiteAnalysis, int> savedIds;

  /// Analyses with a save in progress, by identity, so the UI can show
  /// "Saving…" and not offer a second save.
  final Set<SiteAnalysis> saving;

  bool isSaving(SiteAnalysis analysis) => saving.contains(analysis);

  SavedAnalysesState copyWith({
    List<SavedAnalysisSummary>? items,
    bool? loading,
    String? error,
    bool clearError = false,
    Map<SiteAnalysis, int>? savedIds,
    Set<SiteAnalysis>? saving,
  }) => SavedAnalysesState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    savedIds: savedIds ?? this.savedIds,
    saving: saving ?? this.saving,
  );
}

/// The result of a save: the new record id, or a displayable error.
typedef SaveOutcome = ({int? id, String? error});

/// Saved Analyses list plus save / delete / undo. Writes happen only on an
/// explicit user action; nothing here refreshes or rewrites a record.
class SavedAnalysesController extends Notifier<SavedAnalysesState> {
  /// Session marks removed by a delete, kept so undo can restore them.
  final _undoMarks = <int, List<SiteAnalysis>>{};

  /// Saves in flight, by analysis identity. A second tap (or a second
  /// button for the same analysis) joins the first save instead of writing
  /// a duplicate record.
  final _pendingSaves = Map<SiteAnalysis, Future<SaveOutcome>>.identity();

  SavedAnalysisRepository get _repo =>
      ref.read(savedAnalysisRepositoryProvider);

  @override
  SavedAnalysesState build() {
    Future.microtask(refresh);
    return const SavedAnalysesState();
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _repo.list();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } on SavedAnalysisStorageException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  int? savedIdOf(SiteAnalysis analysis) => state.savedIds[analysis];

  /// Saves [analysis] once. While a save of the same analysis is running,
  /// callers share its outcome; after a failure nothing is marked, so the
  /// user can simply try again.
  Future<SaveOutcome> save(SelectedSite site, SiteAnalysis analysis) {
    final existing = state.savedIds[analysis];
    if (existing != null) return Future.value((id: existing, error: null));
    return _pendingSaves[analysis] ??= _save(site, analysis);
  }

  Future<SaveOutcome> _save(SelectedSite site, SiteAnalysis analysis) async {
    state = state.copyWith(saving: _withSaving(analysis, true));
    try {
      final id = await _repo.save(site, analysis, DateTime.now());
      if (ref.mounted) {
        state = state.copyWith(
          savedIds: Map.identity()
            ..addAll(state.savedIds)
            ..[analysis] = id,
          saving: _withSaving(analysis, false),
        );
        await refresh();
      }
      return (id: id, error: null);
    } on SavedAnalysisStorageException catch (e) {
      return (id: null, error: e.message);
    } catch (e) {
      debugPrint('Saving an analysis failed: ${e.runtimeType}');
      return (id: null, error: 'Could not save the analysis on this device.');
    } finally {
      _pendingSaves.remove(analysis);
      if (ref.mounted && state.isSaving(analysis)) {
        state = state.copyWith(saving: _withSaving(analysis, false));
      }
    }
  }

  Set<SiteAnalysis> _withSaving(SiteAnalysis analysis, bool saving) {
    final next = Set<SiteAnalysis>.identity()..addAll(state.saving);
    saving ? next.add(analysis) : next.remove(analysis);
    return next;
  }

  /// Deletes [id] and returns its row for [undoDelete], or null.
  ///
  /// The item leaves the list immediately (a swiped-away tile must not
  /// linger), then the row is removed. A storage error puts back both the
  /// list item and the "Saved" marks on analyses still on screen.
  Future<Map<String, Object?>?> delete(int id) async {
    final previousItems = state.items;
    final marks = [
      for (final e in state.savedIds.entries)
        if (e.value == id) e.key,
    ];
    _undoMarks[id] = marks;
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id != id) item,
      ],
      savedIds: Map.identity()
        ..addAll(state.savedIds)
        ..removeWhere((_, value) => value == id),
    );
    try {
      return await _repo.delete(id);
    } on SavedAnalysisStorageException {
      _undoMarks.remove(id);
      if (ref.mounted) {
        state = state.copyWith(
          items: previousItems,
          savedIds: Map.identity()
            ..addAll(state.savedIds)
            ..addEntries(marks.map((a) => MapEntry(a, id))),
        );
        await refresh();
      }
      rethrow;
    }
  }

  Future<void> undoDelete(Map<String, Object?> row) async {
    await _repo.restore(row);
    final id = row['id'];
    final marks = _undoMarks.remove(id);
    if (ref.mounted && id is int && marks != null && marks.isNotEmpty) {
      state = state.copyWith(
        savedIds: Map.identity()
          ..addAll(state.savedIds)
          ..addEntries(marks.map((a) => MapEntry(a, id))),
      );
    }
    await refresh();
  }
}

final savedAnalysesControllerProvider =
    NotifierProvider<SavedAnalysesController, SavedAnalysesState>(
      SavedAnalysesController.new,
    );

/// One saved analysis, reopened offline from local storage.
final savedAnalysisProvider = FutureProvider.autoDispose
    .family<SavedAnalysis, int>(
      (ref, id) => ref.read(savedAnalysisRepositoryProvider).load(id),
    );
