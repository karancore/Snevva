package com.coretegra.snevvaa

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles the "Stop" action button tap from the reminder alarm notification.
 *
 * Stops the MediaPlayer (owned by ReminderAlarmReceiver) and dismisses
 * the notification. Never opens the app.
 *
 * IMPORTANT — Do NOT call stopService(AlarmService) here:
 *   If AlarmService is already stopped (from ReminderAlarmReceiver) and the
 *   user also taps the alarm package's own Stop button, AlarmReceiver will call
 *   startForegroundService(AlarmService, stopIntent). That fresh service never
 *   calls startForeground() → ForegroundServiceDidNotStartInTimeException crash.
 *   We must let AlarmService manage itself; we only cancel its notification.
 *
 * Deduplication: Android can deliver the same broadcast multiple times when
 * PendingIntent request codes collide. The handled-ID set prevents duplicate
 * executions within a 10-second window.
 */
class ReminderStopReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ReminderStopReceiver"
        private val recentlyHandled = mutableSetOf<Int>()
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.coretegra.snevvaa.REMINDER_STOP") {
            Log.w(TAG, "Unexpected action: ${intent.action}")
            return
        }

        val notifId = intent.getIntExtra("notifId", -1)
        val alarmId = intent.getIntExtra("alarmId", -1)

        // Dedup guard
        if (notifId in recentlyHandled) {
            Log.w(TAG, "⏭ Duplicate REMINDER_STOP for notifId=$notifId — ignored")
            return
        }
        recentlyHandled.add(notifId)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            recentlyHandled.remove(notifId)
        }, 10_000L)

        Log.d(TAG, "⏹ REMINDER_STOP notifId=$notifId alarmId=$alarmId")

        // 1. Stop our native audio playback
        try {
            ReminderAlarmReceiver.mediaPlayer?.let { mp ->
                try { if (mp.isPlaying) mp.stop() } catch (_: Exception) {}
                try { mp.reset()   } catch (_: Exception) {}
                try { mp.release() } catch (_: Exception) {}
            }
            ReminderAlarmReceiver.mediaPlayer = null
            Log.d(TAG, "✅ MediaPlayer stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping MediaPlayer", e)
        }

        // 2. Dismiss our native notification
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notifId != -1) {
            mgr.cancel(notifId)
            Log.d(TAG, "✅ Notification $notifId dismissed")
        }

        // 3. Also cancel the alarm package's notification (raw alarmId) so its
        //    Stop button can no longer be tapped — preventing the AlarmService crash.
        //    We do NOT call stopService() — see class JavaDoc above.
        if (alarmId != -1) {
            mgr.cancel(alarmId)
            Log.d(TAG, "✅ Alarm-package notification $alarmId cancelled")
        }
    }
}
