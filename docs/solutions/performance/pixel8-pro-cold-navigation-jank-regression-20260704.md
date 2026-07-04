---
title: Pixel 8 Pro cold-navigation jank regression pass
date: 2026-07-04
type: fix
---

# Summary

Cold-start fast navigation regressed across Schedule, Canteen, Dates, and
Dualis. The main avoidable causes found in this pass were startup-adjacent
background work, profile-mode Sentry diagnostics, modal drawer route animation,
secure-storage restore work on Dualis entry, and widget-heavy schedule entry
cards.

This pass reduces that pressure and adds a repeatable aggressive Pixel 8 Pro
profile gate using a real Rapla schedule cache. It still does not satisfy the
strict zero-jank 120Hz target, but the dominant continuous jank from drawer
page switching and Sentry/native startup work is gone.

# Changes

- Added `integration_test/aggressive_cold_navigation_performance_test.dart` and
  `test_driver/aggressive_perf_driver.dart` to drive immediate cold-start
  Schedule, Canteen, Dates, and Dualis interactions and fail on frames above the
  Pixel 8 Pro 120Hz budget.
- The aggressive harness now seeds previous/current/next real Rapla weeks from
  `https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=strand&file=TINF25B5`
  before launch and waits for real `ScheduleEntryWidget`s, so schedule swipes
  are no longer measured against an empty timetable.
- Reduced Sentry profile/release overhead by disabling debug diagnostics outside
  debug mode and keeping trace sampling low outside debug builds.
- Delayed root-level background initialization, foreground heavy work, canteen
  prewarm, schedule filter warmup, canteen prefetch, and Dualis auto-restore so
  they do not compete with immediate cold-start navigation.
- Avoided Dualis secure-storage credential reads when credential persistence is
  disabled.
- Removed startup-adjacent transition layers from the main placeholder, Canteen
  header/content/back-to-today button, Dates loading indicator, Dualis state
  switch, and Schedule current-week button.
- Replaced the phone `Scaffold.drawer` route with a lightweight in-page drawer
  overlay. The built-in drawer route was the biggest page-switch raster source
  because it kept a heavy modal animation active while the destination route was
  still offstage to the test and user.
- Debounced Schedule pager week commits after scroll end so repeated fast swipes
  replace pending cache work instead of starting work during the gesture burst.
- Avoided force-refreshing the visible schedule on source setup when the visible
  window already has cache query metadata, and moved cached-window automatic
  visible refreshes out of the first cold-start interaction window.
- Simplified schedule entry cards from Material/Ink/InkWell stacks to a cheaper
  decorated tappable box while preserving tap-to-detail behavior.

# Validation

- `flutter analyze lib/ui/main_page.dart lib/ui/navigation_drawer.dart lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart lib/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart integration_test/aggressive_cold_navigation_performance_test.dart`
- `flutter test test/common/logging/sentry_configuration_test.dart test/ui/main_page_startup_placeholder_test.dart test/schedule/ui/schedule_page_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/weeklyschedule/schedule_entry_widget_layout_test.dart test/schedule/ui/weeklyschedule/schedule_current_time_indicator_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart test/dualis/ui/viewmodels/study_grades_view_model_test.dart test/dualis/ui/dualis_page_session_restore_test.dart test/common/appstart/app_initializer_startup_policy_test.dart test/canteen/ui/canteen_page_bounds_test.dart test/date_management/ui/date_management_page_test.dart test/dualis/ui/study_overview_loading_animation_test.dart`
- `flutter drive --no-dds --driver=test_driver/aggressive_perf_driver.dart --target=integration_test/aggressive_cold_navigation_performance_test.dart --profile -d 39181FDJG006DP`

# Pixel 8 Pro Result

The final aggressive profile run still failed the 120Hz frame budget, but the
realistic current-tree result is much lower than the first realistic Rapla run
(`build=20 raster=70`):

- Total: build misses 10, raster misses 7
- Launch: build 1, raster 1
- Schedule swipes: build 6, raster 3
- Open Canteen: build 1, raster 2
- Canteen swipes: build 1, raster 0
- Open Dates: build 1, raster 0
- Dates scroll: build 0, raster 1
- Open Dualis: build 0, raster 0
- Dualis visible wait: build 0, raster 0

# Follow-up

The remaining misses are mostly first-render work for real populated Schedule
week pages and first-build frames for Canteen/Dates. Reaching a true zero-miss
120Hz gate likely requires a structural schedule renderer change, such as a
compact custom-painted week-entry layer with explicit hit testing, rather than
more delay-based deferral.
