package de.bennik2000.dhbwstudentapp.widget

import android.content.Context

class WidgetHelper(private val context: Context) {
    fun isWidgetEnabled(): Boolean {
        // Widgets are always enabled by default
        return true
    }

    fun enableWidget() {
        // No-op: widgets are always enabled
    }

    fun disableWidget() {
        // No-op: widgets are always enabled
    }
}
