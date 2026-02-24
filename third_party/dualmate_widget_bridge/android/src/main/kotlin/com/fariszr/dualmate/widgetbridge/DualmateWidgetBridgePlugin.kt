package com.fariszr.dualmate.widgetbridge

import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DualmateWidgetBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Widget bridge is not attached to an engine", null)
            return
        }

        when (call.method) {
            "requestWidgetRefresh", "requestWidgetLaunchIntent" -> {
                refreshAllWidgets(ctx)
                result.success(null)
            }
            "disableWidget" -> {
                setWidgetEnabled(ctx, false)
                refreshAllWidgets(ctx)
                result.success(null)
            }
            "enableWidget" -> {
                setWidgetEnabled(ctx, true)
                refreshAllWidgets(ctx)
                result.success(null)
            }
            "areWidgetsSupported" -> {
                result.success(true)
            }
            "canScheduleExactAlarms" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    result.success(alarmManager.canScheduleExactAlarms())
                } else {
                    result.success(true)
                }
            }
            "requestExactAlarmPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                        Uri.parse("package:${ctx.packageName}"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        ctx.startActivity(intent)
                    } catch (exception: ActivityNotFoundException) {
                        Log.w(TAG, "Exact alarm permission screen unavailable", exception)
                    }
                }
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun setWidgetEnabled(context: Context, isEnabled: Boolean) {
        val preferences =
            context.getSharedPreferences(
                "${context.packageName}.widget_preferences",
                Context.MODE_PRIVATE,
            )
        preferences.edit().putBoolean("isWidgetEnabled", isEnabled).apply()
    }

    private fun refreshAllWidgets(context: Context) {
        refreshWidgetProvider(context, "${context.packageName}.widget.today.ScheduleTodayWidget")
        refreshWidgetProvider(context, "${context.packageName}.widget.now.ScheduleNowWidget")
        refreshWidgetProvider(context, "${context.packageName}.widget.canteen.CanteenTodayWidget")
    }

    private fun refreshWidgetProvider(context: Context, providerClassName: String) {
        try {
            val widgetClass =
                Class
                    .forName(providerClassName)
                    .asSubclass(AppWidgetProvider::class.java)

            val appWidgetManager = AppWidgetManager.getInstance(context.applicationContext)
            val component = ComponentName(context, widgetClass)
            val widgetIds = appWidgetManager.getAppWidgetIds(component)
            if (widgetIds.isEmpty()) {
                return
            }

            val updateIntent = Intent(context, widgetClass).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            }

            context.sendBroadcast(updateIntent)
        } catch (_: ClassNotFoundException) {
            // Optional widget provider for this build flavor.
        } catch (_: IllegalArgumentException) {
            // Provider type mismatch.
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.fariszr.dualmate/widget"
        private const val TAG = "DualmateWidgetBridge"
    }
}
