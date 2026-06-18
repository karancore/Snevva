package com.coretegra.snevvaa

import android.content.Context
import android.content.Intent
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

        // Guard: skip the restart if flutter_background_service is already running.
        // Calling startForegroundService() on an already-running service is a no-op at
        // best and triggers ForegroundServiceDidNotStopInTimeException on Android 16+
        // (SDK 36) at worst, because the OS restarts the lifecycle and the service
        // must call startForeground() again within ~5 s.
        if (isServiceRunning("id.flutter.flutter_background_service.BackgroundService")) {
            Log.d("WatchdogWorker", "FlutterBackgroundService is alive — nothing to do.")
            return Result.success()
        }

        return try {
            val serviceIntent = Intent().apply {
                setClassName(applicationContext, "id.flutter.flutter_background_service.BackgroundService")
            }
            // Use plain startService() — NOT startForegroundService() — so that the
            // plugin's own service is responsible for calling startForeground() on its
            // own thread within the required window.  Calling startForegroundService()
            // from a WorkManager worker on Android 16 (SDK 36) causes the OS to enforce
            // the 5-second startForeground() deadline strictly, which the plugin may not
            // always satisfy, producing ForegroundServiceDidNotStopInTimeException.
            applicationContext.startService(serviceIntent)
            Log.d("WatchdogWorker", "Background service kickstarted!")
            Result.success()
        } catch (e: Exception) {
            Log.e("WatchdogWorker", "Failed to start flutter background service", e)
            Result.failure()
        }
    }

    /** Returns true when [serviceName] is listed among currently running services. */
    @Suppress("DEPRECATION") // getRunningServices is the only reliable check pre-API-34
    private fun isServiceRunning(serviceName: String): Boolean {
        val am = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        return am.getRunningServices(Int.MAX_VALUE)
            .any { it.service.className == serviceName }
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