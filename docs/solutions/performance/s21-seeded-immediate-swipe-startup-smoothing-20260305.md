---
title: Smooth seeded cold start and immediate schedule swipes on S21
date: 2026-03-05
---

# Summary

Seeded cold starts on Galaxy S21 still showed startup jank and dropped frames
when opening the app and swiping the schedule immediately after splash.

This pass removes avoidable startup/main-thread work in the first interaction
window and removes eager week prefetch work from weekly page build paths.

# Changes

- `lib/common/data/preferences/preferences_access.dart`
  - introduced lazy cached `SharedPreferences` instance reuse.
  - avoids repeated `SharedPreferences.getInstance()` platform round-trips on
    each get/set operation.

- `lib/ui/root_page.dart`
  - startup now defers `saveLastStartLanguage()` as best-effort async work
    instead of awaiting it before first interactive frame.
  - keeps language persistence behavior while unblocking cold-start interaction.
  - performance overlay preference load no longer triggers startup `setState`
    rebuilds.

- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart`
  - removed eager adjacent-week prefetch from pager initialization.
  - removed build-triggered prefetch for uncached pages.
  - removed on-page-changed prefetch during active pager movement.
  - prefetch now happens after visible week commit, not during first paint/
    drag path.
  - disabled implicit page prebuild (`allowImplicitScrolling: false`) to avoid
    extra startup/snap-swipe rendering work.

- tests
  - `test/common/data/preferences/preferences_access_test.dart`
    - verifies preferences access reuses one shared prefs instance.
    - verifies concurrent reads still initialize prefs only once.
  - `test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart`
    - adds coverage that weekly page does not prefetch adjacent weeks before
      user interaction.

# Device verification (S21)

- Device: `RFCR31468LJ`
- Method: force-stop app, launch to seeded `main` route, then execute immediate
  horizontal swipes across schedule area.
- Seeded state: `IsFirstStart=false`, iCal source configured, launch dialogs
  disabled in shared prefs for clean interaction probe.

Final profile capture:
- Log: `s21_seeded_immediate_swipe_final_profile.log`
  - route: `Navigating to: main`
  - startup timings:
    - `Root init: base 1ms`
    - `Root init: save language deferred 1ms`
    - `Root init: allow first frame 1ms`
    - `Root init: prefs 6ms`
  - `Choreographer Skipped ...` lines: none
- Gfxinfo: `s21_seeded_immediate_swipe_final_profile_gfxinfo.txt`
  - `90th percentile: 61ms`
  - `95th percentile: 61ms`
  - `99th percentile: 61ms`

Repeated seeded profile probe (5 runs):
- Logs:
  - `s21_seeded_immediate_swipe_profile_run1.log`
  - `s21_seeded_immediate_swipe_profile_run2.log`
  - `s21_seeded_immediate_swipe_profile_run3.log`
  - `s21_seeded_immediate_swipe_profile_run4.log`
  - `s21_seeded_immediate_swipe_profile_run5.log`
- All runs navigated to `main` and showed no `Choreographer: Skipped ...`
  entries.
- Root startup in all 5 runs:
  - `Root init: base 1ms`
  - `Root init: save language deferred 1ms`
  - `Root init: prefs 6-7ms`
- Gfxinfo percentiles across runs:
  - p90: `17-42ms`
  - p95: `17-42ms`
  - p99: `17-42ms`

Historical seeded baseline for reference:
- `s21_seeded_start_logcat.txt`
  - `Root init: base 237ms`
  - `Root init: save language 412ms`
  - `Skipped 58 frames`
  - `Skipped 50 frames`

# Validation

- `flutter analyze lib/common/data/preferences/preferences_access.dart lib/ui/root_page.dart lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart test/common/data/preferences/preferences_access_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart`
- `flutter test test/common/data/preferences/preferences_access_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart test/common/appstart/app_initializer_startup_policy_test.dart`
- `flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart test/common/appstart/app_initializer_startup_policy_test.dart`
- `flutter test integration_test/performance_smoke_test.dart -d RFCR31468LJ`
- `flutter test integration_test/drawer_switch_responsiveness_test.dart -d RFCR31468LJ`
