package com.fariszr.dualmate

import android.app.Application
import com.jakewharton.threetenabp.AndroidThreeTen
import com.fariszr.dualmate.database.ScheduleProvider
import io.flutter.FlutterInjector
import org.threeten.bp.LocalDate

class ExtApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AndroidThreeTen.init(this)
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        ScheduleProvider(applicationContext).queryScheduleEntriesForDay(LocalDate.of(2020, 11, 18))
    }
}
