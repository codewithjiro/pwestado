# PWESTADO - PHASING.md

> **Project:** PWESTADO - Ang tamang pwesto, simula ng negosyo.  
> **Target:** Working Android APK for an October 23, 2026 student business pitch.  
> **Workspace (Windows):** `C:\Users\Jiro\Documents\PitchingSystem`  
> **Owner's workflow:** VS Code + Claude AI coding agent.  
> **Source of truth:** The updated `PWESTADO_System_Overview_UPDATED.pdf`, plus this implementation plan.  
> **Execution policy:** Complete **ONE PHASE AT A TIME**. Never mark untested work as done.

## 1. What we are building

PWESTADO is a **Flutter Android app** that helps aspiring Filipino entrepreneurs explore possible business sites, discover **mapped** competitors, calculate a transparent **heuristic location suitability score**, and compare two sites. It is a pitch-stage proof of concept, **not** a verified demand, traffic, or profitability forecasting product.

**Core demo scenario:** An entrepreneur considers opening a **coffee shop in Santa Ana, Pampanga**, uses a **1 km** search radius, views nearby businesses available in OpenStreetMap, analyzes one candidate site, then compares it with a second site.

### Non-negotiable scope

**MUST work by end of Phase 06:**
1. Android app installed and opened on the user's phone.
2. Mapbox map with a professional style and correct provider attribution.
3. Manual location selection and optional live GPS with permission handling.
4. Business category + radius selection.
5. On-demand Overpass query returning actual available OSM listings, or a clearly identified empty/error state.
6. Competitor pins, names, distance, and counts with source indication.
7. Explainable score only when required evidence is available.
8. Two-site comparison with the **same business category and radius**.
9. Clearly labeled **SAMPLE DEMO DATA** fallback for failed APIs.
10. APK build, app launch, and exact demo-script test on an actual Android device.

**OPTIONAL, ONLY AFTER ALL MUSTS PASS:** SQLite saved analyses and small visual polish.

**OUT OF SCOPE:** Gemini/other AI models, chatbots, startup profit simulation, revenue guarantees, PDF report generation, login, signup, payments, subscriptions, backend servers, deployment, NFC/RFID, foot-traffic estimation, demographic predictions, and mobile Play Store release.

## 2. Locked technology choices

| Layer | Choice | Rule |
|---|---|---|
| Mobile | **Flutter + Dart** | Android-first, real APK. No React, Vite, Leaflet, or webview map. |
| Maps | **Official `mapbox_maps_flutter`** | Pick a current **stable**, SDK-compatible version from pub.dev, pin with `pubspec.lock`. No alpha unless unavoidable and approved. |
| Map style | **Mapbox Standard** | Elegant light style; comply with attribution. Avoid elaborate 3D work if it delays MVP. |
| Map services | **Mapbox** | Valid **public** access token (`pk.`), usage subject to account limits. |
| Business listings | **OpenStreetMap via Overpass API** | On-demand available mapped records; **not** real-time business operations. |
| GPS | **geolocator** | Request only permissions needed. Manual map selection still works when denied. |
| HTTP | **Dio** | Timeout, cancellation, errors, limited retry, no request flooding. |
| State | **flutter_riverpod** | Loading/data/empty/error states. |
| Navigation | **go_router** | Keep route count minimal (one main screen plus details/compare if needed). |
| UI | **Material Design 3** | Brand: deep emerald, mint, off-white; modern card / bottom-sheet design. |
| App design | **MVVM-ish + repository separation** | Separate widgets, state, services, and pure scoring logic without unnecessary abstraction. |
| Storage | **SQLite/sqflite (optional)** | Only add once the complete live demo works. |

**Important reality check:** Mapbox renders the interactive map; Overpass supplies OSM establishment records. Neither source proves that all nearby businesses have been mapped or remain open. Scores are **heuristics**, not verified location quality.

### Verified documentation for the agent

- Mapbox Flutter installation/token: https://docs.mapbox.com/flutter/maps/guides/install/
- Mapbox Flutter package: https://pub.dev/packages/mapbox_maps_flutter
- Mapbox markers: https://docs.mapbox.com/flutter/maps/guides/markers-and-annotations/
- Overpass QL: https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL
- Flutter architecture: https://docs.flutter.dev/app-architecture/guide
- Flutter architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Mapbox pricing: https://www.mapbox.com/pricing

**SDK caution:** Documentation sometimes displays a newer prerelease than the stable pub.dev version. Claude must inspect the installed Flutter version, then select a compatible *stable* package release and use the matching API examples. Do not blindly combine 2.x and 3.x APIs.

## 3. User flow / MVP screens

1. **Explore (home):** full-screen modern Mapbox map, floating select/GPS controls, bottom sheet with category and radius, and a primary **Find competitors** action.
2. **Nearby results:** display selected site pin, nearby competitor pins, source count, sorted business list, loading/empty/error states, data-source timestamp, and visible OSM coverage caveat.
3. **Analyze:** show the heuristic score **if complete inputs are present**, break down **40% competition / 30% complementary businesses / 30% mapped-road-access proxy** and state what each indicator means.
4. **Compare:** choose site B; independently query using the **same category and radius**; present an honest side-by-side comparison of verified counts, data availability, and optional comparable scores.
5. **Sample demo fallback:** a clearly labeled, deterministic local example to show the flow if Overpass fails. Do **not** disguise sample places/counts as live records.

### Initial state

- Default map viewport: **Santa Ana, Pampanga**, approximate municipal reference center `15.0939, 120.7681` (map center, **not a claim that this is an ideal business lot**).
- Default business category: **Coffee Shop** (`amenity=cafe`).
- Default radius: **1000 meters**.
- Supported initial categories: Coffee Shop (`amenity=cafe`), Restaurant (`amenity=restaurant`), Sari-Sari/Convenience Store (`shop=convenience`), Laundry Shop (`shop=laundry`), Bakery (`shop=bakery`). Display the OSM matching caveat.
- Radius options: **500 m, 1 km, 2 km**. Do not query on every map camera movement or keystroke; query only on explicit user action.

## 4. Data contracts and integrity rules

Use sensible immutable Dart models with explicit source metadata. Suggested concepts:

```text
SelectedSite: id, latitude, longitude, displayLabel
BusinessCategory: id, label, osmTagKey, osmTagValue
NearbyBusiness: osmType, osmId, name?, category, latitude, longitude, distanceMeters
FetchState: idle | loading | success | empty | error | sample
Evidence: competitors, complementaryPois, nearbyRoads, fetchedAt, queryStatus, dataSource
Score: total? (0..100), criterionScores, weights, evidenceWarning, isComparable
SiteAnalysis: site, category, radiusMeters, evidence, score?, sourceMode
```

### OSM/Overpass implementation contract

- `nwr` results may be nodes, ways, or relations; coordinates can be `lat/lon` or `center.lat/center.lon`.
- Use stable key `osmType + ':' + osmId` to deduplicate; discard records without valid coordinates and record the number skipped.
- Use `tags.name` if present, otherwise display `Unnamed mapped business` (never invent a shop name).
- Use user-selected latitude, longitude, category tag, and radius to build a bounded Overpass QL query; POST as form data if practical.
- Example syntax only (replace placeholder coordinates with selected site):

```overpass
[out:json][timeout:25];
nwr(around:1000,15.0939,120.7681)["amenity"="cafe"];
out center;
```

- Primary endpoint (configurable): `https://overpass-api.de/api/interpreter`.
- Be considerate to shared public infrastructure: cache recent queries, explicitly refresh, avoid rapid polling, cap radius, limit concurrency, and respect HTTP 429 / 504 with useful messages.
- Add request timeout/cancellation; changing category/site must not allow stale responses to overwrite the latest view.
- Show **'OpenStreetMap contributors'** attribution and Mapbox's required attribution/logo.
- If no businesses are returned, show **'No mapped records found within this radius'**, never 'No competitors exist'.
- Distinguish **live retrieved / cached / sample fallback** in UI and in comparison.

### Honest scoring contract

**Transparent heuristic, no AI:**

```text
Overall score = 0.40 * competitorCriterion
              + 0.30 * complementaryCriterion
              + 0.30 * mappedRoadAccessCriterion
```

All criterion values range 0..100. Document the chosen normalization in code and UI:

- **Competitor proximity (40%)**: a transparent penalty based on number and/or distance of *mapped same-category* businesses in the selected radius. Higher score can mean fewer mapped competitors; clarify that a high count can also indicate existing demand.
- **Complementary establishments (30%)**: count nearby *mapped*, explicitly defined complementary categories (e.g., other retail/amenity categories), avoiding duplicates and same-category businesses. This is not measured customer demand.
- **Road accessibility proxy (30%)**: only if a separate, successful OSM road/highway query supplies evidence near the site. Presence/proximity of mapped roads is **not** proof of road accessibility, travel time, walkability, or transport quality.
- No synthetic statistics. If **any** required category query fails, do not manufacture criterion values: show score as **'Insufficient data'** and a breakdown of the available evidence. A successfully executed query returning zero is different from an API error; still show low-confidence warning for sparse OSM coverage.
- Use one deterministic scoring formula for both sites and **unit test it**.
- Scores cannot be presented as profit, probability of success, measured foot traffic, or verified market demand.

### Styling requirements

- Brand name **PWESTADO**, tagline **Ang tamang pwesto, simula ng negosyo.**
- Visual direction: polished map-first mobile SaaS, readable off-white surface, dark emerald headings, mint accent, contrasting orange competitor pins, responsive bottom sheets, large tappable controls.
- Prioritize legible map labels and real map interaction over decorative 3D effects.
- Include location/OSM caveats near results; no fake testimonials, inaccurate stats, fake loading states, or paid feature promises.

## 5. Architecture (pragmatic)

Suggested structure; evolve only as the code justifies it:

```text
PitchingSystem/
  CLAUDE.md
  PHASING.md
  phases/
  lib/
    main.dart
    app/{app.dart,router.dart,theme.dart}
    core/{config/,models/,utils/}
    features/
      explore/{presentation/,state/}
      discovery/{data/,domain/,presentation/}
      analysis/{domain/,presentation/}
      comparison/{presentation/,state/}
    shared/widgets/
  assets/sample/             # explicitly labeled demo records only
  test/                      # scoring, parsing, comparison tests
  android/
  pubspec.yaml
  pubspec.lock
```

Do not generate dozens of empty files or extra modules just to match a diagram. Keep the first fully runnable vertical slice small.

## 6. Work phases and checkpoints

| Phase | Focus | Acceptance gate | Status |
|---|---|---|---|
| **00** | [Environment and credentials](phases/PHASE_00_ENVIRONMENT.md) | `flutter doctor`, device, SDK compatibility, token plan | [x] |
| **01** | [Flutter shell and design](phases/PHASE_01_APP_SHELL.md) | Runs with polished home screen; no runtime errors | [x] |
| **02** | [Mapbox + GPS + site selection](phases/PHASE_02_MAPBOX_LOCATION.md) | Real map moves, long press picks a site, GPS denial handled | [x] |
| **03** | [Overpass + competitor markers](phases/PHASE_03_COMPETITORS.md) | Real request / honest empty or error, markers/counts | [x] |
| **04** | [Evidence + scoring](phases/PHASE_04_SCORING.md) | Pure Dart scoring, targeted tests and analyzer (no APK) | [ ] |
| **05** | [Two-site comparison](phases/PHASE_05_COMPARISON.md) | Independent A/B + matched settings, focused tests (no APK) | [ ] |
| **06** | [Reliability + APK + demo](phases/PHASE_06_RELEASE.md) | Full regression, release APK and physical-phone demo | [ ] |
| **07** | [Optional SQLite](phases/PHASE_07_OPTIONAL_SQLITE.md) | Optional after pitch; explicit approval only | [ ] |

**Stop rule:** Complete only the approved phase, run its **proportionate** checks, report which checks really passed and which device interactions remain deferred, update only verified checkboxes, then STOP. Phase 06 centralizes the complete physical-device proof.

### Fast iteration gates (effective after Phase 03)

| Phase | Required lightweight checks | Deferred checks |
|---|---|---|
| **04 - Scoring** | Format changed Dart files, `flutter analyze --no-pub`, targeted `flutter test --no-pub` unit/widget tests with mocked OSM evidence. | Android builds/installs, emulator, Mapbox token prompts, repeated Overpass probes and screenshots. |
| **05 - Comparison** | Same format/analyzer/targeted test gate, using fake repositories to verify independent A/B selection, parity and mixed source statuses. | Android builds/installs and live end-to-end walkthrough. |
| **06 - Release** | Full `flutter analyze` and `flutter test`, one release APK build with public token, install and complete demo on physical POCO phone. | Duplicate debug APK builds and unnecessary repeated installations. |
| **07 - Optional SQLite** | Skip until after pitch unless explicitly approved; when approved, focused storage tests first. | Anything that delays the verified pitching APK. |

**Exception:** Native/Gradle/Mapbox platform changes that cannot be assessed by unit/widget tests may justify one focused emulator or build smoke check earlier. State why; it is an exception, not the default phase gate.

**Integrity:** A Phase 04/05 *code/test gate* may PASS while final physical-device integration remains pending Phase 06. Never assert real device, live API, screenshots or APK checks without executing them. Run `flutter pub get` when dependencies actually change; otherwise prefer `--no-pub`. Format only changed Dart files.

## 7. Windows + VS Code environment

The code must be created **inside the owner's project folder**, not a randomly created nested project. In a VS Code PowerShell terminal:

```powershell
cd "C:\Users\Jiro\Documents\PitchingSystem"
flutter doctor -v
flutter devices
```

If it is an empty workspace, the agent may initialize Flutter **in place**:

```powershell
flutter create --project-name pwestado .
```

If it already has a Flutter project, **inspect and reuse it**. Never overwrite existing source, `android/` settings, or user-created files without checking first.

Mapbox's **public `pk.` token** should be provided at runtime/build time via `--dart-define`, not committed to the repository:

```powershell
$env:MAPBOX_ACCESS_TOKEN="pk.YOUR_PUBLIC_TOKEN"
flutter run --dart-define="ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN"
```

```dart
const token = String.fromEnvironment('ACCESS_TOKEN');
```

Never use or expose a Mapbox **secret `sk.` token** in a Flutter app. A public token is included in the compiled client and is not a secret; follow Mapbox token-scope guidance and account controls. Do not print it in normal logs.

**Release example (when all phases pass):**

```powershell
flutter build apk --release --dart-define="ACCESS_TOKEN=$env:MAPBOX_ACCESS_TOKEN"
```

Expected artifact after a successful Flutter release build: `build\app\outputs\flutter-apk\app-release.apk`. Installing and launching on the phone is part of the acceptance gate, not optional.

## 8. Demo strategy

### Exact 90-120 second app demonstration

1. Open PWESTADO on phone; show the Mapbox map of Sta. Ana.
2. Select **Coffee Shop**, radius **1 km**; long-press a potential site.
3. Tap **Find competitors**; show loading then **live OSM results**, if available, or an honest status.
4. Open analysis; point out the **40/30/30** evidence breakdown and limitations.
5. Choose a second location; show side-by-side results and matching query settings.
6. If Overpass fails, switch explicitly to **SAMPLE DEMO MODE** and explain why; never pretend the sample is live.

### Disaster recovery

- Keep a labeled deterministic local sample dataset and a cached successful response if available.
- Test the **same** location/category/radius on both Wi-Fi and mobile data before presenting.
- Capture real screenshots or a short screen recording **only after successful runs**.
- If Maps SDK/token fails, **do not substitute a static screenshot as a functioning map**. Repair the integration or state honestly what is not working.

## 9. Claude agent operating contract

**Read `CLAUDE.md` first.** Then read this file and the file of the current phase.

- Follow the latest instruction from the owner if it differs from this plan, but state any scope impact.
- Before editing, inspect existing files, dependency versions, and environment. Avoid destructive commands.
- Implement **one phase per request**, starting at Phase 00 unless owner identifies an already completed phase.
- Write real runnable code, not placeholders or UI-only mock behavior for must-work features.
- Keep commits/changes small and easy to reverse. No automatic git push, publishing, paid provisioning, or creating paid services.
- Use official version-matching SDK documentation. Never invent method names, imports, parameters, or test results.
- If packages or endpoints fail, show the error and make the smallest corrective change.
- End each completed phase with `Changed`, `Tests run`, `Result`, `Known limitations`, and `Next phase`; then **STOP**.

### Copy/paste kickoff prompt for Claude

> You are coding PWESTADO in `C:\Users\Jiro\Documents\PitchingSystem`. First read `CLAUDE.md`, `PHASING.md`, and `phases/PHASE_00_ENVIRONMENT.md`. Inspect the existing workspace and Flutter toolchain. Implement **Phase 00 only**. Do not start Phase 01 until I approve. Report exact checks, blockers, and one next action. Keep the Mapbox token out of source control.

## 10. Completion definition

This pitch MVP is complete only when the user can actually open an APK, explore a real Mapbox map, choose an arbitrary site, load or truthfully fail an OSM business query, see business pins and counts, inspect a traceable heuristic analysis, and compare another location, with sample/low-coverage disclosures visible. **Polished screens alone do not meet acceptance.**
