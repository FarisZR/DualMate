---
title: Pixel 8 Pro cold-navigation jank regression pass
date: 2026-07-04
type: fix
---

# Summary

Cold-start fast navigation regressed across Schedule, Canteen, Dates, and
Dualis. The main avoidable causes found in this pass were startup-adjacent
background work, profile-mode Sentry diagnostics, AndroidX ProfileInstaller
startup work, secure-storage restore work on Dualis entry, and animation layers
that overlapped fast navigation.

This pass reduces that pressure and adds a repeatable aggressive Pixel 8 Pro
profile gate, but it does not yet satisfy the strict zero-jank 120Hz target.

# Changes

- Added `integration_test/aggressive_cold_navigation_performance_test.dart` and
  `test_driver/aggressive_perf_driver.dart` to drive immediate cold-start
  Schedule, Canteen, Dates, and Dualis interactions and fail on frames above the
  Pixel 8 Pro 120Hz budget.
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
- Debounced Schedule pager week commits after scroll end so repeated fast swipes
  replace pending cache work instead of starting work during the gesture burst.
- Removed AndroidX ProfileInstaller initialization from app startup.
- Suppressed database migration SQL prints outside debug mode.

# Validation

- `flutter analyze lib/common/logging/sentry_configuration.dart lib/common/data/database_access.dart lib/ui/root_page.dart lib/ui/main_page.dart lib/ui/navigation_drawer.dart lib/schedule/ui/schedule_page.dart lib/canteen/ui/canteen_page.dart lib/date_management/ui/date_management_page.dart lib/dualis/ui/dualis_page.dart lib/dualis/ui/viewmodels/study_grades_view_model.dart integration_test/aggressive_cold_navigation_performance_test.dart test_driver/aggressive_perf_driver.dart`
- `flutter test test/common/logging/sentry_configuration_test.dart test/ui/main_page_startup_placeholder_test.dart test/schedule/ui/schedule_page_test.dart test/dualis/ui/viewmodels/study_grades_view_model_test.dart test/dualis/ui/dualis_page_session_restore_test.dart test/common/appstart/app_initializer_startup_policy_test.dart test/canteen/ui/canteen_page_bounds_test.dart test/date_management/ui/date_management_page_test.dart test/dualis/ui/study_overview_loading_animation_test.dart`
- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/schedule_page_test.dart`
- `flutter drive --no-dds --driver=test_driver/aggressive_perf_driver.dart --target=integration_test/aggressive_cold_navigation_performance_test.dart --profile -d 39181FDJG006DP`

# Pixel 8 Pro Result

The final aggressive profile run still failed the 120Hz frame budget:

- Total: 395 frames, build misses 21, raster misses 15
- Launch: build 1, raster 1
- Schedule swipes: build 6, raster 1
- Open Canteen: build 2, raster 6
- Canteen swipes: build 6, raster 1
- Open Dates: build 2, raster 6
- Open Dualis: build 2, raster 0
- Dualis visible wait: build 2, raster 0

# Follow-up

The remaining misses are no longer isolated to one deferred data task. They are
spread across core route/drawer/page transitions and first render work. The next
pass should collect VM-service timeline spans for the failing segments and move
from delay/removal of obvious work to structural rendering changes in the
navigation shell, Schedule pager, and Canteen/Dates page content.
