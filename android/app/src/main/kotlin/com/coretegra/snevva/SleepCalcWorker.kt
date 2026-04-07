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
            MetaStore.syncSleepSchedule(applicationContext)
            val bedMin = MetaStore.bedtimeMinutes(applicationContext)
            val wakeMin = MetaStore.waketimeMinutes(applicationContext)

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

            Log.d(
                "SleepCalcWorker",
                "Wake Time Reached. Flushing file buffers and launching native sync."
            )

            BufferManager.flushAll(applicationContext)
            val yesterday = SleepWindowResolver.formatDayKey(java.time.LocalDate.now().minusDays(1))
            SyncQueueStore.enqueue(applicationContext, yesterday)

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
            MetaStore.syncSleepSchedule(context)
            val wakeMin = MetaStore.waketimeMinutes(context)

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
    }
}
