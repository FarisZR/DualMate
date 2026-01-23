package de.bennik2000.dhbwstudentapp

import androidx.annotation.NonNull
import de.bennik2000.dhbwstudentapp.flutter.AndroidScheduleTodayWidget
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private var pendingRoute: String? = null
    private var navigationChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        AndroidScheduleTodayWidget(applicationContext).setupMethodChannel(flutterEngine)

        navigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "de.bennik2000.dhbwstudentapp/navigation"
        )

        navigationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchRoute" -> result.success(pendingRoute)
                "clearLaunchRoute" -> {
                    pendingRoute = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        queueRoute(routeFromIntent(intent))
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        this.intent = intent
        queueRoute(routeFromIntent(intent))
    }

    private fun routeFromIntent(intent: android.content.Intent?): String? {
        return when (intent?.action) {
            "de.bennik2000.dhbwstudentapp.OPEN_SCHEDULE" -> "schedule"
            "de.bennik2000.dhbwstudentapp.OPEN_CANTEEN" -> "canteen"
            else -> null
        }
    }

    private fun queueRoute(route: String?) {
        if (route == null) return
        pendingRoute = route
        navigationChannel?.invokeMethod("openRoute", route)
    }
}
