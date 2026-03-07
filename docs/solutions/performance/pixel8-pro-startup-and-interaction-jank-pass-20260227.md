---
title: Reduce startup-adjacent jank on schedule swipe, drawer open, and canteen loading
date: 2026-02-27
---

# Summary

Second performance pass focused on Pixel 8 Pro behavior where jank still
appeared right after app launch, during schedule week swipes, drawer opens on
data-heavy pages, and canteen initial population.

# Changes

## Schedule swipe + vertical viewport adjustment

- Locked hour-viewport animation target while the weekly pager is actively
  scrolling in `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`.
- Applied the new viewport only after pager scroll ends, avoiding concurrent
  horizontal page animation plus vertical relayout.
- Reduced per-frame label formatting churn in
  `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart` by caching
  locale `DateFormat` instances.

## Drawer open smoothness on heavy pages

- Added drawer open state tracking in `lib/ui/main_page.dart`.
- Wrapped the main phone body in `TickerMode(enabled: !_isDrawerOpen)` so
  background animations are paused while the drawer transition runs.

## Canteen startup and initial content transitions

- Deferred initial canteen warmup to idle priority with a short delay in
  `lib/canteen/ui/canteen_page.dart`.
- Limited page-change refresh work to week boundaries (not every day swipe).
- Replaced always-running loading shimmer pulse with one-time fade-in skeleton
  to cut continuous repaint pressure.
- Added loading-state `AnimatedSwitcher` so loading/content transitions no
  longer pop abruptly.
- Parallelized cache + last-updated DB reads in
  `lib/canteen/ui/viewmodels/canteen_view_model.dart`.

## Startup/deferred background work pressure

- In `lib/ui/root_page.dart`, moved deferred background init and schedule
  prewarm into idle-priority scheduler tasks.
- Increased deferred delays for heavy/secondary startup work so interaction
  paths get priority right after launch.
- Allowed first frame from root-shell startup path (`root_init_shell`) so UI
  can render a shell before deferred work completes.

## Dates page startup pressure

- Scheduled dates VM initialization at idle priority in
  `lib/date_management/ui/date_management_page.dart`.

# Validation

- `flutter analyze lib/canteen/ui/canteen_page.dart lib/canteen/ui/viewmodels/canteen_view_model.dart lib/date_management/ui/date_management_page.dart lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart lib/ui/main_page.dart lib/ui/root_page.dart`
- `flutter test test/canteen/ui/canteen_page_bounds_test.dart test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/date_management/ui/date_management_page_test.dart test/dualis/ui/viewmodels/study_grades_view_model_test.dart`
- Installed on Pixel 8 Pro for device verification.
