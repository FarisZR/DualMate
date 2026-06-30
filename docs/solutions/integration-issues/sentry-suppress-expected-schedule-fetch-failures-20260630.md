---
module: Schedule
date: 2026-06-30
problem_type: integration_issue
component: sentry_reporting
symptoms:
  - "Sentry Issues flooded with ServiceRequestFailed: Http request failed!"
  - "Sentry Issues flooded with ScheduleQueryFailedException for expected network outages"
  - "Expected external schedule fetch failures escalated to Sentry Issues"
root_cause: expected_network_failures_reported_as_issues
resolution_type: code_fix
severity: medium
tags: [sentry, diagnostics, schedule, network, telemetry]
---

# Suppress expected schedule fetch failures from Sentry Issues

## Problem

Expected external network/request failures from schedule refresh flows
(`ServiceRequestFailed`, `ScheduleQueryFailedException` wrapping
`ServiceRequestFailed`) were creating noisy Sentry Issues. These are not app
bugs—they represent transient connectivity loss or source unavailability—but
they consumed Sentry quota and obscured real regressions.

`ErrorReportScheduleSourceDecorator` already tried to suppress connectivity
errors by rethrowing `ScheduleQueryFailedException(ServiceRequestFailed)`
without reporting. However, downstream catch blocks (notably
`WeeklyScheduleViewModel._refreshScheduleInBackground`) called
`reportException(e, stack)` on the rethrown exception, undoing the suppression.

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

This classifies failures by typed exception hierarchy—not message strings—so
it remains robust against redacted or localized messages.

### Centralized suppression in refresh paths

- `WeeklyScheduleViewModel._refreshScheduleInBackground` and
  `_joinInFlightScheduleRefresh`: skip `reportException` when
  `isExpectedScheduleFetchFailure(e)` is true, but still set
  `task.setCoarseStatus('network_error')`, call `task.fail(...)`, and set
  `updateFailed = true`.
- `_readScheduleFromService`: no longer swallows
  `ScheduleQueryFailedException` into `null`. Exceptions propagate so the
  catch-all can classify them, update telemetry, and decide reporting.
- `BackgroundScheduleUpdate.updateSchedule`: wraps its
  `reportCaughtException` call in the same `isExpectedScheduleFetchFailure`
  guard.

### Decorator simplification

`ErrorReportScheduleSourceDecorator` now rethrows all
`ScheduleQueryFailedException` variants without reporting. The calling refresh
path owns the Sentry Issue decision. This eliminates double-reporting for
unexpected `ScheduleQueryFailedException` variants.

## What still goes to Sentry

- Parse exceptions (`ElementNotFoundParseException`, HTML/ICS structure
  regressions) via `ScheduleProvider.getUpdatedSchedule` error forwarding.
- Non-network `ScheduleQueryFailedException` (e.g. wrapping `StateError`).
- Database/cache/state errors, null errors, lifecycle errors.
- Any unexpected exception during refresh.

## What is suppressed (telemetry only)

- `ServiceRequestFailed` (HTTP request failures).
- `ScheduleQueryFailedException` where `innerException is ServiceRequestFailed`.

These still:
- Set `updateFailed = true` in the view model.
- Mark the performance task with `network_error` coarse status.
- Fail/finish the telemetry task/span.
- Allow retry on the next refresh cycle (freshness gates not marked fetched).

## Privacy

No changes to `sentry_scrubber.dart`. No raw URLs, schedule titles, rooms,
credentials, or user-identifying values are added to Sentry. Existing
scrubbing behavior is fully preserved.

## Verification

- `test/schedule/ui/viewmodels/weekly_schedule_sentry_suppression_test.dart`
  covers all five required scenarios.
- Full schedule, background, date_management, and logging test suites pass
  (322 tests total).
