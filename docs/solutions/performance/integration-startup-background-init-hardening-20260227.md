---
title: Harden deferred background init for integration-test startup runs
date: 2026-02-27
---

# Summary

After removing first-frame deferral from startup, integration tests started
surfacing an uncaught deferred-init failure from background scheduler
registration (`NotRegisteredKiwiError`).

# Findings

1. `RootPage` now schedules deferred startup work on idle priority, so test
   runs execute `initializeAppBackground(false)` more reliably.
2. `BackgroundInitialize().setupBackgroundScheduling()` was called without
   `await`, so async dependency resolution failures escaped the surrounding
   `try/catch` and failed the test process.
3. Running an APK built via `flutter test integration_test/...` directly can
   appear splash-stuck/ANR because it is test-harness-targeted, not a normal
   manual-run APK.

# Changes

- `lib/common/appstart/app_initializer.dart`
  - awaited `BackgroundInitialize().setupBackgroundScheduling()` inside guarded
    `try/catch`.
  - kept startup resilient by swallowing non-critical scheduler setup failures
    and continuing app initialization.
  - wrapped notification-schedule setup in guarded `try/catch` for symmetry and
    to avoid deferred-init crashes.

# Validation

- `flutter test integration_test/performance_smoke_test.dart -d RFCR31468LJ`
- `flutter test integration_test/canteen_startup_responsiveness_test.dart -d RFCR31468LJ`
- `flutter test test/canteen/ui/canteen_page_bounds_test.dart`
- `flutter analyze lib/common/appstart/app_initializer.dart`

# Device checks (S21+)

- Device: `RFCR31468LJ`
- Built and installed a normal debug APK (`flutter build apk --debug`) before
  manual ADB startup checks.
- Repeated cold launches reached app UI (`am start -W` returned `Status: ok`).
- Verified schedule/canteen route switching and swipe interactions by ADB
  intents/gestures, with app staying responsive.
