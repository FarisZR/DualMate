package de.bennik2000.dhbwstudentapp.widget.canteen

import android.content.Intent
import android.widget.RemoteViewsService

class CanteenRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CanteenEntryViewsFactory(this.applicationContext)
    }
}
