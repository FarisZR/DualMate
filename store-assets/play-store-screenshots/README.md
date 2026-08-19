# Play Store screenshot project

This directory is the canonical, git-tracked source for DualMate's Google Play marketing screenshots. The editor itself is **not vendored** here.

## Editor

The project uses the fork at `FZR-forks/app-store-screenshots`, pinned by `setup.sh` to commit:

`640f888c6e116a3e9adfc4d45a4897123b397650`

That fork adds generic support needed by this project: arbitrary movable image elements, per-device orientation/Connected settings, and project-defined custom themes.

## Reopen the project

From this directory:

1. Run `./setup.sh`.
2. Enter `.editor/`.
3. Start the editor with `bun dev --hostname 0.0.0.0 --port 3000`.
4. Open port 3000 in a browser. Edits auto-save through the symlink to the tracked `app-store-screenshots.json` in this directory.

`.editor/` is disposable and ignored by git. Re-run `setup.sh` whenever the pinned editor revision changes or a clean editor is desired.

## Canonical state

`app-store-screenshots.json` contains one combined project:

- Android phone: portrait, Connected canvas, German + English copy.
- Android 10-inch tablet: landscape, Isolated canvas, German + English copy.
- Seven slides per device, including the widgets slide.
- The `dualmate` theme is project-defined in `customThemes`; do not hard-code DualMate branding into the editor fork.

The setup script stages existing repository screenshots and the app icon into the editor. Widget preview images are intentionally stored under `assets/widgets/` because this deck uses the exact previews from DualMate commit `5a8a010f8ab62b8d8f9c510ae1998492cca32e9d`, rather than whatever happens to be current in the Android resources.

## Updating editor functionality

Do not edit generated files inside `.editor/` as the source of truth. If the editor needs a reusable feature, change `FZR-forks/app-store-screenshots`, push it, update `EDITOR_REVISION` in `setup.sh`, rebuild the disposable editor, and verify the existing JSON still renders correctly.

For screenshot-design rules and project workflow, use `.agents/skills/app-store-screenshots/SKILL.md`.
