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

        // ✅ FIX 4: Signal the upcoming cold-start that an alarm just fired.
        //
        // ReminderStopReceiver fires BEFORE the app cold-starts. If we don't
        // write these flags here, the new process will:
        //   a) skip reconciliation (alarm_fired_recently is still false), and
        //   b) skip armFromSharedPrefs (arm epoch is < 60s old from the last fire).
        // Both skips compound, leaving the Flutter engine in a half-initialized
        // state with no alarm state and no reconciliation run.
        //
        // Writing alarm_fired_recently ensures ReconciliationEngine.handleTimezoneStartupChecks()
        // runs _shouldReconcile() -> true on the next open.
        // Zeroing native_alarm_last_arm_epoch_ms forces MainActivity.configureFlutterEngine
        // to run armFromSharedPrefs despite being < 60s after the last alarm fire.
        try {
            context.getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                .edit()
                .putBoolean("flutter.alarm_fired_recently", true)
                .putLong("flutter.native_alarm_last_arm_epoch_ms", 0L)
                .apply()
            Log.d(TAG, "📝 Wrote alarm_fired_recently + reset arm epoch for cold-start")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write cold-start flags", e)
        }
    }
}
