package com.coretegra.snevvaa

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class ResurrectionWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        Log.d("ResurrectionWorker", "Resurrecting StepCounterService")
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            androidx.core.content.ContextCompat.checkSelfPermission(applicationContext, android.Manifest.permission.ACTIVITY_RECOGNITION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        val hasForegroundServiceHealth =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                androidx.core.content.ContextCompat.checkSelfPermission(
                    applicationContext,
                    "android.permission.FOREGROUND_SERVICE_HEALTH"
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            } else {
                true
            }

        if (hasPermission && hasForegroundServiceHealth) {
            val intent = Intent(applicationContext, StepCounterService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(intent)
            } else {
                applicationContext.startService(intent)
            }
        } else {
            Log.d("ResurrectionWorker", "Skipping resurrection: required permissions not granted.")
        }
        return Result.success()
    }
}
