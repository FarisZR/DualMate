---
title: Android widgets miss resize refresh and canteen duplicates first item
date: 2026-01-27
problem_type: ui_bug
module: Android widgets (Schedule/Canteen)
component: AppWidgetProvider + RemoteViewsFactory
severity: medium
symptoms:
  - Widget resize did not reveal additional rows until next periodic refresh
  - Canteen widget sometimes showed the first meal twice before the second
root_cause: Missing onAppWidgetOptionsChanged triggering data reload; no deduplication of identical meal rows
tags: [android, appwidget, resize, remoteviews, canteen, duplication, ui]
---

## Context
Android home-screen widgets (Schedule Today/Now and Canteen) were not updating visible rows on resize. The canteen widget occasionally duplicated the first meal entry. Issue surfaced while extending schedule visibility to 14 days and tightening layout spacing.

## Investigation
- Reviewed `CanteenTodayWidget`, `ScheduleTodayWidget`, `ScheduleNowWidget`: none override `onAppWidgetOptionsChanged`, so height changes never triggered `notifyAppWidgetViewDataChanged`.
- Confirmed `MultiDayViewsFactory` already recalculates visible rows based on current widget height during data change events; missing resize hook was the blocker.
- Traced canteen rendering: `CanteenEntryViewsFactory` groups meals per date from `CanteenProvider` ordered by date/category/name; no deduplication, so duplicate rows in data rendered twice.
- Verified layout spacing in `widget_day_row.xml` constrained horizontal space for meals, motivating padding/text adjustments.

## Solution
- Added `onAppWidgetOptionsChanged` in all providers to refresh list views on resize:
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenTodayWidget.kt`
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/today/ScheduleTodayWidget.kt`
  - `android/app/src/main/kotlin/com/fariszr/dualmate/widget/now/ScheduleNowWidget.kt`
- Kept full data loading and trimming by size; expanded window to 14 days in `MultiDayWidgetHelper.WEEK_WINDOW_DAYS`.
- Introduced deterministic deduplication before grouping canteen entries: `CanteenEntryViewsFactory.deduplicateEntries` (key: date, normalized category/name, price) and reused in `loadItemsForWeek`.
- UI spacing tweaks for better content fit:
  - Reduced padding and date column size/text in `android/app/src/main/res/layout/widget_day_row.xml` (date text 16sp, column 48dp, lighter padding).
  - Tightened canteen item margins/padding in `android/app/src/main/res/layout/widget_canteen_day_item.xml`.
  - Added small top/bottom padding to schedule list views in `widget_schedule_today.xml` and `widget_schedule_now.xml`.

## Code References
- Resize hooks: `CanteenTodayWidget.kt`, `ScheduleTodayWidget.kt`, `ScheduleNowWidget.kt` (added `onAppWidgetOptionsChanged` → `notifyAppWidgetViewDataChanged`).
- Data window + visibility: `MultiDayWidgetHelper.kt` (`WEEK_WINDOW_DAYS = 14`).
- Dedup: `CanteenEntryViewsFactory.kt` (`deduplicateEntries`, used in `loadItemsForWeek`).
- Layout spacing: `widget_day_row.xml`, `widget_canteen_day_item.xml`, `widget_schedule_today.xml`, `widget_schedule_now.xml`.

## Verification
- Automated: `flutter test` (pass) including updated 14-day window test and new canteen dedup test.
- Manual (recommended): `flutter run -d <device-id>`; resize widgets and confirm additional rows appear immediately; canteen widget shows unique meals without duplicated first item.

## Prevention
- Always implement `onAppWidgetOptionsChanged` for list-based widgets and trigger `notifyAppWidgetViewDataChanged` per `appWidgetId` on resize/orientation changes.
- Deduplicate RemoteViews data when upstream sources can repeat rows; normalize keys (trim/lowercase) and keep stable ordering.
- Add regression tests for data windows and dedup keys when changing window sizes (e.g., 7 → 14 days).
- When adjusting layout to fit more content, reduce padding and font sizes before trimming text; re-run visual checks on real devices after changes.

## Related
- Plan: `docs/plans/2026-01-27-fix-android-widget-resize-and-canteen-duplication-plan.md`
