---
module: Schedule
date: 2026-02-24
problem_type: integration_issue
component: android_widget_background_refresh
symptoms:
  - "Schedule-change notifications were shown while Android widgets stayed stale until app open"
  - "Background schedule update path depended on Activity-bound widget channel wiring"
  - "Background channel failures could surface as non-PlatformException and break task flow"
root_cause: activity_bound_widget_channel_with_background_exception_gap
severity: high
tags: [android-widget, background-task, workmanager, method-channel]
---

# Fix: Android Widget Refresh After Background Schedule Updates

## Problem
Background schedule updates (WorkManager) could persist new lesson data and trigger schedule-change notifications, while widgets remained stale until app foreground.

## Root Cause
1. The widget method channel handler was set up from `MainActivity.configureFlutterEngine`, coupling channel availability to an Activity lifecycle path.
2. Dart-side Android widget helper only swallowed `PlatformException`; background/plugin edge cases can throw broader exceptions (for example missing channel/plugin wiring contexts).
3. Widget refresh in background relied on callback side effects and lacked an explicit background-safe refresh step.

## Solution Implemented

### 1) Engine-attached Android widget bridge
- Converted the widget channel handler to an engine plugin (`FlutterPlugin`) in:
  - `android/app/src/main/kotlin/com/fariszr/dualmate/flutter/AndroidScheduleTodayWidget.kt`
- Updated `MainActivity` to register the plugin through `flutterEngine.plugins.add(...)` instead of invoking an Activity-bound setup helper.

### 2) Background-safe refresh abstraction
- Added:
  - `lib/native/widget/background_widget_refresher.dart`
- Registered in DI:
  - `lib/common/appstart/service_injector.dart`
- Explicitly invoked from background schedule task after successful refresh:
  - `lib/schedule/background/background_schedule_update.dart`
  - constructor wiring updated in `lib/common/appstart/background_initialize.dart`

### 3) Non-fatal channel error handling
- Broadened Android helper error handling to swallow generic exceptions for widget bridge calls:
  - `lib/native/widget/android_widget_helper.dart`

### 4) Headless isolate plugin registrant initialization
- Ensured background callback dispatcher initializes Dart plugin registrant before executing WorkManager tasks:
  - `lib/common/background/background_work_scheduler.dart`

## Tests Added
- `test/schedule/background/background_schedule_update_widget_refresh_test.dart`
  - verifies successful background update triggers widget refresh
  - verifies invalid source path skips refresh
  - verifies schedule query failures do not trigger widget refresh
- `test/native/widget/android_widget_helper_background_error_test.dart`
  - verifies helper swallows `MissingPluginException`/generic errors safely
- `test/schedule/business/schedule_provider_callback_ordering_test.dart`
  - verifies schedule change callback order remains stable (`changed` before `updated`)

## Verification
- Targeted tests executed: **7 passed, 0 failed**.
- Android app launched on connected device and logs verified for startup/update path without new runtime exceptions during normal foreground flow.

## Follow-up
- WorkManager headless engine plugin registration behavior is implementation-dependent in current plugin/runtime combinations. If any OEM/device still reports stale widgets in fully headless runs, add a dedicated headless plugin registration hook or migrate the widget bridge to a separately registered Flutter plugin package.
