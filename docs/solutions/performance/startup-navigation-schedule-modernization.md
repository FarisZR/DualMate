---
title: Startup, Navigation, and Schedule Performance Modernization
date: 2026-02-11
---

# Summary

This change set targets frame drops and startup interactivity issues by reducing
main-thread work during launch, avoiding large rebuilds during section/page
switches, and lowering schedule swipe refresh pressure.

# Key Improvements

## Startup

- Deferred heavy foreground work further after first usable UI.
- Kept background initialization asynchronous and non-blocking for first
  interactions.
- Updated notification initialization to request runtime permission on Android
  13+.

## Navigation and Page Switching

- Replaced nested route-shell handoff logic in `MainPage` with an `IndexedStack`
  section architecture.
- Added `MainSectionController` so launch/widget route intents can switch
  sections without waiting for nested navigator readiness.
- Removed page switch throttling and `AnimatedSwitcher` full subtree swaps in
  `PagerWidget`; switched to cached `IndexedStack` pages to preserve state and
  reduce rebuild jank.

## Schedule

- Reduced expensive schedule widget rendering overhead:
  - lower-cost entry card composition,
  - per-day entry bucketing to avoid repeated `schedule.trim` calls per column.
- Replaced heavier shared-axis page transition with simpler fade+slide in the
  weekly page.
- Added in-memory week cache and adjacent-week warming.
- Added short visible-range update debounce to prevent immediate network refresh
  bursts during rapid week swipes while preserving freshness.
- Changed week navigation updates to cache-first immediate visual updates with
  background refresh follow-up.

## Canteen

- Made next-week prefetch fire-and-forget to prevent blocking current-week
  refresh completion.
- Reduced repeated widget-payload work in `build()` and removed extra
  post-frame page jump churn.

## Dependency/Platform Updates

- Updated direct dependencies to newest resolvable versions on current
  Flutter/Dart toolchain:
  - `http` 1.6.0
  - `property_change_notifier` 0.5.0
  - `http_client_helper` 3.0.0
  - `flutter_local_notifications` 18.0.1
  - `flutter_secure_storage` 10.0.0
  - `animations` 2.1.1
- Raised Android `targetSdkVersion` to 36.
- Added `integration_test` for device-level startup/schedule/canteen interaction
  regression coverage.

# Validation

- Unit/widget test suites pass, including schedule lifecycle/background refresh
  and canteen bounds tests.
- Added device integration smoke test:
  - `integration_test/performance_smoke_test.dart`
  - covers launch, schedule interactions, drawer navigation, and canteen paging.
- Integration smoke test validated with real Rapla source URL:
  `https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=eisenbiegler&file=TINF25B4`.

# Remaining Observations

- Cold profile launch can still show a large skipped-frame spike on first install
  path (notably when onboarding + DB migration + secure-storage migration happen
  together). This is now a narrower first-run path and is less representative of
  warmed daily usage.
- `integration_test` reports an Android NDK version recommendation
  (`28.2.13676358`), but local SDK copy for that version is malformed on this
  machine, so project remains buildable on current installed NDK.
