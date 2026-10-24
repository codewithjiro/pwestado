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

### AI Insights (private demo only)

AI Insights calls the Gemini API **directly from the app** with a key compiled
in from an untracked local file. This is for the owner's private testing and
demonstrations only: anyone who has an APK built this way can extract the key.
Do not share such APKs, use a key restricted to the Gemini API with a low
quota, and rotate it in Google AI Studio if an APK leaves your hands.

The app does not compile until the local key file exists. Create it from the
tracked template, then paste your key between the quotes in the new file:

```powershell
Copy-Item lib/core/config/gemini_local_key.example.dart lib/core/config/gemini_local_key.dart
git check-ignore -v lib/core/config/gemini_local_key.dart   # must print the .gitignore rule
```

Never commit that file and never put the key in README files, issues,
screenshots or logs. With an empty key the app shows a clear "not set up"
state and everything else works. The default model is
`gemini-3.5-flash-lite`; override it with `--dart-define=GEMINI_MODEL=...` if
Google retires it. Gemini is called only when you tap "Ask AI to explain",
and it explains the deterministic 40/30/30 score without changing it.

`backend/ai-insights-worker` is the earlier server-side proxy design. The app
no longer uses it; it is kept for reference. Its request allowlist still
covers only the first five categories and the 500 m / 1 km / 2 km radii.

## Business types and search distance

- `BusinessCategory.all` (`lib/core/models/business_category.dart`) lists 41
  business types. Each one maps to a single OSM tag, checked against its
  wiki.openstreetmap.org `Tag:` page. Category ids are stored in saved analyses
  and must never change.
- Search and "Other business type" (`BusinessTypeSearch`) are local lookups of
  labels and aliases, including Filipino terms. Typed text never becomes an
  OSM tag or query. If there is no reliable mapping, the app says so and
  suggests related types instead of searching.
- `SearchRadius` holds any whole number of meters from 100 to 2,000. The
  presets are 250 m, 500 m, 1 km and 2 km. Equal meters are the same query,
  cache entry and saved setting.

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
