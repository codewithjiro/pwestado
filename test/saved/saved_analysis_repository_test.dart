import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/analysis/domain/site_analysis.dart';
import 'package:pwestado/features/discovery/data/sample_competitors.dart';
import 'package:pwestado/features/analysis/domain/site_context.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';
import 'package:pwestado/features/saved/data/saved_analysis_codec.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:pwestado/features/saved/domain/saved_analysis.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../comparison/comparison_fixtures.dart';
import '../fake_competitor_repository.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;

  late Directory dir;
  late String dbPath;
  late SqliteSavedAnalysisRepository repo;

  SqliteSavedAnalysisRepository open() =>
      SqliteSavedAnalysisRepository(factory: factory, path: () async => dbPath);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pwestado_saved_test');
    dbPath = '${dir.path}${Platform.pathSeparator}saved.db';
    repo = open();
  });

  tearDown(() async {
    await repo.close();
    dir.deleteSync(recursive: true);
  });

  final retrieved = DateTime(2026, 10, 22, 9, 15, 30, 123);
  final savedAt = DateTime(2026, 10, 22, 10, 0, 5, 456);
  final site = SelectedSite.at(latitude: siteA.lat, longitude: siteA.lon);

  SiteAnalysis liveAnalysis() => analysisAt(
    queryAt(siteA),
    businesses: [
      business(1, name: 'Kape Way', distance: 100),
      business(2, distance: 200, type: 'way'),
      business(3, distance: 600),
    ],
    fetchedAt: retrieved,
  );

  test('an empty database lists nothing', () async {
    expect(await repo.list(), isEmpty);
  });

  test('save, list and load round-trip every piece of evidence', () async {
    final analysis = liveAnalysis();
    final id = await repo.save(site, analysis, savedAt);

    final summaries = await repo.list();
    expect(summaries, hasLength(1));
    final summary = summaries.single;
    expect(summary.id, id);
    expect(summary.isReadable, isTrue);
    expect(summary.category, BusinessCategory.coffeeShop);
    expect(summary.radius, SearchRadius.km1);
    expect(summary.total, 63.6);
    expect(summary.source, DataSource.live);
    expect(summary.savedAt, savedAt);
    expect(summary.retrievedAt, retrieved);
    expect(summary.coordinatesLabel, '15.09390, 120.76810');

    final saved = await repo.load(id);
    expect(saved.savedAt, savedAt, reason: 'saved time kept to the ms');
    expect(saved.savedTotal, 63.6);
    expect(saved.scoreMatchesSaved, isTrue);
    expect(saved.site.source, SiteSource.mapPick);

    final restored = saved.analysis;
    expect(restored.score.total, analysis.score.total);
    expect(restored.score.formula, analysis.score.formula);
    expect(restored.competitors.fetchedAt, retrieved);
    expect(restored.competitors.source, DataSource.live);
    expect(restored.competitors.query, analysis.competitors.query);
    expect(restored.competitors.businesses.map((b) => b.key), [
      'node:1',
      'way:2',
      'node:3',
    ]);
    expect(restored.competitors.businesses.first.name, 'Kape Way');
    expect(
      restored.competitors.businesses[1].name,
      isNull,
      reason: 'unnamed stays unnamed',
    );
    expect(restored.context!.fetchedAt, retrieved);
    expect(restored.context!.complementary.count, 6);
    expect(restored.context!.complementary.countsByKind, {'school': 6});
    expect(restored.context!.roads.nearestRoadMeters, 30);
    expect(restored.context!.roads.nearestMajorRoadMeters, 120);
  });

  test('a failed evidence request is saved as missing, not invented', () async {
    final analysis = analysisAt(queryAt(siteA), contextFailed: true);
    final id = await repo.save(site, analysis, savedAt);

    final summary = (await repo.list()).single;
    expect(summary.total, isNull);

    final saved = await repo.load(id);
    expect(saved.analysis.context, isNull);
    expect(saved.analysis.contextFailure, CompetitorFailure.serverBusy);
    expect(saved.analysis.contextStatusCode, 504);
    expect(saved.analysis.score.total, isNull);
    expect(saved.scoreMatchesSaved, isTrue);
  });

  test('records keep their cached or sample source label', () async {
    final cached = analysisAt(
      queryAt(siteA),
      source: DataSource.live,
      contextSource: DataSource.cached,
    );
    final query = queryAt(siteB);
    final now = DateTime.now();
    final sample = SiteAnalysis.from(
      competitors: SampleCompetitors.forQuery(query, now),
      context: SampleSiteContext.forQuery(query, now),
    );
    final cachedId = await repo.save(site, cached, savedAt);
    final sampleId = await repo.save(
      SelectedSite.at(latitude: siteB.lat, longitude: siteB.lon),
      sample,
      savedAt.add(const Duration(minutes: 1)),
    );

    final list = await repo.list();
    expect(list.map((s) => s.id), [sampleId, cachedId], reason: 'newest first');
    expect(list.first.source, DataSource.sample);
    expect(list.first.source!.savedLabel, 'SAMPLE DEMO DATA');
    expect(list.last.source, DataSource.cached);
    expect(list.last.source!.savedLabel, 'CACHED');

    final reopened = await repo.load(sampleId);
    expect(reopened.analysis.isSample, isTrue);
    expect(reopened.source, DataSource.sample);
  });

  test('saved analyses survive closing and reopening the database', () async {
    final id = await repo.save(site, liveAnalysis(), savedAt);
    await repo.close();

    final reopened = open();
    addTearDown(reopened.close);
    final list = await reopened.list();
    expect(list.single.id, id);
    final saved = await reopened.load(id);
    expect(saved.analysis.score.total, 63.6);
    expect(saved.savedAt, savedAt);
  });

  test('delete returns the row and restore puts it back unchanged', () async {
    final id = await repo.save(site, liveAnalysis(), savedAt);

    final row = await repo.delete(id);
    expect(row, isNotNull);
    expect(await repo.list(), isEmpty);
    await expectLater(
      repo.load(id),
      throwsA(isA<SavedAnalysisNotFoundException>()),
    );
    expect(await repo.delete(id), isNull, reason: 'already gone');

    await repo.restore(row!);
    final back = await repo.load(id);
    expect(back.id, id);
    expect(back.savedAt, savedAt, reason: 'undo keeps the original time');
  });

  test('a damaged evidence snapshot is reported, not guessed', () async {
    final id = await repo.save(site, liveAnalysis(), savedAt);
    await repo.close();
    final db = await factory.openDatabase(dbPath);
    await db.update(
      SavedColumns.table,
      {SavedColumns.evidence: '{"v": 1, "site": 7'},
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.close();

    final summary = (await repo.list()).single;
    expect(summary.isReadable, isTrue, reason: 'summary columns intact');
    await expectLater(
      repo.load(id),
      throwsA(isA<SavedAnalysisCorruptException>()),
    );
    expect(await repo.delete(id), isNotNull, reason: 'still deletable');
  });

  test('damaged summary columns give an unreadable entry', () async {
    final id = await repo.save(site, liveAnalysis(), savedAt);
    await repo.close();
    final db = await factory.openDatabase(dbPath);
    await db.update(
      SavedColumns.table,
      {SavedColumns.categoryId: 'karaoke_bar'},
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.close();

    final summary = (await repo.list()).single;
    expect(summary.isReadable, isFalse);
    expect(summary.id, id);
    expect(summary.savedAt, savedAt);
  });

  test('an unknown evidence version is rejected', () {
    final row = SavedAnalysisCodec.toRow(site, liveAnalysis(), savedAt);
    final json = jsonDecode(row[SavedColumns.evidence]! as String) as Map;
    json['v'] = 99;
    row[SavedColumns.evidence] = jsonEncode(json);
    row[SavedColumns.id] = 5;
    expect(
      () => SavedAnalysisCodec.fromRow(row),
      throwsA(isA<SavedAnalysisCorruptException>()),
    );
  });

  test('stored rows contain analysis evidence only', () {
    final row = SavedAnalysisCodec.toRow(site, liveAnalysis(), savedAt);
    expect(row.keys.toSet(), {
      ...SavedColumns.summary.where((c) => c != SavedColumns.id),
      SavedColumns.evidence,
    });
    final text = jsonEncode(row);
    expect(text, isNot(contains('token')));
    expect(text, isNot(contains('pk.')));
  });

  test('storage failures surface as a readable exception', () async {
    final blocker = File('${dir.path}${Platform.pathSeparator}not_a_dir')
      ..writeAsStringSync('x');
    final broken = SqliteSavedAnalysisRepository(
      factory: factory,
      path: () async => '${blocker.path}${Platform.pathSeparator}saved.db',
    );
    await expectLater(
      broken.list(),
      throwsA(isA<SavedAnalysisStorageException>()),
    );
  });
}
