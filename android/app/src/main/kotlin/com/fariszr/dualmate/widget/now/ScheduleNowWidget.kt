package com.fariszr.dualmate.widget.now

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.fariszr.dualmate.AlarmManagerUtils
import com.fariszr.dualmate.MainActivity
import com.fariszr.dualmate.R
import com.fariszr.dualmate.database.ScheduleProvider
import com.fariszr.dualmate.model.ScheduleEntry
import com.fariszr.dualmate.widget.WidgetHelper
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime

/**
 * Implementation of App Widget functionality.
 */
class ScheduleNowWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val entriesForDay = ScheduleProvider(context).queryScheduleEntriesForDay(LocalDate.now())

        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }

        scheduleWidgetUpdate(context, entriesForDay)
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        cancelWidgetUpdate(context)
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        Log.d("ScheduleNowWidget", "Updating widget with id $appWidgetId")

        val views = RemoteViews(context.packageName, R.layout.widget_schedule_now)


        if (WidgetHelper(context).isWidgetEnabled()) {
            views.setViewVisibility(R.id.layout_purchase, View.INVISIBLE)
            views.setViewVisibility(R.id.schedule_entries_list_view, View.VISIBLE)
            views.setOnClickPendingIntent(
                R.id.widget_click_overlay,
                PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java).apply {
                        action = "com.fariszr.dualmate.OPEN_SCHEDULE"
                    },
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
            updateScheduleEntryList(context, views, appWidgetManager, appWidgetId)
            views.setViewVisibility(R.id.layout_empty_state, View.INVISIBLE)
        } else {
            views.setViewVisibility(R.id.layout_empty_state, View.INVISIBLE)
            views.setViewVisibility(R.id.schedule_entries_list_view, View.INVISIBLE)
            views.setViewVisibility(R.id.layout_purchase, View.VISIBLE)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun updateScheduleEntryList(context: Context, views: RemoteViews, appWidgetManager: AppWidgetManager, id: Int) {
        val intent = Intent(context, NowScheduleEntryRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.schedule_entries_list_view, intent)

        appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.schedule_entries_list_view)
    }


    companion object {
        fun requestWidgetRefresh(context: Context) {
            val intent = getWidgetUpdateIntent(context)
            context.sendBroadcast(intent)
        }

        fun requestWidgetLaunchIntent(context: Context) {
            val ids: IntArray = AppWidgetManager
                    .getInstance(context.applicationContext)
                    .getAppWidgetIds(ComponentName(context, ScheduleNowWidget::class.java))

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    action = "com.fariszr.dualmate.OPEN_SCHEDULE"
                },
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.widget_schedule_now)
                views.setOnClickPendingIntent(R.id.widget_click_overlay, pendingIntent)
                AppWidgetManager.getInstance(context).updateAppWidget(id, views)
            }
        }

        private fun getWidgetUpdateIntent(context: Context): Intent {
            val intent = Intent(context, ScheduleNowWidget::class.java)

            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE

            val ids: IntArray = AppWidgetManager
                    .getInstance(context.applicationContext)
                    .getAppWidgetIds(ComponentName(context, ScheduleNowWidget::class.java))

            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)

            return intent
        }

        private fun scheduleWidgetUpdate(context: Context, entries: List<ScheduleEntry>) {
            val now = LocalDateTime.now()

            var updateAt = LocalDate
                    .now()
                    .plusDays(1)
                    .atStartOfDay()

            for (entry in entries) {
                if (entry.start.isAfter(now)) {
                    updateAt = entry.start
                    break
                }
                if (entry.end.isAfter(now)) {
                    updateAt = entry.end
                    break
                }
            }

            updateAt.plusSeconds(1)

            Log.d("ScheduleNowWidget", "Scheduling widget update at $updateAt")

            val intent = getWidgetUpdateIntent(context)
            AlarmManagerUtils.scheduleIntentAtExactTime(context, intent, updateAt)
        }

        private fun cancelWidgetUpdate(context: Context) {
            val intent = getWidgetUpdateIntent(context)
            AlarmManagerUtils.cancelIntent(context, intent)
        }
    }
}
