package com.fariszr.dualmate.widget.now

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.fariszr.dualmate.R
import com.fariszr.dualmate.database.ScheduleProvider
import com.fariszr.dualmate.model.ScheduleEntry
import com.fariszr.dualmate.widget.MultiDayViewsFactory
import com.fariszr.dualmate.widget.MultiDayWidgetHelper
import com.fariszr.dualmate.widget.WidgetNavigationExtras
import com.fariszr.dualmate.widget.WidgetItemState
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime
import org.threeten.bp.OffsetDateTime
import org.threeten.bp.format.DateTimeFormatter
import java.util.Locale

class NowScheduleEntryViewsFactory(
    context: Context,
    appWidgetId: Int
) : MultiDayViewsFactory<ScheduleWidgetItem>(context, appWidgetId, ROW_METRICS) {

    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.getDefault())
    private val dayFormatter = DateTimeFormatter.ofPattern("EEE", Locale.getDefault())
    private val dateFormatter = DateTimeFormatter.ofPattern("d", Locale.getDefault())
    private val zoneOffset = OffsetDateTime.now().offset

    override fun getRowLayoutId(): Int {
        return R.layout.widget_day_row
    }

    override fun getRowItemsContainerId(): Int {
        return R.id.day_items_container
    }

    override fun bindDayHeader(views: RemoteViews, date: LocalDate, isToday: Boolean) {
        views.setTextViewText(R.id.day_label, dayFormatter.format(date))
        views.setTextViewText(R.id.date_label, dateFormatter.format(date))
        val dayStartMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
        val dayIntent = Intent().putExtra(WidgetNavigationExtras.scheduleDayStart, dayStartMillis)
        views.setOnClickFillInIntent(
            R.id.day_header_container,
            dayIntent
        )
        views.setOnClickFillInIntent(
            R.id.day_items_container,
            dayIntent
        )
    }

    override fun buildItemView(item: ScheduleWidgetItem, state: WidgetItemState): RemoteViews {
        if (ScheduleWidgetMarkerHelper.isMarkerEntry(item.entry)) {
            return buildMarkerItemView(item, state)
        }

        val views = RemoteViews(context.packageName, R.layout.widget_schedule_day_item)
        views.setTextViewText(R.id.text_view_item_title, item.entry.title)

        val timeRange = "${item.entry.start.format(timeFormatter)} - ${item.entry.end.format(timeFormatter)}"
        val subtitle = if (item.entry.room.isBlank()) timeRange else "$timeRange • ${item.entry.room}"
        views.setTextViewText(R.id.text_view_item_subtitle, subtitle)

        val textColor = resolveTextColor(state)
        val accent = resolveAccent(state)
        val background = resolveBackground(state)

        views.setInt(R.id.layout_schedule_item, "setBackgroundResource", background)
        views.setInt(R.id.view_item_accent, "setBackgroundResource", accent)
        views.setTextColor(R.id.text_view_item_title, textColor)
        views.setTextColor(R.id.text_view_item_subtitle, textColor)

        return views
    }

    private fun buildMarkerItemView(item: ScheduleWidgetItem, state: WidgetItemState): RemoteViews {
        val views = RemoteViews(context.packageName, markerLayoutId(item))
        views.setTextViewText(R.id.text_view_item_title, item.entry.title)

        val textColor = resolveTextColor(state)
        val accent = markerAccentDrawable(item.entry)
        val background = resolveBackground(state)

        views.setInt(R.id.layout_schedule_item, "setBackgroundResource", background)
        views.setInt(R.id.view_item_accent, "setBackgroundResource", accent)
        views.setTextColor(R.id.text_view_item_title, textColor)

        return views
    }

    private fun resolveTextColor(state: WidgetItemState): Int {
        return when (state) {
            WidgetItemState.PAST -> ContextCompat.getColor(context, R.color.widget_schedule_item_text_past)
            WidgetItemState.CURRENT -> ContextCompat.getColor(context, R.color.widget_schedule_item_text_current)
            WidgetItemState.FUTURE -> ContextCompat.getColor(context, R.color.widget_schedule_entry_text_color)
        }
    }

    private fun resolveAccent(state: WidgetItemState): Int {
        return when (state) {
            WidgetItemState.PAST -> R.drawable.widget_schedule_item_accent_past
            WidgetItemState.CURRENT -> R.drawable.widget_schedule_item_accent_current
            WidgetItemState.FUTURE -> R.drawable.widget_schedule_item_accent_future
        }
    }

    private fun resolveBackground(state: WidgetItemState): Int {
        return when (state) {
            WidgetItemState.CURRENT -> R.drawable.widget_schedule_item_current_background
            else -> R.drawable.widget_schedule_item_past_background
        }
    }

    override fun buildOverflowView(date: LocalDate, overflowCount: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_message_item)
        views.setTextViewText(
            R.id.day_message_text,
            context.getString(R.string.widget_schedule_overflow, overflowCount)
        )
        val dayStartMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
        views.setOnClickFillInIntent(
            R.id.day_message_text,
            Intent().putExtra(WidgetNavigationExtras.scheduleDayStart, dayStartMillis)
        )
        return views
    }

    override fun prepareVisibleItems(
        items: List<ScheduleWidgetItem>
    ): MultiDayWidgetHelper.VisibleItems<ScheduleWidgetItem> {
        return MultiDayWidgetHelper.VisibleItems(items, 0)
    }

    override fun buildEmptyView(isToday: Boolean, isDataUnavailable: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_message_item)
        val message = if (isDataUnavailable) {
            R.string.widget_schedule_unavailable_state
        } else {
            R.string.widget_schedule_empty_state
        }
        views.setTextViewText(R.id.day_message_text, context.getString(message))
        return views
    }

    override fun getItemState(item: ScheduleWidgetItem, now: LocalDateTime): WidgetItemState {
        return MultiDayWidgetHelper.resolveItemState(item.entry.start, item.entry.end, now)
    }

    override fun loadItemsForWeek(
        startDate: LocalDate,
        endDate: LocalDate
    ): MultiDayWidgetHelper.LoadResult<ScheduleWidgetItem> {
        val queryResult = ScheduleProvider(context).queryScheduleEntriesBetweenWithStatus(
            startDate.atStartOfDay(),
            endDate.plusDays(1).atStartOfDay()
        )

        return MultiDayWidgetHelper.LoadResult(
            queryResult.entries
                .groupBy { entry -> entry.start.toLocalDate() }
                .mapValues { (_, entries) -> prepareDayItems(entries) },
            queryResult.successful
        )
    }

    companion object {
        private val ROW_METRICS = MultiDayWidgetHelper.RowMetrics(
            headerHeightDp = 0,
            rowVerticalPaddingDp = 12,
            dateColumnMinHeightDp = 36,
            itemHeightDp = 20,
            maxItemsPerRow = 4
        )

        internal fun prepareDayItems(entries: List<ScheduleEntry>): List<ScheduleWidgetItem> {
            val orderedEntries = ScheduleWidgetMarkerHelper.orderEntriesForDisplay(entries)
            val usesFullHeightMarkerLayout =
                orderedEntries.size == 1 && ScheduleWidgetMarkerHelper.isMarkerOnlyDay(orderedEntries)

            return orderedEntries.map { entry ->
                ScheduleWidgetItem(entry, usesFullHeightMarkerLayout)
            }
        }

        internal fun markerLayoutId(item: ScheduleWidgetItem): Int {
            return if (item.usesFullHeightMarkerLayout) {
                R.layout.widget_schedule_day_marker_full_item
            } else {
                R.layout.widget_schedule_day_marker_item
            }
        }

        internal fun markerAccentDrawable(entry: ScheduleEntry): Int {
            return when (entry.type) {
                ScheduleEntry.PUBLIC_HOLIDAY_TYPE -> R.drawable.widget_schedule_item_accent_marker_holiday
                ScheduleEntry.EXAM_TYPE -> R.drawable.widget_schedule_item_accent_marker_exam
                ScheduleEntry.SPECIAL_EVENT_TYPE -> R.drawable.widget_schedule_item_accent_marker_special_event
                else -> R.drawable.widget_schedule_item_accent_marker_unknown
            }
        }
    }
}
