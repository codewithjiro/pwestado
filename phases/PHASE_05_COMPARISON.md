# Phase 05 - Compare two business locations

**Goal:** Select independent sites A and B and compare their mapped evidence and compatible heuristic scores.

## Tasks

1. Implement a simple `Choose site A` / `Choose site B` flow using the same Mapbox view. Do not require a full multi-screen architecture.
2. Capture the **same category and same radius** for both analyses. If settings change, invalidate/re-run previous scores or clearly indicate that comparison is not valid until both are refreshed.
3. Query/compute evidence independently for each site, with cache and loading/error handling; do not silently copy Site A's data into Site B.
4. Show side-by-side labels/location coordinates, category/radius, competitors mapped, complementary establishments mapped, road proxy availability, overall heuristic score (or `Insufficient data`), and timestamps/source modes.
5. Highlight a higher *heuristic* score only when **both** sites have comparable data. Avoid declaring a site objectively 'best' or guaranteed profitable.
6. Handle same site twice, a site without OSM coverage, stale cached results, mixed live/sample modes, and missing network gracefully.
7. Add test cases ensuring compare uses same settings, rejects invalid comparisons, keeps site A/B independent, and never ranks incomparable or failed scores.

## Fast acceptance checks

- Test independent Site A and B queries, category/radius parity, source modes, stale data handling, failure states and missing scores with fake repositories.
- Verify comparison widgets with targeted widget tests; format changed Dart files; run `flutter analyze --no-pub` and focused `flutter test --no-pub`. Resolve dependencies only if changed.
- Do not repeatedly build/install APKs, launch an emulator, request Mapbox token, or run end-to-end live-map demonstrations for this phase. Defer physical map gestures and Android integration to Phase 06 unless a specific native defect demands a focused smoke test.
- A code/test PASS must explicitly state **physical-device comparison pending Phase 06**.

## Acceptance gate

- [x] Select A, select different B, independently analyze both.
- [ ] Side-by-side data and map/site markers match their sites. *(Side-by-side table verified by widget tests; lettered A/B map pins implemented but not yet seen on a device, pending Phase 06.)*
- [x] Settings parity enforced; sample/live sources distinguishable.
- [x] Appropriate uncertainties and missing scores shown; tests pass.
- [x] Code/test gate verified; physical-device walkthrough deferred to Phase 06.

## Stop

Report manual comparison demo and wait for Phase 06 approval.
