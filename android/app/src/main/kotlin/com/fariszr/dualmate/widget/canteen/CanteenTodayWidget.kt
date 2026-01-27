package com.fariszr.dualmate.widget.canteen

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.fariszr.dualmate.MainActivity
import com.fariszr.dualmate.R
import com.fariszr.dualmate.widget.WidgetHelper

class CanteenTodayWidget : AppWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.canteen_entries_list_view)
    }

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
            Intent(context, MainActivity::class.java).apply {
                action = "com.fariszr.dualmate.OPEN_CANTEEN"
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_click_overlay, pendingIntent)

        if (WidgetHelper(context).isWidgetEnabled()) {
            views.setViewVisibility(R.id.layout_purchase, View.INVISIBLE)
            views.setViewVisibility(R.id.canteen_entries_list_view, View.VISIBLE)

            updateCanteenEntryList(context, views, appWidgetManager, appWidgetId)
            views.setViewVisibility(R.id.layout_empty_state, View.INVISIBLE)
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
        val intent = Intent(context, CanteenRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.canteen_entries_list_view, intent)

        appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.canteen_entries_list_view)
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

        fun requestWidgetLaunchIntent(context: Context) {
            val ids: IntArray = AppWidgetManager
                .getInstance(context.applicationContext)
                .getAppWidgetIds(ComponentName(context, CanteenTodayWidget::class.java))

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    action = "com.fariszr.dualmate.OPEN_CANTEEN"
                },
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.widget_canteen_today)
                views.setOnClickPendingIntent(R.id.widget_click_overlay, pendingIntent)
                AppWidgetManager.getInstance(context).updateAppWidget(id, views)
            }
        }
    }
}
