# Phase 03 - Live OSM / Overpass competitor discovery

**Goal:** A selected site + business category + radius triggers a real Overpass request, then shows mapped competitor markers, counts, and list.

## Tasks

1. Add Dio and a small repository/service layer for Overpass. Keep endpoint configurable; use a public interpreter such as `https://overpass-api.de/api/interpreter` subject to its availability and acceptable-use guidelines.
2. Map business categories to real OSM tags: Coffee Shop (`amenity=cafe`), Restaurant (`amenity=restaurant`), Sari-Sari/Convenience (`shop=convenience`), Laundry (`shop=laundry`), Bakery (`shop=bakery`). Warn that OSM mapping/tagging varies.
3. Use `nwr(around:radius,lat,lon)["key"="value"]; out center;` in valid Overpass QL (`[out:json][timeout:25];`). Sanitize inputs; no user-input code injection. Use a single bounded query on explicit **Find competitors** tap.
4. Parse node `lat/lon` vs way/relation `center.lat/center.lon`; deduplicate by `(type, id)`, skip invalid coordinates, calculate distance, and sort nearest first. Keep unknown names clearly unnamed.
5. Render **actual** competitor pins using version-correct Mapbox point annotations/layers; update/clear old pins on each valid new response. Clicking pin/list item shows mapped name and distance.
6. Show distinct `idle`, `loading`, `success`, `empty`, `timeout`, `rate-limited`, `network error`, and `sample` states. For a successful empty result use **No mapped records found**, not **No competitors**.
7. Add small query cache and clear `Fetched at`/`Cached` labels. Do not poll the Overpass API continuously; respect 429/504 and cap retries.
8. Include an offline **SAMPLE DEMO MODE** dataset, explicitly labeled visually and in data models. Never invent that these sample businesses are real.
9. Surface **OpenStreetMap contributors** and the data coverage disclaimer.
10. Add parser and deduplication tests with local mock JSON; test a real request and errors on device.

## Acceptance gate

- [ ] Explicit search calls real Overpass API with selected location/category/radius.
- [ ] Live markers, count, and list reflect the same response; no ghost/duplicate pins.
- [ ] Missing network, no records, and 429/timeout are handled without crash.
- [ ] Sample fallback is unmistakably labeled; it cannot appear as live.
- [ ] Parser tests + `flutter analyze` pass; actual phone tested.

## Stop

Report actual request outcome, API limitations, and wait for Phase 04 approval.
