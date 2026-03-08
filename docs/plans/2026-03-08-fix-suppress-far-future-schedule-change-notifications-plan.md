---
title: fix: suppress far-future schedule change notifications
type: fix
date: 2026-03-08
issue: 37
---

# fix: suppress far-future schedule change notifications

## 🐛 Overview

Users currently receive schedule-change notifications for classes that are far beyond the near-term planning window, including classes months in the future. This plan limits schedule-change notifications to near-term class changes while preserving broader schedule refresh, cache hydration, calendar sync, and Rapla event loading.

## Problem Statement / Motivation

- Reported in `#37`: users can get notifications for newly added or changed classes that are more than two weeks away.
- This creates noisy, low-value alerts and makes schedule-change notifications feel unreliable.
- The shared schedule cache is refreshed by multiple flows with different date ranges, so a broad refresh can currently trigger notifications even when the changed class is outside the intended horizon.
- The product intent is notification filtering, not data-fetch suppression; far-future schedule data should still load where the app needs it.

## Consolidated Research

### Internal architecture and code paths

- Schedule-change notifications are registered during app initialization in `lib/common/appstart/app_initializer.dart:95` via `lib/common/appstart/notification_schedule_changed_initialize.dart:12`.
- Schedule diffs are emitted from `lib/schedule/business/schedule_provider.dart:136` after comparing the refreshed window against cached entries.
- Notification rendering lives in `lib/schedule/ui/notification/schedule_changed_notification.dart:17` and currently has no date-window filter.
- The regular background schedule updater refreshes only the near-term range (`today` to `today + 14 days`) in `lib/schedule/background/background_schedule_update.dart:31`.
- Other valid refresh paths are broader and still feed the same notification callback:
  - calendar sync/settings path refreshes `now .. now + 30 days` in `lib/schedule/background/calendar_synchronizer.dart:47` and `lib/ui/settings/viewmodels/settings_view_model.dart:73`
  - Date Management / Rapla can refresh 3-month windows starting from today in `lib/date_management/ui/viewmodels/date_management_view_model.dart:528`
- `ScheduleProvider._cleanDiffFromNewlyQueriedEntries(...)` only filters newly added entries against previously queried windows in `lib/schedule/business/schedule_provider.dart:175`; it does not enforce a current-date notification horizon.
- The existing notification regression suite in `test/common/appstart/notification_schedule_changed_initialize_test.dart:21` verifies callback wiring and awaited dispatch, but not future-window suppression.

### Institutional learnings applied

- Shared background refresh paths must not leak side effects into unrelated user-visible behavior; previous schedule fixes kept refresh semantics while narrowing the visible/UI impact: `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:21`.
- Background notification setup should stay resilient and isolated from startup failures; fixes in this area preserved behavior by narrowing policy rather than broadening initialization risk: `docs/solutions/performance/integration-startup-background-init-hardening-20260227.md:23`.
- Notification infrastructure recently moved toward explicit, user-meaningful behavior and narrow permission-triggered flows, so this bug fix should stay policy-local and avoid changing unrelated scheduling/setup behavior: `docs/solutions/performance/s21-notification-permission-startup-unblock-20260302.md:16`.

### Research decision

External research is skipped for this planning pass. This is a repo-local bug with strong internal patterns, clear existing notification infrastructure, and relevant recent docs about background refresh and notification behavior.

## ✨ Proposed Solution

Filter schedule-change notifications to entries whose relevant class date falls within a near-term notification horizon, while leaving schedule fetching, cache persistence, calendar sync, and Rapla pagination unchanged.

1. Apply the rule globally to all schedule-change notifications, regardless of which refresh path produced the diff.
2. Define the notification horizon as the device-local calendar date range from today through `today + 14 days`, inclusive.
3. Filter diff entries before existing notification batching/count suppression so far-future items cannot crowd out valid near-term alerts.
4. Keep the filter scoped to notification policy rather than `ScheduleProvider` fetch/storage behavior.
5. Add regression tests covering broader refresh windows, mixed batches, and day-14/day-15 boundaries.

## Technical Considerations

- **Scope:** the fix should affect added, removed, and updated class notifications consistently.
- **Boundary semantics:** use local-device date semantics to avoid unexpected UTC-only behavior in normal app usage.
- **Updated entries:** `UpdatedEntry` only exposes the new/current entry in `lib/schedule/business/schedule_diff_calculator.dart:184`, so the most practical default is to evaluate updated notifications by the new/current scheduled start date.
- **Layering:** keep filtering in `lib/schedule/ui/notification/schedule_changed_notification.dart` or adjacent notification policy code, not in generic diff generation.
- **Regression safety:** broad refresh paths must still update cache/calendar/Rapla state for dates beyond two weeks; only notifications are suppressed.
- **Android-first validation:** per project guidance, final verification should prioritize Android behavior.

## SpecFlow Gaps + Defaults

- **Gap:** Does the 2-week rule apply only to background refresh, or all schedule-change notifications?  
  **Default:** apply it globally to all schedule-change notifications.
- **Gap:** Is day 14 included?  
  **Default:** yes; notify for entries from today through day 14 inclusive, suppress day 15 and later.
- **Gap:** Which date determines eligibility for updated classes?  
  **Default:** use the updated entry's current/new start date.
- **Gap:** Should far-future items count toward the `>4` suppression threshold?  
  **Default:** no; filter first, then apply existing count rules.
- **Gap:** Should manual browsing or refreshing a far-future week bypass suppression?  
  **Default:** no; users still should not get push notifications for >14-day schedule changes.

## ✅ Acceptance Criteria

- [ ] A schedule diff for an added class whose start date is more than 14 days after the current local date does not show a schedule-change notification.
- [ ] A schedule diff for a removed class whose original start date is more than 14 days after the current local date does not show a schedule-change notification.
- [ ] A schedule diff for an updated class whose new/current start date is more than 14 days after the current local date does not show a schedule-change notification.
- [ ] Classes scheduled from today through day 14 inclusive still notify normally when schedule-change notifications are enabled.
- [ ] Mixed diffs containing both in-horizon and out-of-horizon changes notify only for the in-horizon entries.
- [ ] Far-future entries are filtered before the existing per-category `>4` suppression logic is applied.
- [ ] Broader refresh paths (`30`-day calendar sync/settings refresh and `3`-month Rapla/date-management refresh) still update data but do not emit notifications for >14-day schedule changes.
- [ ] Manually viewing or refreshing a far-future schedule range does not trigger notifications for >14-day entries.
- [ ] Existing behavior when schedule-change notifications are disabled remains unchanged.
- [ ] Automated regression tests for issue `#37` are added and pass.

## Success Metrics

- Repro steps from `#37` are no longer reproducible.
- Users receive schedule-change notifications only for near-term classes with immediate planning value.
- New regression tests fail on the old behavior and pass with the fix.
- No regressions are observed in schedule cache refresh, calendar sync, or Rapla event loading.

## Dependencies & Risks

- **Risk:** implementing the cutoff too low in the stack could accidentally suppress legitimate cache or sync behavior.  
  **Mitigation:** keep the change at notification-policy level.
- **Risk:** off-by-one boundary bugs around midnight/day 14 could produce confusing behavior.  
  **Mitigation:** add explicit day-14/day-15 tests with fixed times.
- **Risk:** mixed batches could still lose near-term alerts if filtering happens after count suppression.  
  **Mitigation:** filter first, then apply the existing threshold logic.
- **Risk:** updated-entry semantics may be surprising if a class moves across the boundary.  
  **Mitigation:** document and test the chosen rule using the updated/current class date.

## MVP Flow Sketch

```dart
// lib/schedule/ui/notification/schedule_changed_notification.dart (pseudo)
final cutoffEnd = toStartOfDay(DateTime.now()).add(const Duration(days: 14));
final filteredDiff = scheduleDiff.filterEntriesWithinNotificationWindow(cutoffEnd);

await showEntriesAddedNotifications(filteredDiff, localization);
await showEntriesRemovedNotifications(filteredDiff, localization);
await showEntriesChangedNotifications(filteredDiff, localization);
```

```dart
// test/common/appstart/notification_schedule_changed_initialize_test.dart (pseudo)
test('far-future added entry does not notify', () async {
  await scheduleProvider.emitScheduleChanged(diffWithAddedEntry(daysFromNow: 30));
  expect(notificationApi.titles, isEmpty);
});
```

## 📋 Implementation Checklist (draft)

- [ ] Add failing regression tests for far-future added, removed, and updated schedule changes in `test/common/appstart/notification_schedule_changed_initialize_test.dart`.
- [ ] Add boundary tests for day 14 vs day 15 notification eligibility in `test/common/appstart/notification_schedule_changed_initialize_test.dart` or `test/schedule/ui/notification/schedule_changed_notification_test.dart`.
- [ ] Add a mixed-batch regression test proving out-of-horizon entries do not suppress valid in-horizon notifications.
- [ ] Implement notification-horizon filtering in `lib/schedule/ui/notification/schedule_changed_notification.dart`.
- [ ] Keep `lib/common/appstart/notification_schedule_changed_initialize.dart` focused on preference gating/callback wiring unless a tiny helper extraction improves readability.
- [ ] Re-run existing related notification tests, especially `test/schedule/ui/notification/next_day_information_notification_test.dart` and settings notification permission tests.
- [ ] Record the final fix in `docs/solutions/` after implementation.

## Test Plan

### Automated

- Add test: far-future added class does not notify (`test/common/appstart/notification_schedule_changed_initialize_test.dart`).
- Add test: far-future removed class does not notify (`test/common/appstart/notification_schedule_changed_initialize_test.dart`).
- Add test: far-future updated class does not notify (`test/common/appstart/notification_schedule_changed_initialize_test.dart`).
- Add test: day-14 entry notifies, day-15 entry does not (`test/common/appstart/notification_schedule_changed_initialize_test.dart`).
- Add test: mixed near-term + far-future diff only emits near-term notifications (`test/common/appstart/notification_schedule_changed_initialize_test.dart`).
- Re-run related suites:
  - `test/common/appstart/notification_schedule_changed_initialize_test.dart`
  - `test/schedule/ui/notification/next_day_information_notification_test.dart`
  - `test/ui/settings/viewmodels/settings_view_model_notification_permission_test.dart`

### Manual Android verification

- Enable schedule-change notifications, trigger a refresh containing only far-future changes, and confirm no local notification appears.
- Trigger a refresh containing both near-term and far-future changes, and confirm only near-term notifications appear.
- Open Date Management / Rapla and load later windows; confirm the app can load data without emitting far-future class notifications.
- Enable calendar sync/settings flows that refresh `30` days; confirm data updates still work without far-future notification noise.

## AI-Era Implementation Notes

- Keep the fix narrow to issue `#37`; avoid redesigning schedule refresh architecture.
- Follow TDD per project guidance: write the failing notification-window tests first.
- Require human review of date-boundary semantics, because notification policy bugs are easy to overfit to a single repro.

## References & Research

### Related issue

- `#37`

### Internal references

- `lib/common/appstart/app_initializer.dart:95`
- `lib/common/appstart/notification_schedule_changed_initialize.dart:12`
- `lib/schedule/business/schedule_provider.dart:136`
- `lib/schedule/business/schedule_provider.dart:175`
- `lib/schedule/ui/notification/schedule_changed_notification.dart:17`
- `lib/schedule/background/background_schedule_update.dart:31`
- `lib/schedule/background/calendar_synchronizer.dart:47`
- `lib/date_management/ui/viewmodels/date_management_view_model.dart:528`
- `lib/schedule/business/schedule_diff_calculator.dart:184`
- `test/common/appstart/notification_schedule_changed_initialize_test.dart:21`
- `docs/rapla-cache-refresh-behavior.md:56`

### Institutional learnings

- `docs/solutions/ui-bugs/monday-lessons-missing-after-background-resume-20260210.md:21`
- `docs/solutions/performance/integration-startup-background-init-hardening-20260227.md:23`
- `docs/solutions/performance/s21-notification-permission-startup-unblock-20260302.md:16`
