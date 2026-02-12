---
title: Reduce canteen launch-window jank by deferring startup refresh pressure
date: 2026-02-12
---

# Summary

This change set targets canteen jank observed immediately after app launch. The main fix is separating canteen refresh from startup-heavy initialization, then shifting canteen loading to cache-first visible-week orchestration with stale-gated refreshes and deduplicated network work.

# Findings

1. Launch path still included canteen refresh pressure near first user interactions.
2. Canteen page entry eagerly loaded current/next/previous weeks.
3. Same-week refreshes could overlap without dedupe.
4. Integration smoke flow was unstable when startup dialogs blocked gestures.

# Changes

## Startup orchestration

- Split startup heavy flow in `app_initializer`:
  - `initializeAppForegroundHeavy()` now executes calendar-sync path only.
  - Added one-time `prewarmCanteenIfStale(...)` for deferred canteen prewarm.
- In `RootPage`, canteen prewarm is scheduled later and dispatched with idle scheduler priority.

## Canteen provider refresh policy

- Added `refreshWeekIfStale(...)` in `CanteenProvider`:
  - per-week in-flight dedupe,
  - stale-window checks (default 2h),
  - optional next-week prefetch toggle.

## Canteen viewmodel/page loading strategy

- `CanteenViewModel`:
  - `primeVisibleWeek(...)`
  - `refreshVisibleWeekIfStale(...)`
  - `prefetchAdjacentWeeksDebounced(...)`
- `CanteenPage`:
  - removed eager 3-week context loading on first frame,
  - uses visible-week prime + stale-gated refresh,
  - uses debounced adjacent cache prefetch.

## Integration test hardening

- Added `integration_test/canteen_startup_responsiveness_test.dart` for immediate post-launch canteen interaction.
- Updated `integration_test/performance_smoke_test.dart`:
  - no localhost Rapla dependency,
  - deterministic startup dialog dismissal.

# Validation

- Unit/widget tests pass:
  - `test/common/appstart/app_initializer_startup_policy_test.dart`
  - `test/canteen/business/canteen_provider_refresh_policy_test.dart`
  - `test/canteen/ui/viewmodels/canteen_startup_loading_policy_test.dart`
  - `test/canteen/ui/viewmodels/canteen_visible_days_test.dart`
  - `test/canteen/ui/canteen_page_bounds_test.dart`
- Android integration tests pass on connected device:
  - `flutter test integration_test/canteen_startup_responsiveness_test.dart -d 59RYD25806200107`
  - `flutter test integration_test/performance_smoke_test.dart -d 59RYD25806200107`
- Runtime logs now show separated phases:
  - `Foreground heavy init: calendar sync ...`
  - `Foreground canteen prewarm: refresh ...`

# Notes

- Exact alarm startup prompt behavior is unchanged in this fix set.
- Canteen prewarm remains stale-gated, so startup does not force a full refresh on every launch.
