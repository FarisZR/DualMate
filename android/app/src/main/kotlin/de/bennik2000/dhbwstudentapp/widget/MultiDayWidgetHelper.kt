package de.bennik2000.dhbwstudentapp.widget

import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime
import kotlin.math.max
import kotlin.math.min

object MultiDayWidgetHelper {
    data class RowMetrics(
        val headerHeightDp: Int,
        val rowVerticalPaddingDp: Int,
        val dateColumnMinHeightDp: Int,
        val itemHeightDp: Int,
        val maxItemsPerRow: Int
    )

    data class DayRow<T>(
        val date: LocalDate,
        val items: List<T>,
        val isToday: Boolean
    )

    data class VisibleItems<T>(
        val items: List<T>,
        val overflowCount: Int
    )

    fun weekDates(today: LocalDate): List<LocalDate> {
        return (0 until WEEK_WINDOW_DAYS).map { offset -> today.plusDays(offset.toLong()) }
    }

    fun <T> filterWeekRows(rows: List<DayRow<T>>): List<DayRow<T>> {
        if (rows.isEmpty()) {
            return rows
        }

        return rows.filter { row -> row.isToday || row.items.isNotEmpty() }
    }

    fun <T> limitItems(items: List<T>, maxItems: Int): VisibleItems<T> {
        val safeMax = max(1, maxItems)
        if (items.size <= safeMax) {
            return VisibleItems(items, 0)
        }

        if (safeMax == 1) {
            return VisibleItems(listOf(items.first()), items.size - 1)
        }

        val visibleItems = items.take(safeMax - 1)
        val overflowCount = items.size - visibleItems.size
        return VisibleItems(visibleItems, overflowCount)
    }

    fun calculateRowHeightDp(itemCount: Int, metrics: RowMetrics): Int {
        val safeCount = min(metrics.maxItemsPerRow, max(1, itemCount))
        val contentHeight = metrics.rowVerticalPaddingDp + (safeCount * metrics.itemHeightDp)
        return max(metrics.dateColumnMinHeightDp, contentHeight)
    }

    fun <T> calculateVisibleDayCount(
        widgetHeightDp: Int,
        rows: List<DayRow<T>>,
        metrics: RowMetrics
    ): Int {
        if (rows.isEmpty()) {
            return 0
        }

        var availableHeight = widgetHeightDp - metrics.headerHeightDp
        if (availableHeight <= 0) {
            return 1
        }

        var count = 0
        for (row in rows) {
            val rowHeight = calculateRowHeightDp(row.items.size, metrics)
            if (availableHeight >= rowHeight) {
                availableHeight -= rowHeight
                count++
            } else {
                break
            }
        }

        return max(1, min(count, rows.size))
    }

    fun resolveItemState(
        start: LocalDateTime,
        end: LocalDateTime,
        now: LocalDateTime
    ): WidgetItemState {
        return when {
            now.isAfter(end) -> WidgetItemState.PAST
            now.isAfter(start) -> WidgetItemState.CURRENT
            else -> WidgetItemState.FUTURE
        }
    }

    private const val WEEK_WINDOW_DAYS = 7
}
