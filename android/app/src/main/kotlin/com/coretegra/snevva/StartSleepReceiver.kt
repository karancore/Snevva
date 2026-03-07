package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class StartSleepReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Native alarm path is deprecated; unified Dart background service handles sleep tracking.
        AlarmHelper.cancelSleepAlarms(context)
        Log.d("StartSleepReceiver", "Ignored legacy native start alarm")
    }
}
