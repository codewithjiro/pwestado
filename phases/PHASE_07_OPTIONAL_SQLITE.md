# Phase 07 - Optional SQLite saved analyses

**Status:** OUTSIDE mandatory one-day demo. Start only after Phase 06 passed and owner approved.

## Tasks

1. Add `sqflite` (and `path` if required) and a minimal local repository.
2. Save selected site, category, radius, calculated evidence, score or missing-score reason, source mode (live/cached/sample), and capture time. Clearly label sample entries.
3. Provide a simple list and detail view of past analyses, with ability to remove entries.
4. Keep data model migration simple, avoid persisting credentials or sensitive location history unnecessarily.
5. Test local save/read/delete, compatibility with live analysis, and that core demo still works.

## Scheduling and validation

**Default: SKIP until after the October 23 pitching demo.** Start only if the owner explicitly approves optional enhancements after Phase 06 has passed. Do not risk the already working APK.

If approved later, first perform focused SQLite model/repository tests and analyzer checks. An actual app-restart persistence check is required before claiming saved data survives restarts, but avoid repeated APK builds/installs without a diagnosed failure.

## Acceptance gate

- [ ] Saved analyses survive an app restart. *(Database close/reopen is verified by `test/saved/saved_analysis_repository_test.dart` against real SQLite via sqflite_common_ffi. The restart check on a real Android app is pending the physical-device run.)*
- [x] Source mode and time preserved accurately. *(Tests check LIVE-SOURCED / CACHED / SAMPLE DEMO DATA labels and that save and retrieval timestamps survive to the millisecond, including after undoing a delete.)*
- [ ] No regression in Mapbox/Overpass/scoring/comparison. *(Full `flutter analyze` and `flutter test` pass: 218 tests. Mapbox rendering and live Overpass on a phone are still pending.)*
- [ ] Builds and runs on the Android phone. *(See the build note in the latest report. Running on the POCO phone is pending.)*

### Implementation notes (owner-approved combined UI polish + Phase 07 cycle)

- Storage: `sqflite` and `path`. One table, `saved_analyses`, with schema version 1. Migrations are a per-version statement list that runs from `onCreate` and `onUpgrade`. Each row has summary columns plus a versioned JSON evidence snapshot.
- Reopening rebuilds the score from the stored evidence with the unchanged scoring code, so no request is made. If the scoring rules ever change, the detail screen shows both the saved total and the recalculated total.
- Damaged rows show as unreadable entries that can still be deleted. Damaged evidence opens as a "could not be read" screen. No value is guessed.
- A record is written only when the user taps Save. Delete offers Undo, which restores the original id and timestamps. This storage is separate from the in-memory Overpass caches. No token or credential is stored.
- A saved analysis can be loaded into Site A or Site B. The search settings switch to match it, the usual comparison rules apply, and the slot is marked HISTORICAL.

## Stop

Finish with tested status; do not add cloud syncing/auth without explicit new scope.
