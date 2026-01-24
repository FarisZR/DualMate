package de.bennik2000.dhbwstudentapp.widget.today

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.util.Log
import android.widget.RemoteViewsService

class TodayScheduleEntryRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent?): RemoteViewsFactory {
        Log.d("ScheduleEntryRemoteView", "Creating ScheduleEntryViewsFactory")
        val widgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        return ScheduleEntryViewsFactory(applicationContext, widgetId)
    }
}
