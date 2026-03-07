---
title: Smooth first schedule render after onboarding completion
date: 2026-03-01
---

# Summary

After setup completion, the first transition into main schedule content could
show a transient Flutter exception frame and feel janky on Pixel devices.

# Findings

1. `WeeklySchedulePage` could read `currentDateStart/currentDateEnd` before
   `WeeklyScheduleViewModel.initialize()` ran, causing a brief
   `LateInitializationError` red frame.
2. Schedule startup tasks were launched immediately after first frame of
   `SchedulePage`, which overlapped onboarding->main transition work.

# Changes

- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart`
  - initialize `currentDateStart`/`currentDateEnd` with a safe current-week
    baseline in constructor so first build is always valid.

- `lib/schedule/ui/schedule_page.dart`
  - keep `ScheduleViewModel.initialize()` immediate (lightweight) but defer
    weekly schedule initialization to an idle task after a short delay.
  - defer filter-state warmup to a later idle task and cancel timers on dispose.

- `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
  - added regression test that builds `WeeklySchedulePage` before weekly
    initialization and asserts no transient exception is thrown.

# Validation

- `flutter analyze lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart lib/schedule/ui/schedule_page.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
- `flutter test`
- Pixel 8 Pro integration suite:
  - `integration_test/onboarding_post_setup_navigation_stability_test.dart`
  - `integration_test/drawer_switch_responsiveness_test.dart`
  - `integration_test/date_management_startup_responsiveness_test.dart`
  - `integration_test/canteen_startup_responsiveness_test.dart`
  - `integration_test/performance_smoke_test.dart`
