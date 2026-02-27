---
title: Guard startup against splash-screen stalls with first-frame fallback
date: 2026-02-27
---

# Summary

Some real-device launches could appear stuck on the splash screen when startup
initialization did not reach the normal `allowFirstFrame` path quickly enough.
This fix adds an explicit first-frame fallback release and error-path guards so
the app always presents UI instead of lingering on splash.

# Findings

1. Startup currently defers first frame in `main.dart`, and relies on root
   initialization to release it later.
2. If root initialization stalls or throws before the release point, first
   frame can remain blocked and look like a splash-screen freeze.
3. A blank placeholder while root VM is null makes this state harder to
   distinguish from a freeze.

# Changes

- Added first-frame fallback timer in `RootPage` (`2s`) that calls
  `WidgetsBinding.instance.allowFirstFrame()` if normal init has not completed.
- Centralized release in `_allowFirstFrame(reason)` with idempotent guard and
  telemetry reason tagging.
- Wrapped startup initialization in `try/catch` to ensure frame release even on
  initialization error paths.
- Added a lightweight loading UI while root model is not yet available.
- Cancel fallback timer in `dispose`.

# Validation

- `flutter analyze lib/ui/root_page.dart lib/main.dart`
- `flutter test test/date_management/ui/date_management_page_test.dart`

# Notes

- This is a defensive startup hardening change and does not alter feature
  behavior after root initialization has completed.
