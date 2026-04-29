package com.coretegra.snevva

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * ForegroundService that rings a native reminder alarm.
 *
 * Lifecycle:
 *   1. Started by [ReminderAlarmReceiver] when AlarmManager fires.
 *   2. Shows a high-priority full-screen notification immediately.
 *   3. Plays per-category audio from Flutter's bundled APK assets.
 *   4. Auto-stops after [AUTO_STOP_SECONDS] to prevent infinite ringing.
 *   5. Stopped early when the user taps "Stop" → [ReminderStopReceiver].
 *
 * No Flutter engine is involved — this is 100% native Kotlin.
 */
class ReminderRingService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var autoStopRunnable: Runnable? = null

    companion object {
        private const val TAG = "ReminderRingService"
        const val NOTIFICATION_ID = 9001
        const val ACTION_STOP = "com.coretegra.snevva.REMINDER_STOP"
        private const val AUTO_STOP_SECONDS = 60L
        const val CHANNEL_ID = "reminder_alarm_channel"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val alarmId    = intent?.getIntExtra("alarmId", -1) ?: -1
        val category   = intent?.getStringExtra("category") ?: "meal"
        val title      = intent?.getStringExtra("title") ?: "Reminder"
        val body       = intent?.getStringExtra("body") ?: ""
        val isPreAlarm = intent?.getBooleanExtra("isPreAlarm", false) ?: false

        Log.d(TAG, "onStartCommand alarmId=$alarmId category=$category")

        // ── 1. Raise foreground notification ASAP ────────────────────────────
        val notification = buildNotification(alarmId, title, resolveBody(body, category))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // ── 2. Play audio ─────────────────────────────────────────────────────
        playAudio(category, isPreAlarm)

        // ── 3. Auto-stop after 60 s so the phone doesn't ring forever ────────
        autoStopRunnable?.let { handler.removeCallbacks(it) }
        autoStopRunnable = Runnable { stopSelf() }.also {
            handler.postDelayed(it, AUTO_STOP_SECONDS * 1000L)
        }

        // START_NOT_STICKY: if the OS kills us, don't restart automatically.
        // The next WorkManager reconcile pick will rearm via NativeAlarmBridge.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy — stopping audio and dismissing notification")
        autoStopRunnable?.let { handler.removeCallbacks(it) }

        mediaPlayer?.apply {
            try { if (isPlaying) stop() } catch (_: Exception) {}
            release()
        }
        mediaPlayer = null

        // Dismiss the notification so it doesn't linger after ringing stops
        val nm = getSystemService(NotificationManager::class.java)
        nm?.cancel(NOTIFICATION_ID)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Notification
    // ─────────────────────────────────────────────────────────────────────────

    private fun buildNotification(alarmId: Int, title: String, body: String): Notification {
        // Full-screen intent — wakes the screen / shows over lock screen
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("from_native_alarm", true)
            putExtra("alarmId", alarmId)
        }
        val fullScreenPi = PendingIntent.getActivity(
            this,
            alarmId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // "Stop" action button
        val stopIntent  = Intent(this, ReminderStopReceiver::class.java).apply {
            action = ACTION_STOP
        }
        val stopPi = PendingIntent.getBroadcast(
            this,
            alarmId + 20_000,      // unique request code to avoid collisions
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification1)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPi, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(0, "Stop", stopPi)
            .build()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Audio
    // ─────────────────────────────────────────────────────────────────────────

    private fun playAudio(category: String, isPreAlarm: Boolean) {
        val fileName = if (isPreAlarm) "remind_before.mp3" else audioFileForCategory(category)
        val assetPath = "flutter_assets/assets/sounds/$fileName"

        try {
            val afd = assets.openFd(assetPath)
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                // Loop for main alarms (except water); single-shot for pre-reminders
                isLooping = !isPreAlarm && category.lowercase() in setOf("meal", "medicine", "event")
                prepare()
                start()
            }
            afd.close()
            Log.d(TAG, "▶️ Playing $assetPath (looping=${mediaPlayer?.isLooping})")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play audio $assetPath: ${e.message}")
        }
    }

    private fun audioFileForCategory(category: String): String = when (category.lowercase()) {
        "water"    -> "water.mp3"
        "meal"     -> "meal.mp3"
        "medicine" -> "medicine.mp3"
        "event"    -> "event.mp3"
        else       -> "alarm-327234.mp3"
    }

    private fun resolveBody(body: String, category: String): String {
        if (body.isNotBlank()) return body
        return when (category.lowercase()) {
            "water"    -> "Time to drink water! 💧"
            "meal"     -> "Meal time! 🍽️"
            "medicine" -> "Time to take your medicine 💊"
            "event"    -> "Your scheduled event is starting"
            else       -> ""
        }
    }
}
