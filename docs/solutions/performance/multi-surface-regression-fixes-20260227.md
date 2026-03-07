---
title: Restore schedule viewport animation, next-week canteen pagination, and dualis row fit
date: 2026-02-27
---

# Summary

Follow-up fixes for regressions introduced during the earlier performance pass:

1. Weekly schedule hour viewport was snapping instead of animating.
2. Canteen page only exposed one visible day because the next week was no
   longer refreshed on startup prefetch.
3. Dualis exam rows could overflow by 3 px on long wrapped exam names.

# Changes

## Weekly schedule viewport transitions

- Restored hour-range interpolation in
  `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart` using a
  `TweenAnimationBuilder<_HourViewport>`.
- Added regression test that asserts a mid-transition axis label position is
  between start and end positions (prevents hard jumps).

## Canteen next-week availability

- Restored startup adjacent-week warmup call in
  `lib/canteen/ui/canteen_page.dart` (`prefetchAdjacentWeeksDebounced`).
- Updated adjacent prefetch policy in
  `lib/canteen/ui/viewmodels/canteen_view_model.dart`:
  - previous week remains cache-only,
  - next week now triggers network-backed `loadWeek(...)` so forward swipes can
    reveal upcoming meals.
- Added/updated regression assertions for startup prefetch behavior.

## Dualis exam row overflow

- Updated exam result table rows in
  `lib/dualis/ui/exam_results_page/exam_results_page.dart` to allow taller
  rows (`dataRowMinHeight` / `dataRowMaxHeight`) and constrained text wrapping.
- Added regression test with a long exam title to assert no overflow exception.

## Screenshot sanity workflow

- Removed invalid black-frame screenshots from
  `docs/screenshots/performance/`.
- Added `docs/scripts/validate_screenshot_content.py` to detect blank/black
  captures before upload.

# Validation

- `flutter analyze lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart lib/canteen/ui/canteen_page.dart lib/canteen/ui/viewmodels/canteen_view_model.dart lib/dualis/ui/exam_results_page/exam_results_page.dart`
- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart`
- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
- `flutter test test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart`
- `flutter test test/canteen/ui/canteen_page_bounds_test.dart`
- `flutter test test/dualis/ui/study_overview_loading_animation_test.dart`
- `python3 docs/scripts/validate_screenshot_content.py`
