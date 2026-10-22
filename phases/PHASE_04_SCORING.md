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

## Acceptance gate

- [ ] Same evidence yields same score; all input assumptions visible.
- [ ] 40/30/30 weights and normalizations are applied and unit tested.
- [ ] No fabricated demand, foot-traffic, profitability, or road travel-time figures.
- [ ] Missing evidence does not turn into a supposedly confident score.
- [ ] Source and limitations clearly shown in analysis view; analyze/test passes.

## Stop

Explain exactly which data was fetched, what score means, and wait for Phase 05 approval.
