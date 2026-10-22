# Phase 02 - Live Mapbox map, GPS, and site selection

**Goal:** A real polished Mapbox map that the user can interact with to choose a business site.

## Tasks

1. Add **stable** `mapbox_maps_flutter` and `geolocator` after verifying compatibility and native setup. Use official **version-matching** docs.
2. Configure a Mapbox **public `pk.` token** via `const String.fromEnvironment('ACCESS_TOKEN')`, injected with Flutter `--dart-define`. Do not hardcode or commit tokens. Handle missing token with actionable error UI.
3. Show a real Mapbox Standard map. Default camera center is approximately `15.0939,120.7681` (Santa Ana, Pampanga). Reasonable zoom for a neighborhood; ensure the user can pan and zoom smoothly.
4. Implement **long-press to choose location** (or SDK-supported tap if reliably implemented). Visually distinguish the selected site from competitor markers and surface coordinates/site label without invented address data.
5. Implement **Use my location** with Android location permissions, user-friendly denied/permanently denied states, and GPS unavailable state. **Manual site selection must always remain possible.**
6. Wire category choices and 500m / 1km / 2km radius state. This phase should not fetch OSM records yet.
7. Keep Mapbox attribution visible and test layout on the physical phone.

## Acceptance gate

- [x] Real interactive map renders (not a static image). *(Mapbox Standard tiles, pan + double-tap zoom verified on emulator)*
- [x] Selected location pin changes when the user selects a different site. *(two long-presses on emulator; pin tip within ~3 dp of touch)*
- [x] GPS updates location when permitted; denial does not block map exploration. *(denied, permanently denied, location-off, and granted paths verified on emulator)*
- [x] Category and radius can change without reinitializing map unnecessarily. *(camera and pin kept after changing both)*
- [x] Stable SDK used; no token in source or logs. *(mapbox_maps_flutter 3.33.0; token scan of repo + logcat: 0 hits)*
- [x] `flutter analyze` and device run pass. *(Android 16 emulator; physical-phone run still pending, see Phase 06)*

## Stop

Report working gestures/GPS behavior and wait for Phase 03 approval.
