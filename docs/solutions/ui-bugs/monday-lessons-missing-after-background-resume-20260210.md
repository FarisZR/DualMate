---
module: Schedule UI
date: 2026-02-10
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Monday column is visible but Monday lessons are missing"
  - "After app resume, Monday appears empty across current, past, and future weeks"
  - "Issue disappears after a full app restart"
root_cause: background_refresh_state_leak
resolution_type: code_fix
severity: high
tags: [schedule, weekly-calendar, lifecycle, background-refresh, cache]
---

# Troubleshooting: Monday lessons disappear after app resumes from background

## Problem
After the app stays in background and is reopened, weekly schedule keeps the Monday column but Monday entries disappear across multiple weeks.

## Root Cause
The periodic widget refresh path in `WeeklyScheduleViewModel` refreshed a broad range (`today` to `today + 14 days`) through the same `updateSchedule(...)` flow used by the visible weekly screen.

That flow updates `currentDateStart/currentDateEnd`. If refresh starts on a non-Monday day (for example Tuesday), the visible week state shifted to a Tuesday-based range. Rendering still anchored labels to Monday-Friday, but Monday data was no longer in the loaded range, so Mondays appeared empty in all navigated weeks until restart reinitialized state.

## Solution
- Added an `applyToVisibleState` parameter to `WeeklyScheduleViewModel.updateSchedule(...)`.
- Background widget refresh now calls:
  - `updateSchedule(start, end, force: true, applyToVisibleState: false)`
- When `applyToVisibleState` is `false`:
  - do not call `_setSchedule(...)`
  - do not toggle visible loading/error UI state
  - still execute network/cache refresh so widget/schedule data stays fresh

This keeps background refresh behavior while preventing visible week-state mutation.

## Test Coverage
- Added `test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart`:
  - `background range refresh keeps the currently visible week anchored`
  - `midweek background refresh keeps previous weekdays in visible schedule`
  - `visible range updates still replace the current week window`
- Added `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`:
  - `resume-triggered background refresh keeps monday lessons visible`
  - Sends a real `AppLifecycleState.resumed` signal in widget tests and verifies the Monday lesson remains rendered.

## Commands run
```bash
flutter test test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart
flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart
flutter test test/schedule/ui/viewmodels/weekly_schedule_display_range_test.dart
flutter test test/schedule/ui/viewmodels
flutter analyze lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart
flutter run -d <DEVICE_ID> --debug
```
