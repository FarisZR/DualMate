package com.fariszr.dualmate.widget.now

import com.fariszr.dualmate.model.ScheduleEntry
import java.util.Locale

object ScheduleWidgetMarkerHelper {
    private const val specialEventType = ScheduleEntry.SPECIAL_EVENT_TYPE
    private const val examType = ScheduleEntry.EXAM_TYPE
    private const val publicHolidayType = ScheduleEntry.PUBLIC_HOLIDAY_TYPE
    private const val examWeekKeyword = "klausurwoche"
    private const val theoryPhaseKeyword = "theoriephase"
    private const val beginKeyword = "beginn"

    fun isMarkerEntry(entry: ScheduleEntry): Boolean {
        if (entry.type != specialEventType &&
            entry.type != examType &&
            entry.type != publicHolidayType
        ) {
            return false
        }

        if (entry.type == publicHolidayType) {
            return true
        }

        return isExamWeekTitle(entry.title) || isTheoryPhaseStartTitle(entry.title)
    }

    fun orderEntriesForDisplay(entries: List<ScheduleEntry>): List<ScheduleEntry> {
        return entries.sortedWith(
            compareByDescending<ScheduleEntry> { isMarkerEntry(it) }
                .thenBy { it.start }
                .thenBy { it.end }
                .thenBy { it.title }
        )
    }

    fun isMarkerOnlyDay(entries: List<ScheduleEntry>): Boolean {
        return entries.isNotEmpty() && entries.all { isMarkerEntry(it) }
    }

    private fun isExamWeekTitle(title: String): Boolean {
        return normalizeTitle(title).contains(examWeekKeyword)
    }

    private fun isTheoryPhaseStartTitle(title: String): Boolean {
        val normalized = normalizeTitle(title)
        return normalized.contains(beginKeyword) && normalized.contains(theoryPhaseKeyword)
    }

    private fun normalizeTitle(title: String): String {
        return title
            .lowercase(Locale.ROOT)
            .replace(Regex("[\\s\\.-]"), "")
    }
}
