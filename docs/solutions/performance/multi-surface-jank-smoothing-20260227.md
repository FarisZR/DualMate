---
title: Smooth schedule vertical shifts, drawer open, dates scroll, and dualis loading transitions
date: 2026-02-27
---

# Summary

This pass targeted interaction jank across multiple app surfaces by reducing
heavy rebuild patterns in schedule/date views, isolating repaint boundaries for
drawer transitions, and adding explicit loading transitions in Dualis so data
does not pop in abruptly.

# Findings

1. Weekly schedule hour-range interpolation rebuilt a heavy page surface every
   animation tick, which made vertical range shifts feel choppy on device.
2. Main scaffold and drawer transitions could repaint large surfaces during
   menu open/close interactions.
3. Date management rebuilt broad subtrees too often and scheduled repeated
   post-frame autoload checks while scrolling.
4. Dualis module/semester data appeared suddenly with no explicit loading state
   transition.

# Changes

## Weekly schedule vertical motion

- Removed tweened hour-range interpolation in `WeeklySchedulePage` and applied
  viewport updates directly to avoid repeated heavy relayout during vertical
  shifts.

## Drawer open responsiveness

- Added `RepaintBoundary` wrapping for main body and drawer surfaces in
  `MainPage`.
- Simplified drawer item composition in `MyNavigationDrawer` to reduce widget
  depth in the interaction path.

## Dates page scroll/build pressure

- Switched `DateManagementPage` top-level provider lookup to `listen: false`.
- Scoped `PropertyChangeConsumer` to relevant properties instead of all
  notifications.
- Removed broad `AnimatedSwitcher` around full content surface.
- Added autoload callback dedupe guard to prevent repeated post-frame work.
- Added list `cacheExtent` and section-level `RepaintBoundary` wrapping.
- Cached date/time formatters in `ImportantEventTile`.

## Dualis loading transitions

- Added explicit loading state flags in `StudyGradesViewModel` for:
  - study grades,
  - all modules,
  - semester names,
  - current semester modules.
- Added loading placeholders + `AnimatedSwitcher` transitions in:
  - `StudyOverviewPage` (summary + module table),
  - `ExamResultsPage` (semester module table).
- Refactored `DualisPage` to observe only `loginState` for top-level page
  switching and avoid unrelated rebuild churn.

# Validation

- `flutter test test/dualis/ui/study_overview_loading_animation_test.dart`
- `flutter test test/date_management/ui/date_management_page_test.dart test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart`
- `python3 docs/scripts/validate_screenshot_content.py`
- Attempted device integration smoke run:
- `flutter test integration_test/performance_smoke_test.dart -d <device-id>`
  - Runner returned a harness issue (`No tests were found`) after build/install;
    targeted widget/unit regressions still passed.

# Screenshots

Previous captures in `docs/screenshots/performance/` were invalid black-frame
renders and should not be used as verification evidence. Use
`docs/scripts/validate_screenshot_content.py` before uploading new captures.
