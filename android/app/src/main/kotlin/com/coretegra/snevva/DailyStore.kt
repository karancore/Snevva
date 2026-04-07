package com.coretegra.snevva

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class NativeSleepSegment(
    val screenOffMillis: Long,
    val screenOnMillis: Long,
)

object DailyStore {
    private val zoneId: ZoneId = ZoneId.systemDefault()

    @Synchronized
    fun readDay(context: Context, dayKey: String): JSONObject {
        val file = HealthFilePaths.dailyFile(context, dayKey)
        if (!file.exists()) {
            return createDefaultDay(dayKey)
        }

        return runCatching { JSONObject(file.readText()) }.getOrElse {
            createDefaultDay(dayKey)
        }
    }

    @Synchronized
    fun writeDay(context: Context, dayKey: String, dayJson: JSONObject) {
        val file = HealthFilePaths.dailyFile(context, dayKey)
        file.parentFile?.mkdirs()
        file.writeText(dayJson.toString())
    }

    @Synchronized
    fun applyStepEvents(context: Context, dayKey: String, timestamps: List<Long>) {
        if (timestamps.isEmpty()) return

        val dayJson = readDay(context, dayKey)
        val steps = dayJson.optJSONObject("steps") ?: JSONObject()
        val hourly = ensureHourlyArray(steps.optJSONArray("hourly"))
        var total = steps.optInt("total", 0)

        timestamps.forEach { timestamp ->
            val dateTime = Instant.ofEpochMilli(timestamp).atZone(zoneId).toLocalDateTime()
            val hour = dateTime.hour.coerceIn(0, 23)
            val current = hourly.optInt(hour, 0)
            hourly.put(hour, current + 1)
            total += 1
        }

        steps.put("total", total)
        steps.put("hourly", hourly)
        dayJson.put("steps", steps)
        dayJson.put("sent", false)
        dayJson.put("updated_at", System.currentTimeMillis())
        writeDay(context, dayKey, dayJson)
    }

    @Synchronized
    fun appendSleepSegments(
        context: Context,
        dayKey: String,
        segments: List<NativeSleepSegment>,
        bedtimeMinutes: Int?,
        waketimeMinutes: Int?,
    ) {
        if (segments.isEmpty()) return

        val window = SleepWindowResolver.resolveForDayKey(dayKey, bedtimeMinutes, waketimeMinutes)
        val dayJson = readDay(context, dayKey)
        val sleep = dayJson.optJSONObject("sleep") ?: JSONObject()
        val existingSegments = sleep.optJSONArray("segments") ?: JSONArray()
        val seen = HashSet<String>()

        for (index in 0 until existingSegments.length()) {
            val segment = existingSegments.optJSONObject(index) ?: continue
            val key = "${segment.optLong("screen_off", -1L)}:${segment.optLong("screen_on", -1L)}"
            seen.add(key)
        }

        val clippedSegments = mutableListOf<NativeSleepSegment>()
        segments.forEach { segment ->
            val clipped = clipSegmentToWindow(segment, window) ?: return@forEach
            val signature = "${clipped.screenOffMillis}:${clipped.screenOnMillis}"
            if (seen.add(signature)) {
                existingSegments.put(
                    JSONObject().apply {
                        put("screen_off", clipped.screenOffMillis)
                        put("screen_on", clipped.screenOnMillis)
                    }
                )
            }
            clippedSegments.add(clipped)
        }

        if (clippedSegments.isEmpty() && existingSegments.length() == 0) {
            return
        }

        val totalMinutes = calculateTotalSleepMinutes(existingSegments)
        sleep.put("segments", sortSegments(existingSegments))
        sleep.put("total_sleep_minutes", totalMinutes)
        SleepWindowResolver.formatClock(bedtimeMinutes)?.let { sleep.put("window_start", it) }
        SleepWindowResolver.formatClock(waketimeMinutes)?.let { sleep.put("window_end", it) }
        dayJson.put("sleep", sleep)
        dayJson.put("sent", false)
        dayJson.put("updated_at", System.currentTimeMillis())
        writeDay(context, dayKey, dayJson)
    }

    fun todayStepTotal(context: Context): Int {
        val dayKey = SleepWindowResolver.formatDayKey(LocalDate.now())
        val totalFromDaily =
            readDay(context, dayKey).optJSONObject("steps")?.optInt("total", 0) ?: 0
        return totalFromDaily + BufferManager.pendingBufferedStepCountForDay(context, dayKey)
    }

    fun listPendingDayKeys(context: Context): List<String> {
        val directory = HealthFilePaths.dailyDirectory(context)
        if (!directory.exists()) return emptyList()

        return directory.listFiles()
            ?.filter { it.isFile && it.extension == "json" }
            ?.map { it.nameWithoutExtension }
            ?.sorted()
            ?: emptyList()
    }

    fun deleteDay(context: Context, dayKey: String) {
        HealthFilePaths.dailyFile(context, dayKey).takeIf { it.exists() }?.delete()
    }

    private fun createDefaultDay(dayKey: String): JSONObject {
        return JSONObject().apply {
            put("date", dayKey)
            put(
                "steps",
                JSONObject().apply {
                    put("total", 0)
                    put("hourly", ensureHourlyArray(null))
                }
            )
            put(
                "sleep",
                JSONObject().apply {
                    put("segments", JSONArray())
                    put("total_sleep_minutes", 0)
                }
            )
            put("sent", false)
            put("created_at", System.currentTimeMillis())
        }
    }

    private fun ensureHourlyArray(existing: JSONArray?): JSONArray {
        val hourly = JSONArray()
        for (index in 0 until 24) {
            hourly.put(existing?.optInt(index, 0) ?: 0)
        }
        return hourly
    }

    private fun clipSegmentToWindow(
        segment: NativeSleepSegment,
        window: SleepWindow?,
    ): NativeSleepSegment? {
        if (segment.screenOnMillis <= segment.screenOffMillis) return null
        if (window == null) return segment

        val clippedStart =
            maxOf(segment.screenOffMillis, SleepWindowResolver.toEpochMillis(window.start))
        val clippedEnd =
            minOf(segment.screenOnMillis, SleepWindowResolver.toEpochMillis(window.end))
        if (clippedEnd <= clippedStart) return null

        return NativeSleepSegment(screenOffMillis = clippedStart, screenOnMillis = clippedEnd)
    }

    private fun calculateTotalSleepMinutes(segments: JSONArray): Int {
        var totalMinutes = 0
        for (index in 0 until segments.length()) {
            val segment = segments.optJSONObject(index) ?: continue
            val off = segment.optLong("screen_off", -1L)
            val on = segment.optLong("screen_on", -1L)
            if (off < 0 || on <= off) continue
            totalMinutes += ((on - off) / 60000L).toInt()
        }
        return totalMinutes
    }

    private fun sortSegments(segments: JSONArray): JSONArray {
        val sorted = (0 until segments.length())
            .mapNotNull { segments.optJSONObject(it) }
            .sortedBy { it.optLong("screen_off", Long.MAX_VALUE) }

        return JSONArray().apply {
            sorted.forEach { put(it) }
        }
    }
}
