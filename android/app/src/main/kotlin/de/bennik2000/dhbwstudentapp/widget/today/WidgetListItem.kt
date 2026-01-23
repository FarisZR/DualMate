package de.bennik2000.dhbwstudentapp.widget.today

import de.bennik2000.dhbwstudentapp.model.ScheduleEntry
import org.threeten.bp.LocalDate

sealed class WidgetListItem {
    data class DateHeader(val date: LocalDate) : WidgetListItem()
    data class ScheduleEntryItem(val entry: ScheduleEntry) : WidgetListItem()
}
