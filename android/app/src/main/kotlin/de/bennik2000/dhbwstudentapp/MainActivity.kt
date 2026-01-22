package de.bennik2000.dhbwstudentapp

import androidx.annotation.NonNull
import de.bennik2000.dhbwstudentapp.flutter.AndroidScheduleTodayWidget
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun getInitialRoute(): String? {
        return when (intent?.action) {
            "de.bennik2000.dhbwstudentapp.OPEN_SCHEDULE" -> "schedule"
            "de.bennik2000.dhbwstudentapp.OPEN_CANTEEN" -> "canteen"
            else -> super.getInitialRoute()
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        this.intent = intent

        val route = when (intent.action) {
            "de.bennik2000.dhbwstudentapp.OPEN_SCHEDULE" -> "schedule"
            "de.bennik2000.dhbwstudentapp.OPEN_CANTEEN" -> "canteen"
            else -> null
        }

        if (route != null) {
            flutterEngine?.navigationChannel?.pushRoute(route)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        AndroidScheduleTodayWidget(applicationContext).setupMethodChannel(flutterEngine)
    }
}
