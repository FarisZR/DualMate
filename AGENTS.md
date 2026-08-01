# Dualmate

DualMate is a companion app for DHBW students, it's an app that gives students information for their studies, and helps them in their day-to-day student life.
it shows them stuff like their schedule, what's their to eat in the canteen and so on.

## The Target User

Our target users are students at the DHBW, most of the DHBW students aren't technical, the app should be easy to use, follow standard platform UX conventions, have a nice UI and just look like a plain friendly student app.

Students often save money on their phones, performance optimization is therefore of utmost priority, we can't assume students will have flagship performance.

to fix catastrophic issues and crashes asap, we use sentry to capture errors so they can be fixed asap before a user faces them.

## App design

### just get out of the way.
The app must just follow the UX conventions of the platform, stick to Material 3 / Material you design language, and just follow how an android user would think such an app should function.

This is a companion app, it should be reliable, easy to use and just get out of the way. the faster a user can do something, the better.

### Material 3
this app is designed for android, you should stick to material 3 / material you design standards. everything must feel like native material 3.

## Technical details
- Target platform: Android
- iOS: currently unmaintained, ignore iOS for fixes/features unless explicitly requested

### Localization
- Supported locales: English (`en`) and German (`de`)

### Testing Guidance

- Test tree mirrors feature structure in `test/`.
- Run targeted tests for touched areas, then broader suites.
- High-signal suites recently expanded:
  - `test/schedule/ui/viewmodels/*`
  - `test/schedule/ui/weeklyschedule/*`
  - `test/canteen/ui/*`
  - parser/fixture tests under `test/.../html_resources`

- App performance is only reflective in profile and release builds, use the local release build type to create a release build using a debug key.

### Documentation Workflow

- Record fixes in `docs/solutions/<category>/...md` with frontmatter.
- Keep implementation plans in `docs/plans/`.
- Canonical behavior docs to consult before touching core flows:
  - `docs/modernizing.md`
  - `docs/rapla-cache-refresh-behavior.md`
  - `docs/rapla-schedule-cache-merge.md`
  - `docs/canteen-feature.md`
  - `docs/multi-day-widgets.md`
  - `docs/support/launch-and-orientation.md`

### workflow for new features / bugfixes

- Always look up relevant docs using the tools you have access to look for the most up to date way to implement a feature or a fix.
- Test driven development, write automated tests first with full coverage of the bug or the new feature, to prevent regressions.
- Test your final changes using a connected android device via the `android` cli if available by reading the logs and checking for issues.
- target Material you (Material 3) design language (https://m3.material.io/develop/flutter, https://m3.material.io/foundations/content-design/overview)
- On changes that affect the UI, the UI thread or how the app renders things, you must always run the full cold start performance harness to make sure your new changes don't cause a performance regression.
- Your PRs must include screenshots and video captures for visual changes, if it's a new prompt on an exception.