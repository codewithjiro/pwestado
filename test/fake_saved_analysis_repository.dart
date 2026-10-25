import 'dart:async';

import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/analysis/domain/site_analysis.dart';
import 'package:pwestado/features/saved/data/saved_analysis_codec.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:pwestado/features/saved/domain/saved_analysis.dart';

/// In-memory [SavedAnalysisRepository] for widget tests. Uses the real
/// row codec, so rows look exactly like database rows. Set [failWith] to
/// simulate a storage error on every call.
class FakeSavedAnalysisRepository implements SavedAnalysisRepository {
  final rows = <int, Map<String, Object?>>{};
  int _nextId = 1;
  SavedAnalysisStorageException? failWith;
  int calls = 0;

  /// When set, saves wait for it before writing.
  Completer<void>? saveGate;

  void _check() {
    calls++;
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<List<SavedAnalysisSummary>> list() async {
    _check();
    final sorted = rows.values.toList()
      ..sort((a, b) {
        final byTime = (b[SavedColumns.savedAt]! as int).compareTo(
          a[SavedColumns.savedAt]! as int,
        );
        return byTime != 0
            ? byTime
            : (b[SavedColumns.id]! as int).compareTo(
                a[SavedColumns.id]! as int,
              );
      });
    return [for (final row in sorted) SavedAnalysisCodec.summaryFromRow(row)];
  }

  @override
  Future<SavedAnalysis> load(int id) async {
    _check();
    final row = rows[id];
    if (row == null) throw SavedAnalysisNotFoundException(id);
    return SavedAnalysisCodec.fromRow(row);
  }

  @override
  Future<int> save(
    SelectedSite site,
    SiteAnalysis analysis,
    DateTime savedAt,
  ) async {
    final gate = saveGate;
    if (gate != null) await gate.future;
    _check();
    final id = _nextId++;
    rows[id] = {
      SavedColumns.id: id,
      ...SavedAnalysisCodec.toRow(site, analysis, savedAt),
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> delete(int id) async {
    _check();
    return rows.remove(id);
  }

  @override
  Future<void> restore(Map<String, Object?> row) async {
    _check();
    rows[row[SavedColumns.id]! as int] = Map.of(row);
  }
}
