---
module: Schedule UI
date: 2026-02-09
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Changing schedule filters does not update the weekly calendar immediately"
  - "Filtered lessons disappear only after swiping weeks or switching pages"
root_cause: refresh_gate
resolution_type: code_fix
severity: medium
tags: [schedule, filter, refresh, weekly-calendar, flutter]
---

# Troubleshooting: Schedule filters not applied immediately in weekly calendar

## Problem
After changing lesson visibility in the filter screen, the weekly calendar did not refresh in place. Users had to trigger another interaction (like swiping to another week) before filtered entries were reflected.

## Environment
- Module: Schedule UI
- Rails Version: N/A (Flutter)
- Affected Component: Weekly schedule refresh flow
- Date: 2026-02-09

## Symptoms
- Filter toggles are saved, but the current weekly view still shows now-hidden lessons.
- Manual navigation then shows the expected filtered result.

## Root Cause
The weekly view refresh path used throttling intended for repeated same-range requests. Filter-triggered source-change refreshes could be treated like normal repeated requests and skipped before re-reading cached (filtered) entries.

## Solution
- Added a `force` override to `ScheduleUpdateRequestGate.shouldAllow(...)`.
- Updated `WeeklyScheduleViewModel.updateSchedule(...)` to pass the `force` flag into the gate.
- Updated schedule-source-change handling in `WeeklyScheduleViewModel` to call `updateSchedule(..., force: true)`.
- Made filter apply flow awaitable and awaited it in `WillPopScope` to ensure filter persistence and refresh are triggered in order.

## Test Coverage
- Added a regression test in `test/schedule/ui/viewmodels/schedule_update_request_gate_test.dart`:
  - `allows same range within interval when forced`

This verifies forced refresh requests bypass throttle protection, which is required for immediate refresh after filter changes.

## Commands run
```bash
flutter test test/schedule/ui/viewmodels/schedule_update_request_gate_test.dart
```

## Why This Works
Filter changes should always trigger a refresh of the currently visible week, even if that week was just requested moments before. The forced path preserves normal throttling for regular traffic while guaranteeing a deterministic immediate refresh for filter/source-change events.
