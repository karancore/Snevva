package com.coretegra.snevva

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.*
import java.util.*
import java.util.concurrent.TimeUnit

class SleepCalcWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        Log.d("SleepCalcWorker", "Running SleepCalcWorker...")
        
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val bedMin = prefs.getSleepMinutes("flutter.user_bedtime_ms")
            val wakeMin = prefs.getSleepMinutes("flutter.user_waketime_ms")

            if (bedMin == null || wakeMin == null) {
                Log.w("SleepCalcWorker", "No sleep window found.")
                return Result.success() // Nothing to do
            }

            val bedHour = bedMin / 60
            val bedMinute = bedMin % 60
            val wakeHour = wakeMin / 60
            val wakeMinute = wakeMin % 60

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
            val wakeMin = prefs.getSleepMinutes("flutter.user_waketime_ms")

            if (wakeMin == null) {
                Log.w("SleepCalcWorker", "Skipping scheduleNext: wake time missing or invalid")
                return
            }

            val wakeHour = wakeMin / 60
            val wakeMinute = wakeMin % 60
            
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

        private fun SharedPreferences.getSleepMinutes(key: String): Int? {
            val raw = all[key] ?: return null
            val normalized = when (raw) {
                is Int -> normalizeSleepMinutes(raw.toLong())
                is Long -> normalizeSleepMinutes(raw)
                is Float -> normalizeSleepMinutes(raw.toLong())
                is String -> raw.toLongOrNull()?.let(::normalizeSleepMinutes)
                is Number -> normalizeSleepMinutes(raw.toLong())
                else -> null
            }

            if (normalized == null) {
                Log.w(
                    "SleepCalcWorker",
                    "Ignoring invalid sleep pref $key=$raw (${raw::class.java.simpleName})"
                )
            }

            return normalized
        }

        private fun normalizeSleepMinutes(rawValue: Long): Int? {
            if (rawValue in 0..1439) {
                return rawValue.toInt()
            }

            val millisPerMinute = TimeUnit.MINUTES.toMillis(1)
            val millisPerDay = TimeUnit.DAYS.toMillis(1)

            if (rawValue in 0 until millisPerDay && rawValue % millisPerMinute == 0L) {
                return (rawValue / millisPerMinute).toInt()
            }

            return null
        }
    }
}
