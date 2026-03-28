package com.fariszr.dualmate.model

import org.threeten.bp.LocalDateTime

class ScheduleEntry(
        val id: Int,
        val title: String,
        val details: String,
        val professor: String,
        val room: String,
        val type: Int,
        val start: LocalDateTime,
        val end: LocalDateTime) {
    companion object {
        const val UNKNOWN_TYPE = 0
        const val CLASS_TYPE = 1
        const val ONLINE_TYPE = 2
        const val PUBLIC_HOLIDAY_TYPE = 3
        const val EXAM_TYPE = 4
        const val SPECIAL_EVENT_TYPE = 5
    }
}
