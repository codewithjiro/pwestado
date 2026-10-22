# Phase 07 - Optional SQLite saved analyses

**Status:** OUTSIDE mandatory one-day demo. Start only after Phase 06 passed and owner approved.

## Tasks

1. Add `sqflite` (and `path` if required) and a minimal local repository.
2. Save selected site, category, radius, calculated evidence, score or missing-score reason, source mode (live/cached/sample), and capture time. Clearly label sample entries.
3. Provide a simple list and detail view of past analyses, with ability to remove entries.
4. Keep data model migration simple, avoid persisting credentials or sensitive location history unnecessarily.
5. Test local save/read/delete, compatibility with live analysis, and that core demo still works.

## Acceptance gate

- [ ] Saved analyses survive an app restart.
- [ ] Source mode and time preserved accurately.
- [ ] No regression in Mapbox/Overpass/scoring/comparison.
- [ ] Builds and runs on the Android phone.

## Stop

Finish with tested status; do not add cloud syncing/auth without explicit new scope.
