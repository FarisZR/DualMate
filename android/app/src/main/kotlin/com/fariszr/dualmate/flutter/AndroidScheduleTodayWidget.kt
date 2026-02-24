package com.fariszr.dualmate.flutter

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.fariszr.dualmate.widget.WidgetHelper
import com.fariszr.dualmate.widget.now.ScheduleNowWidget
import com.fariszr.dualmate.widget.today.ScheduleTodayWidget
import com.fariszr.dualmate.widget.canteen.CanteenTodayWidget
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class AndroidScheduleTodayWidget : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestWidgetRefresh" -> {
                updateWidget()
                result.success(null)
            }
            "requestWidgetLaunchIntent" -> {
                updateWidgetLaunchIntent()
                result.success(null)
            }
            "disableWidget" -> {
                WidgetHelper(context).disableWidget()
                updateWidget()
                result.success(null)
            }
            "enableWidget" -> {
                WidgetHelper(context).enableWidget()
                updateWidget()
                result.success(null)
            }
            "areWidgetsSupported" -> {
                result.success(true)
            }
            "canScheduleExactAlarms" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    result.success(alarmManager.canScheduleExactAlarms())
                } else {
                    result.success(true)
                }
            }
            "requestExactAlarmPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                        Uri.parse("package:${context.packageName}")
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                }
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun updateWidget() {
        ScheduleTodayWidget.requestWidgetRefresh(context)
        ScheduleNowWidget.requestWidgetRefresh(context)
        CanteenTodayWidget.requestWidgetRefresh(context)
    }

    private fun updateWidgetLaunchIntent() {
        ScheduleNowWidget.requestWidgetLaunchIntent(context)
        ScheduleTodayWidget.requestWidgetLaunchIntent(context)
        CanteenTodayWidget.requestWidgetLaunchIntent(context)
    }

    companion object {
        const val CHANNEL_NAME = "com.fariszr.dualmate/widget"
    }

}
