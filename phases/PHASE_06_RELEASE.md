# Phase 06 - Stabilization, APK, and pitch rehearsal

**Goal:** Convert an implemented prototype into a **reliably demonstrable Android APK**.

## Tasks

1. Remove confusing dead ends, broken actions, fake data presentations, unused debug screens, and unhandled exceptions; keep the essential flows.
2. Polish consistent Material 3 styling, map-first screen, selected vs competitor pins, compact loading/empty/error feedback, large action buttons, reasonable text sizes, and stable bottom sheets.
3. Ensure Overpass errors and slow requests do not hang the UI; users can retry or explicitly enter SAMPLE DEMO MODE without confusing it with live data.
4. Confirm permission handling, selected site persistence while navigating, category/radius selection, marker clearing, API source/time labels, Mapbox/OSM attribution, and suitable state restoration.
5. Run `dart format .`, `flutter analyze`, `flutter test` (fix errors), then build a release APK using public token injected via `--dart-define`.
6. **Actually install and open on POCO Android phone.** Verify startup with realistic connectivity, location permissions, portrait layout, correct map, and all must-work actions.
7. Rehearse the exact 90-120 second flow in `PHASING.md` using Santa Ana coffee shop / 1km / site A / site B.
8. Record **what was really verified**. If APIs are unavailable, use clearly labeled sample mode during pitch; never mislabel data as live.
9. Note the final APK's exact filesystem path and how to install it. Verify APK exists before claiming build success.

## Acceptance gate

- [ ] No analyzer errors; tests passing.
- [ ] Release APK exists at expected build path, with token configured correctly.
- [ ] APK installed and launched on physical phone.
- [ ] Real Mapbox viewport and gestures functional.
- [ ] Site selection, category/radius, OSM request or honest failure, pins/counts, scoring, and two-site comparison all exercised.
- [ ] SAMPLE DEMO MODE is visibly marked and usable when online services fail.
- [ ] App screenshots from actual running build captured if needed for pitch.

## Stop

Report PASS / PARTIAL / BLOCKED and verified outcomes. Do not start SQLite/other enhancements unless owner explicitly asks.
