# Phase 01 - Flutter foundation and branded app shell

**Goal:** A launchable Flutter Android application with PWESTADO branding and an intentionally designed, map-first screen structure. The actual map comes next.

## Tasks

1. If the inspected workspace has no Flutter project, initialize **in place**: `flutter create --project-name pwestado .` from the project root.
2. Add `flutter_riverpod`, `go_router`, and Material 3 theming; add the other packages only when their phases begin.
3. Create the minimal `main.dart` / `app` / `theme` structure. Keep implementation small, avoid unused scaffolding.
4. Use **PWESTADO** and tagline **Ang tamang pwesto, simula ng negosyo.**; make a modern, clean mobile interface (emerald/mint/off-white).
5. Build a visually polished home screen with a map placeholder explicitly marked **Map integration in Phase 02**, category selector, radius options, and a disabled analysis action until prerequisites are ready. Avoid presenting the placeholder as a live map.
6. Add basic app/error layout and responsive sizing. If route architecture isn't necessary for only one screen, keep go_router minimal.
7. Add one simple widget/smoke test and run on Android device or emulator.

## Acceptance gate

- [x] `flutter run` starts on Android without crashes.
- [x] Branding/theme visible; controls readable and tappable.
- [x] No simulated competitor data or misleading scores.
- [x] `dart format .`, `flutter analyze`, and current tests pass.

## Stop

Report modified files, observed run output, and request approval before Phase 02.
