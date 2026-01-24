package de.bennik2000.dhbwstudentapp.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime

class MultiDayWidgetHelperTest {
    private val metrics = MultiDayWidgetHelper.RowMetrics(
        headerHeightDp = 48,
        rowVerticalPaddingDp = 12,
        dateColumnMinHeightDp = 36,
        itemHeightDp = 20,
        maxItemsPerRow = 4
    )

    @Test
    fun weekDates_returnsSevenDayWindow() {
        val today = LocalDate.of(2026, 1, 21)

        val dates = MultiDayWidgetHelper.weekDates(today)

        assertEquals(7, dates.size)
        assertEquals(today.plusDays(6), dates.last())
    }

    @Test
    fun filterWeekRows_keepsTodayAndNonEmpty() {
        val today = LocalDate.of(2026, 1, 21)
        val rows = listOf(
            MultiDayWidgetHelper.DayRow(today, emptyList<String>(), true),
            MultiDayWidgetHelper.DayRow(today.plusDays(1), emptyList<String>(), false),
            MultiDayWidgetHelper.DayRow(today.plusDays(2), listOf("item"), false)
        )

        val filtered = MultiDayWidgetHelper.filterWeekRows(rows)

        assertEquals(2, filtered.size)
        assertTrue(filtered.first().isToday)
        assertEquals(today.plusDays(2), filtered.last().date)
    }

    @Test
    fun calculateVisibleDayCount_minHeightShowsOne() {
        val today = LocalDate.of(2026, 1, 21)
        val rows = listOf(
            MultiDayWidgetHelper.DayRow(today, listOf("item"), true)
        )

        val count = MultiDayWidgetHelper.calculateVisibleDayCount(40, rows, metrics)

        assertEquals(1, count)
    }

    @Test
    fun calculateRowHeight_increasesWithItems() {
        val singleHeight = MultiDayWidgetHelper.calculateRowHeightDp(1, metrics)
        val multiHeight = MultiDayWidgetHelper.calculateRowHeightDp(3, metrics)

        assertTrue(multiHeight > singleHeight)
    }

    @Test
    fun limitItems_addsOverflow() {
        val items = listOf("one", "two", "three", "four", "five", "six")
        val visible = MultiDayWidgetHelper.limitItems(items, 4)

        assertEquals(3, visible.items.size)
        assertEquals(3, visible.overflowCount)
    }

    @Test
    fun resolveItemState_respectsPastCurrentFuture() {
        val start = LocalDateTime.of(2026, 1, 21, 9, 0)
        val end = LocalDateTime.of(2026, 1, 21, 10, 0)

        assertEquals(
            WidgetItemState.FUTURE,
            MultiDayWidgetHelper.resolveItemState(start, end, LocalDateTime.of(2026, 1, 21, 8, 0))
        )
        assertEquals(
            WidgetItemState.CURRENT,
            MultiDayWidgetHelper.resolveItemState(start, end, LocalDateTime.of(2026, 1, 21, 9, 30))
        )
        assertEquals(
            WidgetItemState.PAST,
            MultiDayWidgetHelper.resolveItemState(start, end, LocalDateTime.of(2026, 1, 21, 10, 30))
        )
    }
}
