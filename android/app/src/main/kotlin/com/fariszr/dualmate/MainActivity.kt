package com.fariszr.dualmate

import androidx.annotation.NonNull
import com.fariszr.dualmate.flutter.AndroidScheduleTodayWidget
import com.fariszr.dualmate.widget.WidgetNavigationExtras
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.util.Log

class MainActivity : FlutterActivity() {
    private var pendingRoute: String? = null
    private var pendingPayload: Map<String, Any?>? = null
    private var navigationChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        flutterEngine.plugins.add(AndroidScheduleTodayWidget())

        navigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.fariszr.dualmate/navigation"
        )

        navigationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchRoute" -> result.success(pendingRoute)
                "clearLaunchRoute" -> {
                    pendingRoute = null
                    result.success(null)
                }
                "getLaunchPayload" -> result.success(pendingPayload)
                "clearLaunchPayload" -> {
                    pendingPayload = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        queueRoute(routeFromIntent(intent), payloadFromIntent(intent))
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        this.intent = intent
        queueRoute(routeFromIntent(intent), payloadFromIntent(intent))
    }

    private fun routeFromIntent(intent: android.content.Intent?): String? {
        return when (intent?.action) {
            "com.fariszr.dualmate.OPEN_SCHEDULE" -> "schedule"
            "com.fariszr.dualmate.OPEN_CANTEEN" -> "canteen"
            else -> null
        }
    }

    private fun payloadFromIntent(intent: android.content.Intent?): Map<String, Any?>? {
        val extras = intent?.extras ?: return null
        val payload = HashMap<String, Any?>()

        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryId)) {
            payload[WidgetNavigationExtras.scheduleEntryId] =
                extras.getInt(WidgetNavigationExtras.scheduleEntryId)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryStart)) {
            payload[WidgetNavigationExtras.scheduleEntryStart] =
                extras.getLong(WidgetNavigationExtras.scheduleEntryStart)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryEnd)) {
            payload[WidgetNavigationExtras.scheduleEntryEnd] =
                extras.getLong(WidgetNavigationExtras.scheduleEntryEnd)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryTitle)) {
            payload[WidgetNavigationExtras.scheduleEntryTitle] =
                extras.getString(WidgetNavigationExtras.scheduleEntryTitle)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryDetails)) {
            payload[WidgetNavigationExtras.scheduleEntryDetails] =
                extras.getString(WidgetNavigationExtras.scheduleEntryDetails)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryProfessor)) {
            payload[WidgetNavigationExtras.scheduleEntryProfessor] =
                extras.getString(WidgetNavigationExtras.scheduleEntryProfessor)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryRoom)) {
            payload[WidgetNavigationExtras.scheduleEntryRoom] =
                extras.getString(WidgetNavigationExtras.scheduleEntryRoom)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleEntryType)) {
            payload[WidgetNavigationExtras.scheduleEntryType] =
                extras.getInt(WidgetNavigationExtras.scheduleEntryType)
        }
        if (extras.containsKey(WidgetNavigationExtras.scheduleDayStart)) {
            payload[WidgetNavigationExtras.scheduleDayStart] =
                extras.getLong(WidgetNavigationExtras.scheduleDayStart)
        }
        if (extras.containsKey(WidgetNavigationExtras.canteenDayStart)) {
            payload[WidgetNavigationExtras.canteenDayStart] =
                extras.getLong(WidgetNavigationExtras.canteenDayStart)
        }

        if (payload.isEmpty()) {
            return null
        }

        Log.d("MainActivity", "Widget payload keys: ${payload.keys}")

        return payload
    }

    private fun queueRoute(route: String?, payload: Map<String, Any?>?) {
        if (route == null) return
        pendingRoute = route
        pendingPayload = payload
        if (payload != null) {
            val arguments = HashMap<String, Any?>()
            arguments["route"] = route
            arguments["payload"] = payload
            navigationChannel?.invokeMethod("openRoute", arguments)
        } else {
            navigationChannel?.invokeMethod("openRoute", route)
        }
    }
}
