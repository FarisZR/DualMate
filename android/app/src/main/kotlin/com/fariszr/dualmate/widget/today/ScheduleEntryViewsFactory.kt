package com.fariszr.dualmate.widget.today

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

class ScheduleEntryViewsFactory(
    context: Context,
    appWidgetId: Int
) : MultiDayViewsFactory<ScheduleEntry>(context, appWidgetId, ROW_METRICS) {

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

    override fun buildItemView(item: ScheduleEntry, state: WidgetItemState): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_schedule_day_item)

        views.setTextViewText(R.id.text_view_item_title, item.title)

        val timeRange = "${item.start.format(timeFormatter)} - ${item.end.format(timeFormatter)}"
        val subtitle = if (item.room.isBlank()) timeRange else "$timeRange • ${item.room}"
        views.setTextViewText(R.id.text_view_item_subtitle, subtitle)

        val textColor = when (state) {
            WidgetItemState.PAST -> ContextCompat.getColor(context, R.color.widget_schedule_item_text_past)
            WidgetItemState.CURRENT -> ContextCompat.getColor(context, R.color.widget_schedule_item_text_current)
            WidgetItemState.FUTURE -> ContextCompat.getColor(context, R.color.widget_schedule_entry_text_color)
        }

        val accent = when (state) {
            WidgetItemState.PAST -> R.drawable.widget_schedule_item_accent_past
            WidgetItemState.CURRENT -> R.drawable.widget_schedule_item_accent_current
            WidgetItemState.FUTURE -> R.drawable.widget_schedule_item_accent_future
        }
        val background = when (state) {
            WidgetItemState.CURRENT -> R.drawable.widget_schedule_item_current_background
            else -> R.drawable.widget_schedule_item_past_background
        }

        views.setInt(R.id.layout_schedule_item, "setBackgroundResource", background)
        views.setInt(R.id.view_item_accent, "setBackgroundResource", accent)
        views.setTextColor(R.id.text_view_item_title, textColor)
        views.setTextColor(R.id.text_view_item_subtitle, textColor)

        return views
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
        items: List<ScheduleEntry>
    ): MultiDayWidgetHelper.VisibleItems<ScheduleEntry> {
        return MultiDayWidgetHelper.VisibleItems(items, 0)
    }

    override fun buildEmptyView(isToday: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_message_item)
        views.setTextViewText(R.id.day_message_text, context.getString(R.string.widget_schedule_empty_state))
        return views
    }

    override fun getItemState(item: ScheduleEntry, now: LocalDateTime): WidgetItemState {
        return MultiDayWidgetHelper.resolveItemState(item.start, item.end, now)
    }

    override fun loadItemsForWeek(
        startDate: LocalDate,
        endDate: LocalDate
    ): Map<LocalDate, List<ScheduleEntry>> {
        val entries = ScheduleProvider(context).queryScheduleEntriesBetween(
            startDate.atStartOfDay(),
            endDate.plusDays(1).atStartOfDay()
        )

        return entries.groupBy { entry -> entry.start.toLocalDate() }
    }

    companion object {
        private val ROW_METRICS = MultiDayWidgetHelper.RowMetrics(
            headerHeightDp = 48,
            rowVerticalPaddingDp = 12,
            dateColumnMinHeightDp = 36,
            itemHeightDp = 20,
            maxItemsPerRow = 4
        )
    }
}
