package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class StopSleepReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Stop any lingering native service and clear legacy alarms.
        context.stopService(Intent(context, SleepNoticingService::class.java))
        AlarmHelper.cancelSleepAlarms(context)
    }
}
