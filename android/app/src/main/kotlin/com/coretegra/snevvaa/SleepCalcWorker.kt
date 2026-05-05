package com.coretegra.snevvaa

import android.content.Context
import android.util.Log
import androidx.work.*
import org.json.JSONObject
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * SleepCalcWorker — the SOLE owner of sleep session finalization.
 *
 * Runs at the user's wake time every day. Responsibilities:
 *  1. Detect and flush any open screen-off interval (screen never turned on during window).
 *  2. Flush sleep_buf.tmp → daily JSON.
 *  3. Compute the final merged sleep total from the daily JSON.
 *  4. Write the final total + session date to FlutterSharedPreferences so:
 *       a. StepCounterService notification shows the correct final value (CASE B).
 *       b. Dart UI reads the correct data when the Sleep screen is opened.
 *  5. Clear all "is_sleeping" + window session keys from FlutterSharedPreferences so
 *     Dart knows the session has ended without needing to call _stopSleepAndSave().
 *  6. Enqueue the sleep dateKey (type=sleep) into the typed sync queue.
 *  7. Enqueue ApiSyncWorker to hit the sleep API endpoint.
 *  8. Reschedule itself for the next day's wake time so the chain never breaks,
 *     even if the user never opens the app.
 */
class SleepCalcWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        Log.d(TAG, "Running SleepCalcWorker...")

        try {
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )

            // ── Read bedtime / wake time from prefs ────────────────────────────
            val bedMin  = prefs.getLong("flutter.user_bedtime_ms",  -1L)
            val wakeMin = prefs.getLong("flutter.user_waketime_ms", -1L)

            if (bedMin == -1L || wakeMin == -1L) {
                Log.w(TAG, "No sleep window found. Rescheduling for next attempt.")
                scheduleNext(applicationContext)
                return Result.success()
            }

            val bedHour    = (bedMin  / 60).toInt()
            val bedMinute  = (bedMin  % 60).toInt()
            val wakeHour   = (wakeMin / 60).toInt()
            val wakeMinute = (wakeMin % 60).toInt()

            // ── Compute the sleep window that just ended ───────────────────────
            val now   = Calendar.getInstance()
            val start = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, bedHour)
                set(Calendar.MINUTE,      bedMinute)
                set(Calendar.SECOND,      0)
                set(Calendar.MILLISECOND, 0)
            }
            if (start.after(now)) start.add(Calendar.DAY_OF_MONTH, -1)

            val end = Calendar.getInstance().apply {
                time = start.time
                set(Calendar.HOUR_OF_DAY, wakeHour)
                set(Calendar.MINUTE,      wakeMinute)
                set(Calendar.SECOND,      0)
                set(Calendar.MILLISECOND, 0)
            }
            if (!end.after(start)) end.add(Calendar.DAY_OF_MONTH, 1)

            val sleepDateKey = "%04d-%02d-%02d".format(
                start.get(Calendar.YEAR),
                start.get(Calendar.MONTH) + 1,
                start.get(Calendar.DAY_OF_MONTH)
            )

            // ── Wake date (the day the worker fires, used for sleep_final_date) ─
            // sleep_final_date is compared to "today" by StepCounterService so it
            // knows whether to show the final total (CASE B) or "--" (CASE C).
            val wakeDate = "%04d-%02d-%02d".format(
                end.get(Calendar.YEAR),
                end.get(Calendar.MONTH) + 1,
                end.get(Calendar.DAY_OF_MONTH)
            )

            Log.d(TAG, "Sleep window: $sleepDateKey → $wakeDate (worker fired)")

            // ── Edge case: screen never turned on during the sleep window ──────
            // Dart seeds 'last_screen_off_<dateKey>' when the session starts.
            // Intervals are only written to sleep_buf.tmp when SCREEN_ON fires.
            // If SCREEN_ON never fired, the buffer is empty and we'd record 0 sleep.
            // We detect this here and append the clamped [anchor → windowEnd] interval.
            val lastOffKey = "flutter.last_screen_off_$sleepDateKey"
            val lastOffIso = prefs.getString(lastOffKey, null)
            if (lastOffIso != null) {
                Log.d(TAG, "Found open interval anchor: $lastOffIso")
                try {
                    val fmt    = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
                    val rawOff = fmt.parse(lastOffIso.take(23))
                    if (rawOff != null) {
                        val intervalStart = if (rawOff.before(start.time)) start.time else rawOff
                        val intervalEnd   = end.time   // worker fires at/after wake time

                        val diffMin    = ((intervalEnd.time - intervalStart.time) / 60_000).toInt()
                        val minSleepGap = 3 // mirrors Dart's SleepNoticingService.minSleepGap

                        if (diffMin >= minSleepGap) {
                            val isoFmt   = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
                            val startIso = isoFmt.format(intervalStart)
                            val endIso   = isoFmt.format(intervalEnd)
                            BufferManager.appendSleepInterval(applicationContext, sleepDateKey, startIso, endIso)
                            Log.d(TAG, "Flushed open interval (screen-never-on): ${diffMin}m ($startIso → $endIso)")
                        } else {
                            Log.d(TAG, "Open interval too short (${diffMin}m < ${minSleepGap}m), skipping.")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse last_screen_off anchor: $e")
                }
                // Clear anchor so the next session starts clean (no double-count)
                prefs.edit().remove(lastOffKey).apply()
                Log.d(TAG, "Cleared SharedPrefs anchor: $lastOffKey")
            }

            Log.d(TAG, "Wake time reached. Flushing buffers and computing final sleep total.")

            // ── Flush step and sleep buffers into daily JSON ───────────────────
            BufferManager.flushStepsToDaily(applicationContext)
            BufferManager.flushSleepToDaily(applicationContext)

            // ── Read the final merged sleep total from the daily JSON ──────────
            val finalSleepMinutes = readDailySleepMinutes(sleepDateKey)
            Log.d(TAG, "📊 Final sleep total for $sleepDateKey: ${finalSleepMinutes}m")

            // ── Write final total + metadata to FlutterSharedPreferences ───────
            // StepCounterService.refreshNotification() reads these on every 1-min tick.
            //   flutter.sleep_final_minutes  → total minutes (CASE B display)
            //   flutter.sleep_final_date     → the WAKE date (compared to "today")
            //   flutter.sleep_elapsed_minutes→ overwritten so live value is correct
            //   flutter.is_sleeping          → false (session over)
            prefs.edit()
                .putLong("flutter.sleep_final_minutes", finalSleepMinutes.toLong())
                .putString("flutter.sleep_final_date", wakeDate)
                // Reset to 0 so next night's accumulation in StepCounterService.handleScreenOn()
                // starts from zero.  StepCounterService.computeSleepDisplayMinutes() will use
                // sleep_final_minutes (while sleep_final_date == today) for today's display.
                .putLong("flutter.sleep_elapsed_minutes", 0L)
                .putBoolean("flutter.is_sleeping", false)
                // Clear all session window keys so Dart's BG isolate knows the session ended
                .remove("flutter.sleep_start_time")
                .remove("flutter.current_sleep_window_start")
                .remove("flutter.current_sleep_window_end")
                .remove("flutter.current_sleep_window_key")
                .remove("flutter.sleep_intervals_$sleepDateKey")
                .apply()

            Log.d(TAG, "✅ FlutterSharedPreferences updated: final=${finalSleepMinutes}m, date=$wakeDate, is_sleeping=false")

            // ── Enqueue the sleep dateKey for sleep-only API sync ─────────────
            // TYPE_SLEEP ensures ApiSyncWorker only calls the sleep endpoint,
            // not the step endpoint (steps are queued separately at midnight).
            BufferManager.addToSyncQueue(
                applicationContext,
                sleepDateKey,
                ApiSyncWorker.TYPE_SLEEP
            )

            // ── Chain to ApiSyncWorker ─────────────────────────────────────────
            val syncRequest = OneTimeWorkRequestBuilder<ApiSyncWorker>()
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()

            WorkManager.getInstance(applicationContext).enqueue(syncRequest)
            Log.d(TAG, "✅ ApiSyncWorker enqueued for $sleepDateKey [sleep]")

            // ── Reschedule for the next day's wake time ────────────────────────
            // This is what keeps the chain alive indefinitely without the user opening the app.
            scheduleNext(applicationContext)

            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error in SleepCalcWorker", e)
            return Result.failure()
        }
    }

    // ── Reads total_sleep_minutes from the daily JSON file ────────────────────

    /** Returns the user-scoped fs/<uid>/ directory. */
    private fun fsDir(): java.io.File {
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val uid = prefs.getString("flutter.PatientCode", "anonymous") ?: "anonymous"
        return java.io.File(applicationContext.filesDir, "fs/$uid").also { it.mkdirs() }
    }

    private fun readDailySleepMinutes(dateKey: String): Int {
        return try {
            val dailyFile = java.io.File(fsDir(), "daily/$dateKey.json")
            if (!dailyFile.exists()) return 0
            val json = JSONObject(dailyFile.readText())
            json.optJSONObject("sleep")?.optInt("total_sleep_minutes") ?: 0
        } catch (e: Exception) {
            Log.e(TAG, "readDailySleepMinutes error: ${e.message}")
            0
        }
    }

    companion object {
        private const val TAG = "SleepCalcWorker"

        /**
         * Schedules (or re-schedules) SleepCalcWorker to fire at the next occurrence
         * of the user's wake time.  Uses REPLACE policy so only one instance is ever
         * pending, and this makes it safe to call even if a previous one is already queued.
         *
         * Call sites:
         *  - BootReceiver            — on device reboot
         *  - MainActivity            — when the user updates sleep settings
         *  - SleepCalcWorker.doWork() — self-reschedule after each nightly run
         */
        fun scheduleNext(context: Context) {
            val prefs   = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val wakeMin = prefs.getLong("flutter.user_waketime_ms", -1L)

            if (wakeMin == -1L) {
                Log.w(TAG, "scheduleNext: no wake time set, skipping.")
                return
            }

            val wakeHour   = (wakeMin / 60).toInt()
            val wakeMinute = (wakeMin % 60).toInt()

            val now      = Calendar.getInstance()
            val wakeTime = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, wakeHour)
                set(Calendar.MINUTE,      wakeMinute)
                set(Calendar.SECOND,      0)
                set(Calendar.MILLISECOND, 0)
            }

            // If the wake time has already passed today, schedule for tomorrow
            if (!wakeTime.after(now)) {
                wakeTime.add(Calendar.DAY_OF_MONTH, 1)
            }

            val delayMs = wakeTime.timeInMillis - now.timeInMillis
            Log.d(TAG, "Scheduling next SleepCalcWorker in ${delayMs / 1000}s (${wakeHour}:${"%02d".format(wakeMinute)})")

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
