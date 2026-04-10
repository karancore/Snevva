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
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (start.after(now)) start.add(Calendar.DAY_OF_MONTH, -1)

            val end = Calendar.getInstance().apply {
                time = start.time
                set(Calendar.HOUR_OF_DAY, wakeHour)
                set(Calendar.MINUTE, wakeMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (!end.after(start)) end.add(Calendar.DAY_OF_MONTH, 1)

            val sleepDateKey = "%04d-%02d-%02d".format(
                start.get(Calendar.YEAR),
                start.get(Calendar.MONTH) + 1,
                start.get(Calendar.DAY_OF_MONTH)
            )

            // ── Edge case: screen never turned on during the sleep window ──────────────
            // Dart's SleepNoticingService seeds 'last_screen_off_<dateKey>' in SharedPrefs
            // when the session starts (via initializeForSleepWindow). Intervals are only
            // written to sleep_buf.tmp when SCREEN_ON fires. If SCREEN_ON never fired, the
            // buffer is empty and we'd record 0 sleep. We detect this here and append the
            // clamped [anchor → windowEnd] interval before the regular buffer flush.
            //
            // SharedPrefs key format used by Dart: "flutter.last_screen_off_YYYY-MM-DD"
            val lastOffKey = "flutter.last_screen_off_$sleepDateKey"
            val lastOffIso = prefs.getString(lastOffKey, null)
            if (lastOffIso != null) {
                Log.d("SleepCalcWorker", "Found open interval anchor: $lastOffIso")
                try {
                    val fmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
                    val rawOff = fmt.parse(lastOffIso.take(23))
                    if (rawOff != null) {
                        // Clamp start: anchor ≥ windowStart
                        val intervalStart = if (rawOff.before(start.time)) start.time else rawOff
                        // Clamp end: min(windowEnd, now) — worker runs at/after wake time,
                        // so using end.time (windowEnd) is correct.
                        val intervalEnd = end.time

                        val diffMin = ((intervalEnd.time - intervalStart.time) / 60_000).toInt()
                        val minSleepGap = 3 // minutes — mirrors Dart's SleepNoticingService.minSleepGap

                        if (diffMin >= minSleepGap) {
                            val isoFmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
                            val startIso = isoFmt.format(intervalStart)
                            val endIso   = isoFmt.format(intervalEnd)
                            BufferManager.appendSleepInterval(applicationContext, sleepDateKey, startIso, endIso)
                            Log.d("SleepCalcWorker", "Flushed open interval (screen-never-on): ${diffMin}m ($startIso → $endIso)")
                        } else {
                            Log.d("SleepCalcWorker", "Open interval too short (${diffMin}m < ${minSleepGap}m), skipping.")
                        }
                    }
                } catch (e: Exception) {
                    Log.e("SleepCalcWorker", "Failed to parse last_screen_off anchor: $e")
                }
                // Clear the anchor so the next session starts clean and we don't double-count
                prefs.edit().remove(lastOffKey).apply()
                Log.d("SleepCalcWorker", "Cleared SharedPrefs anchor: $lastOffKey")
            }

            Log.d("SleepCalcWorker", "Wake Time Reached. Flushing buffers and launching API Sync.")

            // Flush step and sleep buffers into daily JSON before syncing
            BufferManager.flushStepsToDaily(applicationContext)
            BufferManager.flushSleepToDaily(applicationContext)

            // Add the night's sleep date to the sync queue
            BufferManager.addToSyncQueue(applicationContext, sleepDateKey)

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
