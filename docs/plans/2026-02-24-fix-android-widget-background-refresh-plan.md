---
title: fix: refresh android widget after background lesson changes
type: fix
date: 2026-02-24
---

# fix: refresh android widget after background lesson changes

## 🐛 Overview
When schedule data changes in background (WorkManager), users can receive a schedule-change notification while Android home widgets still show stale lessons. Widgets only catch up after opening the app, which indicates the refresh path is tied to foreground lifecycle.

## Problem Statement / Motivation
- Reported in `#25`: notifications confirm lesson changes, but widget data remains stale until app open.
- This breaks trust in widgets as a quick source of truth.
- Current architecture likely refreshes widget through an Activity-bound method channel, which is fragile in background execution.

## Consolidated Research
- Background schedule updates run through WorkManager callback isolate and call schedule refresh: `lib/common/background/background_work_scheduler.dart:107`, `lib/schedule/background/background_schedule_update.dart:33`.
- Schedule change notifications are triggered from diff callbacks: `lib/common/appstart/notification_schedule_changed_initialize.dart:14`, `lib/schedule/business/schedule_provider.dart:151`.
- Widget refresh callbacks are triggered after schedule persistence via `_scheduleUpdatedCallbacks`: `lib/schedule/business/schedule_provider.dart:123`, `lib/native/widget/widget_update_callback.dart:24`.
- Flutter-side widget refresh uses method channel `com.fariszr.dualmate/widget`: `lib/native/widget/android_widget_helper.dart:8`.
- Channel handler registration is currently in `MainActivity.configureFlutterEngine(...)`: `android/app/src/main/kotlin/com/fariszr/dualmate/MainActivity.kt:17`, `android/app/src/main/kotlin/com/fariszr/dualmate/flutter/AndroidScheduleTodayWidget.kt:20`.
- Institutional learnings indicate two relevant patterns:
  - Background tasks should isolate non-fatal failures and never crash the task: `docs/solutions/integration-issues/unhandled-background-exception-widget-logic-Schedule-20260124.md:88`.
  - Widget updates should be explicitly triggered on Android provider paths: `docs/solutions/ui-bugs/widget-resize-and-canteen-duplication-20260127.md:25`.

### External docs (2026 check)
- Flutter docs: background isolates can use platform channels only when isolate/registrant setup is correct; plugin/channel handling should be engine-attached, not Activity-coupled.
- Flutter docs: platform channels can be implemented in `FlutterPlugin.onAttachedToEngine(...)`, which works with the engine messenger and supports background task queues.
- `flutter_workmanager` docs: background tasks run in a dedicated isolate/engine context, so plugin registration for that context is required.
- `home_widget` docs: reliable widget updates from Flutter are possible, but migrating would require replacing current custom Android widget bridge and data plumbing.

## Research Decision
External research was added because this bug depends on Flutter background isolate/channel behavior and Workmanager engine lifecycle.

## ✨ Proposed Solution
Use an engine-level Android widget bridge plugin (best option) so the same `MethodChannel` works in both foreground and Workmanager headless background engines.

1. Keep schedule fetch/save/diff flow unchanged.
2. Move widget channel handling from `MainActivity` to an engine-attached plugin (`FlutterPlugin`) and register it for background engines.
3. Treat widget refresh as non-fatal side effect with explicit logging.
4. Keep notification behavior intact and independent.

### Suggested implementation direction
- Keep `WidgetHelper`/`AndroidWidgetHelper` API stable in Dart.
- Replace Activity-bound registration with engine-level plugin registration for `com.fariszr.dualmate/widget`.
- Ensure Workmanager background isolate initializes plugin registrant so the channel exists in headless execution.
- Reuse existing native widget provider refresh functions (`ScheduleTodayWidget.requestWidgetRefresh`, `ScheduleNowWidget.requestWidgetRefresh`, `CanteenTodayWidget.requestWidgetRefresh`).

### Alternatives considered
- **Direct native refresh call from background task code path:** viable but duplicates bridge logic and creates divergent foreground/background behavior.
- **Migrate to `home_widget`:** robust long-term option but larger migration scope than needed for this bug.
- **Chosen:** engine-level plugin bridge as minimal, architecture-aligned, and background-safe.

### Pseudocode (planning only)
```dart
// lib/schedule/background/background_schedule_update.dart
Future<void> updateSchedule() async {
  await scheduleProvider.getUpdatedSchedule(today, end, token);
  await backgroundWidgetRefresher.requestRefreshSafe();
}
```

## Technical Considerations
- **Lifecycle:** Background isolate may execute without `MainActivity`; refresh must still succeed.
- **Plugin wiring:** Channel handler must be attached to every relevant Flutter engine (foreground and Workmanager background engine).
- **Failure isolation:** Widget refresh errors must not roll back successful schedule persistence.
- **Callback semantics:** Notification can be emitted before/independently of widget refresh; this is acceptable only if widget refresh is reliably background-safe.
- **Performance/battery:** Avoid refresh storms from overlapping triggers (periodic + resume + manual).
- **Platform scope:** Android only (per project guide).

## ✅ Acceptance Criteria
- [ ] With app terminated and at least one schedule widget pinned, a background schedule change updates the widget without opening app UI.
- [ ] If a schedule-change notification is shown, widget reflects corresponding lesson changes within 60 seconds.
- [ ] Background refresh works even when no `MainActivity` instance exists in current process lifecycle.
- [ ] Widget refresh channel is available in Workmanager background execution without requiring app UI launch.
- [ ] Widget refresh failures are logged and non-fatal; schedule persistence still succeeds.
- [ ] No duplicate notification spam or duplicate refresh storms from one update cycle.
- [ ] Foreground widget behavior (manual app usage, resume, widget tap navigation) has no regression.
- [ ] If no widgets are pinned, refresh path is a safe no-op.

## Success Metrics
- Repro from issue `#25` is no longer reproducible on Android test devices.
- In manual runs, notification + widget refresh consistency reaches 100% for test scenarios.
- No new background task crashes tied to widget refresh in logs.

## Dependencies & Risks
- **Risk:** Incorrect bridge wiring may break existing foreground refresh.
- **Risk:** Over-broadcasting may increase battery use.
- **Risk:** Device-specific background restrictions (OEM/Doze) may mask failures.
- **Mitigation:** Keep a single refresh abstraction, add structured logs for each stage (fetch, diff, notify, widget refresh), and validate on multiple Android versions.

## 📋 Implementation Checklist (draft)
- [x] Define background-safe refresh abstraction and inject where needed in `lib/common/appstart/service_injector.dart`.
- [x] Update `lib/schedule/background/background_schedule_update.dart` to call the new background-safe refresh path after successful schedule update.
- [x] Move channel handler wiring out of `android/app/src/main/kotlin/com/fariszr/dualmate/MainActivity.kt` into an engine-level Android plugin class under `android/app/src/main/kotlin/com/fariszr/dualmate/flutter/`.
- [x] Ensure Workmanager background isolate/plugin registrant initializes that plugin (headless engine support).
- [x] Update `lib/native/widget/android_widget_helper.dart` exception handling to catch non-`PlatformException` background/plugin failures safely.
- [x] Keep `lib/native/widget/widget_update_callback.dart` behavior intact for foreground paths unless deduping refresh triggers is required.
- [x] Keep Android-side refresh entrypoint provider-based and engine-agnostic under `android/app/src/main/kotlin/com/fariszr/dualmate/widget/...`.
- [x] Verify provider refresh helpers still target all relevant widgets:
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/today/ScheduleTodayWidget.kt`
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/ScheduleNowWidget.kt`
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenTodayWidget.kt` (if shared refresh path remains unified)
- [x] Add/update tests:
  - `test/schedule/background/background_schedule_update_widget_refresh_test.dart`
  - `test/native/widget/android_widget_helper_background_error_test.dart`
  - `test/schedule/business/schedule_provider_callback_ordering_test.dart`
  - `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart` (regression check)
- [x] Add/update solution note after implementation in `docs/solutions/integration-issues/`.

## Test & Verification Plan
### Automated
- Unit tests for background refresh success/failure isolation.
- Unit tests for helper exception handling in background context.
- Regression tests for schedule lifecycle and callback ordering.

### Manual (Android device)
- App killed, widget pinned, wait for background schedule update -> confirm widget updates without app launch.
- App backgrounded (not killed), same scenario.
- Force-stop/open-never-after-boot scenario -> confirm first Workmanager run still refreshes widget.
- Notification disabled scenario -> confirm intended widget behavior still occurs.
- No widgets pinned -> confirm no crash/no-op behavior.
- Boundary checks near midnight and week transition.

## SpecFlow Gaps + Defaults
- **Gap:** Should widget refresh run on every successful fetch or only when diff changes?  
  **Default:** every successful fetch for schedule widgets (safer freshness), then optimize if needed.
- **Gap:** Success SLA for widget after notification?  
  **Default:** 60 seconds.
- **Gap:** If background refresh fails, retry strategy?  
  **Default:** log and rely on next periodic run; do not crash task.

## References & Research
- Related issue: `https://github.com/FarisZR/DualMate/issues/25`
- Background scheduler: `lib/common/background/background_work_scheduler.dart:107`
- Background schedule task: `lib/schedule/background/background_schedule_update.dart:33`
- Schedule callbacks: `lib/schedule/business/schedule_provider.dart:123`
- Notification callback setup: `lib/common/appstart/notification_schedule_changed_initialize.dart:14`
- Widget callback glue: `lib/native/widget/widget_update_callback.dart:24`
- Android widget helper (method channel): `lib/native/widget/android_widget_helper.dart:25`
- MainActivity channel setup: `android/app/src/main/kotlin/com/fariszr/dualmate/MainActivity.kt:17`
- Native widget channel handler: `android/app/src/main/kotlin/com/fariszr/dualmate/flutter/AndroidScheduleTodayWidget.kt:20`
- Flutter platform channels (background isolate + plugin/engine patterns): `https://docs.flutter.dev/platform-integration/platform-channels`
- Flutter isolates + plugin usage in background isolates: `https://docs.flutter.dev/perf/isolates`
- Workmanager plugin docs (dedicated background isolate context): `https://github.com/fluttercommunity/flutter_workmanager/blob/main/README.md`
- Home Widget docs (alternative approach): `https://github.com/abausg/home_widget/blob/main/docs/usage/update-widget.mdx`
- Institutional learnings:
  - `docs/solutions/integration-issues/unhandled-background-exception-widget-logic-Schedule-20260124.md:88`
  - `docs/solutions/ui-bugs/widget-resize-and-canteen-duplication-20260127.md:25`
  - `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:27`