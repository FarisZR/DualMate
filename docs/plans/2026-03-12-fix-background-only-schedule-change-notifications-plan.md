---
title: fix: make schedule change notifications background-only
type: fix
date: 2026-03-12
issue: 47
related_issues:
  - 37
---

# fix: make schedule change notifications background-only

## 🐛 Overview

Schedule-change notifications still fire when users browse future weeks or when other foreground refresh paths reuse the shared schedule refresh pipeline. This plan restricts notifications to unattended background schedule refreshes while keeping the existing 14-day notification window, cache updates, calendar sync, and Rapla loading intact.

## Problem Statement / Motivation

- Reported in `#47`: notifications should only happen in the background when something changes and the user did not open the app to discover it themselves.
- The recent fix for `#37` already suppresses far-future notifications, but it does not distinguish background refreshes from foreground, user-driven refreshes.
- `ScheduleProvider.getUpdatedSchedule(...)` is currently a shared refresh engine for weekly browsing, resume refresh, settings/calendar sync, Rapla loading, and the true background scheduler, so any of those flows can still trigger notifications.
- This makes notifications feel noisy and redundant precisely when the user is already checking schedule data.

## Consolidated Research

### Internal architecture and code paths

- Notification wiring is still global: `lib/common/appstart/app_initializer.dart:95` registers schedule-change notifications through `lib/common/appstart/notification_schedule_changed_initialize.dart:12`.
- The shared diff pipeline lives in `lib/schedule/business/schedule_provider.dart:88`; diffs are emitted in `lib/schedule/business/schedule_provider.dart:136` and changed callbacks run before updated callbacks in `lib/schedule/business/schedule_provider.dart:149`.
- The notification policy already filters to today through day 14 in `lib/schedule/ui/notification/schedule_changed_notification.dart:37`; the remaining bug is refresh-origin eligibility, not date-window filtering.
- Foreground schedule browsing can reach the same provider path through `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:288`, `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:309`, and `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:564`.
- Resume currently triggers a silent-visible-state refresh, but not a silent-notification refresh, from `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart:69` and `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:199`.
- Foreground maintenance flows also reuse the same provider path:
  - `lib/schedule/background/calendar_synchronizer.dart:47`
  - `lib/ui/settings/viewmodels/settings_view_model.dart:66`
  - `lib/date_management/business/rapla_important_events_provider.dart:32`
- The true unattended background path is `lib/schedule/background/background_schedule_update.dart:25`.
- Current tests cover notification-window behavior and callback ordering, but they do not yet cover caller eligibility for `#47`:
  - `test/common/appstart/notification_schedule_changed_initialize_test.dart:21`
  - `test/schedule/ui/notification/schedule_changed_notification_test.dart:1`
  - `test/schedule/business/schedule_provider_callback_ordering_test.dart:16`
  - `test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart:14`
  - `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart:46`

### Institutional learnings applied

- Keep shared refresh behavior, but narrow side effects at the boundary that causes the user-visible problem; that was the winning pattern for background-resume schedule bugs in `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:22`.
- Keep notification policy local and minimal rather than redesigning cache/diff layers; that was the right fix shape for the earlier schedule-notification bug in `docs/solutions/ui-bugs/far-future-schedule-change-notifications-20260308.md:42`.
- Startup notification wiring should stay resilient and guarded; avoid broadening init risk while fixing notification behavior in `docs/solutions/performance/integration-startup-background-init-hardening-20260227.md:25`.
- Notification permission and notification behavior are now intentionally user-initiated and narrow in scope, so this follow-up should keep the same restraint in `docs/solutions/performance/s21-notification-permission-startup-unblock-20260302.md:13`.
- Shared Rapla/schedule refreshes are expected to keep updating cached data in the background, so this fix must not suppress cache refresh itself: `docs/rapla-cache-refresh-behavior.md:56`.

### External best-practice guidance

- Android's notification design guidance is explicit: notifications should be brief, timely, relevant, and used when the app is not in use. That directly validates the product goal behind `#47`: `https://developer.android.com/design/ui/mobile/guides/home-screen/notifications`.
- WorkManager remains the recommended Android API for persistent unattended background work, so the existing background schedule updater is the correct architectural place for notification-eligible refreshes: `https://developer.android.com/develop/background-work/background-tasks/persistent`.
- Flutter lifecycle docs distinguish `resumed`, `inactive`, `hidden`, and `paused`, and warn not to treat lifecycle delivery as perfectly complete. That supports using lifecycle as a safety guard, but not as the only rule: `https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html` and `https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html`.
- Modern Flutter architecture guidance favors passing explicit intent/origin through shared data layers rather than inferring behavior from side effects later. That aligns with tagging refreshes by origin before deciding whether they may notify: `https://docs.flutter.dev/app-architecture/recommendations`.

### Research decision

External research confirmed the repo-local direction and sharpened it: the modern best-practice shape is origin-based notification eligibility with an app-visibility safety check, while keeping WorkManager as the only unattended notification path.

## ✨ Proposed Solution

Adopt the modern best-practice pattern for shared refresh engines: pass explicit refresh origin into the provider path, allow notifications only for unattended background work, and add a final app-visibility guard before posting a system notification.

1. Add a small `ScheduleRefreshOrigin`-style option to `lib/schedule/business/schedule_provider.dart` so each refresh declares why it is running.
2. Derive notification eligibility from that origin, with only the WorkManager-backed path in `lib/schedule/background/background_schedule_update.dart` marked as notification-eligible.
3. Pass foreground/user-attended origins from weekly browsing, resume refresh, calendar sync, settings-triggered sync, and Rapla/date-management refreshes so those paths stay silent.
4. Add a tiny app-visibility tracker so notification delivery does one final "app not in use" check before posting, even if a background refresh began first.
5. Keep `lib/schedule/ui/notification/schedule_changed_notification.dart` responsible for the existing today..day-14 filtering and message rendering, not refresh-origin decisions.

## Technical Considerations

- **Best-practice control point:** because `NotificationScheduleChangedInitialize` is the only current registration site for `addScheduleEntryChangedCallback(...)`, the cleanest place to carry refresh intent is the provider boundary rather than a deeper diff/cache layer.
- **Preserve shared refresh engine:** `ScheduleProvider.getUpdatedSchedule(...)` should still diff, save, update cache, and fire updated callbacks for all callers.
- **Origin first, lifecycle second:** refresh origin should be the primary rule; lifecycle state is a safety guard because Flutter warns lifecycle callbacks may not always be delivered perfectly.
- **Silent by default:** any new origin should default to non-notifying unless it is explicitly marked as unattended background work.
- **No awareness-state redesign in MVP:** do not add per-week, per-entry, or per-session "user saw this" storage yet; origin + visibility already matches platform guidance and issue intent.
- **Race safety:** if resume and background work overlap, notification eligibility must travel with the specific refresh invocation, and notification posting should re-check current visibility before delivery.
- **Future extensibility:** if notification trust still needs improvement after this fix, a later follow-up can add lightweight dedupe or "last seen" fingerprints without changing the core refresh API again.

## SpecFlow Gaps + Defaults

- **Gap:** What counts as "background" for this bug?  
  **Default:** only `BackgroundScheduleUpdate` is notification-eligible.
- **Gap:** What does "I didn't open the app" mean in practice?  
  **Default:** use refresh origin as the awareness proxy, then enforce a final visibility guard so any foreground/resume/user-triggered refresh is silent.
- **Gap:** Should resume-triggered `refreshWidgetRangeInBackground()` notify?  
  **Default:** no, because the app is already open and the user is actively returning to it.
- **Gap:** Should calendar sync, settings-triggered refreshes, and Rapla refreshes notify?  
  **Default:** no; they are maintenance/data-loading flows, not unattended discovery flows.
- **Gap:** Should the existing today..day-14 notification horizon change?  
  **Default:** no; keep the current horizon exactly as implemented for `#37`.
- **Gap:** Should the first implementation use a boolean or a richer origin enum?  
  **Default:** use a tiny explicit origin enum now; external guidance favors explicit intent over implicit booleans for shared refresh engines.
- **Gap:** Which lifecycle states count as "app in use" for the final guard?  
  **Default:** suppress while `resumed`, and treat `inactive` as attended enough to suppress as well.

## ✅ Acceptance Criteria

- [x] Only the refresh path in `lib/schedule/background/background_schedule_update.dart` can emit schedule-change notifications.
- [x] Manual week navigation and explicit week opening from `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart` never emit schedule-change notifications.
- [x] Resume-triggered refresh from `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart` stays silent.
- [x] Calendar sync refresh from `lib/schedule/background/calendar_synchronizer.dart` stays silent.
- [x] Settings-triggered 30-day refresh from `lib/ui/settings/viewmodels/settings_view_model.dart` stays silent.
- [x] Rapla/date-management refresh from `lib/date_management/business/rapla_important_events_provider.dart` stays silent.
- [x] Background schedule refreshes still notify for qualifying diffs inside the existing today..day-14 window.
- [x] If the app is visible/attended when notification delivery is about to occur, the notification is skipped even if the refresh started from a background origin.
- [x] Existing user preference gating for schedule-change notifications remains unchanged.
- [x] Cache persistence, query-info saving, widget refreshes, and updated callbacks continue to work for all refresh callers.
- [x] Automated regression tests for issue `#47` are added and pass.

## Success Metrics

- The reproduction from `#47` is no longer possible while browsing future weeks or semesters.
- The existing fix from `#37` still holds: only near-term changes can notify.
- No local notification appears during active app use, app resume, settings-triggered refreshes, or Rapla refreshes.
- A real unattended background refresh still produces a notification for a qualifying near-term schedule change.
- The notification behavior now matches Android guidance that notifications are for when the app is not in use.

## Dependencies & Risks

- **Risk:** one caller is missed and remains notification-eligible.  
  **Mitigation:** make non-background origins silent by default and add one targeted test per caller class.
- **Risk:** lifecycle state alone is flaky or delayed.  
  **Mitigation:** keep origin as the primary rule and use visibility only as a final guard.
- **Risk:** the team overbuilds a persistent awareness model.  
  **Mitigation:** keep MVP scoped to refresh-origin eligibility only.
- **Risk:** resume/background overlap creates inconsistent behavior.  
  **Mitigation:** bind origin to each `getUpdatedSchedule(...)` invocation and re-check current visibility before notification delivery.

## MVP Flow Sketch

```dart
// lib/schedule/business/schedule_provider.dart (pseudo)
Future<ScheduleQueryResult> getUpdatedSchedule(
  DateTime start,
  DateTime end,
  CancellationToken cancellationToken, {
  ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userInitiated,
}) async {
  final diff = await _diffToCache(start, end, schedule);
  if (origin.mayNotify && diff.didSomethingChange()) {
    await _notifyChangedCallbacks(diff);
  }
  await _notifyUpdatedCallbacks(schedule, start, end);
}
```

```dart
// lib/schedule/background/background_schedule_update.dart (pseudo)
await scheduleProvider.getUpdatedSchedule(
  today,
  end,
  cancellationToken,
  origin: ScheduleRefreshOrigin.backgroundPeriodic,
);
```

```dart
// lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart (pseudo)
await scheduleProvider.getUpdatedSchedule(
  start,
  end,
  token,
  origin: ScheduleRefreshOrigin.userBrowsing,
);
```

```dart
// lib/common/appstart/notification_schedule_changed_initialize.dart (pseudo)
if (appVisibilityTracker.isAppAttended) {
  return;
}
await notification.showNotification(scheduleDiff);
```

## 📋 Implementation Checklist (draft)

- [x] Add a failing provider regression test in `test/schedule/business/schedule_provider_callback_ordering_test.dart` proving background origins can emit changed callbacks while attended origins still run updated callbacks silently.
- [x] Extend `test/schedule/background/background_schedule_update_widget_refresh_test.dart` to assert background refresh uses the notification-eligible origin.
- [x] Add or extend weekly schedule tests in `test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart` so foreground week browsing uses a silent/user-browsing origin.
- [x] Add or extend lifecycle coverage in `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart` so resume refresh uses a silent/attended origin.
- [x] Add a new `test/schedule/background/calendar_synchronizer_test.dart` covering silent 30-day sync refreshes.
- [x] Add a new `test/ui/settings/viewmodels/settings_view_model_schedule_refresh_test.dart` or extend an existing settings test to cover silent calendar-sync refreshes.
- [x] Add a new targeted Rapla refresh test in `test/date_management/business/rapla_important_events_provider_test.dart` or a companion test file.
- [x] Add app-visibility tracker coverage proving notification delivery is skipped while the app is attended.
- [x] Re-run existing notification policy tests in `test/common/appstart/notification_schedule_changed_initialize_test.dart` and `test/schedule/ui/notification/schedule_changed_notification_test.dart` to confirm the 14-day horizon still behaves as before.
- [x] Record the shipped fix in `docs/solutions/` after implementation.

## Test Plan

### Automated

- Add test: attended refresh origins skip changed callbacks but still fire updated callbacks (`test/schedule/business/schedule_provider_callback_ordering_test.dart`).
- Add test: `BackgroundScheduleUpdate` passes the notification-eligible origin (`test/schedule/background/background_schedule_update_widget_refresh_test.dart`).
- Add test: weekly visible refresh passes a user-browsing origin (`test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart`).
- Add test: resume-triggered refresh passes a silent/attended origin (`test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`).
- Add test: calendar synchronizer passes silent mode (`test/schedule/background/calendar_synchronizer_test.dart`).
- Add test: settings calendar-sync refresh passes silent mode (`test/ui/settings/viewmodels/settings_view_model_schedule_refresh_test.dart`).
- Add test: Rapla refresh passes silent mode (`test/date_management/business/rapla_important_events_provider_test.dart` or companion file).
- Add test: notification callback skips delivery when the app is attended (`test/common/appstart/notification_schedule_changed_initialize_test.dart` or a new companion test file).
- Re-run related suites:
  - `test/common/appstart/notification_schedule_changed_initialize_test.dart`
  - `test/schedule/ui/notification/schedule_changed_notification_test.dart`
  - `test/schedule/business/schedule_provider_callback_ordering_test.dart`
  - `test/schedule/background/background_schedule_update_widget_refresh_test.dart`

### Manual Android verification

- Enable schedule-change notifications, open the app, browse several future weeks, and confirm no schedule-change notification appears from those foreground refreshes.
- Background the app, trigger or wait for a qualifying near-term background schedule change, and confirm one notification still appears.
- Reopen the app and confirm the resume-triggered refresh does not emit a notification.
- Enable calendar sync in settings and confirm the 30-day refresh updates data without showing a schedule-change notification.
- Open Date Management and load additional Rapla windows; confirm data refresh continues without notifications.

## AI-Era Implementation Notes

- Keep the fix narrow to issue `#47`; do not redesign schedule awareness or session-state tracking unless a follow-up bug demands it.
- Follow repo guidance and write the failing tests first before changing the provider signature or call sites.
- Prefer one explicit origin on the shared provider API over scattered ad hoc notification guards.
- Require human review of the final behavior on Android because notification timing bugs are easy to misjudge from unit tests alone.

## References & Research

### Related issues

- `#47`
- `#37`

### Internal references

- `lib/common/appstart/app_initializer.dart:95`
- `lib/common/appstart/notification_schedule_changed_initialize.dart:12`
- `lib/schedule/business/schedule_provider.dart:88`
- `lib/schedule/business/schedule_provider.dart:136`
- `lib/schedule/business/schedule_provider.dart:149`
- `lib/schedule/ui/notification/schedule_changed_notification.dart:37`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:199`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:288`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:309`
- `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart:564`
- `lib/schedule/ui/weeklyschedule/weekly_schedule_page.dart:69`
- `lib/schedule/background/background_schedule_update.dart:25`
- `lib/schedule/background/calendar_synchronizer.dart:47`
- `lib/ui/settings/viewmodels/settings_view_model.dart:66`
- `lib/date_management/business/rapla_important_events_provider.dart:32`
- `test/common/appstart/notification_schedule_changed_initialize_test.dart:21`
- `test/schedule/business/schedule_provider_callback_ordering_test.dart:16`
- `test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart:14`
- `test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart:46`
- `docs/rapla-cache-refresh-behavior.md:56`

### Institutional learnings

- `docs/solutions/ui-bugs/far-future-schedule-change-notifications-20260308.md:42`
- `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:22`
- `docs/solutions/performance/integration-startup-background-init-hardening-20260227.md:25`
- `docs/solutions/performance/s21-notification-permission-startup-unblock-20260302.md:13`

### External references

- `https://developer.android.com/design/ui/mobile/guides/home-screen/notifications`
- `https://developer.android.com/develop/background-work/background-tasks/persistent`
- `https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html`
- `https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html`
- `https://docs.flutter.dev/app-architecture/recommendations`
