---
title: Marker events stay in widgets but stop triggering notifications
date: 2026-03-27
problem_type: ui_bug
module: Schedule notifications + Android widget
component: ScheduleChangedNotification, NextDayInformationNotification, ScheduleNowWidget
severity: medium
symptoms:
  - Rapla marker entries like `Klausurwoche` triggered schedule notifications
  - Next-day notifications could announce a marker entry instead of a real class
  - The schedule widget rendered marker entries like normal classes with subtitle details
root_cause: Marker events were stored as normal schedule entries, but notification and widget surfaces had no marker-specific presentation or suppression rules
tags: [schedule, notifications, widget, rapla, android]
---

## Context

Rapla important events such as exam-week banners, theory-phase start markers,
and public-holiday rows should remain visible in the app and widget, but they
are not actionable lessons.
Treating them like regular classes produced noisy schedule-change notifications,
misleading next-day notifications, and cluttered widget rows.

## Investigation

- Rapla marker entries already existed as normal `ScheduleEntry` rows and were
  intentionally reused by Dates/important-events flows.
- `ScheduleChangedNotification` notified on any near-term diff entry.
- `NextDayInformationNotification` chose the next future schedule entry without
  distinguishing marker rows from real classes.
- `NowScheduleEntryViewsFactory` rendered every schedule row with the same
  title + subtitle layout and chronological ordering.

## Solution

- Added a shared Dart helper at `lib/schedule/model/schedule_marker_event.dart`
  to recognize marker entries by the existing type and title heuristics:
  - `Klausurwoche`
  - `Beginn ... Theoriephase`
  - all `PublicHoliday` schedule entries
- Filtered marker entries out of notification delivery in:
  - `lib/schedule/ui/notification/schedule_changed_notification.dart`
  - `lib/schedule/ui/notification/next_day_information_notification.dart`
- Added widget-side marker handling in:
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/ScheduleWidgetMarkerHelper.kt`
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/NowScheduleEntryViewsFactory.kt`
- Added a compact title-only widget row layout:
  - `android/app/src/main/res/layout/widget_schedule_day_marker_item.xml`
- Marker rows now sort ahead of normal classes inside the widget day column.

## Code References

- Marker detection: `lib/schedule/model/schedule_marker_event.dart`
- Schedule-change notification filtering:
  `lib/schedule/ui/notification/schedule_changed_notification.dart`
- Next-day notification filtering:
  `lib/schedule/ui/notification/next_day_information_notification.dart`
- Widget ordering + rendering:
  `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/ScheduleWidgetMarkerHelper.kt`
  `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/NowScheduleEntryViewsFactory.kt`
  `android/app/src/main/res/layout/widget_schedule_day_marker_item.xml`

## Verification

- `flutter test test/schedule/model/schedule_marker_event_test.dart test/schedule/ui/notification/schedule_changed_notification_test.dart test/schedule/ui/notification/next_day_information_notification_test.dart`
- `flutter analyze lib/schedule/model/schedule_marker_event.dart lib/schedule/ui/notification/schedule_changed_notification.dart lib/schedule/ui/notification/next_day_information_notification.dart test/schedule/model/schedule_marker_event_test.dart test/schedule/ui/notification/schedule_changed_notification_test.dart test/schedule/ui/notification/next_day_information_notification_test.dart`
- `flutter build apk --debug`

## Prevention

- Keep marker-event detection in one helper per runtime where sharing is not
  possible, and keep those rules aligned instead of sprinkling title checks
  through notification or widget code.
- Treat notifications and widget presentation as policy layers; do not remove
  marker entries from shared schedule storage unless product wants to change the
  Dates page behavior too.
- When widgets need special rendering for one schedule subtype, prefer a small
  layout override instead of changing the shared query path.
