package com.coretegra.snevvaa

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.coretegra.snevvaa.ReminderArmingHelper.PREFS_KEY
import org.json.JSONArray
import java.io.File
import java.util.Date

/**
 * Pure-Kotlin singleton that owns arming and cancelling reminder alarms via
 * AlarmManager.setExactAndAllowWhileIdle().
 *
 * This layer is completely independent of the Flutter engine — it survives
 * OEM battery optimization kills and device reboots.
 *
 * Dart writes a JSON array of scheduled alarms to SharedPreferences under
 * [PREFS_KEY]. This helper reads that array and arms/cancels AlarmManager
 * entries independently of whether the Flutter engine is alive.
 *
 * Called from:
 *   • BootReceiver  — re-arms all alarms after reboot
 *   • MainActivity  — re-arms on every app open (idempotent)
 *   • MethodChannel — arms immediately after Dart saves a new reminder
 */
object ReminderArmingHelper {

    private const val TAG = "ReminderArmingHelper"

    /** SharedPreferences file name used by the Flutter shared_preferences plugin. */
    private const val PREFS_FILE = "FlutterSharedPreferences"

    /** Flutter shared_preferences adds "flutter." prefix to all keys. */
    private const val PREFS_KEY = "flutter.native_reminder_alarms"

    /**
     * Tombstone keys written by Flutter's _recordLocalDeletion().
     * We read these so armFromSharedPrefs / BootReceiver / rescheduleNext
     * never resurrect a reminder the user explicitly deleted.
     */
    private const val DELETED_GROUP_IDS_KEY = "flutter.deleted_reminder_group_ids_v1"
    private const val DELETED_ALARM_IDS_KEY = "flutter.deleted_reminder_alarm_ids_v1"

    /** Intent action fired to ReminderAlarmReceiver by AlarmManager. */
    const val ACTION_FIRE = "com.coretegra.snevvaa.REMINDER_FIRE"

    // ─────────────────────────────────────────────────────────────────────────
    // armFromSharedPrefs — read saved schedule + arm all future alarms
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Reads all alarms from SharedPrefs and arms every one whose trigger
     * time is still in the future. Safe to call multiple times (idempotent).
     *
     * ✅ Tombstone guard: skips any alarm whose groupId or alarmId appears in
     * the Flutter-written deleted-IDs lists, so BootReceiver / engine-attach
     * re-arms cannot resurrect reminders the user explicitly deleted.
     */
    fun armFromSharedPrefs(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

        // ✅ GUARD: Skip re-arming if reminders are disabled (e.g. user logged out)
        if (prefs.getBoolean("flutter.reminders_disabled", false)) {
            Log.d(TAG, "⛔ armFromSharedPrefs: Reminders are disabled (logged out) — skipping")
            return
        }

        val json = prefs.getString(PREFS_KEY, null)
        if (json.isNullOrBlank()) {
            Log.d(TAG, "armFromSharedPrefs: no saved alarms")
            return
        }

        // ── Load tombstone sets written by Flutter's _recordLocalDeletion() ──
        val deletedGroupIds = readIntSetFromJsonArray(prefs, DELETED_GROUP_IDS_KEY)
        val deletedAlarmIds = readIntSetFromJsonArray(prefs, DELETED_ALARM_IDS_KEY)

        try {
            val arr = JSONArray(json)
            val now = System.currentTimeMillis()
            var armed = 0
            var skipped = 0
            var tombstoned = 0

            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val alarmId = obj.getInt("alarmId")
                val epochMs = obj.getLong("epochMs")
                val groupId = obj.optString("groupId", "").toIntOrNull() ?: -1

                // ✅ Skip deleted reminders — user explicitly removed these
                if (alarmId in deletedAlarmIds || (groupId != -1 && groupId in deletedGroupIds)) {
                    Log.d(TAG, "⛔ Skipping tombstoned alarm id=$alarmId groupId=$groupId")
                    tombstoned++
                    continue
                }

                if (epochMs <= now) {
                    skipped++
                    continue
                }

                arm(
                    context    = context,
                    alarmId    = alarmId,
                    epochMs    = epochMs,
                    groupId    = obj.optString("groupId", ""),
                    category   = obj.optString("category", ""),
                    title      = obj.optString("title", "Reminder"),
                    body       = obj.optString("body", ""),
                    intervalMs = obj.optLong("intervalMs", 0L),
                )
                armed++
            }

            Log.d(TAG, "armFromSharedPrefs: armed=$armed skipped=$skipped tombstoned=$tombstoned")
        } catch (e: Exception) {
            Log.e(TAG, "armFromSharedPrefs failed: ${e.message}")
        }
    }

    /** Reads a Flutter-persisted JSON array of ints into a Set<Int>. */
    private fun readIntSetFromJsonArray(
        prefs: android.content.SharedPreferences,
        key: String,
    ): Set<Int> {
        val raw = prefs.getString(key, null) ?: return emptySet()
        return try {
            val arr = JSONArray(raw)
            val set = mutableSetOf<Int>()
            for (i in 0 until arr.length()) {
                when (val v = arr.get(i)) {
                    is Int    -> set.add(v)
                    is Long   -> set.add(v.toInt())
                    is String -> v.toIntOrNull()?.let { set.add(it) }
                }
            }
            set
        } catch (_: Exception) {
            emptySet()
        }
    }

    // Alias used by BootReceiver
    fun armAllFromSharedPrefs(context: Context) = armFromSharedPrefs(context)

    // ─────────────────────────────────────────────────────────────────────────
    // arm — set a single exact alarm via AlarmManager
    // ─────────────────────────────────────────────────────────────────────────

    fun arm(
        context: Context,
        alarmId: Int,
        epochMs: Long,
        groupId: String,
        category: String,
        title: String,
        body: String,
        intervalMs: Long = 0L,
    ) {
        if (epochMs <= System.currentTimeMillis()) {
            Log.w(TAG, "Skipping past alarm id=$alarmId at epochMs=$epochMs")
            return
        }

        val intent = buildFireIntent(context, alarmId, groupId, category, title, body, intervalMs)
        val pending = PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val mgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    if (mgr.canScheduleExactAlarms()) {
                        mgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pending)
                    } else {
                        mgr.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pending)
                    }
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    mgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pending)
                }
                else -> {
                    mgr.setExact(AlarmManager.RTC_WAKEUP, epochMs, pending)
                }
            }
            Log.d(TAG, "✅ armed alarmId=$alarmId category=$category at ${Date(epochMs)}" +
                    if (intervalMs > 0) " interval=${intervalMs}ms" else "")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException arming alarm id=$alarmId — exact alarm permission denied", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error arming alarm id=$alarmId", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // cancel — cancel a single alarm by alarmId
    // ─────────────────────────────────────────────────────────────────────────

    fun cancel(context: Context, alarmId: Int) {
        // 1. Cancel from AlarmManager
        cancelFromAlarmManager(context, alarmId)

        // 2. ✅ FIX: Remove from persisted JSON schedule so armFromSharedPrefs /
        //    BootReceiver cannot re-arm it the next time the app opens or reboots.
        removeFromPersistedSchedule(context, setOf(alarmId))

        Log.d(TAG, "🗑️ cancelled native alarmId=$alarmId")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // cancelAll — batch cancel by alarm IDs (called by "cancelAlarms" channel)
    // ─────────────────────────────────────────────────────────────────────────

    fun cancelAll(context: Context, alarmIds: List<Int>) {
        if (alarmIds.isEmpty()) return

        for (alarmId in alarmIds) {
            cancelFromAlarmManager(context, alarmId)
            Log.d(TAG, "🗑️ cancelled native alarmId=$alarmId")
        }

        // ✅ Single SharedPrefs write for the entire batch — avoids N separate commits.
        removeFromPersistedSchedule(context, alarmIds.toSet())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // cancelAllPersisted — clears all alarms globally (e.g., on logout)
    // ─────────────────────────────────────────────────────────────────────────

    fun cancelAllPersisted(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(PREFS_KEY, null)

        if (!json.isNullOrBlank()) {
            try {
                val arr = JSONArray(json)
                for (i in 0 until arr.length()) {
                    val alarmId = arr.getJSONObject(i).optInt("alarmId", -1)
                    if (alarmId != -1) {
                        cancelFromAlarmManager(context, alarmId)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "cancelAllPersisted failed to parse schedule", e)
            }
        }

        prefs.edit()
            .remove(PREFS_KEY)
            .remove("flutter.alarm_fired_recently")
            .apply()

        Log.d(TAG, "🗑️ cancelAllPersisted: Removed all native alarms and schedule.")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // cancelByGroupId — cancels ALL alarms belonging to a reminder group.
    //
    // ✅ NEW — Correct delete method for meal / medicine / event reminders.
    // Each group can have multiple alarmIds. Cancelling only the IDs known at
    // delete-time misses any ID created by rescheduleNext() in a race condition
    // (alarm fires at the exact moment user taps delete). Sweeping by groupId
    // catches every entry regardless of when it was written.
    // ─────────────────────────────────────────────────────────────────────────

    fun cancelByGroupId(context: Context, groupId: Int) {
        if (groupId == -1) return

        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(PREFS_KEY, null) ?: return

        try {
            val arr = JSONArray(json)
            val updated = JSONArray()
            val cancelledIds = mutableListOf<Int>()

            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val entryGroupId = obj.optString("groupId", "").toIntOrNull() ?: -1
                if (entryGroupId == groupId) {
                    val alarmId = obj.optInt("alarmId", -1)
                    if (alarmId != -1) {
                        cancelFromAlarmManager(context, alarmId)
                        cancelledIds.add(alarmId)
                    }
                } else {
                    updated.put(obj)
                }
            }

            if (cancelledIds.isNotEmpty()) {
                prefs.edit().putString(PREFS_KEY, updated.toString()).apply()
                Log.d(TAG, "🗑️ cancelByGroupId=$groupId removed ${cancelledIds.size} alarm(s): $cancelledIds")
            } else {
                Log.d(TAG, "🗑️ cancelByGroupId=$groupId — no entries found in JSON schedule")
            }
        } catch (e: Exception) {
            Log.e(TAG, "cancelByGroupId failed for groupId=$groupId", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // removeFromPersistedSchedule — purges IDs from the JSON schedule in prefs
    // ─────────────────────────────────────────────────────────────────────────

    private fun removeFromPersistedSchedule(context: Context, alarmIds: Set<Int>) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(PREFS_KEY, null) ?: return

        try {
            val arr = JSONArray(json)
            val updated = JSONArray()
            var removed = 0

            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optInt("alarmId", -1) in alarmIds) {
                    removed++
                } else {
                    updated.put(obj)
                }
            }

            if (removed > 0) {
                prefs.edit().putString(PREFS_KEY, updated.toString()).apply()
                Log.d(TAG, "🗑️ Removed $removed entry/entries from persisted schedule → $alarmIds")
            }
        } catch (e: Exception) {
            Log.e(TAG, "removeFromPersistedSchedule failed", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // cancelFromAlarmManager — cancel a single PendingIntent from AlarmManager
    // ─────────────────────────────────────────────────────────────────────────

    private fun cancelFromAlarmManager(context: Context, alarmId: Int) {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
        }
        val pending = PendingIntent.getBroadcast(
            context, alarmId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val mgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        mgr.cancel(pending)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // armAll — arm from a raw JSON string (MethodChannel / reconcile)
    // ─────────────────────────────────────────────────────────────────────────

    fun armAll(context: Context, jsonString: String) {
        try {
            val array = JSONArray(jsonString)
            val now = System.currentTimeMillis()
            var armed = 0

            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val alarmId  = obj.optInt("alarmId", -1)
                val epochMs  = obj.optLong("epochMs", 0L)

                if (alarmId == -1 || epochMs <= 0 || epochMs <= now) continue

                arm(
                    context,
                    alarmId,
                    epochMs,
                    obj.optString("groupId", ""),
                    obj.optString("category", ""),
                    obj.optString("title", "Reminder"),
                    obj.optString("body", ""),
                    obj.optLong("intervalMs", 0L),
                )
                armed++
            }
            Log.d(TAG, "✅ armAll: armed $armed of ${array.length()} alarms")
        } catch (e: Exception) {
            Log.e(TAG, "armAll parse error", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // rescheduleNext — called by ReminderAlarmReceiver after alarm fires
    // ─────────────────────────────────────────────────────────────────────────

    fun rescheduleNext(context: Context, firedAlarmId: Int) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(PREFS_KEY, null)
        if (json.isNullOrEmpty()) return

        // ✅ GUARD: Read tombstones — do not reschedule deleted reminders.
        // This prevents the race condition where a meal/medicine/event alarm
        // fires at the exact moment the user deletes it, causing rescheduleNext
        // to revive it for the next day/interval.
        val deletedAlarmIds = readIntSetFromJsonArray(prefs, DELETED_ALARM_IDS_KEY)
        val deletedGroupIds = readIntSetFromJsonArray(prefs, DELETED_GROUP_IDS_KEY)

        // ✅ Fast-path: check alarm-level tombstone before parsing the JSON array
        if (firedAlarmId in deletedAlarmIds) {
            Log.d(TAG, "⛔ rescheduleNext skipped — alarmId=$firedAlarmId is tombstoned")
            removeFromPersistedSchedule(context, setOf(firedAlarmId))
            return
        }

        try {
            val array = JSONArray(json)
            val now = System.currentTimeMillis()

            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                if (obj.optInt("alarmId", -1) != firedAlarmId) continue

                val groupId = obj.optString("groupId", "").toIntOrNull() ?: -1

                // ✅ GUARD: group-level tombstone covers meal/medicine/event where
                // multiple alarmIds share one groupId
                if (groupId != -1 && groupId in deletedGroupIds) {
                    Log.d(TAG, "⛔ rescheduleNext skipped — groupId=$groupId is tombstoned (alarmId=$firedAlarmId)")
                    // Sweep out all stale entries for this group in one pass
                    cancelByGroupId(context, groupId)
                    return
                }

                val intervalMs = obj.optLong("intervalMs", 0L)
                if (intervalMs <= 0) {
                    Log.d(TAG, "Alarm id=$firedAlarmId is not recurring — not rescheduling")
                    return
                }

                val nextEpochMs = now + intervalMs
                arm(
                    context,
                    firedAlarmId,
                    nextEpochMs,
                    obj.optString("groupId", ""),
                    obj.optString("category", ""),
                    obj.optString("title", "Reminder"),
                    obj.optString("body", ""),
                    intervalMs,
                )

                // Update the stored epochMs for this alarm
                obj.put("epochMs", nextEpochMs)
                prefs.edit().putString(PREFS_KEY, array.toString()).apply()

                Log.d(TAG, "🔁 Rescheduled alarm id=$firedAlarmId → ${Date(nextEpochMs)} (+${intervalMs}ms)")
                return
            }

            // ✅ FIX 3: Alarm not found — this entry is an orphan (the alarm fired
            // but the corresponding JSON record was already removed, e.g. by a
            // concurrent cancelByGroupId() call). Defensively remove it from both
            // the AlarmManager and the persisted schedule so it cannot re-surface.
            Log.w(TAG, "Alarm id=$firedAlarmId not found in schedule — cancelling orphan entry")
            cancelFromAlarmManager(context, firedAlarmId)
            removeFromPersistedSchedule(context, setOf(firedAlarmId))
        } catch (e: Exception) {
            Log.e(TAG, "rescheduleNext error for id=$firedAlarmId", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // copyAudioAssetsIfNeeded — copies Flutter audio assets to internal storage
    // ─────────────────────────────────────────────────────────────────────────

    fun copyAudioAssetsIfNeeded(context: Context) {
        val audioFiles = listOf(
            "flutter_assets/assets/sounds/water.mp3",
            "flutter_assets/assets/sounds/meal.mp3",
            "flutter_assets/assets/sounds/medicine.mp3",
            "flutter_assets/assets/sounds/event.mp3",
            "flutter_assets/assets/sounds/alarm-327234.mp3",
            "flutter_assets/assets/sounds/remind_before.mp3",
            "flutter_assets/assets/sounds/sleep.mp3"
        )

        val destDir = File(context.filesDir, "reminder_audio")
        if (!destDir.exists()) destDir.mkdirs()

        for (assetPath in audioFiles) {
            val fileName = assetPath.substringAfterLast("/")
            val destFile = File(destDir, fileName)
            if (destFile.exists() && destFile.length() > 0) continue
            try {
                context.assets.open(assetPath).use { input ->
                    destFile.outputStream().use { output -> input.copyTo(output) }
                }
                Log.d(TAG, "✅ Copied audio asset: $assetPath → ${destFile.absolutePath}")
            } catch (e: Exception) {
                Log.w(TAG, "Could not copy asset $assetPath: ${e.message}")
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // audioFileForCategory — maps category label → audio File
    // ─────────────────────────────────────────────────────────────────────────

    fun audioFileForCategory(context: Context, category: String): File? {
        val name = when (category.trim().lowercase()) {
            "water"    -> "water.mp3"
            "meal"     -> "meal.mp3"
            "medicine" -> "medicine.mp3"
            "event"    -> "event.mp3"
            "sleep"    -> "sleep.mp3"
            else       -> "alarm-327234.mp3"
        }
        val file = File(File(context.filesDir, "reminder_audio"), name)
        return if (file.exists()) file else null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // buildFireIntent — intent delivered to ReminderAlarmReceiver
    // ─────────────────────────────────────────────────────────────────────────

    fun buildFireIntent(
        context: Context,
        alarmId: Int,
        groupId: String,
        category: String,
        title: String,
        body: String,
        intervalMs: Long = 0L,
    ): Intent {
        return Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra("alarmId", alarmId)
            putExtra("groupId", groupId)
            putExtra("category", category)
            putExtra("title", title)
            putExtra("body", body)
            if (intervalMs > 0L) putExtra("intervalMs", intervalMs)
        }
    }
}