package de.bennik2000.dhbwstudentapp.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.AdapterView
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime
import kotlin.math.max

abstract class MultiDayViewsFactory<T>(
    protected val context: Context,
    private val appWidgetId: Int,
    private val rowMetrics: MultiDayWidgetHelper.RowMetrics
) : RemoteViewsService.RemoteViewsFactory {

    private val appWidgetManager = AppWidgetManager.getInstance(context)
    private var visibleRows: List<MultiDayWidgetHelper.DayRow<T>> = emptyList()

    override fun onCreate() {
        reloadRows()
    }

    override fun onDataSetChanged() {
        reloadRows()
    }

    override fun onDestroy() {
    }

    override fun getCount(): Int {
        return visibleRows.size
    }

    override fun getViewAt(position: Int): RemoteViews? {
        if (position == AdapterView.INVALID_POSITION || position >= visibleRows.size) {
            return null
        }

        val row = visibleRows[position]
        val views = RemoteViews(context.packageName, getRowLayoutId())
        bindDayHeader(views, row.date, row.isToday)

        views.removeAllViews(getRowItemsContainerId())

        if (row.items.isEmpty()) {
            views.addView(getRowItemsContainerId(), buildEmptyView(row.isToday))
            return views
        }

        val now = LocalDateTime.now()
        val visibleItems = MultiDayWidgetHelper.limitItems(row.items, rowMetrics.maxItemsPerRow)

        visibleItems.items.forEach { item ->
            views.addView(getRowItemsContainerId(), buildItemView(item, getItemState(item, now)))
        }

        if (visibleItems.overflowCount > 0) {
            views.addView(getRowItemsContainerId(), buildOverflowView(visibleItems.overflowCount))
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return visibleRows[position].date.toEpochDay()
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    protected abstract fun getRowLayoutId(): Int
    protected abstract fun getRowItemsContainerId(): Int
    protected abstract fun bindDayHeader(views: RemoteViews, date: LocalDate, isToday: Boolean)
    protected abstract fun buildItemView(item: T, state: WidgetItemState): RemoteViews
    protected abstract fun buildOverflowView(overflowCount: Int): RemoteViews
    protected abstract fun buildEmptyView(isToday: Boolean): RemoteViews
    protected abstract fun getItemState(item: T, now: LocalDateTime): WidgetItemState
    protected abstract fun loadItemsForWeek(startDate: LocalDate, endDate: LocalDate): Map<LocalDate, List<T>>

    private fun reloadRows() {
        val today = LocalDate.now()
        val weekDates = MultiDayWidgetHelper.weekDates(today)
        val endDate = weekDates.last()
        val itemsByDate = loadItemsForWeek(today, endDate)


        val allRows = weekDates.map { date ->
            MultiDayWidgetHelper.DayRow(date, itemsByDate[date].orEmpty(), date == today)
        }

        val filteredRows = MultiDayWidgetHelper.filterWeekRows(allRows)
        val widgetHeight = getWidgetHeightDp()
        val visibleCount = MultiDayWidgetHelper.calculateVisibleDayCount(
            widgetHeight,
            filteredRows,
            rowMetrics
        )

        visibleRows = filteredRows.take(visibleCount).ifEmpty { filteredRows.take(1) }
    }

    private fun getWidgetHeightDp(): Int {
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            return rowMetrics.headerHeightDp + rowMetrics.dateColumnMinHeightDp
        }
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minHeight = options.getInt(
            AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,
            rowMetrics.headerHeightDp
        )
        val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight)
        return max(minHeight, maxHeight)
    }
}
