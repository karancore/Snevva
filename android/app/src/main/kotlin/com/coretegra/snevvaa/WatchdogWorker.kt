package com.coretegra.snevvaa

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.*
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class WatchdogWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    private fun appendLog(prefs: android.content.SharedPreferences, message: String) {
        try {
            val currentLogs = prefs.getString("flutter.period_sync_debug_logs", "[]") ?: "[]"
            val array = JSONArray(currentLogs)
            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            
            val list = ArrayList<String>()
            for (i in 0 until array.length()) {
                list.add(array.getString(i))
            }
            list.add("[$timestamp] Watchdog: $message")
            if (list.size > 100) {
                list.removeAt(0)
            }
            
            val newArray = JSONArray()
            for (item in list) {
                newArray.put(item)
            }
            prefs.edit().putString("flutter.period_sync_debug_logs", newArray.toString()).apply()
        } catch (e: Exception) {
            Log.e("WatchdogWorker", "Failed to append log", e)
        }
    }

    override suspend fun doWork(): Result {
        Log.d("WatchdogWorker", "Bark! Checking if FlutterBackgroundService is alive...")

        return withContext(Dispatchers.IO) {
            // ── 1. Flush buffers first — ensures data survives even if the service is dead
            try {
                BufferManager.flushStepsToDaily(applicationContext)
                BufferManager.flushSleepToDaily(applicationContext)
            } catch (e: Exception) {
                Log.e("WatchdogWorker", "Buffer flush error: ${e.message}")
            }

            // ── 2. Native new-cycle detection — fires API even if app is never opened
            try {
                checkAndSyncNewCycle()
            } catch (e: Exception) {
                Log.e("WatchdogWorker", "checkAndSyncNewCycle error: ${e.message}")
            }

            // ── 3. Keep flutter_background_service alive
            try {
                val serviceIntent = Intent()
                serviceIntent.setClassName(
                    applicationContext,
                    "id.flutter.flutter_background_service.BackgroundService"
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(serviceIntent)
                } else {
                    applicationContext.startService(serviceIntent)
                }
                Log.d("WatchdogWorker", "Background service kickstarted!")
                Result.success()
            } catch (e: Exception) {
                Log.e("WatchdogWorker", "Failed to start flutter background service", e)
                // Don't return failure — the critical work (flush + cycle sync) already ran.
                // Returning failure causes exponential back-off on the periodic worker.
                Result.success()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // New-cycle detection
    //
    // Mirrors Flutter's _calculateNextDates() roll-forward logic exactly.
    // Runs every 15 min via WatchdogWorker so the API is hit even when the
    // user never opens the app after a cycle boundary passes.
    //
    // Dedup key "flutter.last_synced_cycle_start" prevents re-queuing the
    // same cycle on every watchdog tick.
    // ─────────────────────────────────────────────────────────────────────────
    private fun checkAndSyncNewCycle() {
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )

        // Flutter SharedPreferences prepends "flutter." to every key
        val lastPeriodStr = prefs.getString("flutter.periodLastPeriodDay", null)
        if (lastPeriodStr.isNullOrBlank()) {
            Log.d("WatchdogWorker", "No period data in prefs — skipping cycle check")
            appendLog(prefs, "No period data in prefs — skipping cycle check")
            return
        }

        val cycleDaysStr = prefs.getString("flutter.periodCycleDays", "28") ?: "28"
        val cycleLength = cycleDaysStr.toIntOrNull() ?: 28

        val sdf = SimpleDateFormat("dd/MM/yyyy", Locale.US)

        var cycleStart: Date = try {
            sdf.parse(lastPeriodStr) ?: return
        } catch (e: Exception) {
            Log.e("WatchdogWorker", "Failed to parse lastPeriodDay '$lastPeriodStr': ${e.message}")
            return
        }

        // Midnight today
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time

        // Roll forward — same logic as Flutter's while-loop
        var nextPeriod = Date(cycleStart.time + cycleLength * 86_400_000L)
        var cycleRolledForward = false

        while (!nextPeriod.after(today)) {
            cycleStart = nextPeriod
            nextPeriod = Date(cycleStart.time + cycleLength * 86_400_000L)
            cycleRolledForward = true
        }

        if (!cycleRolledForward) {
            Log.d("WatchdogWorker", "No new cycle yet — next period on ${sdf.format(nextPeriod)}")
            appendLog(prefs, "No new cycle yet — next period on ${sdf.format(nextPeriod)}")
            return
        }

        // Dedup: skip if we already synced this exact cycle start
        val newCycleStartStr = sdf.format(cycleStart)
        val lastSyncedCycleStart = prefs.getString("flutter.last_synced_cycle_start", null)
        if (lastSyncedCycleStart == newCycleStartStr) {
            Log.d("WatchdogWorker", "Cycle $newCycleStartStr already synced — skipping")
            appendLog(prefs, "Cycle $newCycleStartStr already synced — skipping")
            return
        }

        Log.d(
            "WatchdogWorker",
            "🔄 New cycle detected: start=$newCycleStartStr, nextPeriod=${sdf.format(nextPeriod)}"
        )
        appendLog(prefs, "🔄 New cycle detected: start=$newCycleStartStr, nextPeriod=${sdf.format(nextPeriod)}")

        // Build payload — note: java.util.Date months are 0-indexed, year is since 1900
        val cal = Calendar.getInstance()

        cal.time = cycleStart
        val startDay   = cal.get(Calendar.DAY_OF_MONTH)
        val startMonth = cal.get(Calendar.MONTH) + 1
        val startYear  = cal.get(Calendar.YEAR)

        cal.time = nextPeriod
        val predDay   = cal.get(Calendar.DAY_OF_MONTH)
        val predMonth = cal.get(Calendar.MONTH) + 1
        val predYear  = cal.get(Calendar.YEAR)

        val payload = org.json.JSONObject().apply {
            put("StartDay",      startDay)
            put("StartMonth",    startMonth)
            put("StartYear",     startYear)
            put("PredictedDay",  predDay)
            put("PredictedMonth", predMonth)
            put("PredictedYear", predYear)
            put("IsMatched",     false)
        }

        // Write payload + dedup key atomically, then enqueue the worker
        prefs.edit()
            .putString("flutter.pending_period_sync", payload.toString())
            .putString("flutter.last_synced_cycle_start", newCycleStartStr)
            .apply()

        PeriodSyncWorker.enqueue(applicationContext)

        Log.d("WatchdogWorker", "✅ PeriodSyncWorker enqueued for cycle $newCycleStartStr")
        appendLog(prefs, "✅ PeriodSyncWorker enqueued for cycle $newCycleStartStr")
    }

    companion object {
        fun start(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<WatchdogWorker>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().build())
                .setBackoffCriteria(BackoffPolicy.LINEAR, 5, TimeUnit.MINUTES)
                .build()

            // UPDATE replaces any stale deferred request so new ticks are never silently skipped.
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "SERVICE_WATCHDOG",
                ExistingPeriodicWorkPolicy.UPDATE,
                workRequest
            )
            Log.d("WatchdogWorker", "Watchdog scheduled every 15 minutes.")
        }
    }
}