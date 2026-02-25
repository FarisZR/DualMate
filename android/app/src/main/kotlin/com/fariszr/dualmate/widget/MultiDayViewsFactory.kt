package com.fariszr.dualmate.widget

import android.content.Context
import android.widget.AdapterView
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime

abstract class MultiDayViewsFactory<T>(
    protected val context: Context,
    private val appWidgetId: Int,
    private val rowMetrics: MultiDayWidgetHelper.RowMetrics
) : RemoteViewsService.RemoteViewsFactory {

    private var visibleRows: List<MultiDayWidgetHelper.DayRow<T>> = emptyList()
    private var dataUnavailable = false

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

        val visibleItems = prepareVisibleItems(row.items)
        if (visibleItems.items.isEmpty() && visibleItems.overflowCount == 0) {
            views.addView(
                getRowItemsContainerId(),
                buildEmptyView(row.isToday, dataUnavailable)
            )
            return views
        }

        val now = LocalDateTime.now()
        visibleItems.items.forEach { item ->
            views.addView(getRowItemsContainerId(), buildItemView(item, getItemState(item, now)))
        }

        if (visibleItems.overflowCount > 0) {
            views.addView(getRowItemsContainerId(), buildOverflowView(row.date, visibleItems.overflowCount))
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
    protected abstract fun buildOverflowView(date: LocalDate, overflowCount: Int): RemoteViews
    protected abstract fun buildEmptyView(isToday: Boolean, isDataUnavailable: Boolean): RemoteViews
    protected abstract fun getItemState(item: T, now: LocalDateTime): WidgetItemState
    protected abstract fun loadItemsForWeek(
        startDate: LocalDate,
        endDate: LocalDate
    ): MultiDayWidgetHelper.LoadResult<T>

    protected open fun prepareVisibleItems(items: List<T>): MultiDayWidgetHelper.VisibleItems<T> {
        return MultiDayWidgetHelper.VisibleItems(items, 0)
    }

    private fun reloadRows() {
        val today = LocalDate.now()
        val weekDates = MultiDayWidgetHelper.weekDates(today)
        val endDate = weekDates.last()
        val loadResult = loadItemsForWeek(today, endDate)

        if (!loadResult.successful) {
            if (visibleRows.isNotEmpty()) {
                return
            }

            dataUnavailable = true
            visibleRows = listOf(
                MultiDayWidgetHelper.DayRow(today, emptyList(), true)
            )
            return
        }

        dataUnavailable = false


        val allRows = weekDates.map { date ->
            MultiDayWidgetHelper.DayRow(
                date,
                loadResult.itemsByDate[date].orEmpty(),
                date == today
            )
        }

        val filteredRows = MultiDayWidgetHelper.filterWeekRows(allRows)
        visibleRows = filteredRows.ifEmpty { allRows.take(1) }
    }
}
