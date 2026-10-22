# Phase 00 - Environment and credentials

**Goal:** Confirm that the real Windows environment can build a Flutter Android app with a compatible stable Mapbox SDK. Make no risky source changes.

## Tasks

1. Open `C:\Users\Jiro\Documents\PitchingSystem`. Inspect contents. If `pubspec.yaml` exists, examine the app before deciding to initialize.
2. Run `flutter --version`, `dart --version`, `flutter doctor -v`, and `flutter devices`. Record outputs that affect Android builds.
3. Confirm that VS Code can run Flutter commands and that an Android phone or emulator is available. Note phone debugging/authorization status without assuming it is enabled.
4. Check current **stable** `mapbox_maps_flutter` requirements from https://pub.dev/packages/mapbox_maps_flutter. Choose a version compatible with the installed Flutter/Dart/Android SDK. Do not choose a prerelease just because the docs use it.
5. Confirm that the owner has a Mapbox **public** token (`pk.`), without printing or putting it in git; advise secure `--dart-define` setup.
6. Confirm availability of internet access for Mapbox tiles and Overpass queries, and that the Mapbox account's allowance fits a small demo.
7. Avoid creating nested app folders; if a Flutter project needs initializing, plan `flutter create --project-name pwestado .` from this folder.

## Acceptance gate

- [x] Flutter and Dart versions known.
- [x] Android build toolchain blockers identified or resolved.
- [x] Android device visible **or** specific device blocker documented.
- [x] A compatible stable Mapbox SDK path selected.
- [x] Public-token strategy clear; no token in tracked files.
- [x] Existing project preserved.

## Stop

Show results. If any prerequisite fails, resolve that failure only. Otherwise request Phase 01 approval. Do not start coding Phase 01 on your own.
