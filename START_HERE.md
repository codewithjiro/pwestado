# PWESTADO - Using these files in VS Code + Claude

1. Download and unzip this pack into `C:\Users\Jiro\Documents\PitchingSystem`, keeping `PHASING.md`, `CLAUDE.md`, and the `phases` folder together.
2. Open that **exact folder** in VS Code. Launch the Claude coding agent in the same workspace.
3. Paste this kickoff prompt:

   > Read `CLAUDE.md`, `PHASING.md`, and `phases/PHASE_00_ENVIRONMENT.md`. You are building the original PWESTADO Flutter Android MVP in this workspace for tomorrow's pitch. Inspect the current project first. Work on **Phase 00 only**, verify the toolchain/device/Mapbox stable version, report results, and stop until I approve the next phase. Never hardcode API tokens.

4. After a phase genuinely passes, tell Claude `Proceed to Phase 01`, then `Proceed to Phase 02`, and so on, approving only one phase at a time.
5. A Mapbox public access token (`pk.`) is required to show Mapbox maps. Use secure local environment / `--dart-define`; **do not paste a secret `sk.` token** into source code.

**Priority order:** Mapbox map > site selection > actual OSM competitor query > honest scoring > comparison > build/test APK. SQLite is optional.

**Note:** This zip contains planning/instruction files, **not implemented Flutter code**. Your coding agent will create the app in your local Windows project folder.
