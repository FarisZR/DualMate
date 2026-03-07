---
title: Polish schedule loading indicator behavior and stabilize canteen bounds test on S21
date: 2026-02-27
---

# Summary

Follow-up polish pass after real-device feedback from Galaxy S21+ focused on:

1. removing redundant loading UI in weekly schedule,
2. reducing unnecessary loading-line flicker,
3. aligning loading indicator colors with Material 3 app theme,
4. smoothing canteen loading/content transitions, and
5. fixing memory-heavy test behavior in canteen page bounds tests.

# Changes

## Weekly schedule loading UI

- Removed the full-screen empty-week loading prompt from
  `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`.
- Kept a single top loading line, now with delayed visibility (`220ms`) so very
  short refreshes do not flash the indicator.
- Added `_TopLoadingIndicator` stateful widget to manage delayed show/hide.

## Material 3 loading colors

- Set global progress indicator colors in `lib/common/ui/colors.dart` using
  `ProgressIndicatorThemeData` and app palette shades for indicator + track.
- This removes the previous harsh contrast and keeps loading bars visually
  consistent with Material 3 theming across app surfaces.

## Canteen transition smoothness

- Unified canteen day-state transitions in
  `lib/canteen/ui/canteen_page.dart` with a single `AnimatedSwitcher` transition
  builder (fade + subtle vertical motion) for loading/empty/ready states.
- Reduced list cache extent to avoid unnecessary memory pressure during page
  switches.

## Test stability and memory

- Updated `test/canteen/ui/canteen_page_bounds_test.dart` to use bounded pump
  windows via `_pumpFor(...)` instead of repeated `pumpAndSettle()`.
- This avoids long-running settle loops that can accumulate memory on-device.
- Updated schedule lifecycle test expectation to the delayed top loading line in
  `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`.

# Validation

- `flutter test test/canteen/ui/canteen_page_bounds_test.dart`
- `flutter test test/canteen/ui/canteen_page_bounds_test.dart -d RFCR31468LJ`
- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart`
- `flutter run -d RFCR31468LJ --no-resident`
