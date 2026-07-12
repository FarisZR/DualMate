---
title: Stabilize Canteen rendering for first open and day transitions
date: 2026-07-12
type: fix
---

# Summary

The Canteen page now keeps one pager and one day scrollable mounted while
loading and content state changes. The change targets first-open construction,
day swipes, meal-count transitions, filtering, and drawer-to-Canteen
activation on high-refresh-rate phones without changing the existing animation
durations, skeleton content, paging rules, or performance harness thresholds.

# Findings

1. The page swapped a temporary single-day body for a full `PageView` when
   content days became available.
2. Each day transition animated an outgoing skeleton or old list against an
   incoming full `ListView`, increasing layout and paint work on every frame.
3. The root Canteen consumer rebuilt the header, filter row, pager, and floating
   action button for unrelated state changes.
4. `loadWeek` emitted separate menu, error, and loading notifications, while
   `mealsForDay` repeatedly searched and allocated filtered meal lists during
   builds.

# Changes

## Stable shell and scoped rebuilds

- The Canteen shell mounts a keyed `PageView` from its first frame, including
  the empty/loading fallback day.
- Header, filter, pager, and day content now have separate property consumers.
- The pager consumes one coalesced `weekState` property; individual day
  widgets use selector equality so unchanged day render states do not rebuild.
- Page synchronization defers targets that are outside the pager range being
  mounted during a content-day list update.

## Single-scrollable day transitions

- A day always owns one `ListView`; empty and loading content are list items
  rather than nested scrollables.
- The existing 320 ms fade/slide transition is retained at the item boundary,
  allowing skeleton-to-meal and meal-count changes to progress without two
  full scrollable trees overlapping.
- If cached data becomes ready while Canteen is still offstage, the outgoing
  loading state is retained and the transition starts when `TickerMode` becomes
  active. This prevents the animation from elapsing before the page is visible.
- State keys remain available for loading, ready, and error/empty regression
  checks, and the existing skeleton card layout is unchanged.

## Immutable render snapshots and filtering cache

- `CanteenWeekRenderState` snapshots normalized five-day menus, content days,
  and per-day immutable meal lists once per applied week.
- `CanteenDayContentState` is the exact day/filter selection consumed by the
  day widget.
- Filtered meals are cached by normalized day and `CanteenFilter`; replacing a
  week invalidates only that week's day entries.
- Visible content days are maintained from week snapshots and exposed as one
  immutable sorted list rather than rescanned and reallocated during builds.
- Meaningful loading/content phases publish one `weekState` notification each;
  foreground provider callbacks do not duplicate the final load notification.

# Regression coverage

Added or updated Canteen tests cover:

- stable page-content keys and pager mounting through loading-to-content;
- one PageView plus one day scrollable during the transition;
- no visible stale day after a committed swipe;
- filtered meal results, identity reuse, replacement invalidation, immutable
  weekly menus, and coalesced week-state notifications;
- existing page bounds, overscroll, adjacent prefetch, and page-sync behavior.

# Pixel 8 Pro performance results

Device conditions:

- Pixel 8 Pro in profile mode;
- 120 Hz display;
- Android animation scales at `1.0`;
- deterministic offline fixture data.

The prior Pixel repeat baseline measured drawer-to-Canteen at roughly 25.5% of
frames over 8.33 ms, with a 56.0 ms worst frame. Three optimized runs produced
a 15.0% median, and the final exact-code confirmation measured 14.29% with a
47.3 ms worst frame. The final run also recorded:

- cold loaded day swipe: 7.32% over 8.33 ms, 14.0 ms worst;
- varied meal-content transition: 2.44%, 16.75 ms worst;
- repeated settled interaction: 0%, 6.37 ms worst.

All Canteen final-state and animation-progression checks passed after the
`TickerMode` hardening. The separate existing Dates loading-progression check
remained the only diagnostic warning.

# Validation

- full `flutter analyze`: passed;
- `flutter test test/canteen`: 56 tests passed;
- three-run diagnostic profile on the Pixel 8 Pro;
- final post-hardening diagnostic profile on the Pixel 8 Pro;
- no performance thresholds, fixture data, or integration harness files were
  changed.
