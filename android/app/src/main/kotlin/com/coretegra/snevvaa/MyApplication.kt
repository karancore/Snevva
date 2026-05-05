package com.coretegra.snevvaa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.multidex.MultiDexApplication

class MyApplication : MultiDexApplication() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return

            // Tracker channel — low importance, persistent foreground notification
            val trackerChannel = NotificationChannel(
                "tracker_channel",
                "Health Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Step & sleep tracking"
            }

            // Reminder/alarm channel — high importance, shown over lock screen.
            // Sound is intentionally null: ReminderAlarmReceiver plays audio via
            // MediaPlayer so the OS system sound doesn't double-fire.
            val reminderChannel = NotificationChannel(
                ReminderAlarmReceiver.CHANNEL_ID,
                "Reminders & Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminder and alarm notifications"
                setSound(null, null)
                enableVibration(true)
                enableLights(true)
                setBypassDnd(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            manager.createNotificationChannel(trackerChannel)
            manager.createNotificationChannel(reminderChannel)
        }
    }
}