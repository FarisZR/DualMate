package com.fariszr.dualmate.widget.now

import com.fariszr.dualmate.R
import com.fariszr.dualmate.model.ScheduleEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.threeten.bp.LocalDateTime

class NowScheduleEntryViewsFactoryTest {
    @Test
    fun prepareDayItems_usesFullHeightLayoutForSingleMarkerDay() {
        val items = NowScheduleEntryViewsFactory.prepareDayItems(
            listOf(entry(title = "Karfreitag", type = ScheduleEntry.PUBLIC_HOLIDAY_TYPE))
        )

        assertEquals(1, items.size)
        assertTrue(items.single().usesFullHeightMarkerLayout)
        assertEquals(
            R.layout.widget_schedule_day_marker_full_item,
            NowScheduleEntryViewsFactory.markerLayoutId(items.single())
        )
    }

    @Test
    fun prepareDayItems_keepsCompactLayoutForMixedDays() {
        val items = NowScheduleEntryViewsFactory.prepareDayItems(
            listOf(
                entry(title = "Beginn der 1. Theoriephase", type = ScheduleEntry.SPECIAL_EVENT_TYPE),
                entry(title = "Algorithms", type = ScheduleEntry.CLASS_TYPE)
            )
        )

        val markerItem = items.first { ScheduleWidgetMarkerHelper.isMarkerEntry(it.entry) }

        assertFalse(markerItem.usesFullHeightMarkerLayout)
        assertEquals(
            R.layout.widget_schedule_day_marker_item,
            NowScheduleEntryViewsFactory.markerLayoutId(markerItem)
        )
    }

    @Test
    fun markerAccentDrawable_matchesSchedulePageColors() {
        assertEquals(
            R.drawable.widget_schedule_item_accent_marker_special_event,
            NowScheduleEntryViewsFactory.markerAccentDrawable(
                entry(title = "Beginn der 1. Theoriephase", type = ScheduleEntry.SPECIAL_EVENT_TYPE)
            )
        )
        assertEquals(
            R.drawable.widget_schedule_item_accent_marker_holiday,
            NowScheduleEntryViewsFactory.markerAccentDrawable(
                entry(title = "Karfreitag", type = ScheduleEntry.PUBLIC_HOLIDAY_TYPE)
            )
        )
        assertEquals(
            R.drawable.widget_schedule_item_accent_marker_exam,
            NowScheduleEntryViewsFactory.markerAccentDrawable(
                entry(title = "Exam marker", type = ScheduleEntry.EXAM_TYPE)
            )
        )
    }

    private fun entry(title: String, type: Int): ScheduleEntry {
        val start = LocalDateTime.of(2026, 4, 1, 7, 0)

        return ScheduleEntry(
            id = 1,
            title = title,
            details = "",
            professor = "",
            room = "",
            type = type,
            start = start,
            end = start.plusHours(1)
        )
    }
}
