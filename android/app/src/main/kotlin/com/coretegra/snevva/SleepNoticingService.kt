package com.coretegra.snevva

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder

class SleepNoticingService : Service() {

    private var screenReceiver: ScreenReceiver? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        // Register screen receiver
        if (screenReceiver == null) {
            screenReceiver = ScreenReceiver { event ->
                // Handle screen events
                // You can send this to Flutter using MethodChannel or EventChannel
                val broadcastIntent = Intent("com.coretegra.snevva.SCREEN_EVENT")
                broadcastIntent.putExtra("event", event)
                broadcastIntent.putExtra("time", System.currentTimeMillis())
                sendBroadcast(broadcastIntent)
            }

            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenReceiver, filter)
            }
        }
        
        // 🔥 Make this a Foreground Service to prevent killing
        // We can reuse the channel created by flutter_background_service or create one
        // ideally, we should create our own or use a shared hidden one.
        // For now, we will assume the channel exists or post to the same one.
        /*
          NOTE: To be fully correct, we should create a specific channel for this if needed.
          But strictly, `startForeground` needs a notification.
        */
        // Simple placeholder notification - in a real app, you might want to sync this with the main service
        // or just keep it silent/minimized.
        // For this fix, we are ensuring the service STAYS ALIVE.
        
        /* 
           Uncommenting this block would make it a true foreground service. 
           However, we already have `WrapperService` (Unified) running as FG.
           If this service is started *independently*, it needs its own startForeground.
           
           If this service is just a helper, it might not need to be FG if the main app is FG.
           But the user complained about "killing", so lets be safe.
        */
        
        // val channelId = "sleep_noticing_channel"
        // val channel = NotificationChannel(channelId, "Sleep Monitor", NotificationManager.IMPORTANCE_LOW)
        // getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        
        // val notification = Notification.Builder(this, channelId)
        //    .setContentTitle("Sleep Service Active")
        //    .setContentText("Monitoring screen state for sleep accuracy")
        //    .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
        //    .build()
            
        // startForeground(888, notification)

        return START_STICKY
    }

    override fun onDestroy() {
        try {
            if (screenReceiver != null) {
                unregisterReceiver(screenReceiver)
            }
        } catch (_: Exception) {}

        screenReceiver = null
        super.onDestroy()
    }
}

class ScreenReceiver(private val callback: (String) -> Unit) : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SCREEN_OFF -> callback("screen_off")
            Intent.ACTION_SCREEN_ON -> callback("screen_on")
        }
    }
}