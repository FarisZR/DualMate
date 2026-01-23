package de.bennik2000.dhbwstudentapp.widget.today

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.util.Log
import android.widget.RemoteViewsService
import de.bennik2000.dhbwstudentapp.widget.today.ScheduleEntryViewsFactory

class TodayScheduleEntryRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent?): RemoteViewsFactory {
        Log.d("ScheduleEntryRemoteView", "Creating ScheduleEntryViewsFactory")
        
        // Get the widget size to determine how many days to show
        val appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        
        val numDays = intent?.getIntExtra("numDays", 1) ?: 1
        
        return ScheduleEntryViewsFactory(applicationContext, numDays)
    }
}