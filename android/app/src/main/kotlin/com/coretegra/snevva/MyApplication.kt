package com.coretegra.snevva

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.graphics.Color
import androidx.multidex.MultiDexApplication

class MyApplication : MultiDexApplication() {
    companion object {
        private const val BACKGROUND_SERVICE_CHANNEL_ID = "flutter_background_service"
        private const val REMINDER_CHANNEL_ID = "reminder_critical_channel_v1"
        private const val ALARM_PLUGIN_CHANNEL_ID = "alarm_plugin_channel"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    BACKGROUND_SERVICE_CHANNEL_ID,
                    "Background Service",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Channel for background service notifications"
                }
            )

            createOrRefreshCriticalReminderChannel(
                manager = manager,
                channelId = REMINDER_CHANNEL_ID,
                channelName = "Critical Reminders",
                channelDescription = "Urgent reminder alerts for medicine, water, meals, and events."
            )
            createOrRefreshCriticalReminderChannel(
                manager = manager,
                channelId = ALARM_PLUGIN_CHANNEL_ID,
                channelName = "Critical Reminder Alarms",
                channelDescription = "Alarm plugin channel reserved for urgent reminder alarms."
            )
        }
    }

    private fun createOrRefreshCriticalReminderChannel(
        manager: NotificationManager,
        channelId: String,
        channelName: String,
        channelDescription: String
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val canUseBypassDnd =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M || manager.isNotificationPolicyAccessGranted

        val existing = manager.getNotificationChannel(channelId)
        val shouldRefresh =
            existing == null ||
                existing.importance != NotificationManager.IMPORTANCE_MAX ||
                !existing.shouldVibrate() ||
                !existing.shouldShowLights() ||
                existing.lockscreenVisibility != Notification.VISIBILITY_PUBLIC ||
                (canUseBypassDnd && !existing.canBypassDnd())

        if (shouldRefresh && existing != null) {
            manager.deleteNotificationChannel(channelId)
        }

        if (!shouldRefresh && existing != null) {
            return
        }

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_MAX
        ).apply {
            description = channelDescription
            enableVibration(true)
            vibrationPattern = longArrayOf(0L, 800L, 400L, 800L, 400L, 1200L)
            enableLights(true)
            lightColor = Color.parseColor("#FF6B35")
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            if (canUseBypassDnd) {
                setBypassDnd(true)
            }
            setSound(soundUri, audioAttributes)
            setShowBadge(true)
        }

        manager.createNotificationChannel(channel)
    }
}
