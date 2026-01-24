---
title: "feat: Multi-Day Widget Display for Calendar and Canteen"
type: feat
date: 2026-01-24
---

# Multi-Day Widget Display for Calendar and Canteen

## Overview

Transform the existing single-day Android home screen widgets (Schedule Today and Canteen Today) into multi-day displays that dynamically show multiple days based on widget height. Each day appears as a row with the date on the left and courses/meals on the right.

## Problem Statement / Motivation

Currently, both widgets only show today's classes/meals. When today has no remaining classes (e.g., evening time), the widget becomes useless until tomorrow. Users want:

1. See upcoming days at a glance without opening the app
2. Dynamic content that adapts to widget size
3. Clear visual distinction between past, current, and future items
4. No wasted space on empty days

## Proposed Solution

### Architecture: Shared Multi-Day Widget Component

Create a shared `MultiDayViewsFactory` base that both schedule and canteen widgets extend:

```
┌─────────────────────────────────────────────────────────────┐
│                    SHARED ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            MultiDayViewsFactory (abstract)            │   │
│  │  - calculateVisibleDayCount(height)                   │   │
│  │  - filterNonEmptyDays(days, keepToday)               │   │
│  │  - buildDayRow(date, items)                          │   │
│  │  - getItemsForDate(date): abstract                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ▲                                   │
│           ┌──────────────┼──────────────┐                   │
│           │                             │                    │
│  ┌────────┴────────┐         ┌─────────┴─────────┐         │
│  │ScheduleMultiDay │         │CanteenMultiDay    │         │
│  │ ViewsFactory    │         │ ViewsFactory      │         │
│  │ - getItems...   │         │ - getItems...     │         │
│  │ - renderClass() │         │ - renderMeal()    │         │
│  └─────────────────┘         └───────────────────┘         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Visual Design (Material 3)

```
┌─────────────────────────────────────────┐
│ Classes                              ⟳  │  ← Header (existing)
├─────────────────────────────────────────┤
│ Today        │ ▓▓ Math (done)          │  ← Past class: grayed
│ Fri, Jan 24  │ ██ Physics (now)        │  ← Current: brighter bg
│              │ ░░ Chemistry            │  ← Future: normal
├─────────────────────────────────────────┤
│ Monday       │ ░░ Programming          │
│ Jan 27       │ ░░ Databases            │
├─────────────────────────────────────────┤
│ Tuesday      │ ░░ Networking           │
│ Jan 28       │ ░░ +2 more              │  ← Overflow indicator
└─────────────────────────────────────────┘
```

**Visual States:**
- **Past class**: Grayed out (reduced opacity + gray text)
- **Current class**: Brighter background (highlighted gray, accent tint)
- **Future class**: Normal appearance (existing colors)

### Height Calculation Algorithm

Variable row heights based on content:

```kotlin
// Pseudocode for day fitting algorithm
fun calculateVisibleDays(widgetHeight: Int, dayData: List<DayData>): Int {
    val headerHeight = 48.dp
    val rowPadding = 8.dp
    val minRowHeight = 56.dp  // Single item
    val itemHeight = 24.dp    // Per additional item
    val maxItemsPerRow = 4    // Cap before "+N more"
    
    var availableHeight = widgetHeight - headerHeight
    var daysToShow = 0
    
    for (day in dayData) {
        val itemCount = min(day.items.size, maxItemsPerRow)
        val rowHeight = minRowHeight + (max(0, itemCount - 1) * itemHeight) + rowPadding
        
        if (availableHeight >= rowHeight) {
            availableHeight -= rowHeight
            daysToShow++
        } else {
            break
        }
    }
    
    return max(1, daysToShow)  // Minimum 1 day
}
```

### Day Filtering Logic

```kotlin
fun getVisibleDays(startDate: LocalDate): List<DayData> {
    val result = mutableListOf<DayData>()
    val today = LocalDate.now()
    
    // Always include today (even if empty)
    result.add(getDayData(today))
    
    // Find non-empty future days (current week only)
    for (offset in 1..daysRemainingInWeek(today)) {
        val date = today.plusDays(offset)
        val dayData = getDayData(date)
        
        if (dayData.items.isNotEmpty()) {
            result.add(dayData)
        }
    }
    
    return result
}
```

### Time-Based State Logic

```kotlin
enum class ItemState { PAST, CURRENT, FUTURE }

fun getItemState(item: ScheduleEntry, now: LocalDateTime): ItemState {
    return when {
        now.isAfter(item.end) -> ItemState.PAST       // After end time
        now.isAfter(item.start) -> ItemState.CURRENT  // During class
        else -> ItemState.FUTURE                       // Before start
    }
}
```

## Technical Considerations

### Android RemoteViews Constraints

RemoteViews only supports limited view types:
- FrameLayout, LinearLayout, RelativeLayout
- TextView, ImageView, ProgressBar
- ListView (via RemoteViewsService)

**Approach:** Use nested LinearLayouts for day rows, with ListView only if needed for scrolling (but we chose static display).

### Database Query Optimization

```kotlin
// Query schedule entries for date range (already exists)
fun queryScheduleEntriesBetween(start: LocalDate, end: LocalDate): List<ScheduleEntry>

// Query canteen meals for date range (already exists)
fun queryMealsForDateRange(start: LocalDate, end: LocalDate): List<Meal>
```

**Optimization:** Query only the current week, then filter in memory. Cache results per update cycle.

### Widget Update Triggers

1. **onUpdate()** - System periodic update (every 90 min via widget info)
2. **App data sync** - Via MethodChannel when Flutter app syncs
3. **Time change** - Register `ACTION_TIME_CHANGED` broadcast
4. **Day change** - Schedule AlarmManager for midnight updates
5. **Resize** - `onAppWidgetOptionsChanged()` callback

### Performance Considerations

- **Week-only lookahead** - Limits work to the current week for performance
- **Cached day calculations** - Don't recalculate on every paint
- **Efficient layouts** - Avoid deep view hierarchies (RemoteViews limit)

## Acceptance Criteria

### Functional Requirements

- [x] Widget shows multiple days based on available height
- [x] Each day row displays date label on left, items on right
- [x] Today always shown first (even if empty)
- [x] Empty days (no classes/meals) are skipped (except today)
- [x] Past classes shown grayed out (after end time)
- [x] Current classes shown with brighter background
- [x] Future classes shown with normal appearance
- [x] Minimum 1 day visible at minimum widget height (40dp)
- [x] Overflow handled with "+N more" indicator

### Non-Functional Requirements

- [x] Material 3 design language compliance
- [x] Localized date formats (English/German)
- [ ] Smooth resize experience
- [ ] Updates reflect within 1 minute of class end time
- [ ] No performance degradation vs. current single-day widgets

### Testing Requirements

- [x] Unit tests for day calculation algorithm
- [x] Unit tests for item state determination (past/current/future)
- [x] Unit tests for day filtering logic
- [ ] Integration tests with various widget heights
- [ ] Visual tests for all three item states

## Success Metrics

- Widget provides value even after today's classes end
- Users can see upcoming week at a glance
- No reported crashes or "Problem loading widget" errors

## Dependencies & Risks

### Dependencies

- Existing `ScheduleProvider` and `CanteenProvider` Kotlin classes
- Existing widget layouts and RemoteViewsService infrastructure
- SQLite database schema (no changes needed)

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| RemoteViews layout complexity exceeds limits | Medium | High | Test on low-memory devices, simplify if needed |
| Variable height calculation is imprecise | Medium | Medium | Add padding buffer, round conservatively |
| Midnight update fails | Low | Medium | Multiple update triggers as backup |
| Performance with week-range queries | Low | Low | Already efficient indexed queries |

## Implementation Phases

### Phase 1: Shared Infrastructure (Kotlin)

**Files to create/modify:**

1. `android/.../widget/MultiDayViewsFactory.kt` (NEW)
   - Abstract base class with shared day calculation/filtering logic
   
2. `android/.../widget/WidgetItemState.kt` (NEW)
   - Enum for PAST, CURRENT, FUTURE states
   
3. `android/.../widget/MultiDayWidgetHelper.kt` (NEW)
   - Height calculation, date formatting utilities

**Estimated effort:** 4-6 hours

### Phase 2: Schedule Widget Conversion

**Files to modify:**

1. `android/.../widget/today/ScheduleTodayWidget.kt`
   - Rename to `ScheduleMultiDayWidget.kt`
   - Use new base class
   
2. `android/.../widget/today/ScheduleEntryViewsFactory.kt`
   - Extend `MultiDayViewsFactory`
   - Implement schedule-specific rendering
   
3. `android/.../res/layout/widget_schedule_today.xml`
   - Update layout for day rows structure
   
4. `android/.../res/layout/widget_schedule_day_row.xml` (NEW)
   - Layout for single day row

**Estimated effort:** 6-8 hours

### Phase 3: Canteen Widget Conversion

**Files to modify:**

1. `android/.../widget/canteen/CanteenTodayWidget.kt`
   - Similar conversion as schedule widget
   
2. `android/.../widget/canteen/CanteenEntryViewsFactory.kt`
   - Extend `MultiDayViewsFactory`
   
3. `android/.../res/layout/widget_canteen_today.xml`
   - Update layout structure
   
4. `android/.../res/layout/widget_canteen_day_row.xml` (NEW)

**Estimated effort:** 4-6 hours

### Phase 4: Visual Polish & Testing

1. Material 3 color theming for all states
2. Localized date formatting
3. Widget preview images update
4. Comprehensive test suite

**Estimated effort:** 4-6 hours

## MVP Implementation

### MultiDayViewsFactory.kt

```kotlin
package de.bennik2000.dhbwstudentapp.widget

import android.content.Context
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.time.LocalDate
import java.time.LocalDateTime

abstract class MultiDayViewsFactory(
    protected val context: Context
) : RemoteViewsService.RemoteViewsFactory {
    
    protected data class DayData(
        val date: LocalDate,
        val items: List<WidgetItem>,
        val isToday: Boolean
    )
    
    protected data class WidgetItem(
        val title: String,
        val subtitle: String?,
        val startTime: LocalDateTime?,
        val endTime: LocalDateTime?,
        val color: Int
    )
    
    protected var visibleDays: List<DayData> = emptyList()
    
    abstract fun getItemsForDate(date: LocalDate): List<WidgetItem>
    abstract fun getDayRowLayout(): Int
    abstract fun getItemLayout(): Int
    
    override fun onDataSetChanged() {
        visibleDays = calculateVisibleDays()
    }
    
    private fun calculateVisibleDays(): List<DayData> {
        val today = LocalDate.now()
        val result = mutableListOf<DayData>()
        
        // Always include today
        result.add(DayData(today, getItemsForDate(today), isToday = true))
        
        // Find non-empty future days (current week only)
        for (offset in 1..daysRemainingInWeek(today)) {
            val date = today.plusDays(offset.toLong())
            val items = getItemsForDate(date)
            if (items.isNotEmpty()) {
                result.add(DayData(date, items, isToday = false))
            }
        }
        
        return result
    }
    
    protected fun getItemState(item: WidgetItem): ItemState {
        val now = LocalDateTime.now()
        val end = item.endTime ?: return ItemState.FUTURE
        val start = item.startTime ?: return ItemState.FUTURE
        
        return when {
            now.isAfter(end) -> ItemState.PAST
            now.isAfter(start) -> ItemState.CURRENT
            else -> ItemState.FUTURE
        }
    }
    
    override fun getCount(): Int = visibleDays.size
    
    // ... remaining RemoteViewsFactory methods
}

enum class ItemState { PAST, CURRENT, FUTURE }
```

### widget_schedule_day_row.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:padding="8dp">

    <!-- Date Column -->
    <LinearLayout
        android:layout_width="56dp"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:gravity="center">

        <TextView
            android:id="@+id/day_label"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textSize="12sp"
            android:textColor="?android:textColorSecondary" />

        <TextView
            android:id="@+id/date_label"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textSize="14sp"
            android:textStyle="bold"
            android:textColor="?android:textColorPrimary" />
    </LinearLayout>

    <!-- Divider -->
    <View
        android:layout_width="1dp"
        android:layout_height="match_parent"
        android:layout_marginHorizontal="8dp"
        android:background="?android:dividerVertical" />

    <!-- Items Column -->
    <LinearLayout
        android:id="@+id/items_container"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical" />

</LinearLayout>
```

## Test Plan

### Unit Tests (Kotlin)

```kotlin
// test/.../widget/MultiDayViewsFactoryTest.kt

class ItemStateTest {
    @Test
    fun `class after end time is PAST`() {
        val item = createItem(
            start = LocalDateTime.of(2026, 1, 24, 9, 0),
            end = LocalDateTime.of(2026, 1, 24, 10, 30)
        )
        val now = LocalDateTime.of(2026, 1, 24, 11, 0)
        
        assertEquals(ItemState.PAST, getItemState(item, now))
    }
    
    @Test
    fun `class during time is CURRENT`() {
        val item = createItem(
            start = LocalDateTime.of(2026, 1, 24, 10, 0),
            end = LocalDateTime.of(2026, 1, 24, 11, 30)
        )
        val now = LocalDateTime.of(2026, 1, 24, 10, 30)
        
        assertEquals(ItemState.CURRENT, getItemState(item, now))
    }
    
    @Test
    fun `class before start time is FUTURE`() {
        val item = createItem(
            start = LocalDateTime.of(2026, 1, 24, 14, 0),
            end = LocalDateTime.of(2026, 1, 24, 15, 30)
        )
        val now = LocalDateTime.of(2026, 1, 24, 10, 0)
        
        assertEquals(ItemState.FUTURE, getItemState(item, now))
    }
}

class DayFilteringTest {
    @Test
    fun `today is always included even when empty`() {
        val factory = TestMultiDayFactory(emptyDataForToday = true)
        val days = factory.calculateVisibleDays()
        
        assertEquals(1, days.count { it.isToday })
        assertTrue(days.first().isToday)
    }
    
    @Test
    fun `empty future days are skipped`() {
        val factory = TestMultiDayFactory(
            emptyDays = listOf(
                LocalDate.now().plusDays(1),
                LocalDate.now().plusDays(2)
            ),
            nonEmptyDays = listOf(
                LocalDate.now().plusDays(3)
            )
        )
        
        val days = factory.calculateVisibleDays()
        
        assertFalse(days.any { it.date == LocalDate.now().plusDays(1) })
        assertFalse(days.any { it.date == LocalDate.now().plusDays(2) })
        assertTrue(days.any { it.date == LocalDate.now().plusDays(3) })
    }
    
    @Test
    fun `minimum 1 day at minimum widget height`() {
        val factory = TestMultiDayFactory(widgetHeight = 40) // min height
        val days = factory.calculateVisibleDays()
        
        assertTrue(days.size >= 1)
    }
}

class HeightCalculationTest {
    @Test
    fun `single item day uses minimum row height`() {
        val dayData = DayData(items = listOf(singleItem))
        val height = calculateRowHeight(dayData)
        
        assertEquals(56.dp, height)
    }
    
    @Test
    fun `multiple items increase row height`() {
        val dayData = DayData(items = listOf(item1, item2, item3))
        val height = calculateRowHeight(dayData)
        
        assertTrue(height > 56.dp)
    }
    
    @Test
    fun `max 4 items shown before overflow`() {
        val dayData = DayData(items = (1..6).map { createItem() })
        val visibleCount = getVisibleItemCount(dayData)
        
        assertEquals(4, visibleCount) // 4 shown + "+2 more"
    }
}
```

### Integration Tests

```kotlin
class WidgetIntegrationTest {
    @Test
    fun `widget renders at minimum height`() {
        val widget = ScheduleMultiDayWidget()
        val options = Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 40)
        }
        
        widget.onAppWidgetOptionsChanged(context, appWidgetManager, widgetId, options)
        
        // Verify widget doesn't crash and shows at least 1 day
    }
    
    @Test
    fun `widget updates on data change`() {
        // Insert new schedule entry
        // Trigger widget refresh
        // Verify new entry appears
    }
}
```

## References

### Internal References

- Current widget implementation: `android/.../widget/today/ScheduleTodayWidget.kt`
- Widget layouts: `android/.../res/layout/widget_schedule_today.xml`
- Schedule provider: `android/.../database/ScheduleProvider.kt`
- Widget tap fix documentation: `docs/solutions/integration-issues/widget-tap-not-navigating-android-widgets-20260122.md`

### External References

- Material 3 Android widgets: https://m3.material.io/develop/android
- RemoteViews documentation: https://developer.android.com/reference/android/widget/RemoteViews
- App Widget sizing: https://developer.android.com/develop/ui/views/appwidgets/layouts

### Related Work

- Existing widget infrastructure established in previous modernization work
- MethodChannel integration for widget refresh already in place
