package de.bennik2000.dhbwstudentapp.widget.canteen

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import de.bennik2000.dhbwstudentapp.MainActivity
import de.bennik2000.dhbwstudentapp.R
import de.bennik2000.dhbwstudentapp.database.CanteenProvider
import de.bennik2000.dhbwstudentapp.widget.WidgetHelper
import org.threeten.bp.LocalDate

class CanteenTodayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        Log.d("CanteenTodayWidget", "Updating widget with id $appWidgetId")

        val views = RemoteViews(context.packageName, R.layout.widget_canteen_today)

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        if (WidgetHelper(context).isWidgetEnabled()) {
            views.setViewVisibility(R.id.layout_purchase, View.INVISIBLE)
            views.setViewVisibility(R.id.canteen_entries_list_view, View.VISIBLE)

            val hasEntries = CanteenProvider(context).hasMealsForDay(LocalDate.now())

            updateCanteenEntryList(context, views, appWidgetManager, appWidgetId)
            updateCanteenListEmptyState(views, hasEntries)
        } else {
            views.setViewVisibility(R.id.layout_empty_state, View.INVISIBLE)
            views.setViewVisibility(R.id.canteen_entries_list_view, View.INVISIBLE)
            views.setViewVisibility(R.id.layout_purchase, View.VISIBLE)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun updateCanteenEntryList(
        context: Context,
        views: RemoteViews,
        appWidgetManager: AppWidgetManager,
        id: Int
    ) {
        val intent = Intent(context, CanteenRemoteViewsService::class.java)
        views.setRemoteAdapter(R.id.canteen_entries_list_view, intent)

        appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.canteen_entries_list_view)
    }

    private fun updateCanteenListEmptyState(views: RemoteViews, hasEntries: Boolean) {
        val visibility = if (hasEntries) View.INVISIBLE else View.VISIBLE
        views.setViewVisibility(R.id.layout_empty_state, visibility)
    }

    companion object {
        fun requestWidgetRefresh(context: Context) {
            val intent = Intent(context, CanteenTodayWidget::class.java)

            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE

            val ids: IntArray = AppWidgetManager
                .getInstance(context.applicationContext)
                .getAppWidgetIds(ComponentName(context, CanteenTodayWidget::class.java))

            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }
}
