package de.bennik2000.dhbwstudentapp.widget.today

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import de.bennik2000.dhbwstudentapp.MainActivity
import de.bennik2000.dhbwstudentapp.R
import de.bennik2000.dhbwstudentapp.database.ScheduleProvider
import de.bennik2000.dhbwstudentapp.widget.WidgetHelper
import org.threeten.bp.LocalDate
import kotlin.math.max

class ScheduleTodayWidget : AppWidgetProvider() {
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        Log.d("ScheduleTodayWidget", "Updating widget with id $appWidgetId")

        val views = RemoteViews(context.packageName, R.layout.widget_schedule_today)

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                action = "de.bennik2000.dhbwstudentapp.OPEN_SCHEDULE"
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_click_overlay, pendingIntent)

        if(WidgetHelper(context).isWidgetEnabled()) {
            views.setViewVisibility(R.id.layout_purchase, View.INVISIBLE)
            views.setViewVisibility(R.id.schedule_entries_list_view, View.VISIBLE)

            // Calculate number of days based on widget height
            val numDays = calculateNumDaysFromHeight(appWidgetManager, appWidgetId)
            Log.d("ScheduleTodayWidget", "Showing $numDays days")

            val hasEntries = hasScheduleEntriesForDays(context, numDays)

            updateScheduleEntryList(context, views, appWidgetManager, appWidgetId, numDays)
            updateScheduleListEmptyState(views, hasEntries)
        }
        else {
            views.setViewVisibility(R.id.layout_empty_state, View.INVISIBLE)
            views.setViewVisibility(R.id.schedule_entries_list_view, View.INVISIBLE)
            views.setViewVisibility(R.id.layout_purchase, View.VISIBLE)
        }


        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun calculateNumDaysFromHeight(appWidgetManager: AppWidgetManager, appWidgetId: Int): Int {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        
        // Calculate number of days based on height
        // Each day roughly needs 120dp (title bar 48dp + minimum space for entries ~70dp + date header if multiple days)
        return when {
            minHeight < HEIGHT_THRESHOLD_2_DAYS -> 1
            minHeight < HEIGHT_THRESHOLD_3_DAYS -> 2
            minHeight < HEIGHT_THRESHOLD_4_DAYS -> 3
            minHeight < HEIGHT_THRESHOLD_5_DAYS -> 4
            minHeight < HEIGHT_THRESHOLD_6_DAYS -> 5
            minHeight < HEIGHT_THRESHOLD_7_DAYS -> 6
            else -> 7  // Maximum 7 days (one week)
        }.also { 
            Log.d("ScheduleTodayWidget", "Widget height: ${minHeight}dp, showing $it days")
        }
    }

    private fun hasScheduleEntriesForDays(context: Context, numDays: Int): Boolean {
        val provider = ScheduleProvider(context)
        for (i in 0 until numDays) {
            if (provider.hasScheduleEntriesForDay(LocalDate.now().plusDays(i.toLong()))) {
                return true
            }
        }
        return false
    }

    private fun updateScheduleEntryList(
        context: Context, 
        views: RemoteViews, 
        appWidgetManager: AppWidgetManager, 
        id: Int,
        numDays: Int
    ) {
        val intent = Intent(context, TodayScheduleEntryRemoteViewsService::class.java)
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        intent.putExtra("numDays", numDays)
        views.setRemoteAdapter(R.id.schedule_entries_list_view, intent)

        appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.schedule_entries_list_view)
    }

    private fun updateScheduleListEmptyState(views: RemoteViews, hasEntries: Boolean) {
        var visibility = View.VISIBLE

        if (hasEntries) {
            visibility = View.INVISIBLE
        }

        views.setViewVisibility(R.id.layout_empty_state, visibility)
    }


    companion object {
        // Height thresholds in dp for determining number of days to display
        private const val HEIGHT_THRESHOLD_2_DAYS = 200
        private const val HEIGHT_THRESHOLD_3_DAYS = 320
        private const val HEIGHT_THRESHOLD_4_DAYS = 440
        private const val HEIGHT_THRESHOLD_5_DAYS = 560
        private const val HEIGHT_THRESHOLD_6_DAYS = 680
        private const val HEIGHT_THRESHOLD_7_DAYS = 800
        
        fun requestWidgetRefresh(context: Context) {
            val intent = Intent(context, ScheduleTodayWidget::class.java)

            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE

            val ids: IntArray = AppWidgetManager
                    .getInstance(context.applicationContext)
                    .getAppWidgetIds(ComponentName(context, ScheduleTodayWidget::class.java))

            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }

        fun requestWidgetLaunchIntent(context: Context) {
            val ids: IntArray = AppWidgetManager
                    .getInstance(context.applicationContext)
                    .getAppWidgetIds(ComponentName(context, ScheduleTodayWidget::class.java))

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    action = "de.bennik2000.dhbwstudentapp.OPEN_SCHEDULE"
                },
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.widget_schedule_today)
                views.setOnClickPendingIntent(R.id.widget_click_overlay, pendingIntent)
                AppWidgetManager.getInstance(context).updateAppWidget(id, views)
            }
        }
    }
}
