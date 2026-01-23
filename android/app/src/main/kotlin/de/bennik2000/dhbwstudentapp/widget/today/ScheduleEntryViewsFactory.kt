package de.bennik2000.dhbwstudentapp.widget.today

import android.content.Context
import android.widget.AdapterView
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import de.bennik2000.dhbwstudentapp.R
import de.bennik2000.dhbwstudentapp.database.ScheduleProvider
import de.bennik2000.dhbwstudentapp.model.ScheduleEntry
import org.threeten.bp.LocalDate
import org.threeten.bp.format.DateTimeFormatter
import java.util.Locale


class ScheduleEntryViewsFactory(private val context: Context, private val numDays: Int = 1) : RemoteViewsService.RemoteViewsFactory {

    private var items: ArrayList<WidgetListItem> = ArrayList()
    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")
    private val dateFormatter = DateTimeFormatter.ofPattern("EEEE, dd.MM.yyyy", Locale.getDefault())

    companion object {
        private const val VIEW_TYPE_DATE_HEADER = 0
        private const val VIEW_TYPE_SCHEDULE_ENTRY = 1
    }

    override fun onCreate() {
        loadScheduleEntries()
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getItemId(position: Int): Long {
        val item = items.getOrNull(position) ?: return position.toLong()
        return when (item) {
            is WidgetListItem.DateHeader -> {
                // Use date's epoch day as a unique ID for date headers
                item.date.toEpochDay()
            }
            is WidgetListItem.ScheduleEntryItem -> {
                // Use entry ID plus an offset to avoid collision with date headers
                // Date headers use epoch days (small numbers), entries use large IDs
                10000000L + item.entry.id.toLong()
            }
        }
    }

    override fun onDataSetChanged() {
        loadScheduleEntries()
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    override fun getViewAt(position: Int): RemoteViews? {
        if (position == AdapterView.INVALID_POSITION || position >= items.size) {
            return null
        }

        val item = items[position]

        return when (item) {
            is WidgetListItem.DateHeader -> createDateHeaderView(item.date)
            is WidgetListItem.ScheduleEntryItem -> createScheduleEntryView(item.entry)
        }
    }

    private fun createDateHeaderView(date: LocalDate): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.widget_date_header)
        rv.setTextViewText(R.id.text_view_date_header, date.format(dateFormatter))
        return rv
    }

    private fun createScheduleEntryView(entry: ScheduleEntry): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.widget_schedule_entry_list_item)

        rv.setTextViewText(R.id.text_view_entry_title, entry.title)
        rv.setTextViewText(R.id.text_view_time_start, entry.start.format(timeFormatter))
        rv.setTextViewText(R.id.text_view_time_end, entry.end.format(timeFormatter))
        rv.setTextViewText(R.id.text_view_entry_professor, entry.professor)
        rv.setTextViewText(R.id.text_view_entry_room, entry.room)

        val background = arrayOf(
                R.drawable.schedule_entry_unknown_background,
                R.drawable.schedule_entry_class_background,
                R.drawable.schedule_entry_online_background,
                R.drawable.schedule_entry_holiday_background,
                R.drawable.schedule_entry_exam_background
        )

        if (entry.type >= 0 && entry.type < background.size) {
            rv.setInt(R.id.layout_schedule_entry, "setBackgroundResource", background[entry.type])
        }

        return rv
    }

    override fun getCount(): Int {
        return items.size
    }

    override fun getViewTypeCount(): Int {
        return 2  // Date header and schedule entry
    }

    override fun onDestroy() {
    }

    private fun loadScheduleEntries() {
        items.clear()
        val provider = ScheduleProvider(context)
        
        // Load entries for multiple days
        val startDate = LocalDate.now()
        val entries = provider.queryScheduleEntriesForDays(startDate, numDays)
        
        // Group entries by date
        val entriesByDate = entries.groupBy { it.start.toLocalDate() }
        
        // Build items list with date headers
        for (dayOffset in 0 until numDays) {
            val date = startDate.plusDays(dayOffset.toLong())
            val dayEntries = entriesByDate[date] ?: emptyList()
            
            // Only add date header if we have multiple days
            if (numDays > 1) {
                items.add(WidgetListItem.DateHeader(date))
            }
            
            // Add entries for this day
            for (entry in dayEntries) {
                items.add(WidgetListItem.ScheduleEntryItem(entry))
            }
        }
    }
}
