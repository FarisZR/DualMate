# AGENTS.md - Engineering Guide for DualMate

## Project Overview

- Project: `DualMate` (Flutter/Dart app for DHBW students)
- Target platform: Android
- iOS: currently unmaintained, ignore iOS for fixes/features unless explicitly requested

## Localization
- Supported locales: English (`en`) and German (`de`)

## Testing Guidance

- Test tree mirrors feature structure in `test/`.
- Run targeted tests for touched areas, then broader suites.
- High-signal suites recently expanded:
  - `test/schedule/ui/viewmodels/*`
  - `test/schedule/ui/weeklyschedule/*`
  - `test/canteen/ui/*`
  - parser/fixture tests under `test/.../html_resources`

Use real Android device runs when available for final verification of:
- lifecycle/resume behavior
- widget tap navigation/payload handling
- background refresh and performance

## Documentation Workflow

- Record fixes in `docs/solutions/<category>/...md` with frontmatter.
- Keep implementation plans in `docs/plans/`.
- Canonical behavior docs to consult before touching core flows:
  - `docs/modernizing.md`
  - `docs/rapla-cache-refresh-behavior.md`
  - `docs/rapla-schedule-cache-merge.md`
  - `docs/canteen-feature.md`
  - `docs/multi-day-widgets.md`
  - `docs/support/launch-and-orientation.md`

## workflow for new features / bugfixes

- Always look up relevant docs using the tools you have access to look for the most up to date way to implement a feature or a fix.
- Test driven development, write automated tests first with full coverage of the bug or the new feature
- Test your final changes using the debugger and the connected android device if available by reading the logs and checking for issues.
- target Material you (Material 3) design language (https://m3.material.io/develop/flutter, https://m3.material.io/foundations/content-design/overview)

## Practical Notes

- `README.md` is marked TODO and is not the source of truth for current architecture.
- `android/build/...` contains generated artifacts; do not treat them as source docs.
- There is no strict custom lint config (`analysis_options.yaml` absent).

- This is a hard cutover project, meaning there are no current users. Backwards compatibility isn't needed and it shouldn't be taken into account nor have any code written for it.
