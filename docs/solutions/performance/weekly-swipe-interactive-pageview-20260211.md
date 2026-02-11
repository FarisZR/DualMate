# Solution: Interactive Weekly Swipe With PageView Ring

## Problem Symptom
- Weekly schedule swipe behaved like a trigger instead of an interactive drag.
- Users saw little to no movement while dragging, then a sudden snap on release.
- This interaction felt janky and amplified perceived frame drops.

## Root Cause
- `WeeklySchedulePage` used a root `GestureDetector` with distance/velocity thresholds.
- Week changes were committed only after drag end (`previousWeek` / `nextWeek`).
- The calendar itself was not inside a horizontal scrollable page interaction.

## Implemented Fix
1. Replaced threshold gesture handling with a ring-based `PageView` (previous/current/next).
2. Added cache-first week rendering to each page using `WeeklyScheduleViewModel.getCachedWeek(...)`.
3. Added non-blocking warmup API `prefetchWeek(...)` with in-flight dedupe.
4. Re-centered the pager after each settle so only 3 heavy pages stay alive.
5. Removed extra per-week switch animation in favor of direct pager motion.

## Performance Considerations
- Drag-time work is reduced to compositing and page translation.
- Adjacent week data is prefetched from cache to avoid first-drag stalls.
- Each page is wrapped in `RepaintBoundary` to isolate paint costs.
- The existing update/freshness gating logic remains intact.

## Validation
- Added `test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart` covering:
  - drag progress updates before finger release,
  - committed week changes for both swipe and chevron actions.
- Re-ran weekly schedule regression tests successfully.

## Follow-up
- For stricter performance gating, run profile integration tests with frame timing collection on target hardware.
