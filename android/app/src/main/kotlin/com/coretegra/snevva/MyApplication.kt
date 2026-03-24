package com.coretegra.snevva

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.multidex.MultiDexApplication

// Ensures MultiDex is enabled for the application.
class MyApplication : MultiDexApplication() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Single unified tracker channel used by StepCounterService AND
            // the flutter_background_service isolate.
            val channel = NotificationChannel(
                "tracker_channel",
                "Health Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Step & sleep tracking"
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}