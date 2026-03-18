package com.coretegra.snevva

import android.content.Context
import android.util.Log
import androidx.work.*
import java.util.*
import java.util.concurrent.TimeUnit

class SleepCalcWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        Log.d("SleepCalcWorker", "Running SleepCalcWorker...")
        
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Get bedtime/waketime from prefs
            val bedMin = prefs.getLong("flutter.user_bedtime_ms", -1L)
            val wakeMin = prefs.getLong("flutter.user_waketime_ms", -1L)
            
            if (bedMin == -1L || wakeMin == -1L) {
                Log.w("SleepCalcWorker", "No sleep window found.")
                return Result.success() // Nothing to do
            }

            val bedHour = (bedMin / 60).toInt()
            val bedMinute = (bedMin % 60).toInt()
            val wakeHour = (wakeMin / 60).toInt()
            val wakeMinute = (wakeMin % 60).toInt()

            val now = Calendar.getInstance()
            val start = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, bedHour)
                set(Calendar.MINUTE, bedMinute)
            }
            if (start.after(now)) start.add(Calendar.DAY_OF_MONTH, -1)

            val end = Calendar.getInstance().apply {
                time = start.time
                set(Calendar.HOUR_OF_DAY, wakeHour)
                set(Calendar.MINUTE, wakeMinute)
            }
            if (!end.after(start)) end.add(Calendar.DAY_OF_MONTH, 1)

            // Save interval in ISO format
            val windowKey = "${start.get(Calendar.YEAR)}-${(start.get(Calendar.MONTH) + 1).toString().padStart(2, '0')}-${start.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')}"
            val intervalsKey = "flutter.sleep_intervals_$windowKey"
            
            val intervalStr = "${start.time.toInstant()}|${end.time.toInstant()}"
            val existing = prefs.getString(intervalsKey, "") ?: ""
            val updated = if (existing.isEmpty()) intervalStr else "$existing,$intervalStr"
            
            prefs.edit().putString(intervalsKey, updated).apply()
            Log.d("SleepCalcWorker", "Sleep calculated and saved: $intervalStr for window $windowKey")

            // Chain to API Sync
            val syncRequest = OneTimeWorkRequestBuilder<ApiSyncWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
                
            WorkManager.getInstance(applicationContext).enqueue(syncRequest)

            return Result.success()
        } catch (e: Exception) {
            Log.e("SleepCalcWorker", "Error calculating sleep", e)
            return Result.failure()
        }
    }
    
    companion object {
        fun scheduleNext(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val wakeMin = prefs.getLong("flutter.user_waketime_ms", -1L)
            
            if (wakeMin == -1L) return
            
            val wakeHour = (wakeMin / 60).toInt()
            val wakeMinute = (wakeMin % 60).toInt()
            
            val now = Calendar.getInstance()
            val wakeTime = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, wakeHour)
                set(Calendar.MINUTE, wakeMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // If the wake time has already passed today, schedule for tomorrow
            if (wakeTime.before(now)) {
                wakeTime.add(Calendar.DAY_OF_MONTH, 1)
            }
            
            val delayMs = wakeTime.timeInMillis - now.timeInMillis
            Log.d("SleepCalcWorker", "Scheduling next SleepCalcWorker in ${delayMs / 1000} seconds")

            val calcWork = OneTimeWorkRequestBuilder<SleepCalcWorker>()
                .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
                .build()
                
            WorkManager.getInstance(context).enqueueUniqueWork(
                "SLEEP_CALC_WORK",
                ExistingWorkPolicy.REPLACE,
                calcWork
            )
        }
    }
}
