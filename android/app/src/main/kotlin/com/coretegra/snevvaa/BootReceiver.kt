package com.coretegra.snevvaa

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {

            Log.d("BootReceiver", "Device rebooted or package replaced. Restarting services...")

            // 1. Check if we have permissions before starting StepCounterService
            val hasActivityRecognition = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.ACTIVITY_RECOGNITION
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }

            val hasForegroundServiceHealth =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ContextCompat.checkSelfPermission(
                        context,
                        "android.permission.FOREGROUND_SERVICE_HEALTH"
                    ) == PackageManager.PERMISSION_GRANTED
                } else {
                    true
                }

            // Only start StepCounterService if the user is logged in AND we have required permissions.
            // forceLogout() calls SharedPreferences.clear() which removes flutter.auth_token.
            // Without this guard the sticky notification reappears after every reboot.
            val flutterPrefs = context.getSharedPreferences(
                "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
            )
            val isLoggedIn = flutterPrefs.contains("flutter.auth_token")

            if (isLoggedIn && hasActivityRecognition && hasForegroundServiceHealth) {
                // Android 15+ restricts starting health foreground services directly from
                // BOOT_COMPLETED receivers. Use WorkManager instead — workers are exempt.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                    WorkManager.getInstance(context)
                        .enqueue(OneTimeWorkRequestBuilder<ResurrectionWorker>().build())
                    Log.d(
                        "BootReceiver",
                        "✅ StepCounterService queued via WorkManager (Android 15+)."
                    )
                } else {
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
                }
            } else if (!isLoggedIn) {
                Log.d("BootReceiver", "⚠️ Skipping StepCounterService start - user logged out")
            } else {
                Log.d("BootReceiver", "⚠️ Skipping StepCounterService start - missing permissions")
            }

            // 2. flutter_background_service handles its own boot start via autoStartOnBoot=true.
            //    No manual start needed here.

            // 3. Schedule SleepCalcWorker to trigger API sync at wake time
            SleepCalcWorker.scheduleNext(context)

            // 4. Keep AlarmHelper call for legacy alarm cancellation (it's a no-op stub now)
            AlarmHelper.scheduleSleepAlarms(context)

            // 5. Re-arm all pending reminder alarms from Flutter SharedPreferences.
            //    This ensures 1-week / 1-month alarms survive device reboot WITHOUT
            //    requiring the app or Flutter engine to be open — pure Kotlin path.
            try {
                ReminderArmingHelper.armFromSharedPrefs(context)
                Log.d("BootReceiver", "✅ Native reminder alarms re-armed on boot")
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to re-arm reminder alarms on boot: ${e.message}")
            }
        }
    }
}

