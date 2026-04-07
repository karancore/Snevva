package com.coretegra.snevva

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * BufferManager
 *
 * Append-only step/sleep buffer with time-based auto-flush.
 *
 * Rules:
 *  - appendStepEvent() never reads the buffer; it only appends one line.
 *  - flushStepsToDaily() reads the buffer exactly once, aggregates per-day,
 *    merges into daily JSON, then deletes the buffer. RAM is freed immediately.
 *  - Flush fires on WHICHEVER comes first:
 *      • 5-minute time threshold
 *      • 500-line safety cap
 *  - Day change flush and onTaskRemoved flush are always forced (ignoring thresholds).
 *
 * File layout (inside context.filesDir):
 *   fs/buffer/steps_buf.tmp   ← "$epochSec,$steps\n"  (append-only)
 *   fs/buffer/sleep_buf.tmp   ← "$dateKey|$startIso|$endIso\n"
 *   fs/daily/YYYY-MM-DD.json  ← aggregated daily record
 *   fs/sync_queue.json        ← ["2026-04-05","2026-04-06"]
 */
object BufferManager {

    private const val TAG = "BufferManager"

    private const val FLUSH_INTERVAL_MS = 5 * 60 * 1000L   // 5 minutes
    private const val MAX_BUFFER_LINES  = 500               // safety cap

    @Volatile private var lastFlushTime = System.currentTimeMillis()
    @Volatile private var stepLineCount = 0

    // ─────────────────────────────────────────────
    // STEP BUFFER
    // ─────────────────────────────────────────────

    /**
     * Appends one step event to the buffer. O(1) — no read, no parse.
     * Triggers auto-flush when time or line threshold is exceeded.
     */
    @Synchronized
    fun appendStepEvent(context: Context, steps: Int, ts: Long = System.currentTimeMillis() / 1000L) {
        try {
            val bufFile = stepsBufFile(context)
            bufFile.appendText("$ts,$steps\n")
            stepLineCount++

            val now = System.currentTimeMillis()
            val elapsed = now - lastFlushTime

            if (elapsed >= FLUSH_INTERVAL_MS || stepLineCount >= MAX_BUFFER_LINES) {
                Log.d(TAG, "Auto-flush triggered (elapsed=${elapsed}ms, lines=$stepLineCount)")
                flushStepsToDaily(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "appendStepEvent error: ${e.message}")
        }
    }

    /**
     * Force-flush regardless of thresholds. Call on day change, onTaskRemoved,
     * or before any sync operation.
     */
    @Synchronized
    fun flushStepsToDaily(context: Context) {
        try {
            val bufFile = stepsBufFile(context)
            if (!bufFile.exists() || bufFile.length() == 0L) return

            val lines = bufFile.readLines()
            val maxPerDay = mutableMapOf<String, Int>()

            for (line in lines) {
                val (ts, steps) = parseStepLine(line) ?: continue
                val key = dateKeyFromEpoch(ts)
                val cur = maxPerDay[key] ?: 0
                if (steps > cur) maxPerDay[key] = steps
            }

            for ((dateKey, steps) in maxPerDay) {
                mergeStepsIntoDailyFile(context, dateKey, steps)
            }

            bufFile.delete()
            lastFlushTime = System.currentTimeMillis()
            stepLineCount = 0

            Log.d(TAG, "Steps buffer flushed (${maxPerDay.size} day(s))")
        } catch (e: Exception) {
            Log.e(TAG, "flushStepsToDaily error: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────
    // SLEEP BUFFER
    // ─────────────────────────────────────────────

    @Synchronized
    fun appendSleepInterval(context: Context, dateKey: String, startIso: String, endIso: String) {
        try {
            val bufFile = sleepBufFile(context)
            bufFile.appendText("$dateKey|$startIso|$endIso\n")
            Log.d(TAG, "Sleep interval buffered: $dateKey")
        } catch (e: Exception) {
            Log.e(TAG, "appendSleepInterval error: ${e.message}")
        }
    }

    @Synchronized
    fun flushSleepToDaily(context: Context) {
        try {
            val bufFile = sleepBufFile(context)
            if (!bufFile.exists() || bufFile.length() == 0L) return

            val lines = bufFile.readLines()
            // Group by dateKey
            val byDay = mutableMapOf<String, MutableList<Pair<String, String>>>()

            for (line in lines) {
                val parts = line.trim().split("|")
                if (parts.size < 3) continue
                val key = parts[0]
                byDay.getOrPut(key) { mutableListOf() }.add(Pair(parts[1], parts[2]))
            }

            for ((dateKey, segments) in byDay) {
                var totalMinutes = 0
                for ((startIso, endIso) in segments) {
                    try {
                        val fmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
                        val start = fmt.parse(startIso.take(23)) ?: continue
                        val end   = fmt.parse(endIso.take(23))   ?: continue
                        val diff = ((end.time - start.time) / 60_000).toInt()
                        if (diff > 0) totalMinutes += diff
                    } catch (_: Exception) {}
                }
                mergeSleepIntoDailyFile(context, dateKey, totalMinutes)
            }

            bufFile.delete()
            Log.d(TAG, "Sleep buffer flushed")
        } catch (e: Exception) {
            Log.e(TAG, "flushSleepToDaily error: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────
    // SYNC QUEUE
    // ─────────────────────────────────────────────

    fun addToSyncQueue(context: Context, dateKey: String) {
        try {
            val queueFile = File(fsDir(context), "sync_queue.json")
            val existing = if (queueFile.exists()) {
                val arr = org.json.JSONArray(queueFile.readText())
                (0 until arr.length()).map { arr.getString(it) }.toMutableList()
            } else mutableListOf()

            if (!existing.contains(dateKey)) {
                existing.add(dateKey)
                queueFile.writeText(org.json.JSONArray(existing).toString())
                Log.d(TAG, "Added $dateKey to sync queue")
            }
        } catch (e: Exception) {
            Log.e(TAG, "addToSyncQueue error: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────
    // DAILY JSON HELPERS
    // ─────────────────────────────────────────────

    private fun mergeStepsIntoDailyFile(context: Context, dateKey: String, steps: Int) {
        mergeDailyJson(context, dateKey) { json ->
            val current = json.optJSONObject("steps")?.optInt("total") ?: 0
            if (steps > current) {
                json.put("steps", JSONObject().put("total", steps))
            }
        }
    }

    private fun mergeSleepIntoDailyFile(context: Context, dateKey: String, totalMinutes: Int) {
        mergeDailyJson(context, dateKey) { json ->
            val existing = json.optJSONObject("sleep")?.optInt("total_sleep_minutes") ?: 0
            if (totalMinutes >= existing) {
                val sleepObj = json.optJSONObject("sleep") ?: JSONObject()
                sleepObj.put("total_sleep_minutes", totalMinutes)
                json.put("sleep", sleepObj)
            }
        }
    }

    private fun mergeDailyJson(context: Context, dateKey: String, mutate: (JSONObject) -> Unit) {
        val file = dailyFile(context, dateKey)
        val json = if (file.exists()) {
            try { JSONObject(file.readText()) } catch (_: Exception) { emptyDailyJson(dateKey) }
        } else emptyDailyJson(dateKey)

        mutate(json)
        file.writeText(json.toString(2))
    }

    private fun emptyDailyJson(dateKey: String): JSONObject =
        JSONObject()
            .put("date", dateKey)
            .put("steps", JSONObject().put("total", 0))
            .put("sleep", JSONObject().put("total_sleep_minutes", 0).put("segments", org.json.JSONArray()))
            .put("sent", false)
            .put("created_at", System.currentTimeMillis() / 1000L)

    // ─────────────────────────────────────────────
    // FILE HELPERS
    // ─────────────────────────────────────────────

    private fun fsDir(context: Context): File =
        File(context.filesDir, "fs").also { it.mkdirs() }

    private fun bufferDir(context: Context): File =
        File(fsDir(context), "buffer").also { it.mkdirs() }

    private fun dailyDir(context: Context): File =
        File(fsDir(context), "daily").also { it.mkdirs() }

    private fun stepsBufFile(context: Context) = File(bufferDir(context), "steps_buf.tmp")
    private fun sleepBufFile(context: Context) = File(bufferDir(context), "sleep_buf.tmp")
    private fun dailyFile(context: Context, dateKey: String) = File(dailyDir(context), "$dateKey.json")

    private fun parseStepLine(line: String): Pair<Long, Int>? {
        return try {
            val parts = line.trim().split(",")
            if (parts.size < 2) null
            else Pair(parts[0].toLong(), parts[1].toInt())
        } catch (_: Exception) { null }
    }

    private fun dateKeyFromEpoch(epochSec: Long): String {
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = epochSec * 1000L
        return "%04d-%02d-%02d".format(
            cal.get(java.util.Calendar.YEAR),
            cal.get(java.util.Calendar.MONTH) + 1,
            cal.get(java.util.Calendar.DAY_OF_MONTH)
        )
    }
}
