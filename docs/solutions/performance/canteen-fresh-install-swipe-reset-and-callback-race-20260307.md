---
title: Stop canteen fresh-install swipe resets and callback races
date: 2026-03-07
---

# Summary

This follow-up fixes a fresh-install canteen regression where early background
updates could replay the swipe animation, snap interaction back toward the first
page, and sometimes throw a `Concurrent modification during iteration` error in
`CanteenProvider`.

# Findings

1. `CanteenProvider._notifyCallbacks(...)` iterated the live callback list.
   When a listener detached during a foreground prewarm refresh, the provider
   could throw and abort the background update path.
2. `CanteenPage._syncPageForVisibleDays(...)` could call `jumpToPage(...)`
   while the pager was still scrolling or while `AnimatedSwitcher` temporarily
   attached multiple `PageView`s to the same controller.
3. Those index-correction jumps are useful after the pager settles, but they are
   disruptive during active gestures and can replay the swipe animation.
4. A remaining first-open edge still let page sync trust the base-date fallback
   even after the pager had already moved to the next visible day, so a rebuild
   could still anchor the first swipe back to day one.
5. Another remaining edge existed before `onPageChanged`: any fractional pager
   offset still counted as the committed page, so a rebuild could correct the
   controller back to the old page while the first swipe was mid-flight.
6. The per-day canteen body also reused the same subtree identity across day
   changes, so the day-level `AnimatedSwitcher` could briefly animate the
   previous day over the newly swiped day.

# Changes

- `lib/canteen/business/canteen_provider.dart`
  - iterate over a snapshot of registered callbacks during notification.
- `lib/canteen/ui/canteen_page.dart`
  - defer page-index correction until the pager is stable.
  - avoid syncing while no clients are attached, while multiple `PageView`
    positions are attached, or while the pager is actively scrolling.
  - retry the deferred sync after the transition settles instead of snapping the
    controller immediately.
  - when the first sync still only has the base-date fallback, prefer the active
    pager page over that fallback so the first successful swipe stays anchored
    to the user-visible day.
  - treat any fractional or otherwise uncommitted pager offset as pending and
    defer page correction until the swipe fully commits.
  - give each canteen day page a stable date key so the body transition cannot
    replay the previous day overlay after the first swipe.
- `test/canteen/business/canteen_provider_refresh_policy_test.dart`
  - added regression coverage for listeners removing callbacks mid-notify.
- `test/canteen/ui/canteen_page_bounds_test.dart`
  - added coverage for the pager-sync deferral policy.
  - added coverage for preserving the active page over the stale first-day
    fallback during first-open sync.
  - added coverage that any non-committed pager offset blocks corrective sync.
  - added coverage that day-page keys stay stable per date.

# Validation

- `flutter test test/canteen/business/canteen_provider_refresh_policy_test.dart test/canteen/ui/canteen_page_bounds_test.dart`
- `flutter test test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart`
- `flutter analyze lib/canteen/business/canteen_provider.dart lib/canteen/ui/canteen_page.dart test/canteen/business/canteen_provider_refresh_policy_test.dart test/canteen/ui/canteen_page_bounds_test.dart`

# Notes

- The fix is aimed at the first-install race between foreground canteen entry,
  deferred prewarm work, and pager stabilization.
