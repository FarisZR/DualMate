# AGENTS.md - Engineering Guide for DualMate

This file is an onboarding and implementation guide for engineers and AI/code agents working in this repository.
Update this file when doing changes that affect documented items in it.

## Project Overview

- Project: `DualMate` (Flutter/Dart app for DHBW students)
- Target platform: Android
- iOS: currently unmaintained, ignore iOS for fixes/features unless explicitly requested

## Repository / Remote Rules

- Treat `FarisZR/DualMate` as the authoritative upstream repository for this
  project.
- Create branches, issues, and pull requests against `FarisZR/DualMate`.
- Do not open pull requests, push branches, or otherwise touch
  `Bennik2000/DHBWStudentInformationApp` for DualMate work.
- When using GitHub CLI, pass the target repository explicitly if there is any
  ambiguity in local `gh` context.

## Localization
- Supported locales: English (`en`) and German (`de`)

## Feature Modules and Core Paths

Important runtime behavior:
- Cache-first rendering, then stale-window background refresh.
- Range-aware freshness and request gating.
- Background widget refresh updates data without mutating visible week:
  - `updateSchedule(..., applyToVisibleState: false)`
- Filters must force refresh and invalidate cached ranges where needed.

### Date Management (`lib/date_management`)

- View model: `lib/date_management/ui/viewmodels/date_management_view_model.dart`
- Default source is Rapla important events (DHmine optional via settings toggle).
- Rapla events are derived from shared schedule cache (not a separate legacy cache).
- Pagination is windowed (3-month chunks), throttled, and bounded.
- Local device calendar export is behind the `DUALMATE_ENABLE_LOCAL_CALENDAR`
  Dart define and the Android `localCalendar` flavor.

### Canteen (`lib/canteen`)

- View model: `lib/canteen/ui/viewmodels/canteen_view_model.dart`
- Page: `lib/canteen/ui/canteen_page.dart`
- Provider/repository: `lib/canteen/business/canteen_provider.dart`, `lib/canteen/data/canteen_meal_repository.dart`
- Scraping/parsing offloads heavy parsing to isolate path in service layer.
- UI is day-based with visible-content-day bounds (recent fixes prevent invalid swipe pages/overscroll edge issues).

### Dualis (`lib/dualis`)

- Navigation entry and page under `lib/dualis/ui`
- Service stack includes cache decorator + scraper/authentication in `lib/dualis/service`
- Stored Dualis credentials should restore the session automatically when the
  Dualis section is shown again; long-idle returns should trigger a refresh
  instead of dropping the user back to the login form.
- Logged-in Dualis pages support manual pull-to-refresh, which should force a
  cache-busting reload of overview and semester data.

### Schedule (`lib/schedule`)

- UI entry is `SchedulePage`, which keeps a shared `WeeklyScheduleViewModel`, renders `WeeklySchedulePage` directly, and guards against missing data sources by showing `BannerWidget` + `SelectSourceDialog` when no schedule URL is configured.
- `ScheduleViewModel` orchestrates cache-first initialization/weathered refreshes, while `FilterViewModel.preloadStates` warmed via `ScheduleEntryRepository` and `ScheduleFilterRepository` keeps the filter UI snappy.
- Widget navigation payloads from `WidgetNavigationPayloadStore` open the relevant week directly, and the background updater under `lib/schedule/background` keeps shared caches fresh every few hours.
- The `business`, `data`, `model`, and `service` packages contain the schedule cache logic, repositories, and DTO mapping that feed the UI layers.

### Information (`lib/information`)

- `UsefulInformationNavigationEntry` wires into the main navigation, and `UsefulInformationPage` exposes the curated quick links (DHBW homepage, Dualis, Roundcube, Moodle, campus info, Eduroam, StuV, Hochschulsport) via `url_launcher` taps.

### Widgets and native bridge (`lib/native`, `android/.../widget`)

- Widget refresh bridging: `lib/native/widget/widget_update_callback.dart`
- Android method channel helper: `lib/native/widget/android_widget_helper.dart`
- Widget payloads are routed into app via `RootPage` method channel and `WidgetNavigationPayloadStore`.

## Background Jobs and Scheduling

- Background scheduler setup: `lib/common/appstart/background_initialize.dart`
- Tasks:
  - `BackgroundScheduleUpdate` (~every 4h)
  - `BackgroundCanteenUpdate` (~every 8h)
  - `NextDayInformationNotification`
- Schedule-change notifications are policy-filtered to class dates within the
  next 14 days; broader refresh windows still update cached data silently.
- Android uses real scheduler service; non-Android gets no-op scheduler.
- Local calendar sync startup work is disabled in the standard build. Use
  `--flavor localCalendar --dart-define=DUALMATE_ENABLE_LOCAL_CALENDAR=true`
  only when the local calendar feature should be compiled in and Android
  calendar permissions should be requested.

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
