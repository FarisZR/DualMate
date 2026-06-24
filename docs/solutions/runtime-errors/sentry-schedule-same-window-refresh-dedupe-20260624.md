---
module: Schedule
date: 2026-06-24
problem_type: runtime_error
component: weekly_schedule_refresh
symptoms:
  - "Sentry DUALMATE-H captured a handled SqfliteDatabaseException during startup"
  - "Two schedule.refresh operations for the same date window entered schedule.state.apply within milliseconds"
root_cause: same_window_refresh_race
resolution_type: code_fix
severity: medium
tags: [sentry, schedule, sqlite, refresh, concurrency]
---

# Troubleshooting: Same-window schedule refresh race

## Problem
Startup could launch overlapping forced refreshes for the same weekly schedule
window. Both refreshes fetched the same remote window and then wrote the same
`ScheduleQueryInformation(start, end)` primary key.

## Solution
Deduplicate in-flight weekly schedule refreshes by date window. If another
refresh for the same `(start, end)` window is already running, the duplicate
request now joins that future instead of launching a second remote fetch and
database write. Different visible-week requests still use the existing
cancelable update path.

As a second layer of hardening, `ScheduleQueryInformationRepository` now writes
query metadata with an atomic SQLite replace insert instead of delete-then-insert.

## Verification
Covered with view-model tests for:
- Two concurrent same-window forced refreshes.
- A startup-style visible initial refresh plus another same-window forced refresh.
- Different-window forced refreshes still launching independently.
