---
title: Canteen first-swipe overlay regression
date: 2026-03-07
---

# Summary

The canteen page started showing the previous day over the newly swiped day on
the first swipe after opening the page. This regression was introduced during
the recent canteen interaction smoothing work.

# Cause

- Adjacent-week prefetch was deferred until after initial page open.
- The first same-week swipe therefore became the first moment that mutated the
  canteen page list.
- When `visibleContentDays` changed, the `PageView.builder` still reused page
  children by index unless it could map stable day keys back to their new
  indexes.
- That let an old day body animate over the new one during the first swipe.

# Fix

- `lib/canteen/ui/canteen_page.dart`
  - restore adjacent-week prefetch during initial canteen load instead of making
    the first swipe trigger it.
  - seed `_lastInteractionWeekStart` from the initial base week so the first
    same-week swipe is not treated like a week transition.
  - add `findChildIndexCallback` for the `PageView.builder` using stable per-day
    keys so page children keep their identity when visible days change.

- `test/canteen/ui/canteen_page_bounds_test.dart`
  - cover the stable day-index lookup.
  - cover that adjacent content is ready before the first swipe path.

# Validation

- `flutter test test/canteen/ui/canteen_page_bounds_test.dart test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart test/canteen/business/canteen_provider_refresh_policy_test.dart`
- `flutter analyze lib/canteen/ui/canteen_page.dart test/canteen/ui/canteen_page_bounds_test.dart`

# Device check

- Verified on the connected S21 (`RFCR31468LJ`) with a fresh seeded Rapla setup.
- Captured before/after swipe screenshots under `debugging-files/` while testing
  the first-open canteen flow.
