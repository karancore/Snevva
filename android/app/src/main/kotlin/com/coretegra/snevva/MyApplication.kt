package com.coretegra.snevva

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.app.FlutterApplication
import androidx.multidex.MultiDexApplication

// This is the simplest way to ensure MultiDex is enabled
class MyApplication : MultiDexApplication() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "flutter_background_service",
                "Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Channel for background service notifications"
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}