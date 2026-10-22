# CLAUDE.md - Instructions for the PWESTADO coding agent

You are implementing **PWESTADO**, a **Flutter Android** location-intelligence pitching prototype in:

`C:\Users\Jiro\Documents\PitchingSystem`

**Start here:** Read `PHASING.md` and the current file under `phases/`. Those documents define scope, acceptance tests, quality checks, and phase order. The updated system overview PDF, if available in the workspace, is background product context.

## Working rules

1. **One phase at a time.** Do not move to the next phase without the owner's explicit approval.
2. **Inspect first.** Review workspace, code, packages, SDK, device, config, and existing work before making edits. If a Flutter project exists, reuse it. Avoid destructive overwrites.
3. **Work in the supplied folder only** unless the owner explicitly directs otherwise.
4. **Actual functionality over mockups.** Build a working Android APK, real Mapbox integration, actual Overpass queries, deterministic scoring, and two-location comparison. Sample mode must be visibly labeled.
5. **Correct SDK versions.** Prefer compatible stable `mapbox_maps_flutter` rather than mixing prerelease docs and stable APIs. Verify imports, native Android configuration, and permissions.
6. **Never leak secrets.** Public `pk.` Mapbox token via `--dart-define`, never hardcode in tracked source. Never put `sk.` tokens in mobile code, commits, screenshots, or logs.
7. **Data integrity.** Mapbox != source of competitors. Business listings come from OSM/Overpass and are incomplete. No pretend real-time sales, foot traffic, or verified demand; heuristic scores must show evidence and formula.
8. **Efficient APIs.** Query only on explicit search/refresh; add caching, cancellation, timeout, respectful limits, and useful HTTP error states.
9. **Avoid scope creep.** No Gemini, Firebase, Supabase, auth, backend, web deployment, paid APIs, or profit simulator. Do not add SQLite until Phase 07, and only after core demo passes.
10. **Modern UI, restrained implementation.** Map-first Material 3, dark emerald + mint + off-white, accessible tap targets, clear bottom-sheet controls, distinctive site/competitor pins, no gratuitous animations.
11. **Test each phase.** Run format, analyze, appropriate automated tests, and device test when possible. Do not report commands as passed unless they were run successfully.
12. **Protect the demo.** Never break a previously accepted phase for optional polish. No git push or paid provisioning without user request.

## Required response format after a phase

```text
PHASE: NN - Title
STATUS: PASS | BLOCKED | PARTIAL
CHANGED: [files and why]
CHECKS: [actual commands run and observed results]
DEMO: [specific behavior verified]
LIMITATIONS: [anything not working / unverified]
NEXT: [single next phase/action; WAIT FOR APPROVAL]
```

**Most important:** Implement only the owner's currently approved phase and stop. Do not quietly generate the entire app in one unreviewable pass.
