---
title: Remove first-frame deferral to prevent S21 splash stalls
date: 2026-02-27
---

# Summary

Galaxy S21+ could intermittently remain on the Android splash screen even after
previous startup hardening. The root cause was startup still relying on a
deferred-first-frame path plus pre-`runApp` async work.

# Findings

1. Cold-launch screenshots showed the Android splash icon still visible after
   multiple seconds.
2. In affected launches, Dart-side startup logs from `RootPage` were absent,
   indicating startup could stall before the app rendered its own first frame.
3. Any async operation before `runApp` (`setPreferredOrientations`) can hold
   the native splash if delayed.

# Changes

- `lib/main.dart`
  - removed `WidgetsBinding.deferFirstFrame()` usage.
  - made startup non-blocking by moving orientation setup to
    `unawaited(PlatformUtil.initializePortraitLandscapeMode())` after `runApp`.
- `lib/ui/root_page.dart`
  - removed first-frame fallback timer and `allowFirstFrame` guard plumbing.
  - kept app-shell loading behavior while `RootViewModel` initializes.
- `docs/solutions/performance/startup-first-frame-fallback-20260227.md`
  - annotated as superseded by this approach.

# Device verification (S21+)

- Device: `RFCR31468LJ`
- Performed 3 cold launches via ADB (`force-stop` + `am start`) and captured
  screenshots each run.
- Verified each launch reached app UI (weekly schedule page) instead of native
  splash.
- Ran direct route/device interaction checks:
  - weekly schedule swipes,
  - canteen route launch via intent action,
  - canteen day swipes,
  - drawer open on schedule and canteen.

# Validation

- `flutter analyze lib/main.dart lib/ui/root_page.dart`
- `flutter test test/date_management/ui/date_management_page_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`
