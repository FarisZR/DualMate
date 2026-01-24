package de.bennik2000.dhbwstudentapp.widget.canteen

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.widget.RemoteViewsService

class CanteenRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        return CanteenEntryViewsFactory(this.applicationContext, widgetId)
    }
}
