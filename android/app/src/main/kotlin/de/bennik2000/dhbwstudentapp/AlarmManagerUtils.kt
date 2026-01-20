package de.bennik2000.dhbwstudentapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.threeten.bp.LocalDateTime
import org.threeten.bp.OffsetDateTime

class AlarmManagerUtils {
    companion object {
        fun scheduleIntentAtExactTime(context: Context, intent: Intent, scheduleAt: LocalDateTime) {
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, pendingIntentFlags)
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val zoneOffset = OffsetDateTime.now().offset
            val updateAtMillis = scheduleAt.toEpochSecond(zoneOffset) * 1000

            alarmManager.cancel(pendingIntent)

            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager
                                .setExactAndAllowWhileIdle(
                                        AlarmManager.RTC_WAKEUP,
                                        updateAtMillis,
                                        pendingIntent)
                    } else {
                        alarmManager
                                .setAndAllowWhileIdle(
                                        AlarmManager.RTC_WAKEUP,
                                        updateAtMillis,
                                        pendingIntent)
                    }
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager
                            .setExactAndAllowWhileIdle(
                                    AlarmManager.RTC_WAKEUP,
                                    updateAtMillis,
                                    pendingIntent)
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager
                            .setExact(AlarmManager.RTC_WAKEUP,
                                    updateAtMillis,
                                    pendingIntent)
                }
                else -> {
                    alarmManager
                            .set(AlarmManager.RTC_WAKEUP,
                                    updateAtMillis,
                                    pendingIntent)
                }
            }
        }
        
        fun cancelIntent(context: Context, intent: Intent) {
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, pendingIntentFlags)
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
        }
    }
}