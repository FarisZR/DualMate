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
            type = 5
        )

        assertTrue(ScheduleWidgetMarkerHelper.isMarkerEntry(entry))
    }

    @Test
    fun isMarkerEntry_ignoresRegularExam() {
        val entry = entry(
            title = "Klausur Informatik 2",
            type = 4
        )

        assertFalse(ScheduleWidgetMarkerHelper.isMarkerEntry(entry))
    }

    @Test
    fun isMarkerEntry_ignoresUnrelatedType5() {
        val entry = entry(
            title = "Career Fair",
            type = 5
        )

        assertFalse(ScheduleWidgetMarkerHelper.isMarkerEntry(entry))
    }

    @Test
    fun orderEntriesForDisplay_movesMarkersToTop() {
        val classEntry = entry(
            title = "Algorithms",
            type = 1,
            start = LocalDateTime.of(2026, 4, 1, 8, 0)
        )
        val markerEntry = entry(
            title = "Beginn der 1. Theoriephase",
            type = 5,
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
            1,
            title,
            "",
            "",
            "",
            type,
            start,
            start.plusHours(1)
        )
    }
}
