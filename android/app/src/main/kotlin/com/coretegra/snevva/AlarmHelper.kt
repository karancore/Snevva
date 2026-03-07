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

    fun scheduleSleepAlarms(context: Context) {
        // Sleep tracking is handled by unified Dart background service.
        // Keep this method for backward compatibility and clear any legacy native alarms.
        cancelSleepAlarms(context)
        Log.d(TAG, "Legacy native sleep alarms disabled; using unified background service")
    }

    fun cancelSleepAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val bedPendingIntent = PendingIntent.getBroadcast(
            context,
            START_SLEEP_REQUEST_CODE,
            Intent(context, StartSleepReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val wakePendingIntent = PendingIntent.getBroadcast(
            context,
            STOP_SLEEP_REQUEST_CODE,
            Intent(context, StopSleepReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(bedPendingIntent)
        alarmManager.cancel(wakePendingIntent)

        Log.d(TAG, "Cancelled legacy StartSleep/StopSleep alarms")
    }
}
