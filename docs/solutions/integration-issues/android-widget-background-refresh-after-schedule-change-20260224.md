---
title: fix: stabilize android widget refresh after background schedule updates
date: 2026-02-24
category: integration-issues
---

## Summary

Background schedule updates could complete while widget refresh calls failed in a background isolate context. This could leave Android widgets stale even when schedule data and notifications were already updated.

## Root Cause

- Widget channel handling was tied to foreground activity setup.
- Background callback isolates run in a headless engine where manual `MainActivity` plugin wiring is not applied.
- This left the widget channel unavailable in some background runs even when schedule-change notifications were delivered.

## Changes

- Added a local plugin dependency `dualmate_widget_bridge` and implemented `DualmateWidgetBridgePlugin` as the channel handler for `com.fariszr.dualmate/widget`.
- Removed activity-bound widget channel setup from `MainActivity`.
- Removed the vendored `workmanager_android` fork and switched back to the standard `workmanager` package path.
- Kept background callback initialization with:
  - `WidgetsFlutterBinding.ensureInitialized()`
  - `DartPluginRegistrant.ensureInitialized()`
- Added explicit, non-fatal widget refresh call in `BackgroundScheduleUpdate` after successful schedule persistence.
- Hardened Android widget helper refresh call to swallow generic channel/plugin exceptions in addition to `PlatformException`.
- Implemented provider broadcast refresh in the plugin (`ACTION_APPWIDGET_UPDATE`) for schedule/canteen widget providers.

## Validation

Automated tests added:
- `test/schedule/background/background_schedule_update_widget_refresh_test.dart`
- `test/native/widget/android_widget_helper_background_error_test.dart`
- `test/schedule/business/schedule_provider_callback_ordering_test.dart`

Verification run:
- targeted Flutter tests for widget/background callback flows
- Android debug APK build (`flutter build apk --debug`) to validate plugin wiring/compilation

## Notes

This fix keeps schedule persistence and notifications independent from widget refresh side effects and prevents background task failure on widget channel issues.
