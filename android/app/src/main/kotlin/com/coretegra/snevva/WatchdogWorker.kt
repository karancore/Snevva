package com.coretegra.snevva

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

class WatchdogWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        Log.d("WatchdogWorker", "Bark! Checking if FlutterBackgroundService is alive...")
        // Flush buffers first — ensures data survives even if the service is dead
        try {
            BufferManager.flushStepsToDaily(applicationContext)
            BufferManager.flushSleepToDaily(applicationContext)
        } catch (e: Exception) {
            Log.e("WatchdogWorker", "Buffer flush error: ${e.message}")
        }
        try {
            val serviceIntent = Intent()
            serviceIntent.setClassName(applicationContext, "id.flutter.flutter_background_service.BackgroundService")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(serviceIntent)
            } else {
                applicationContext.startService(serviceIntent)
            }
            Log.d("WatchdogWorker", "Background service kickstarted!")
            return Result.success()
        } catch (e: Exception) {
            Log.e("WatchdogWorker", "Failed to start flutter background service", e)
            return Result.failure()
        }
    }

    companion object {
        fun start(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<WatchdogWorker>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().build())
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "SERVICE_WATCHDOG",
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
            Log.d("WatchdogWorker", "Watchdog scheduled every 15 minutes.")
        }
    }
}
