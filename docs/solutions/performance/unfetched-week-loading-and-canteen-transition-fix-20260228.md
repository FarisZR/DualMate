---
title: Restore unfetched-week loading line and canteen loading transition
date: 2026-02-28
---

# Summary

Two UX regressions were addressed after the loading-indicator simplification:

1. swiping to an unfetched schedule week could show no top loading line,
2. canteen startup could switch from skeleton to meals without a visible
   transition.

# Findings

1. Schedule week opening used a debounced visible refresh path, so first-time
   week loads could miss the loading line window.
2. The top loading line delay was useful for short refreshes, but it also hid
   first-fetch feedback for not-yet-fetched weeks.
3. Canteen changed layout structure from single-day placeholder view to
   paged-content view once meals appeared, which bypassed the day-level
   `AnimatedSwitcher` and made the transition feel abrupt.

# Changes

- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart`
  - added visible-week first-fetch detection (`visibleWeekNeedsInitialFetch`).
  - when opening an unfetched week, start visible refresh immediately instead of
    waiting for the debounce window.
- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`
  - wired first-fetch signal into `_TopLoadingIndicator`.
  - loading line now bypasses delay for unfetched weeks and keeps a short
    minimum visible duration to avoid instant blink-out.
- `lib/canteen/ui/canteen_page.dart`
  - added page-content-level `AnimatedSwitcher` so transitioning from startup
    skeleton container to paged meals is animated.
  - made day-state keys date-aware and slightly strengthened transition timing.

# Validation

- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
- `flutter test test/canteen/ui/canteen_page_bounds_test.dart`
- `flutter analyze lib/common/appstart/app_initializer.dart lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart lib/canteen/ui/canteen_page.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
