# Phase 04 - Evidence collection and explainable suitability score

**Goal:** Deterministic, transparent preliminary location scoring based on OSM evidence. Avoid fake precision and market-demand claims.

## Tasks

1. Implement a **pure Dart** scoring function (no UI/network code inside) with weighting: 40% competitor proximity, 30% complementary mapped establishments, 30% mapped-road-access proxy.
2. Collect *additional* Overpass evidence using bounded, explicit requests and appropriate tags. For complementary locations use a disclosed, fixed list of mapped category tags and exclude same-category competitors. For road proxy query mapped `highway` ways within a small radius of the site; explicitly label it a rough OSM proxy.
3. Keep OSM source metadata, fetch time, API status, skipped or missing records, selected radius/category, and confidence/caveats.
4. Define and **document** stable normalization rules before implementing. Example only (may improve if justified): competitorScore = `100 * (1 - min(competitors,10)/10)`; complementaryScore = `100 * min(complementaryCount,8)/8`; roadProxyScore = `100` if at least one qualifying mapped road within 150m, otherwise `0` after a successful road query. These numbers are **developer heuristic assumptions**, not research-backed ground truth. Document how distance enters competitor scoring if applicable.
5. If any required query fails, produce `totalScore: null` and **Insufficient data**; do not backfill made-up counts or zeros. Distinguish successful zero records from API failures and warn when coverage is sparse.
6. Render a readable breakdown card with criterion scores, weights, fetched/cached/sample state, and explanation of each criterion. Sample score must say **Sample heuristic result**.
7. Unit-test scoring: deterministic outputs, range 0..100, missing-query => no total score, fixed weights, zero/large counts, repeated identical inputs => identical results.

## Fast acceptance checks

- Use mocked Overpass evidence and pure Dart unit tests for scoring weights, normalization, zero/sparse records, failures, caching/source metadata, and determinism. Add targeted widget tests for labels.
- Format only changed Dart files; run `flutter analyze --no-pub` and focused `flutter test --no-pub` on relevant test files. Run `flutter pub get` only if packages actually change.
- No routine emulator launch, APK build/install, Mapbox token prompt, screenshots, or repeated live Overpass calls in Phase 04.
- Phase 04 can pass its code/test gate with actual Android UI integration **pending Phase 06**. If an unmockable native regression arises, run only a focused smoke check.

## Acceptance gate

- [x] Same evidence yields same score; all input assumptions visible.
- [x] 40/30/30 weights and normalizations are applied and unit tested.
- [x] No fabricated demand, foot-traffic, profitability, or road travel-time figures.
- [x] Missing evidence does not turn into a supposedly confident score.
- [x] Source and limitations checked by widget tests; analyzer/targeted tests pass; phone demo deferred to Phase 06.

## Stop

Explain exactly which data was fetched, what score means, and wait for Phase 05 approval.
