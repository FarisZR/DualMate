---
title: Suppress far-future schedule change notifications
date: 2026-03-08
category: ui-bugs
---

# Summary

Schedule-change notifications could fire for classes far beyond the near-term
planning window because every schedule diff used the same notification path,
even when the refresh came from 30-day calendar sync or 3-month Rapla loads.

# Changes

- `lib/schedule/ui/notification/schedule_changed_notification.dart`
  - filters added, removed, and updated entries to a local-device window from
    today through day 14 inclusive before any notification batching logic runs.
  - keeps broad cache refresh behavior intact; only notification policy changes.
  - allows injecting the current time in tests for stable boundary coverage.

- `test/schedule/ui/notification/schedule_changed_notification_test.dart`
  - verifies day-14 inclusion, day-15 exclusion, removed/updated far-future
    suppression, and mixed-batch filtering before count limits.

- `test/common/appstart/notification_schedule_changed_initialize_test.dart`
  - adds regression coverage that the initialized callback path suppresses a
    far-future schedule-change diff.

- `integration_test/schedule_change_notification_window_test.dart`
  - verifies on a real Android device that far-future diffs stay silent while
    day-14 diffs still notify through the same runtime code path.

- `docs/plans/2026-03-08-fix-suppress-far-future-schedule-change-notifications-plan.md`
  - records the implementation plan shipped with this fix.

- `AGENTS.md`
  - documents that schedule-change notifications are policy-filtered to the next
    14 days while wider refresh windows still update cached data silently.

# Why Here

The notification horizon belongs in notification policy, not in the generic
schedule diff or cache layers. This keeps Rapla, calendar sync, and broader
refresh windows working while removing low-value notification noise.

# Validation

- `flutter test test/common/appstart/notification_schedule_changed_initialize_test.dart test/schedule/ui/notification/schedule_changed_notification_test.dart test/schedule/ui/notification/next_day_information_notification_test.dart test/ui/settings/viewmodels/settings_view_model_notification_permission_test.dart`
- `flutter test`
- `flutter analyze lib/schedule/ui/notification/schedule_changed_notification.dart test/common/appstart/notification_schedule_changed_initialize_test.dart test/schedule/ui/notification/schedule_changed_notification_test.dart`

# Device verification (Galaxy S21+)

- Device: `RFCR31468LJ`
- Command: `flutter test integration_test/schedule_change_notification_window_test.dart -d RFCR31468LJ`
- Result: passed on device; far-future diff stayed silent and day-14 diff still
  emitted a notification through the runtime notification path.
- Captured fresh device log after the run at
  `debugging-files/s21_schedule_change_notification_window_test.log`.
- Scoped log review found no DualMate runtime crash signatures; the only
  matching app-adjacent warning was Play Store package-stat churn during APK
  replacement (`Finsky ... NameNotFoundException`), which is expected during
  test install/update.

# Notes

- A full `flutter analyze` still reports unrelated pre-existing issues under
  `third_party/path_provider_android/pigeons/messages.dart` because `pigeon`
  tooling types are not available in the current workspace analyze baseline.
  Targeted analyze for the touched notification files is clean.
