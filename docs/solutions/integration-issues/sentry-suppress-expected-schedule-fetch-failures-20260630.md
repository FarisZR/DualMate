---
module: App
date: 2026-06-30
problem_type: integration_issue
component: sentry_reporting
symptoms:
  - "Sentry Issues flooded with ServiceRequestFailed: Http request failed!"
  - "Sentry Issues flooded with ScheduleQueryFailedException for expected network outages"
  - "Expected external schedule/canteen/dualis fetch failures escalated to Sentry Issues"
root_cause: expected_network_failures_reported_as_issues
resolution_type: code_fix
severity: medium
tags: [sentry, diagnostics, schedule, canteen, dualis, network, telemetry]
---

# Suppress expected external fetch failures from Sentry Issues

## Problem

Expected external network/request failures from schedule, canteen, and dualis
fetch flows were creating noisy Sentry Issues. These are not app bugs—they
represent transient connectivity loss or source unavailability—but they
consumed Sentry quota and obscured real regressions.

## Solution

### Typed classifier

Added `isExpectedScheduleFetchFailure(Object error)` to
`lib/schedule/service/schedule_source.dart`:

```dart
bool isExpectedScheduleFetchFailure(Object error) {
  if (error is ServiceRequestFailed) return true;
  if (error is ScheduleQueryFailedException) {
    return error.innerException is ServiceRequestFailed;
  }
  return false;
}
```

Classifies failures by typed exception hierarchy, not message strings.

### Schedule refresh paths

- `WeeklyScheduleViewModel._refreshScheduleInBackground` and
  `_joinInFlightScheduleRefresh`: skip `reportException` when
  `isExpectedScheduleFetchFailure(e)` is true, but still set telemetry status
  and `updateFailed`.
- `_readScheduleFromService`: propagates exceptions instead of swallowing all
  `ScheduleQueryFailedException` into `null`.
- `BackgroundScheduleUpdate.updateSchedule`: guards its
  `reportCaughtException` call.
- `ErrorReportScheduleSourceDecorator`: rethrows all
  `ScheduleQueryFailedException` without reporting (callers own the decision).

### Canteen paths

- `CanteenScraper._makeRequest` and `DhbwAppCanteenSource`: now throw typed
  `ServiceRequestFailed` instead of generic `Exception` for HTTP failures.
- `BackgroundCanteenUpdate.updateCanteen`: guards its
  `reportCaughtException` call with `isExpectedScheduleFetchFailure`.
- `RootPage._runCanteenPrewarm`: guards its canteen prewarm report.

### Dualis paths

- `StudyGradesViewModel` (`loadStudyGrades`, `loadAllModules`,
  `loadSemesterByName`, `loadSemesterNamesForCurrentSelection`): swallow
  expected network failures via `isExpectedScheduleFetchFailure` so they
  don't propagate as unhandled async exceptions. Unexpected errors still
  rethrow.
- `DualisLoginViewModel.testCredentials`: guards `reportException` call.
- `MannheimViewModel.loadCourses`: guards `reportException` call.

### Global error handler

- `main.dart` `FlutterError.onError`: guards `reportException` with
  `isExpectedScheduleFetchFailure` so unhandled expected network failures
  don't create Sentry Issues.

## What still goes to Sentry

- Parse exceptions (`ElementNotFoundParseException`, HTML/ICS structure
  regressions) via `ScheduleProvider.getUpdatedSchedule` error forwarding.
- Non-network `ScheduleQueryFailedException` (e.g. wrapping `StateError`).
- Database/cache/state errors, null errors, lifecycle errors.
- Any unexpected exception in any feature path.

## What is suppressed (telemetry only)

- `ServiceRequestFailed` (HTTP request failures) from any feature.
- `ScheduleQueryFailedException` where `innerException is ServiceRequestFailed`.

These still update UI failure state, mark telemetry tasks, and allow retry.

## Privacy

No changes to `sentry_scrubber.dart`. Existing scrubbing fully preserved.

## Verification

- `test/schedule/ui/viewmodels/weekly_schedule_sentry_suppression_test.dart`
  (12 tests)
- `test/canteen/background/background_canteen_update_sentry_suppression_test.dart`
  (2 tests)
- `test/canteen/service/dhbw_app_canteen_source_test.dart` (added
  ServiceRequestFailed type assertion)
- `test/dualis/ui/viewmodels/study_grades_view_model_test.dart` (added 4
  swallow/rethrow tests)
- Full suite: 329 tests pass.
