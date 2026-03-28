package com.fariszr.dualmate.widget.now

import com.fariszr.dualmate.model.ScheduleEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.threeten.bp.LocalDateTime

class ScheduleWidgetMarkerHelperTest {
    @Test
    fun isMarkerEntry_matchesExamWeekMarker() {
        val entry = entry(
            title = "Klausurwoche 2. Semester",
            type = ScheduleEntry.SPECIAL_EVENT_TYPE
        )

        assertTrue(ScheduleWidgetMarkerHelper.isMarkerEntry(entry))
    }

    @Test
    fun isMarkerEntry_ignoresRegularExam() {
        val entry = entry(
            title = "Klausur Informatik 2",
            type = ScheduleEntry.EXAM_TYPE
        )

        assertFalse(ScheduleWidgetMarkerHelper.isMarkerEntry(entry))
    }

    @Test
    fun isMarkerEntry_ignoresUnrelatedType5() {
        val entry = entry(
            title = "Career Fair",
            type = ScheduleEntry.SPECIAL_EVENT_TYPE
        )

        assertFalse(ScheduleWidgetMarkerHelper.isMarkerEntry(entry))
    }

    @Test
    fun isMarkerEntry_matchesPublicHoliday() {
        val entry = entry(
            title = "Karfreitag",
            type = ScheduleEntry.PUBLIC_HOLIDAY_TYPE
        )

        assertTrue(ScheduleWidgetMarkerHelper.isMarkerEntry(entry))
    }

    @Test
    fun isMarkerOnlyDay_trueWhenAllEntriesAreMarkers() {
        val entries = listOf(
            entry(
                title = "Karfreitag",
                type = ScheduleEntry.PUBLIC_HOLIDAY_TYPE
            )
        )

        assertTrue(ScheduleWidgetMarkerHelper.isMarkerOnlyDay(entries))
    }

    @Test
    fun isMarkerOnlyDay_falseWhenRegularClassesExist() {
        val entries = listOf(
            entry(
                title = "Beginn der 1. Theoriephase",
                type = ScheduleEntry.SPECIAL_EVENT_TYPE
            ),
            entry(
                title = "Algorithms",
                type = ScheduleEntry.CLASS_TYPE
            )
        )

        assertFalse(ScheduleWidgetMarkerHelper.isMarkerOnlyDay(entries))
    }

    @Test
    fun orderEntriesForDisplay_movesMarkersToTop() {
        val classEntry = entry(
            title = "Algorithms",
            type = ScheduleEntry.CLASS_TYPE,
            start = LocalDateTime.of(2026, 4, 1, 8, 0)
        )
        val markerEntry = entry(
            title = "Beginn der 1. Theoriephase",
            type = ScheduleEntry.SPECIAL_EVENT_TYPE,
            start = LocalDateTime.of(2026, 4, 1, 10, 0)
        )

        val ordered = ScheduleWidgetMarkerHelper.orderEntriesForDisplay(
            listOf(classEntry, markerEntry)
        )

        assertEquals(markerEntry.title, ordered.first().title)
        assertEquals(classEntry.title, ordered.last().title)
    }

    private fun entry(
        title: String,
        type: Int,
        start: LocalDateTime = LocalDateTime.of(2026, 4, 1, 7, 0)
    ): ScheduleEntry {
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
