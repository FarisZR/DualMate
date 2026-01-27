---
module: Android widgets (schedule/canteen)
date: 2026-01-27
problem_type: integration_issue
component: tooling
symptoms:
  - "Tapping schedule/canteen item rows does nothing"
  - "Day header taps still open the correct week/day"
  - "Item taps stopped after switching to day-only navigation"
root_cause: wrong_api
resolution_type: code_fix
severity: medium
tags: [android-widget, remoteviews, click-handling, schedule, canteen]
---

# Troubleshooting: Widget item taps not opening day navigation

## Problem
After switching widget item taps to day-only navigation, tapping a class/meal row stopped opening the app. Day header taps still worked, but item taps had no effect.

## Environment
- Module: Android widgets (schedule/canteen)
- Affected component: RemoteViews click handling
- Date: 2026-01-27
- Stage: post-implementation

## Symptoms
- Tapping a schedule class or canteen meal row does nothing.
- Day header taps still open the correct week/day.
- The issue reproduces across schedule and canteen widgets.

## What Didn't Work

**Attempted Solution 1:** Keep item-level fill-in intents but remove per-entry payloads.
- **Why it failed:** Item rows were no longer clickable after layout changes, so the fill-in intent never fired.

**Attempted Solution 2:** Rely on day header taps only.
- **Why it failed:** The items column itself was not clickable, so taps on the right side were ignored.

## Solution

Make the items column (`day_items_container`) the clickable target for day navigation and remove clickability from individual item layouts. This lets taps on any item bubble to the day column and use the same day payload as the header.

**Code changes** (Android RemoteViews):

```kotlin
// android/app/src/main/kotlin/com/fariszr/dualmate/widget/today/ScheduleEntryViewsFactory.kt
override fun bindDayHeader(views: RemoteViews, date: LocalDate, isToday: Boolean) {
    val dayStartMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
    val dayIntent = Intent().putExtra(WidgetNavigationExtras.scheduleDayStart, dayStartMillis)
    views.setOnClickFillInIntent(R.id.day_header_container, dayIntent)
    views.setOnClickFillInIntent(R.id.day_items_container, dayIntent)
}
```

```kotlin
// android/app/src/main/kotlin/com/fariszr/dualmate/widget/canteen/CanteenEntryViewsFactory.kt
override fun bindDayHeader(views: RemoteViews, date: LocalDate, isToday: Boolean) {
    val dayStartMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
    val dayIntent = Intent().putExtra(WidgetNavigationExtras.canteenDayStart, dayStartMillis)
    views.setOnClickFillInIntent(R.id.day_header_container, dayIntent)
    views.setOnClickFillInIntent(R.id.day_items_container, dayIntent)
}
```

```xml
<!-- android/app/src/main/res/layout/widget_day_row.xml -->
<LinearLayout
    android:id="@+id/day_items_container"
    android:layout_width="0dp"
    android:layout_height="wrap_content"
    android:layout_weight="1"
    android:clickable="true"
    android:focusable="true"
    android:orientation="vertical" />
```

```xml
<!-- android/app/src/main/res/layout/widget_schedule_day_item.xml -->
<LinearLayout
    android:id="@+id/layout_schedule_item"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal">
    ...
</LinearLayout>
```

```xml
<!-- android/app/src/main/res/layout/widget_canteen_day_item.xml -->
<LinearLayout
    android:id="@+id/layout_canteen_item"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal">
    ...
</LinearLayout>
```

## Why This Works

- RemoteViews list items only trigger fill-in intents on views marked clickable.
- By making the day items column clickable and wiring it to the day intent, any tap in that column routes to the correct day.
- Removing clickable flags from the item views prevents them from swallowing taps without a fill-in intent.

## Prevention

- Always attach click handlers to a single, consistently clickable parent view in RemoteViews lists.
- If item-level click behavior changes, verify at least one clickable target remains in the items column.
- Avoid marking child views clickable unless they have their own fill-in intents.

## Related Issues

- See also: [widget-item-tap-day-only-and-canteen-main-meals-20260127.md](widget-item-tap-day-only-and-canteen-main-meals-20260127.md)
- See also: [widget-item-taps-missing-when-app-resumed-20260127.md](widget-item-taps-missing-when-app-resumed-20260127.md)
