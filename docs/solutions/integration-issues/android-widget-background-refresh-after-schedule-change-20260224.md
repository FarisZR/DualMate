---
title: fix: stabilize android widget refresh after background schedule updates
date: 2026-02-24
category: integration-issues
---

## Summary
Background schedule updates could complete while widget refresh calls failed in a background isolate context. This could leave Android widgets stale even when schedule data and notifications were already updated.

## Root Cause
- Widget channel handling was tied to foreground activity setup.
- Background callback isolates may run in a different engine lifecycle where widget channel registration is not guaranteed.
- The refresh path treated some platform/channel failures as fatal in update flows.

## Changes
- Moved widget channel handler to engine-attached plugin implementation in `AndroidScheduleTodayWidget` (`FlutterPlugin` + `MethodCallHandler`).
- Removed activity-bound widget channel setup from `MainActivity`.
- Added plugin registrant initialization in background task callback dispatcher:
  - `WidgetsFlutterBinding.ensureInitialized()`
  - `DartPluginRegistrant.ensureInitialized()`
- Added explicit, non-fatal widget refresh call in `BackgroundScheduleUpdate` after successful schedule persistence.
- Hardened Android widget helper refresh call to swallow generic channel/plugin exceptions in addition to `PlatformException`.

## Validation
Automated tests added:
- `test/schedule/background/background_schedule_update_widget_refresh_test.dart`
- `test/native/widget/android_widget_helper_background_error_test.dart`
- `test/schedule/business/schedule_provider_callback_ordering_test.dart`

All tests pass in CI-local run:
- targeted new tests
- full test suite

## Notes
This fix keeps schedule persistence and notifications independent from widget refresh side effects and prevents background task failure on widget channel issues.
