---
title: Smooth canteen first load, filter transitions, and heavy-page drawer opens on S21
date: 2026-03-06
---

# Summary

This pass targeted three remaining Galaxy S21+ interaction hitches:

1. canteen first-load animation stutter,
2. dropped frames when opening or applying schedule filters over a busy week,
3. drawer hitching on heavy pages like Dates and Canteen.

# Findings

1. `CanteenPage` still combined current-week loading with early adjacent-week prefetch,
   implicit page prebuilds, and large list cache extents during first open.
2. Schedule filter open/apply still did avoidable work on the animation path:
   - a fixed `320ms` initialization delay,
   - a slide transition over the heavy weekly schedule,
   - delete-then-insert persistence,
   - schedule invalidation before the filter page finished closing.
3. Drawer open still rebuilt `MainPage` state on every open/close toggle, and
   Dates kept a large list cache extent active while the drawer animated.

# Changes

- `lib/canteen/ui/canteen_page.dart`
  - delayed initial adjacent-week prefetch until after first-load settle.
  - disabled `PageView.allowImplicitScrolling`.
  - reduced meal-list cache extent.
  - cached header date formatters.
- `lib/canteen/ui/widgets/meal_card.dart`
  - cached locale price formatters.
- `lib/schedule/ui/schedule_navigation_entry.dart`
  - changed filter route transition from slide to fade.
  - reused preload work for the pushed filter page.
  - deferred schedule invalidation until after the filter route returned.
- `lib/schedule/ui/weeklyschedule/filter/schedule_filter_page.dart`
  - removed the fixed startup delay.
  - awaited preload work directly and returned whether filters actually changed.
- `lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart`
  - parallelized filter-state reads.
  - skipped persistence when hidden names were unchanged.
- `lib/schedule/data/schedule_filter_repository.dart`
  - batched hidden-name inserts.
- `lib/ui/main_page.dart`
  - replaced drawer-open `setState` churn with a `ValueNotifier<bool>` scoped to
    the phone body ticker/repaint wrapper.
- `lib/date_management/ui/date_management_page.dart`
  - reduced important-events list cache extent.

# Validation

- Focused tests:
  - `flutter test test/canteen/ui/canteen_page_bounds_test.dart`
  - `flutter test test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart`
  - `flutter test test/schedule/ui/weeklyschedule/filter/filter_view_model_cache_test.dart`
  - `flutter test test/schedule/data/schedule_filter_repository_test.dart`
  - `flutter test test/date_management/ui/date_management_page_test.dart`
- Analyze:
  - `flutter analyze lib/canteen/ui/canteen_page.dart lib/canteen/ui/widgets/meal_card.dart lib/schedule/data/schedule_filter_repository.dart lib/schedule/data/schedule_entry_repository.dart lib/schedule/ui/weeklyschedule/filter/filter_view_model.dart lib/schedule/ui/weeklyschedule/filter/schedule_filter_page.dart lib/schedule/ui/schedule_navigation_entry.dart lib/ui/main_page.dart lib/date_management/ui/date_management_page.dart`
- Real device verification on `RFCR31468LJ`:
  - opened Schedule with a populated week,
  - opened and applied filters,
  - opened Canteen from the drawer,
  - opened Dates and then the drawer,
  - reopened the drawer over heavy content pages.
- Device integration tests on `RFCR31468LJ`:
  - `flutter test integration_test/canteen_startup_responsiveness_test.dart -d RFCR31468LJ`
  - `flutter test integration_test/date_management_startup_responsiveness_test.dart -d RFCR31468LJ`
  - `flutter test integration_test/drawer_switch_responsiveness_test.dart -d RFCR31468LJ`

# Notes

- Existing integration tests still log a known Kiwi background-scheduling setup
  warning in test mode, but the device tests above completed successfully.
