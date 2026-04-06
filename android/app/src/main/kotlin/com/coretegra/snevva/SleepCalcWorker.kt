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
            // Bug 1C fix: Flutter's SharedPreferences.setInt() uses putInt() (32-bit),
            // NOT putLong(). Reading with getLong() always returned the -1L default.
            val bedMin = prefs.getInt("flutter.user_bedtime_ms", -1)
            val wakeMin = prefs.getInt("flutter.user_waketime_ms", -1)
            
            if (bedMin == -1 || wakeMin == -1) {
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

            // [REMOVED CONFLICT] 
            // We NO LONGER overwrite "flutter.sleep_intervals" directly from native code.
            // Dart's `unified_background_service.dart` handles the precise sleep calculation via Screen ON/OFF tracking.
            // This Worker serves solely to launch the ApiSyncWorker periodically at wake time!
            
            Log.d("SleepCalcWorker", "Wake Time Reached. Launching API Sync for the new day.")

            // Chain to API Sync
            val syncRequest = OneTimeWorkRequestBuilder<ApiSyncWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
                
            WorkManager.getInstance(applicationContext).enqueue(syncRequest)

            // Reschedule exactly for the next day's wake time so the chain isn't broken
            scheduleNext(applicationContext)

            return Result.success()
        } catch (e: Exception) {
            Log.e("SleepCalcWorker", "Error calculating sleep", e)
            return Result.failure()
        }
    }
    
    companion object {
        fun scheduleNext(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Bug 1C fix: use getInt() to match Flutter's SharedPreferences.setInt().
            val wakeMin = prefs.getInt("flutter.user_waketime_ms", -1)
            
            if (wakeMin == -1) return
            
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
