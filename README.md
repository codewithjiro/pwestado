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

## Checks

```powershell
dart format .
flutter analyze
flutter test
```
