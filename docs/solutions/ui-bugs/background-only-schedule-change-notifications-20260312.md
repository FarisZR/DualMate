---
title: Make schedule change notifications background-only
date: 2026-03-12
category: ui-bugs
---

# Summary

Schedule-change notifications could still fire while the user was actively
browsing the schedule or while other foreground refresh paths reused the shared
schedule refresh pipeline.

This fix keeps notifications limited to unattended background schedule refreshes
and suppresses delivery when the app is currently attended.

# Changes

- `lib/schedule/business/schedule_provider.dart`
  - adds explicit `ScheduleRefreshOrigin` tagging for schedule refreshes.
  - limits changed-callback delivery to `backgroundPeriodic` refreshes while
    keeping updated callbacks and cache persistence unchanged.

- `lib/common/appstart/app_visibility_tracker.dart`
  - adds a tiny app-attended state holder for notification gating.

- `lib/common/appstart/service_injector.dart`
  - registers `AppVisibilityTracker` with a foreground/background-aware initial
    state.

- `lib/common/appstart/notification_schedule_changed_initialize.dart`
  - skips schedule-change notifications when the app is currently attended.

- Refresh callers now declare silent foreground origins:
  - `lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart`
  - `lib/schedule/background/calendar_synchronizer.dart`
  - `lib/ui/settings/viewmodels/settings_view_model.dart`
  - `lib/date_management/business/rapla_important_events_provider.dart`

- `lib/schedule/background/background_schedule_update.dart`
  - marks the periodic background refresh as the only notification-eligible
    schedule refresh path.

- Tests
  - extends notification callback, provider callback ordering, weekly schedule,
    and lifecycle tests to cover silent foreground refreshes and attended-app
    suppression.
  - adds focused tests for calendar sync, settings-triggered refreshes, and
    Rapla refreshes.

- `docs/plans/2026-03-12-fix-background-only-schedule-change-notifications-plan.md`
  - checked off the completed implementation work.

# Why Here

The shared provider remains the single refresh engine, but refresh intent is now
explicit. That keeps cache/diff logic reusable while making notification policy
match Android guidance: notify only when the app is not in use.

# Validation

- `flutter test test/common/appstart/notification_schedule_changed_initialize_test.dart test/schedule/business/schedule_provider_callback_ordering_test.dart test/schedule/background/background_schedule_update_widget_refresh_test.dart test/schedule/background/calendar_synchronizer_test.dart test/ui/settings/viewmodels/settings_view_model_schedule_refresh_test.dart test/date_management/business/rapla_important_events_provider_refresh_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/notification/schedule_changed_notification_test.dart test/ui/settings/viewmodels/settings_view_model_notification_permission_test.dart`
- `flutter analyze lib/common/appstart/app_visibility_tracker.dart lib/common/appstart/service_injector.dart lib/common/appstart/notification_schedule_changed_initialize.dart lib/schedule/business/schedule_provider.dart lib/schedule/background/background_schedule_update.dart lib/schedule/background/calendar_synchronizer.dart lib/date_management/business/rapla_important_events_provider.dart lib/ui/settings/viewmodels/settings_view_model.dart lib/schedule/ui/viewmodels/weekly_schedule_view_model.dart lib/ui/root_page.dart test/common/appstart/notification_schedule_changed_initialize_test.dart test/schedule/business/schedule_provider_callback_ordering_test.dart test/schedule/background/background_schedule_update_widget_refresh_test.dart test/schedule/background/calendar_synchronizer_test.dart test/ui/settings/viewmodels/settings_view_model_schedule_refresh_test.dart test/date_management/business/rapla_important_events_provider_refresh_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart`

# Notes

- Existing 14-day notification-window behavior from the earlier far-future fix
  stays intact.
- No Android device verification was run in this session.
