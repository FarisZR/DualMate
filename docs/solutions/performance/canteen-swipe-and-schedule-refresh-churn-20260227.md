---
title: Reduce canteen swipe churn and schedule refresh overfetch
date: 2026-02-27
---

# Summary

This change set reduces avoidable main-isolate work during fast interactions by
throttling canteen week refresh requests, caching computed visible canteen days,
and tightening weekly schedule stale-window behavior for already-fetched ranges.

# Findings

1. Canteen day swipes triggered repeated same-week refresh requests.
2. `CanteenViewModel.loadWeek(...)` re-read SQLite for already loaded weeks.
3. `visibleContentDays` was rebuilt from all loaded menus on each read.
4. Weekly schedule stale checks could still overfetch when revisiting windows,
   because the global freshness gate was OR-ed with per-window freshness.

# Changes

## Canteen refresh/request throttling

- Added same-week refresh request throttling in
  `CanteenViewModel.refreshVisibleWeekIfStale(...)`.
- Added center-week dedupe in `prefetchAdjacentWeeksDebounced(...)` so
  adjacent prefetching is not rescheduled repeatedly for the same week.
- In `CanteenPage`, visible-week stale refresh is now requested only when the
  user crosses into a different week.

## Canteen viewmodel cache pressure reduction

- `loadWeek(...)` now avoids unconditional DB reads when a week is already in
  memory and no forced reload is needed.
- Added cached `visibleContentDays` computation with invalidation on menu
  updates to reduce rebuild-time work.

## Weekly schedule stale-window behavior

- In `WeeklyScheduleViewModel._doUpdateSchedule(...)`, stale evaluation now
  respects per-window freshness gating instead of forcing refetch due the
  global last-range gate.

# Validation

- `flutter test test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart --no-pub`
- `flutter test test/canteen/ui/canteen_page_bounds_test.dart test/canteen/ui/viewmodels/canteen_visible_days_test.dart test/schedule/ui/viewmodels --no-pub`

# Notes

- Device-level jank logs still show startup spikes in debug mode.
- Interaction paths are now less chatty in canteen and have tighter stale-range
  behavior for schedule revisit flows.
