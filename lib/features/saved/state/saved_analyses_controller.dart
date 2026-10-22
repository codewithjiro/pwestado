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
  });

  /// Newest first.
  final List<SavedAnalysisSummary> items;
  final bool loading;

  /// A storage problem while listing; safe to display.
  final String? error;

  /// Analyses saved in this session, by identity, mapped to their record
  /// id, so the same on-screen analysis is not saved twice by accident.
  final Map<SiteAnalysis, int> savedIds;

  SavedAnalysesState copyWith({
    List<SavedAnalysisSummary>? items,
    bool? loading,
    String? error,
    bool clearError = false,
    Map<SiteAnalysis, int>? savedIds,
  }) => SavedAnalysesState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    savedIds: savedIds ?? this.savedIds,
  );
}

/// The result of a save: the new record id, or a displayable error.
typedef SaveOutcome = ({int? id, String? error});

/// Saved Analyses list plus save / delete / undo. Writes happen only on an
/// explicit user action; nothing here refreshes or rewrites a record.
class SavedAnalysesController extends Notifier<SavedAnalysesState> {
  /// Session marks removed by a delete, kept so undo can restore them.
  final _undoMarks = <int, List<SiteAnalysis>>{};

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

  Future<SaveOutcome> save(SelectedSite site, SiteAnalysis analysis) async {
    final existing = state.savedIds[analysis];
    if (existing != null) return (id: existing, error: null);
    try {
      final id = await _repo.save(site, analysis, DateTime.now());
      if (ref.mounted) {
        state = state.copyWith(
          savedIds: Map.identity()
            ..addAll(state.savedIds)
            ..[analysis] = id,
        );
        await refresh();
      }
      return (id: id, error: null);
    } on SavedAnalysisStorageException catch (e) {
      return (id: null, error: e.message);
    }
  }

  /// Deletes [id] and returns its row for [undoDelete], or null.
  ///
  /// The item leaves the list immediately (a swiped-away tile must not
  /// linger), then the row is removed; a storage error restores the list.
  Future<Map<String, Object?>?> delete(int id) async {
    _undoMarks[id] = [
      for (final e in state.savedIds.entries)
        if (e.value == id) e.key,
    ];
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
      await refresh();
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
