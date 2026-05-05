package com.coretegra.snevvaa

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
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

    /** Intent action fired to ReminderAlarmReceiver by AlarmManager. */
    const val ACTION_FIRE = "com.coretegra.snevvaa.REMINDER_FIRE"

    // ─────────────────────────────────────────────────────────────────────────
    // armFromSharedPrefs — read saved schedule + arm all future alarms
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Reads all alarms from SharedPrefs and arms every one whose trigger
     * time is still in the future. Safe to call multiple times (idempotent).
     */
    fun armFromSharedPrefs(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val json = prefs.getString(PREFS_KEY, null)
        if (json.isNullOrBlank()) {
            Log.d(TAG, "armFromSharedPrefs: no saved alarms")
            return
        }

        try {
            val arr = JSONArray(json)
            val now = System.currentTimeMillis()
            var armed = 0
            var skipped = 0

            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val epochMs = obj.getLong("epochMs")

                if (epochMs <= now) {
                    skipped++
                    continue
                }

                arm(
                    context  = context,
                    alarmId  = obj.getInt("alarmId"),
                    epochMs  = epochMs,
                    groupId  = obj.optString("groupId", ""),
                    category = obj.optString("category", ""),
                    title    = obj.optString("title", "Reminder"),
                    body     = obj.optString("body", ""),
                    intervalMs = obj.optLong("intervalMs", 0L),
                )
                armed++
            }

            Log.d(TAG, "armFromSharedPrefs: armed=$armed skipped=$skipped")
        } catch (e: Exception) {
            Log.e(TAG, "armFromSharedPrefs failed: ${e.message}")
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
                        // No exact-alarm permission — use inexact but wakeup
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
    // cancel — cancel a single alarm
    // ─────────────────────────────────────────────────────────────────────────

    fun cancel(context: Context, alarmId: Int) {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
        }
        val pending = PendingIntent.getBroadcast(
            context, alarmId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val mgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        mgr.cancel(pending)
        Log.d(TAG, "🗑️ cancelled native alarmId=$alarmId")
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

        try {
            val array = JSONArray(json)
            val now = System.currentTimeMillis()

            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                if (obj.optInt("alarmId", -1) != firedAlarmId) continue

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

                Log.d(TAG, "🔁 Rescheduled alarm id=$firedAlarmId → $nextEpochMs (+${intervalMs}ms)")
                return
            }
            Log.d(TAG, "Alarm id=$firedAlarmId not found in schedule for rescheduling")
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
