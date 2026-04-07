package com.coretegra.snevva

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log

object AlarmHelper {
    private const val TAG = "AlarmHelper"
    private const val START_SLEEP_REQUEST_CODE = 1001
    private const val STOP_SLEEP_REQUEST_CODE = 1002
    private const val DAY_CHANGE_REQUEST_CODE = 1042

    fun scheduleSleepAlarms(context: Context) {
        MetaStore.syncSleepSchedule(context)
        scheduleNextDayChange(context)
        cancelSleepAlarms(context)
        Log.d(TAG, "Sleep schedule synced to meta.json and day-change alarm refreshed")
    }

    fun cancelSleepAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val bedPendingIntent = PendingIntent.getBroadcast(
            context,
            START_SLEEP_REQUEST_CODE,
            Intent().setComponent(android.content.ComponentName(context, "com.coretegra.snevva.StartSleepReceiver")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val wakePendingIntent = PendingIntent.getBroadcast(
            context,
            STOP_SLEEP_REQUEST_CODE,
            Intent().setComponent(android.content.ComponentName(context, "com.coretegra.snevva.StopSleepReceiver")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(bedPendingIntent)
        alarmManager.cancel(wakePendingIntent)

        Log.d(TAG, "Cancelled legacy StartSleep/StopSleep alarms")
    }

    fun scheduleNextDayChange(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            DAY_CHANGE_REQUEST_CODE,
            Intent(context, DayChangeReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val now = java.util.Calendar.getInstance()
        val next = java.util.Calendar.getInstance().apply {
            add(java.util.Calendar.DAY_OF_MONTH, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 5)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }

        if (next.before(now)) {
            next.add(java.util.Calendar.DAY_OF_MONTH, 1)
        }

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            next.timeInMillis,
            pendingIntent
        )

        Log.d(TAG, "Scheduled next day-change alarm at ${next.time}")
    }

    fun cancelDayChangeAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            DAY_CHANGE_REQUEST_CODE,
            Intent(context, DayChangeReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }
}
