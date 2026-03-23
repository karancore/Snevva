package com.coretegra.snevva

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class SparseWakeupReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SparseWakeupReceiver", "Sparse wakeup triggered")

        // Reschedule for 15 minutes
        val alarmIntent = Intent(context, SparseWakeupReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 15 * 60 * 1000,
                pendingIntent
            )
        } catch (e: Exception) {
            Log.e("SparseWakeupReceiver", "Failed to set alarm", e)
        }

        StepCounterService.flutterEngine?.let { engine ->
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.coretegra.snevva/step_detector")
            channel.invokeMethod("onAlarmWakeup", null)
            Log.d("SparseWakeupReceiver", "Wakeup sent to Flutter channel")
        }
    }
}
