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

        // ── Logged-out guard ──────────────────────────────────────────────────
        // forceLogout() calls SharedPreferences.clear() which removes flutter.auth_token.
        // Do NOT restart the foreground service (and its sticky notification) when no
        // user is signed in — the notification must stay gone after logout.
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        val isLoggedIn = flutterPrefs.contains("flutter.auth_token")
        if (!isLoggedIn) {
            Log.d("ResurrectionWorker", "User logged out — skipping resurrection.")
            return Result.success()
        }
        // ─────────────────────────────────────────────────────────────────────

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
