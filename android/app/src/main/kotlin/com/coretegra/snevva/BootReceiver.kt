package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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
            val started = StepServiceStarter.tryStart(context, "boot")
            if (started) {
                Log.d("BootReceiver", "✅ StepCounterService started on boot.")
            } else {
                Log.d("BootReceiver", "Skipping StepCounterService start on boot.")
            }

            // 2. flutter_background_service handles its own boot start via autoStartOnBoot=true.
            //    No manual start needed here.

            // 3. Schedule SleepCalcWorker to trigger API sync at wake time
            runCatching {
                SleepCalcWorker.scheduleNext(context)
            }.onFailure { error ->
                Log.e("BootReceiver", "Failed to schedule SleepCalcWorker on boot", error)
            }

            // 4. Refresh file-system schedule/sync state.
            runCatching {
                AlarmHelper.scheduleSleepAlarms(context)
                AlarmHelper.scheduleNextDayChange(context)
                BufferManager.flushAll(context)
                SyncManager.processQueue(context)
            }.onFailure { error ->
                Log.e("BootReceiver", "Failed to refresh storage/sync scheduling on boot", error)
            }
        }
    }
}
