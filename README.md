# PWESTADO

*Ang tamang pwesto, simula ng negosyo.*

Flutter Android prototype for exploring candidate business sites. See `PHASING.md`
for scope and `phases/` for the phase-by-phase plan.

## Run

```powershell
flutter pub get
flutter run
```

From Phase 02 onward, pass the public Mapbox token at build time (never commit it):

```powershell
$env:MAPBOX_ACCESS_TOKEN="pk.YOUR_PUBLIC_TOKEN"
flutter run --dart-define="ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN"
```

Optional: PWESTADO AI Insights needs the secure proxy in
`backend/ai-insights-worker` (see its README). Pass only its public URL; the
Gemini key stays on the server and must never be added to the app:

```powershell
flutter run --dart-define="ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN" `
  --dart-define="AI_INSIGHTS_URL=https://pwestado-ai-insights.<you>.workers.dev"
```

Without it, the app shows a clear "not set up" state and everything else works.

## Design system

- Semantic light/dark tokens: `AppPalette` in `lib/app/theme.dart`, read with
  `context.palette`. `BrandColors` is only for fixed brand moments (splash, map
  pin bitmaps).
- Fonts are bundled, not downloaded at runtime: Plus Jakarta Sans (headings,
  metrics) and Inter (body, UI). Both use the SIL Open Font License; the texts
  are in `assets/fonts/` and on the in-app licenses page.
- Appearance: System / Light / Dark under About & appearance (the tune icon),
  saved with `shared_preferences`. The Mapbox Standard map switches between
  its `day` and `night` light presets without being recreated.
- Category illustrations are drawn in code (`CategoryArt`), so there is no
  third-party artwork to license. Business photos appear only when an OSM
  record links a Wikimedia Commons image, credited with author and license.
  Brand-level images are labeled as such.

## Checks

```powershell
dart format .
flutter analyze
flutter test
cd backend/ai-insights-worker; npm test   # proxy unit tests (no network)
```
