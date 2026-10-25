import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/saved/data/saved_analysis_codec.dart';
import 'package:pwestado/features/saved/data/saved_analysis_repository.dart';
import 'package:pwestado/features/saved/domain/saved_analysis.dart';
import 'package:pwestado/features/saved/state/saved_analyses_controller.dart';

import '../comparison/comparison_fixtures.dart';
import '../fake_saved_analysis_repository.dart';

void main() {
  late FakeSavedAnalysisRepository repo;
  late ProviderContainer container;

  final site = SelectedSite.at(latitude: siteA.lat, longitude: siteA.lon);

  setUp(() {
    repo = FakeSavedAnalysisRepository();
    container = ProviderContainer(
      overrides: [savedAnalysisRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  SavedAnalysesController controller() =>
      container.read(savedAnalysesControllerProvider.notifier);
  SavedAnalysesState state() => container.read(savedAnalysesControllerProvider);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('loads existing records on first use', () async {
    await repo.save(site, analysisAt(queryAt(siteA)), DateTime(2026, 10, 1));
    expect(state().loading, isTrue);
    await settle();
    expect(state().loading, isFalse);
    expect(state().items, hasLength(1));
  });

  test('saving stores one record and marks the analysis as saved', () async {
    await settle();
    final analysis = analysisAt(queryAt(siteA));

    final first = await controller().save(site, analysis);
    expect(first.error, isNull);
    expect(state().items.single.id, first.id);
    expect(controller().savedIdOf(analysis), first.id);

    final again = await controller().save(site, analysis);
    expect(again.id, first.id, reason: 'same analysis is not saved twice');
    expect(repo.rows, hasLength(1));

    final other = await controller().save(site, analysisAt(queryAt(siteA)));
    expect(other.id, isNot(first.id), reason: 'a new analysis is new');
    expect(repo.rows, hasLength(2));
  });

  test('delete then undo restores the original record and mark', () async {
    await settle();
    final analysis = analysisAt(queryAt(siteA));
    final id = (await controller().save(site, analysis)).id!;
    final savedAt = repo.rows[id]![SavedColumns.savedAt];

    final row = await controller().delete(id);
    expect(state().items, isEmpty);
    expect(controller().savedIdOf(analysis), isNull);

    await controller().undoDelete(row!);
    expect(state().items.single.id, id);
    expect(repo.rows[id]![SavedColumns.savedAt], savedAt);
    expect(controller().savedIdOf(analysis), id);
  });

  test('two saves of the same analysis at once write one record', () async {
    await settle();
    final analysis = analysisAt(queryAt(siteA));
    repo.saveGate = Completer<void>();

    final first = controller().save(site, analysis);
    final second = controller().save(site, analysis);
    expect(state().isSaving(analysis), isTrue);

    repo.saveGate!.complete();
    final outcomes = await Future.wait([first, second]);
    expect(outcomes[0].id, isNotNull);
    expect(outcomes[1].id, outcomes[0].id);
    expect(repo.rows, hasLength(1));
    expect(state().isSaving(analysis), isFalse);
  });

  test('a failed save can be retried', () async {
    await settle();
    final analysis = analysisAt(queryAt(siteA));
    repo.failWith = const SavedAnalysisStorageException('Disk full');

    final failed = await controller().save(site, analysis);
    expect(failed.error, 'Disk full');
    expect(state().isSaving(analysis), isFalse);
    expect(controller().savedIdOf(analysis), isNull);

    repo.failWith = null;
    final retried = await controller().save(site, analysis);
    expect(retried.id, isNotNull);
    expect(controller().savedIdOf(analysis), retried.id);
  });

  test('a failed delete restores the list item and the saved mark', () async {
    await settle();
    final analysis = analysisAt(queryAt(siteA));
    final id = (await controller().save(site, analysis)).id!;
    expect(state().items, hasLength(1));

    // Every storage call fails now, including the follow-up refresh.
    repo.failWith = const SavedAnalysisStorageException('Locked');
    await expectLater(
      controller().delete(id),
      throwsA(isA<SavedAnalysisStorageException>()),
    );

    expect(state().items.single.id, id);
    expect(controller().savedIdOf(analysis), id);
  });

  test('storage errors are reported, never thrown at the UI', () async {
    repo.failWith = const SavedAnalysisStorageException('Disk full');
    state();
    await settle();
    expect(state().error, 'Disk full');
    expect(state().items, isEmpty);

    final outcome = await controller().save(site, analysisAt(queryAt(siteA)));
    expect(outcome.id, isNull);
    expect(outcome.error, 'Disk full');
    expect(state().savedIds, isEmpty);
  });
}
