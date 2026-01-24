---
module: Schedule
date: 2026-01-24
problem_type: integration_issue
component: background_task
symptoms:
  - "Unhandled Exception: Http request failed for https://rapla..."
  - "Widget showing 'No upcoming events today' when events exist for next week"
  - "App crash during background schedule update"
root_cause: uncaught_exception_in_background_task
severity: medium
tags: [android-widget, background-task, exception-handling, rapla]
---

# Fix: Background Schedule Exception & Widget Data Window

## Problem

1.  **Background Crash**: The `BackgroundScheduleUpdate` task crashed with an unhandled `ScheduleQueryFailedException` when the Rapla API returned an error (e.g., connection failure or 404). This polluted logs and could destabilize the background worker.
2.  **Widget Data**: The Multi-Day Widget displayed "No upcoming events today" on Saturdays, even though events existed on the following Monday.
3.  **Widget Design**: The widget styling (colors, padding) did not match the desired Material You 3 aesthetic.

## Analysis

### 1. Background Exception
The `BackgroundScheduleUpdate.dart` called `scheduleProvider.getUpdatedSchedule` which rethrows exceptions. The background task runner didn't catch `ScheduleQueryFailedException`, leading to an unhandled exception.

```dart
// OLD CODE
await scheduleProvider.getUpdatedSchedule(
  today,
  end,
  cancellationToken,
);
```

### 2. Widget Data Window
The `MultiDayWidgetHelper.weekDates` function calculated the date range as "days remaining in the current week" (until Sunday).
On a Saturday, `daysRemainingInWeek` returned 1 (Saturday + Sunday). Monday's events were excluded from the query/display list.

```kotlin
// OLD CODE
private fun daysRemainingInWeek(today: LocalDate): Int {
    return max(0, 7 - today.dayOfWeek.value)
}
```

## Solution

### 1. Handle Background Exception
Added a `try-catch` block specifically for `ScheduleQueryFailedException` in `BackgroundScheduleUpdate.dart` to log the error gracefully instead of crashing.

```dart
// NEW CODE (lib/schedule/background/background_schedule_update.dart)
try {
  await scheduleProvider.getUpdatedSchedule(
    today,
    end,
    cancellationToken,
  );
} on ScheduleQueryFailedException catch (e, trace) {
  print("Background schedule update failed");
  print(e.innerException.toString());
  // Log but don't crash
  return;
}
```

### 2. Rolling 7-Day Window
Changed `MultiDayWidgetHelper` to use a fixed rolling 7-day window instead of the remaining calendar week.

```kotlin
// NEW CODE (android/.../widget/MultiDayWidgetHelper.kt)
fun weekDates(today: LocalDate): List<LocalDate> {
    return (0 until WEEK_WINDOW_DAYS).map { offset -> today.plusDays(offset.toLong()) }
}
private const val WEEK_WINDOW_DAYS = 7
```

### 3. Widget Styling
Updated `colors.xml` and layouts to match the red accent design:
- Added `@color/widget_schedule_item_accent_future` (#E04B4B)
- Increased text sizes (16sp/13sp)
- Adjusted padding in `widget_day_row.xml`

## Prevention

1.  **Background Tasks**: Always wrap external API calls in background tasks with comprehensive `try-catch` blocks. Background isolates often don't have the same global error handling as the UI thread.
2.  **Date Logic**: When defining "upcoming" views, verify if "current week" vs "next N days" is the intended behavior, especially for weekends.
3.  **Database Safety**: Added `try-catch` in `ScheduleProvider.kt` database queries to prevent widget crashes from corrupting the main app experience.
