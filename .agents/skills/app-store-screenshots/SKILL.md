---
name: app-store-screenshots
description: Use when updating, exporting, reviewing, or extending DualMate's Google Play/App Store marketing screenshot project. Triggers on Play Store screenshots, store assets, screenshot editor, phone/tablet screenshot marketing, widget preview marketing, or app-store-screenshots.json.
license: MIT
metadata:
  upstream: https://github.com/ParthJadhav/app-store-screenshots
  upstream-revision: e58f81961b5fd9e3969c680061f7cfd8f286ae55
  dualmate-fork: https://github.com/FZR-forks/app-store-screenshots
  fork-revision: 640f888c6e116a3e9adfc4d45a4897123b397650
---

# DualMate store screenshot workflow

This is the project-specific entrypoint for the upstream `app-store-screenshots` skill. The upstream skill text is preserved verbatim at `references/upstream-SKILL.md`; its design guidance and quality bar still apply. For this repository, the workflow below overrides the upstream scaffolding/migration steps.

## Canonical project

- Project root: `store-assets/play-store-screenshots/`
- Canonical state: `store-assets/play-store-screenshots/app-store-screenshots.json`
- Disposable editor: `store-assets/play-store-screenshots/.editor/` (gitignored)
- Setup: `store-assets/play-store-screenshots/setup.sh`
- Documentation: `store-assets/play-store-screenshots/README.md`

Never vendor another editor copy into DualMate. Never treat `.editor/` as source-of-truth code.

## Reopen / edit

1. Read `store-assets/play-store-screenshots/README.md` and the current JSON before changing anything.
2. Run `./setup.sh` from `store-assets/play-store-screenshots/`. It clones the pinned DualMate fork revision into the ignored `.editor/`, stages source assets, and symlinks the canonical JSON into the editor.
3. Start from `.editor/` with `bun dev --hostname 0.0.0.0 --port 3000` when the user wants browser/LAN access.
4. The editor auto-saves into the tracked JSON via the symlink. Preserve user-made positioning/copy unless asked to redesign it.
5. Before committing, run a production build from `.editor/` and inspect `git diff` for the canonical JSON/assets only.

## Current deck contract

- Locales: German (`de`) and English (`en`).
- Android phone: portrait, Connected canvas.
- Android 10-inch tablet: landscape, Isolated canvas.
- Both device decks live in the same JSON.
- Seven slides per device: schedule, reminders, Dualis, canteen, dates, widgets, all-features summary.
- The DualMate visual theme is defined in JSON under `customThemes.dualmate` and uses the hero-style near-white/red treatment.
- Real product screenshots must remain real screenshots. Do not regenerate or restyle the app UI with an image-generation model.
- Widget cards are arbitrary `imageElements`, not fake device screenshots.

## Asset staging

`setup.sh` intentionally reconstructs the editor's `public/` tree from repository sources:

- Phone UI: `screenshots/phone-light-*.png`
- Tablet UI: `screenshots/tablet-light-*.jpg`
- App icon: `icons/dualmate_icon_v1_refined_playstore_512.png`
- Widget previews: `store-assets/play-store-screenshots/assets/widgets/`

The phone deck currently references one shared set of phone captures while localizing the marketing copy. Tablet locale paths are both staged from the current light tablet captures. Preserve this behavior unless new locale-specific product captures are supplied.

## Editor changes

The pinned fork already includes reusable support for:

- movable/resizable arbitrary image elements;
- per-device orientation and Connected/Isolated canvas preferences;
- project-defined custom themes/background decorations.

If another reusable editor capability is needed, implement it in `FZR-forks/app-store-screenshots`, validate the fork template, push it, then update the pinned revision in `setup.sh`. Keep DualMate-specific content in project JSON/assets, not fork source.

## Design guidance

Read `style-prompts/_QUALITY_BAR.md` before substantial redesigns. Use `references/upstream-SKILL.md` for the upstream workflow, copywriting principles, layout guidance, and export-quality rules. In conflicts, this project-specific file wins for paths, setup, persistence, and fork usage.

For DualMate specifically:

- Match the existing website/app marketing hero: near-white canvas, strong black type, red accents, restrained line/dot decoration.
- Keep headlines readable at Play Store thumbnail size.
- Labels should add context rather than repeat the headline.
- Keep phone compositions varied; tablet compositions should exploit horizontal space.
- Do not let tablet devices bleed across screenshot boundaries unless the user explicitly redesigns the deck for that.

## Export / browser note

The editor uses `html-to-image`. Chromium has been validated for these decks. If Firefox export fails in its font embedding path, validate/export with Chromium rather than changing project state to work around a browser-specific failure.
