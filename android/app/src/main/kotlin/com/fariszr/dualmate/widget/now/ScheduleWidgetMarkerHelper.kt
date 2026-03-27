package com.fariszr.dualmate.widget.now

import com.fariszr.dualmate.model.ScheduleEntry
import java.util.Locale

object ScheduleWidgetMarkerHelper {
    private const val specialEventType = 5 // Mirrors Dart ScheduleEntryType.SpecialEvent.
    private const val examWeekKeyword = "klausurwoche"
    private const val theoryPhaseKeyword = "theoriephase"
    private const val beginKeyword = "beginn"

    fun isMarkerEntry(entry: ScheduleEntry): Boolean {
        if (entry.type != specialEventType) {
            return false
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
