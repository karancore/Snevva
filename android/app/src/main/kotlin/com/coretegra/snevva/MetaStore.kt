package com.coretegra.snevva

import android.content.Context
import org.json.JSONObject

object MetaStore {
    private const val KEY_CURRENT_DAY = "current_day"
    private const val KEY_BEDTIME_MINUTES = "bedtime_minutes"
    private const val KEY_WAKETIME_MINUTES = "waketime_minutes"
    private const val KEY_LAST_SYNC_TS = "last_sync_ts"
    private const val KEY_MIGRATION_COMPLETED = "migration_completed"
    private const val KEY_PENDING_SLEEP_OFF_TS = "pending_sleep_off_ts"
    private const val KEY_SLEEP_WINDOW_START = "sleep_window_start"
    private const val KEY_SLEEP_WINDOW_END = "sleep_window_end"
    private const val KEY_SLEEP_WINDOW_KEY = "sleep_window_key"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"

    @Synchronized
    fun read(context: Context): JSONObject {
        val file = HealthFilePaths.metaFile(context)
        if (!file.exists()) {
            val created = JSONObject().apply {
                put(KEY_CURRENT_DAY, SleepWindowResolver.formatDayKey(java.time.LocalDate.now()))
                put(KEY_LAST_SYNC_TS, 0L)
                put(KEY_MIGRATION_COMPLETED, false)
            }
            file.writeText(created.toString())
            return created
        }

        return runCatching { JSONObject(file.readText()) }.getOrElse {
            JSONObject().apply {
                put(KEY_CURRENT_DAY, SleepWindowResolver.formatDayKey(java.time.LocalDate.now()))
                put(KEY_LAST_SYNC_TS, 0L)
                put(KEY_MIGRATION_COMPLETED, false)
            }
        }
    }

    @Synchronized
    fun write(context: Context, meta: JSONObject) {
        HealthFilePaths.metaFile(context).writeText(meta.toString())
    }

    @Synchronized
    fun update(context: Context, mutate: (JSONObject) -> Unit): JSONObject {
        val meta = read(context)
        mutate(meta)
        write(context, meta)
        return meta
    }

    fun ensureCurrentDay(context: Context): String {
        val today = SleepWindowResolver.formatDayKey(java.time.LocalDate.now())
        update(context) { meta ->
            meta.put(KEY_CURRENT_DAY, today)
        }
        return today
    }

    fun currentDay(context: Context): String =
        read(context).optString(
            KEY_CURRENT_DAY,
            SleepWindowResolver.formatDayKey(java.time.LocalDate.now())
        )

    fun bedtimeMinutes(context: Context): Int? {
        val metaValue = read(context).optInt(KEY_BEDTIME_MINUTES, -1).takeIf { it >= 0 }
        if (metaValue != null) return metaValue
        return context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .all["flutter.user_bedtime_ms"]
            .toIntCompat()
    }

    fun waketimeMinutes(context: Context): Int? {
        val metaValue = read(context).optInt(KEY_WAKETIME_MINUTES, -1).takeIf { it >= 0 }
        if (metaValue != null) return metaValue
        return context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .all["flutter.user_waketime_ms"]
            .toIntCompat()
    }

    fun syncSleepSchedule(context: Context) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val bedtime = prefs.all["flutter.user_bedtime_ms"].toIntCompat()
        val waketime = prefs.all["flutter.user_waketime_ms"].toIntCompat()
        updateSleepSchedule(context, bedtime, waketime)
    }

    fun updateSleepSchedule(context: Context, bedtimeMinutes: Int?, waketimeMinutes: Int?) {
        update(context) { meta ->
            if (bedtimeMinutes != null) {
                meta.put(KEY_BEDTIME_MINUTES, bedtimeMinutes)
            } else {
                meta.remove(KEY_BEDTIME_MINUTES)
            }
            if (waketimeMinutes != null) {
                meta.put(KEY_WAKETIME_MINUTES, waketimeMinutes)
            } else {
                meta.remove(KEY_WAKETIME_MINUTES)
            }
            meta.put(KEY_CURRENT_DAY, SleepWindowResolver.formatDayKey(java.time.LocalDate.now()))
        }
    }

    fun lastSyncTimestamp(context: Context): Long = read(context).optLong(KEY_LAST_SYNC_TS, 0L)

    fun setLastSyncTimestamp(context: Context, timestampMillis: Long) {
        update(context) { meta -> meta.put(KEY_LAST_SYNC_TS, timestampMillis) }
    }

    fun isMigrationCompleted(context: Context): Boolean =
        read(context).optBoolean(KEY_MIGRATION_COMPLETED, false)

    fun markMigrationCompleted(context: Context, completed: Boolean = true) {
        update(context) { meta -> meta.put(KEY_MIGRATION_COMPLETED, completed) }
    }

    fun pendingSleepOffTimestamp(context: Context): Long? =
        read(context).optLong(KEY_PENDING_SLEEP_OFF_TS, -1L).takeIf { it >= 0L }

    fun setPendingSleepOffTimestamp(context: Context, timestampMillis: Long?) {
        update(context) { meta ->
            if (timestampMillis == null) {
                meta.remove(KEY_PENDING_SLEEP_OFF_TS)
            } else {
                meta.put(KEY_PENDING_SLEEP_OFF_TS, timestampMillis)
            }
        }
    }

    fun updateResolvedSleepWindow(context: Context, window: SleepWindow?) {
        update(context) { meta ->
            if (window == null) {
                meta.remove(KEY_SLEEP_WINDOW_START)
                meta.remove(KEY_SLEEP_WINDOW_END)
                meta.remove(KEY_SLEEP_WINDOW_KEY)
            } else {
                meta.put(KEY_SLEEP_WINDOW_START, window.start.toString())
                meta.put(KEY_SLEEP_WINDOW_END, window.end.toString())
                meta.put(KEY_SLEEP_WINDOW_KEY, window.dayKey)
            }
        }
    }

    fun resolveSleepWindow(
        context: Context,
        timestampMillis: Long = System.currentTimeMillis()
    ): SleepWindow? {
        val bedtime = bedtimeMinutes(context)
        val waketime = waketimeMinutes(context)
        val window = SleepWindowResolver.resolveForTimestamp(timestampMillis, bedtime, waketime)
        updateResolvedSleepWindow(context, window)
        return window
    }

    private fun Any?.toIntCompat(): Int? = when (this) {
        is Int -> this
        is Long -> this.toInt()
        is Float -> this.toInt()
        is Double -> this.toInt()
        is String -> this.toIntOrNull()
        is Number -> this.toInt()
        else -> null
    }
}
