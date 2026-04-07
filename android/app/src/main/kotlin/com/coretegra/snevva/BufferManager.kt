package com.coretegra.snevva

import android.content.Context
import android.util.Log
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.time.Instant
import java.time.ZoneId

object BufferManager {
    private const val TAG = "BufferManager"
    private const val STEP_FLUSH_THRESHOLD = 100
    private const val SLEEP_FLUSH_THRESHOLD = 10

    private val zoneId: ZoneId = ZoneId.systemDefault()
    private val stepBuilder = StringBuilder()
    private val sleepBuilder = StringBuilder()
    private var stepEventCount = 0
    private var sleepEventCount = 0

    @Synchronized
    fun appendStepEvent(context: Context, timestampMillis: Long, delta: Int = 1) {
        stepBuilder.append(timestampMillis).append(',').append(delta).append('\n')
        stepEventCount += 1

        if (stepEventCount >= STEP_FLUSH_THRESHOLD) {
            flushStepBuilderToBuffer(context)
            flushStepsToDaily(context)
        }
    }

    @Synchronized
    fun appendSleepEvent(context: Context, timestampMillis: Long, event: String) {
        sleepBuilder.append(timestampMillis).append(',').append(event).append('\n')
        sleepEventCount += 1

        if (sleepEventCount >= SLEEP_FLUSH_THRESHOLD || event == "ON") {
            flushSleepBuilderToBuffer(context)
            flushSleepToDaily(context)
        }
    }

    @Synchronized
    fun flushAll(context: Context) {
        flushStepBuilderToBuffer(context)
        flushSleepBuilderToBuffer(context)
        flushStepsToDaily(context)
        flushSleepToDaily(context)
    }

    @Synchronized
    fun pendingBufferedStepCountForDay(context: Context, dayKey: String): Int {
        var count = 0
        stepBuilder.lineSequence().forEach { line ->
            val parts = line.split(',')
            val timestamp = parts.firstOrNull()?.toLongOrNull() ?: return@forEach
            val key = SleepWindowResolver.formatDayKey(
                Instant.ofEpochMilli(timestamp).atZone(zoneId).toLocalDate()
            )
            if (key == dayKey) {
                count += parts.getOrNull(1)?.toIntOrNull() ?: 0
            }
        }

        val file = HealthFilePaths.stepBufferFile(context)
        if (!file.exists()) return count

        file.forEachLine { line ->
            val parts = line.split(',')
            val timestamp = parts.firstOrNull()?.toLongOrNull() ?: return@forEachLine
            val key = SleepWindowResolver.formatDayKey(
                Instant.ofEpochMilli(timestamp).atZone(zoneId).toLocalDate()
            )
            if (key == dayKey) {
                count += parts.getOrNull(1)?.toIntOrNull() ?: 0
            }
        }
        return count
    }

    @Synchronized
    fun flushStepsToDaily(context: Context) {
        val file = HealthFilePaths.stepBufferFile(context)
        if (!file.exists() || file.length() == 0L) return

        val timestampsByDay = LinkedHashMap<String, MutableList<Long>>()
        file.forEachLine { line ->
            val parsed = parseStepLine(line) ?: return@forEachLine
            val dayKey = SleepWindowResolver.formatDayKey(
                Instant.ofEpochMilli(parsed.first).atZone(zoneId).toLocalDate()
            )
            repeat(parsed.second.coerceAtLeast(1)) {
                timestampsByDay.getOrPut(dayKey) { mutableListOf() }.add(parsed.first)
            }
        }

        timestampsByDay.forEach { (dayKey, timestamps) ->
            DailyStore.applyStepEvents(context, dayKey, timestamps)
        }

        file.writeText("")
    }

    @Synchronized
    fun flushSleepToDaily(context: Context) {
        val file = HealthFilePaths.sleepBufferFile(context)
        if (!file.exists() || file.length() == 0L) return

        val bedtime = MetaStore.bedtimeMinutes(context)
        val waketime = MetaStore.waketimeMinutes(context)
        var pendingOff = MetaStore.pendingSleepOffTimestamp(context)
        val segmentsByDay = LinkedHashMap<String, MutableList<NativeSleepSegment>>()

        file.forEachLine { line ->
            val parsed = parseSleepLine(line) ?: return@forEachLine
            when (parsed.second) {
                "OFF" -> {
                    if (pendingOff == null) {
                        pendingOff = parsed.first
                    }
                }

                "ON" -> {
                    val offTs = pendingOff ?: return@forEachLine
                    if (parsed.first <= offTs) {
                        pendingOff = null
                        return@forEachLine
                    }

                    val window = SleepWindowResolver.resolveForTimestamp(offTs, bedtime, waketime)
                    if (window != null) {
                        segmentsByDay.getOrPut(window.dayKey) { mutableListOf() }
                            .add(
                                NativeSleepSegment(
                                    screenOffMillis = offTs,
                                    screenOnMillis = parsed.first
                                )
                            )
                    }
                    pendingOff = null
                }
            }
        }

        segmentsByDay.forEach { (dayKey, segments) ->
            DailyStore.appendSleepSegments(context, dayKey, segments, bedtime, waketime)
        }

        MetaStore.setPendingSleepOffTimestamp(context, pendingOff)
        file.writeText("")
    }

    private fun flushStepBuilderToBuffer(context: Context) {
        if (stepBuilder.isEmpty()) return
        appendToFile(HealthFilePaths.stepBufferFile(context), stepBuilder.toString())
        stepBuilder.setLength(0)
        stepEventCount = 0
    }

    private fun flushSleepBuilderToBuffer(context: Context) {
        if (sleepBuilder.isEmpty()) return
        appendToFile(HealthFilePaths.sleepBufferFile(context), sleepBuilder.toString())
        sleepBuilder.setLength(0)
        sleepEventCount = 0
    }

    private fun appendToFile(file: File, payload: String) {
        file.parentFile?.mkdirs()
        runCatching {
            BufferedWriter(FileWriter(file, true)).use { writer ->
                writer.write(payload)
                writer.flush()
            }
        }.onFailure { error ->
            Log.e(TAG, "Failed writing buffer file ${file.name}", error)
        }
    }

    private fun parseStepLine(line: String): Pair<Long, Int>? {
        val parts = line.trim().split(',')
        if (parts.size < 2) return null
        val timestamp = parts[0].toLongOrNull() ?: return null
        val delta = parts[1].toIntOrNull() ?: return null
        return timestamp to delta
    }

    private fun parseSleepLine(line: String): Pair<Long, String>? {
        val parts = line.trim().split(',')
        if (parts.size < 2) return null
        val timestamp = parts[0].toLongOrNull() ?: return null
        val state = parts[1].uppercase()
        if (state != "OFF" && state != "ON") return null
        return timestamp to state
    }
}
