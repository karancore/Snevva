package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {

            Log.d("BootReceiver", "Device rebooted or package replaced. Restarting services...")

            // 1. Restart StepCounterService immediately so step counting works from boot
            //    without requiring the user to open the app.
            val stepIntent = Intent(context, StepCounterService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(stepIntent)
                } else {
                    context.startService(stepIntent)
                }
                Log.d("BootReceiver", "✅ StepCounterService started on boot.")
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to start StepCounterService on boot", e)
            }

            // 2. flutter_background_service handles its own boot start via autoStartOnBoot=true.
            //    No manual start needed here.

            // 3. Schedule SleepCalcWorker to trigger API sync at wake time
            SleepCalcWorker.scheduleNext(context)

            // 4. Keep AlarmHelper call for legacy alarm cancellation (it's a no-op stub now)
            AlarmHelper.scheduleSleepAlarms(context)
        }
    }
}
