---
module: Schedule UI
date: 2026-02-25
problem_type: ui_bug
component: frontend_flutter
symptoms:
  - "Current time in weekly calendar is hard to identify"
  - "Current-time cue is mostly perceived as background shade"
  - "No explicit current-time line in the visible schedule grid"
root_cause: missing_explicit_now_indicator
resolution_type: code_fix
severity: medium
tags: [schedule, weekly-calendar, ui, material3, accessibility]
---

# Troubleshooting: Current-time indicator is unclear in weekly calendar

## Problem

Weekly calendar used only the past-time shading overlay as the visual cue for now. This made the current time hard to locate, especially in sparse schedules or when shading blended with lesson blocks.

## Root Cause

- `ScheduleWidget` rendered `SchedulePastOverlay` but had no explicit "now" line.
- Existing `colorCurrentTimeIndicator(...)` token was available but only used in daily-list indicator UI.
- Without a dedicated overlay line, users had to infer the current time from broad background tint.

## Solution

- Added a dedicated weekly overlay widget:
  - `lib/schedule/ui/weeklyschedule/widgets/schedule_current_time_indicator.dart`
- Wired it into `ScheduleWidget` with minute-precise vertical positioning:
  - `lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart`
- Indicator behavior:
  - show only for the today column
  - show only when now is within `displayStartHour <= now < displayEndHour`
  - hide when now is outside visible hours
  - ignore hit testing so lesson taps are not blocked
- Updated current-time indicator color token to use Material 3 theme role (`onSurface` with alpha):
  - `lib/common/ui/colors.dart`

## Test Coverage

- Added `test/schedule/ui/weeklyschedule/schedule_current_time_indicator_test.dart`:
  - `shows weekly current-time indicator when now is in range`
  - `hides weekly current-time indicator before visible hours`
  - `hides weekly current-time indicator after visible hours`
  - `weekly current-time indicator does not block entry taps`

## Verification Commands

```bash
flutter test test/schedule/ui/weeklyschedule/schedule_current_time_indicator_test.dart
flutter test test/schedule/ui/weeklyschedule/schedule_widget_layout_profile_test.dart test/schedule/ui/weeklyschedule/weekly_schedule_page_lifecycle_test.dart test/schedule/ui/viewmodels/weekly_schedule_background_refresh_test.dart
flutter test test/schedule/ui/weeklyschedule/weekly_schedule_page_swipe_test.dart
flutter analyze lib/schedule/ui/weeklyschedule/widgets/schedule_widget.dart lib/schedule/ui/weeklyschedule/widgets/schedule_current_time_indicator.dart lib/common/ui/colors.dart test/schedule/ui/weeklyschedule/schedule_current_time_indicator_test.dart
```

## Notes

- Analyzer output includes an existing informational deprecation notice for `useMaterial3` in `lib/common/ui/colors.dart` that predates this fix and does not block the feature behavior.
