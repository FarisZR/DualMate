package de.bennik2000.dhbwstudentapp.flutter

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import de.bennik2000.dhbwstudentapp.widget.WidgetHelper
import de.bennik2000.dhbwstudentapp.widget.now.ScheduleNowWidget
import de.bennik2000.dhbwstudentapp.widget.canteen.CanteenTodayWidget
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class AndroidScheduleTodayWidget(private val context: Context) : MethodChannel.MethodCallHandler {
    fun setupMethodChannel(@NonNull flutterEngine: FlutterEngine) {
        MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "de.bennik2000.dhbwstudentapp/widget")
                .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestWidgetRefresh" -> {
                updateWidget()
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
        ScheduleNowWidget.requestWidgetRefresh(context)
        CanteenTodayWidget.requestWidgetRefresh(context)
    }


}
