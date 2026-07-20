package com.fariszr.dualmate

import androidx.annotation.NonNull
import com.fariszr.dualmate.widget.WidgetNavigationExtras
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log

class MainActivity : FlutterActivity() {
    private var pendingRoute: String? = null
    private var pendingPayload: Map<String, Any?>? = null
    private var navigationChannel: MethodChannel? = null
    private var notificationSettingsChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

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

        notificationSettingsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.fariszr.dualmate/notification_settings"
        )
        notificationSettingsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openClassReminderNotificationSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    result.success(openNotificationSettings(channelId))
                }
                "openClassReminderBatterySettings" -> {
                    result.success(openClassReminderBatterySettings())
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

    private fun openNotificationSettings(channelId: String?): Boolean {
        return try {
            val settingsIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !channelId.isNullOrBlank()
            ) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                }
            } else {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            }
            startActivity(settingsIntent)
            true
        } catch (error: Exception) {
            Log.w("MainActivity", "Could not open notification settings", error)
            false
        }
    }

    private fun openClassReminderBatterySettings(): Boolean {
        if (Build.MANUFACTURER.equals("samsung", ignoreCase = true)) {
            val samsungIntent = Intent(
                "com.samsung.android.sm.ACTION_OPEN_CHECKABLE_LISTACTIVITY"
            ).apply {
                setPackage("com.samsung.android.lool")
                putExtra("activity_type", 2)
            }
            if (tryOpenSettings(samsungIntent)) return true
        }

        if (tryOpenSettings(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) {
            return true
        }

        return tryOpenSettings(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
        )
    }

    private fun tryOpenSettings(settingsIntent: Intent): Boolean {
        return try {
            startActivity(settingsIntent)
            true
        } catch (error: ActivityNotFoundException) {
            Log.w("MainActivity", "Could not open settings intent", error)
            false
        } catch (error: SecurityException) {
            Log.w("MainActivity", "Could not open settings intent", error)
            false
        }
    }
}
