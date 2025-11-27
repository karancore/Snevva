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