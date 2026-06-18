package com.coretegra.snevvaa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Fires when AlarmManager triggers a reminder alarm.
 *
 * This receiver NEVER opens the app. It:
 *   1. Shows a high-priority notification with a "Stop" action
 *   2. Plays category-specific audio from internal storage via MediaPlayer
 *   3. Reschedules the next occurrence (for recurring alarms) via ReminderArmingHelper
 *
 * The Flutter engine is NOT involved. This runs entirely in native Kotlin.
 *
 * IMPORTANT — Notification ID offset:
 *   The flutter_alarm package posts its alarm notification using the raw alarmId
 *   as the notification ID. We offset ours by +2_000_000 to avoid any collision.
 *   We also immediately cancel the alarm-package notification (by raw alarmId) so
 *   the user only ever sees our single native notification.
 *
 * IMPORTANT — Do NOT call stopService(AlarmService):
 *   Stopping the alarm package's foreground service and then letting its own
 *   AlarmReceiver call startForegroundService() with a stop-intent causes a
 *   ForegroundServiceDidNotStartInTimeException crash (Android 16+). We must
 *   let AlarmService manage its own lifecycle; we only cancel its notification.
 */
class ReminderAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ReminderAlarmReceiver"
        const val CHANNEL_ID = "reminder_alarm_channel"

        /** Added to alarmId to form our notification ID — avoids collision with flutter_alarm. */
        private const val NOTIF_ID_OFFSET = 2_000_000

        // Static so ReminderStopReceiver can stop it
        @Volatile var mediaPlayer: MediaPlayer? = null

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val mgr = context.getSystemService(NotificationManager::class.java)
                if (mgr?.getNotificationChannel(CHANNEL_ID) != null) return
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Reminders & Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Reminder and alarm notifications"
                    setSound(null, null)       // audio handled by MediaPlayer
                    enableVibration(true)
                    setBypassDnd(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                mgr?.createNotificationChannel(channel)
            }
        }

        fun notifIdFor(alarmId: Int) = alarmId + NOTIF_ID_OFFSET
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderArmingHelper.ACTION_FIRE) {
            Log.w(TAG, "Unexpected action: ${intent.action}")
            return
        }

        val alarmId    = intent.getIntExtra("alarmId", -1)
        val groupId    = intent.getStringExtra("groupId") ?: ""
        val category   = intent.getStringExtra("category") ?: ""
        val title      = intent.getStringExtra("title") ?: "Reminder"
        val body       = intent.getStringExtra("body") ?: ""
        val intervalMs = intent.getLongExtra("intervalMs", 0L)

        Log.d(TAG, "🔔 REMINDER_FIRE id=$alarmId cat=$category groupId=$groupId intervalMs=$intervalMs")

        // ✅ GUARD: Check tombstones BEFORE showing notification or playing audio.
        // This is the last line of defence — if cancelByGroupId() was called but
        // the AlarmManager entry had already been queued by the kernel, this check
        // prevents the alarm from firing visually even if we couldn't cancel it
        // from AlarmManager in time (race condition on meal/medicine/event delete).
        if (isDeleted(context, alarmId, groupId)) {
            Log.d(TAG, "⛔ REMINDER_FIRE suppressed — alarmId=$alarmId groupId=$groupId was deleted by user")
            // Clean up any stale JSON entry
            if (groupId.isNotBlank()) {
                val gid = groupId.toIntOrNull() ?: -1
                if (gid != -1) ReminderArmingHelper.cancelByGroupId(context, gid)
            } else {
                ReminderArmingHelper.cancel(context, alarmId)
            }
            return
        }

        // ✅ GUARD: Global logout / disable flag
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (prefs.getBoolean("flutter.reminders_disabled", false)) {
            Log.d(TAG, "⛔ REMINDER_FIRE suppressed — reminders are disabled (logged out)")
            return
        }

        // ✅ GUARD: User toggled "Disable Notifications" in settings (DND mode)
        if (prefs.getBoolean("flutter.is_dnd_enabled", false)) {
            Log.d(TAG, "⛔ REMINDER_FIRE suppressed — user enabled DND in settings")
            return
        }

        // Signal Flutter that an alarm just fired so reconciliation runs on the
        // next app open (bypasses the 2-hour throttle in reconciliation_engine.dart).
        // Also stamp the arm epoch so MainActivity can skip a redundant full re-arm.
        val nowMs = System.currentTimeMillis()
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.alarm_fired_recently", true)
            .putLong("flutter.native_alarm_last_arm_epoch_ms", nowMs)
            .apply()
        Log.d(TAG, "📝 Wrote alarm_fired_recently + arm epoch to FlutterSharedPreferences")

        // Cancel the alarm-package's own notification so only ours is visible.
        // We do NOT call stopService(AlarmService) — doing so then letting its
        // AlarmReceiver call startForegroundService() causes a crash on Android 14+.
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        mgr.cancel(alarmId)   // alarm-package uses raw alarmId

        createNotificationChannel(context)
        showNotification(context, alarmId, title, body, category)
        playAudio(context, category)

        // ✅ Reschedule next occurrence via ReminderArmingHelper which already
        // has tombstone guards inside rescheduleNext() — so deleted recurring
        // reminders won't be rescheduled even if this point is reached.
        if (intervalMs > 0L) {
            val nextEpochMs = nowMs + intervalMs
            ReminderArmingHelper.arm(
                context, alarmId, nextEpochMs, groupId, category, title, body, intervalMs
            )
            Log.d(TAG, "🔁 Fast-rescheduled alarm id=$alarmId in ${intervalMs}ms")
        } else {
            ReminderArmingHelper.rescheduleNext(context, alarmId)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isDeleted — checks both alarm-level and group-level tombstones
    // ─────────────────────────────────────────────────────────────────────────

    private fun isDeleted(context: Context, alarmId: Int, groupId: String): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return try {
            val deletedAlarmIdsRaw = prefs.getString("flutter.deleted_reminder_alarm_ids_v1", null)
            if (deletedAlarmIdsRaw != null) {
                val arr = org.json.JSONArray(deletedAlarmIdsRaw)
                for (i in 0 until arr.length()) {
                    if (arr.optInt(i, -1) == alarmId) return true
                }
            }
            val gid = groupId.toIntOrNull() ?: return false
            val deletedGroupIdsRaw = prefs.getString("flutter.deleted_reminder_group_ids_v1", null)
                ?: return false
            val arr2 = org.json.JSONArray(deletedGroupIdsRaw)
            for (i in 0 until arr2.length()) {
                if (arr2.optInt(i, -1) == gid) return true
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Notification
    // ─────────────────────────────────────────────────────────────────────────

    private fun showNotification(
        context: Context,
        alarmId: Int,
        title: String,
        body: String,
        category: String
    ) {
        val notifId = notifIdFor(alarmId)

        val stopIntent = Intent(context, ReminderStopReceiver::class.java).apply {
            action = "com.coretegra.snevvaa.REMINDER_STOP"
            putExtra("notifId", notifId)
            putExtra("alarmId", alarmId)
        }
        val stopPending = PendingIntent.getBroadcast(
            context,
            notifId,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val emoji = when (category.trim().lowercase()) {
            "water"    -> "💧"
            "meal"     -> "\uD83C\uDF7D"
            "medicine" -> "💊"
            "event"    -> "📅"
            "sleep"    -> "🌙"
            else       -> "⏰"
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification_bg)
            .setContentTitle("$emoji $title")
            .setContentText(body.ifEmpty { title })
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .setColor(0xFFA95BFF.toInt())
            .setColorized(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPending)
            .build()

        mgr(context).notify(notifId, notification)
        Log.d(TAG, "✅ Notification shown notifId=$notifId")
    }

    private fun mgr(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    // ─────────────────────────────────────────────────────────────────────────
    // Audio
    // ─────────────────────────────────────────────────────────────────────────

    private fun playAudio(context: Context, category: String) {
        try {
            mediaPlayer?.let { mp ->
                try { if (mp.isPlaying) mp.stop() } catch (_: Exception) {}
                try { mp.reset()   } catch (_: Exception) {}
                try { mp.release() } catch (_: Exception) {}
            }
            mediaPlayer = null

            val audioFile = ReminderArmingHelper.audioFileForCategory(context, category)
            if (audioFile == null || !audioFile.exists()) {
                Log.w(TAG, "⚠️ Audio file not found for category=$category — retrying copy")
                try { ReminderArmingHelper.copyAudioAssetsIfNeeded(context) } catch (_: Exception) {}
                val retry = ReminderArmingHelper.audioFileForCategory(context, category)
                if (retry == null || !retry.exists()) {
                    Log.e(TAG, "❌ Audio still not found after copy for category=$category")
                    return
                }
                playFile(retry.absolutePath)
                Log.d(TAG, "🎵 Playing (retry): ${retry.name} (category=$category)")
                return
            }

            playFile(audioFile.absolutePath)
            Log.d(TAG, "🎵 Playing: ${audioFile.name} (category=$category)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play audio for category=$category", e)
        }
    }

    private fun playFile(path: String) {
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            setDataSource(path)
            isLooping = true
            prepare()
            start()
        }
    }
}