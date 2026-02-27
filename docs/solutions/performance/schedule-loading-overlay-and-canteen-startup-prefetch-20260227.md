---
title: Keep schedule loading state accurate and reduce canteen startup prefetch work
date: 2026-02-27
---

# Summary

This follow-up reduces visible loading state glitches in weekly schedule refresh
and trims canteen startup work by avoiding extra adjacent network prefetch during
first render.

# Findings

1. Weekly schedule refresh could leave `isUpdating` active longer than expected
   on some async paths, which kept loading UI visible.
2. Canteen entry still scheduled adjacent week prefetch immediately on page
   entry, adding unnecessary startup work.
3. Adjacent prefetch used network refresh for next week even when only cache
   warming was needed.

# Changes

## Weekly schedule loading state and overlay

- Added `scheduleLoadingLatest` localization for loading overlay text.
- Added a Material 3 styled loading overlay in `WeeklySchedulePage` when the
  visible week is empty and a refresh is active.
- Updated `WeeklyScheduleViewModel` refresh flow so visible loading state stays
  true while the active request is in flight and is cleared via request-id aware
  completion handling.
- Increased visible refresh debounce to 420ms to reduce rapid swipe-triggered
  request churn.

## Canteen startup prefetch behavior

- Removed immediate adjacent prefetch trigger on canteen page entry.
- Updated `prefetchAdjacentWeeksDebounced(...)` to warm adjacent weeks from
  cache only during debounce, avoiding startup network refresh for the next
  week.

# Validation

- `flutter test test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
