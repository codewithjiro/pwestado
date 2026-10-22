import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/models/selected_site.dart';
import '../../../core/utils/redact.dart';
import '../../analysis/domain/site_analysis.dart';
import '../domain/saved_analysis.dart';
import 'saved_analysis_codec.dart';

/// Local store of analyses the user chose to save. Completely separate from
/// the short-lived in-memory Overpass caches: nothing here is ever served
/// as a search result, and nothing is written without an explicit save.
abstract interface class SavedAnalysisRepository {
  /// Newest first. Damaged rows are returned as unreadable summaries.
  Future<List<SavedAnalysisSummary>> list();

  /// Throws [SavedAnalysisNotFoundException] or
  /// [SavedAnalysisCorruptException].
  Future<SavedAnalysis> load(int id);

  /// Stores [analysis] as it is now, stamped [savedAt]. Returns the new id.
  Future<int> save(SelectedSite site, SiteAnalysis analysis, DateTime savedAt);

  /// Removes the record and returns its raw row (for undo), or null if it
  /// did not exist.
  Future<Map<String, Object?>?> delete(int id);

  /// Puts back a row returned by [delete], with its original id and times.
  Future<void> restore(Map<String, Object?> row);
}

/// [SavedAnalysisRepository] backed by sqflite.
///
/// Every failure surfaces as [SavedAnalysisStorageException] so the UI can
/// show a calm message instead of crashing.
class SqliteSavedAnalysisRepository implements SavedAnalysisRepository {
  SqliteSavedAnalysisRepository({
    DatabaseFactory? factory,
    Future<String> Function()? path,
  }) : _databaseFactory = factory,
       _path = path ?? _defaultPath;

  static const fileName = 'pwestado_saved_analyses.db';

  /// Current schema version. Each version's statements live in
  /// [_migrations]; opening an older file runs only the missing steps.
  static const schemaVersion = 1;

  static const _migrations = <int, List<String>>{
    1: [
      '''
      CREATE TABLE ${SavedColumns.table} (
        ${SavedColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${SavedColumns.savedAt} INTEGER NOT NULL,
        ${SavedColumns.latitude} REAL NOT NULL,
        ${SavedColumns.longitude} REAL NOT NULL,
        ${SavedColumns.siteLabel} TEXT NOT NULL,
        ${SavedColumns.categoryId} TEXT NOT NULL,
        ${SavedColumns.radiusMeters} INTEGER NOT NULL,
        ${SavedColumns.dataSource} TEXT NOT NULL,
        ${SavedColumns.totalScore} REAL,
        ${SavedColumns.retrievedAt} INTEGER NOT NULL,
        ${SavedColumns.evidence} TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_saved_analyses_saved_at '
          'ON ${SavedColumns.table} (${SavedColumns.savedAt} DESC)',
    ],
  };

  final DatabaseFactory? _databaseFactory;
  final Future<String> Function() _path;
  Future<Database>? _db;

  static Future<String> _defaultPath() async =>
      p.join(await getDatabasesPath(), fileName);

  Future<Database> _database() async {
    final pending = _db ??= _open();
    try {
      return await pending;
    } catch (_) {
      // Let the next call try again instead of caching the failure.
      if (identical(_db, pending)) _db = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final factory = _databaseFactory ?? databaseFactory;
    return factory.openDatabase(
      await _path(),
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    for (var version = from + 1; version <= to; version++) {
      for (final statement in _migrations[version] ?? const <String>[]) {
        batch.execute(statement);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<T> _guard<T>(
    String action,
    Future<T> Function(Database db) body,
  ) async {
    try {
      return await body(await _database());
    } on SavedAnalysisNotFoundException {
      rethrow;
    } on SavedAnalysisCorruptException {
      rethrow;
    } catch (e) {
      debugPrint('Saved analyses: $action failed: ${describeError(e)}');
      throw SavedAnalysisStorageException(
        'Could not $action on this device. Local storage may be full or '
        'unavailable.',
      );
    }
  }

  @override
  Future<List<SavedAnalysisSummary>> list() =>
      _guard('read saved analyses', (db) async {
        final rows = await db.query(
          SavedColumns.table,
          columns: SavedColumns.summary,
          orderBy: '${SavedColumns.savedAt} DESC, ${SavedColumns.id} DESC',
        );
        return [for (final row in rows) SavedAnalysisCodec.summaryFromRow(row)];
      });

  @override
  Future<SavedAnalysis> load(int id) => _guard('open the analysis', (db) async {
    final rows = await db.query(
      SavedColumns.table,
      where: '${SavedColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw SavedAnalysisNotFoundException(id);
    return SavedAnalysisCodec.fromRow(rows.single);
  });

  @override
  Future<int> save(
    SelectedSite site,
    SiteAnalysis analysis,
    DateTime savedAt,
  ) => _guard(
    'save the analysis',
    (db) => db.insert(
      SavedColumns.table,
      SavedAnalysisCodec.toRow(site, analysis, savedAt),
    ),
  );

  @override
  Future<Map<String, Object?>?> delete(int id) =>
      _guard('delete the analysis', (db) async {
        return db.transaction((txn) async {
          final rows = await txn.query(
            SavedColumns.table,
            where: '${SavedColumns.id} = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (rows.isEmpty) return null;
          await txn.delete(
            SavedColumns.table,
            where: '${SavedColumns.id} = ?',
            whereArgs: [id],
          );
          return Map.of(rows.single);
        });
      });

  @override
  Future<void> restore(Map<String, Object?> row) =>
      _guard('restore the analysis', (db) async {
        await db.insert(
          SavedColumns.table,
          row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      });

  /// Closes the database; the next call reopens it.
  Future<void> close() async {
    final pending = _db;
    _db = null;
    if (pending != null) await (await pending).close();
  }
}

final savedAnalysisRepositoryProvider = Provider<SavedAnalysisRepository>(
  (ref) => SqliteSavedAnalysisRepository(),
);
