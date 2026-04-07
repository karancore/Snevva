package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ScreenStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val timestamp = System.currentTimeMillis()
        val window = MetaStore.resolveSleepWindow(context, timestamp)

        if (window == null) {
            Log.d("ScreenStateReceiver", "Ignoring $action outside configured sleep window")
            return
        }

        when (action) {
            Intent.ACTION_SCREEN_OFF -> {
                BufferManager.appendSleepEvent(context, timestamp, "OFF")
                MetaStore.setPendingSleepOffTimestamp(
                    context,
                    MetaStore.pendingSleepOffTimestamp(context) ?: timestamp
                )
                Log.d("ScreenStateReceiver", "Logged SCREEN_OFF for ${window.dayKey}")
            }

            Intent.ACTION_SCREEN_ON -> {
                BufferManager.appendSleepEvent(context, timestamp, "ON")
                Log.d("ScreenStateReceiver", "Logged SCREEN_ON for ${window.dayKey}")
            }
        }
    }
}
