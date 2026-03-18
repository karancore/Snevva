package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d("BootReceiver", "Device rebooted or package replaced. Restarting services...")
            
            // 1. Restart StepCounterService
            val serviceIntent = Intent(context, StepCounterService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            // 2. Schedule SleepCalcWorker to calculate sleep gracefully
            SleepCalcWorker.scheduleNext(context)
            
            // 3. Keep old AlarmHelper behavior for reminders
            AlarmHelper.scheduleSleepAlarms(context)
        }
    }
}
