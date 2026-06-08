package com.coretegra.snevvaa

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Display
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val sleepServiceChannelName = "com.coretegra.snevvaa/sleep_service"
    private val stepServiceChannelName = "com.coretegra.snevvaa/step_service"
    private val displayConfigChannelName = "com.coretegra.snevvaa/display_config"
    private val oemChannelName = "com.coretegra.snevvaa/oem_settings"
    private val timezoneChannelName = "com.coretegra.snevvaa/timezone"
    private val reminderAlarmsChannelName = "com.coretegra.snevvaa/reminder_alarms"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Reset headless flag for pure UI run
        getSharedPreferences("steps_prefs", android.content.Context.MODE_PRIVATE)
            .edit().putBoolean("is_headless", false).apply()

        // Only start (or keep alive) the step counter service when a user is actually
        // signed in.  Starting it unconditionally here was re-showing the sticky
        // notification every time the app was opened, even on the sign-in screen.
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        if (flutterPrefs.contains("flutter.auth_token")) {
            startStepCounterService()
        } else {
            Log.d("MainActivity", "⚠️ Skipping StepCounterService start — user not logged in")
        }

        AlarmHelper.cancelSleepAlarms(this)
        requestHighestRefreshRate()

        // Copy flutter audio assets to internal storage so native MediaPlayer can read them.
        // Done here (on main thread, before first frame) so they're ready when the first
        // alarm fires — even if the app has never been opened since install.
        Thread {
            try {
                ReminderArmingHelper.copyAudioAssetsIfNeeded(this)
            } catch (e: Exception) {
                Log.e("MainActivity", "copyAudioAssets failed", e)
            }
        }.start()

        Log.d("Lifecycle", "onCreate called")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // No wake-screen flags: our reminder layer is BroadcastReceiver-based and
        // never needs MainActivity to show over the lock screen.
    }

    private fun startStepCounterService(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.ACTIVITY_RECOGNITION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.d(
                "MainActivity",
                "Skipping StepCounterService start until ACTIVITY_RECOGNITION is granted"
            )
            return false
        }

        val stepIntent = Intent(this, StepCounterService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(stepIntent)
        } else {
            startService(stepIntent)
        }
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Give StepCounterService a reference to the live UI engine so sensor
        // events can be delivered via MethodChannel to the running Flutter app.
        StepCounterService.flutterEngine = flutterEngine

        // Re-arm all native reminder alarms every time the Flutter engine attaches.
        // This is idempotent and covers the case where the user opens the app after
        // a background kill, ensuring AlarmManager entries are always up-to-date.
        //
        // ✅ Cooldown: if armFromSharedPrefs ran within the last 60 seconds (e.g.
        // because ReminderAlarmReceiver.rescheduleNext already re-armed on alarm
        // fire), skip the full sweep to avoid redundant binder IPC calls during
        // the Flutter engine attach window.
        Thread {
            try {
                val prefs = applicationContext.getSharedPreferences(
                    "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
                )
                val lastArmMs = prefs.getLong("flutter.native_alarm_last_arm_epoch_ms", 0L)
                val elapsedMs = System.currentTimeMillis() - lastArmMs
                if (elapsedMs > 60_000L) {
                    ReminderArmingHelper.armFromSharedPrefs(applicationContext)
                    prefs.edit()
                        .putLong("flutter.native_alarm_last_arm_epoch_ms", System.currentTimeMillis())
                        .apply()
                    Log.d("MainActivity", "✅ Native reminder alarms re-armed on engine attach")
                } else {
                    // ✅ FIX 2: Even when we skip the full sweep, refresh the arm epoch
                    // to now. Without this, a cold-start triggered by ReminderStopReceiver
                    // (which fires only ~15s after the last arm) would see elapsedMs still
                    // below 60s and skip indefinitely, leaving the alarm schedule stale.
                    // Refreshing the epoch here means the NEXT open always gets a clean
                    // 60-second window rather than compounding the skip chain.
                    prefs.edit()
                        .putLong("flutter.native_alarm_last_arm_epoch_ms", System.currentTimeMillis())
                        .apply()
                    Log.d(
                        "MainActivity",
                        "⏭ Skipping armFromSharedPrefs — done ${elapsedMs}ms ago (cooldown 60s). " +
                        "Epoch refreshed. App will use cached alarm schedule."
                    )
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "armFromSharedPrefs failed: ${e.message}")
            }
        }.start()

        // ── MethodChannels ────────────────────────────────────────────────────

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, oemChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> result.success(Build.MANUFACTURER)
                    "openAutostartSettings" -> {
                        openAutostartSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, timezoneChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTimeZoneId" -> result.success(java.util.TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            stepServiceChannelName
        )
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startStepService" -> result.success(startStepCounterService())

                    "seedTodaySteps" -> {
                        val steps = (call.arguments as? Int) ?: 0
                        val nativePrefs = getSharedPreferences("steps_prefs", android.content.Context.MODE_PRIVATE)
                        val flutterPrefs = applicationContext.getSharedPreferences(
                            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
                        )
                        val currentNative = nativePrefs.getInt("today_steps", 0)
                        val currentFlutter = flutterPrefs.getLong("flutter.today_steps", 0L).toInt()
                        if (steps > currentNative) {
                            nativePrefs.edit().putInt("today_steps", steps).apply()
                            Log.d("MainActivity", "🌱 Seeded native today_steps → $steps")
                        }
                        if (steps > currentFlutter) {
                            flutterPrefs.edit().putLong("flutter.today_steps", steps.toLong()).apply()
                            Log.d("MainActivity", "🌱 Seeded flutter.today_steps → $steps")
                        }
                        val notifIntent = Intent(applicationContext, StepCounterService::class.java)
                        notifIntent.action = "REFRESH_NOTIFICATION"
                        try { applicationContext.startService(notifIntent) } catch (_: Exception) {}
                        result.success(true)
                    }

                    "stopStepService" -> {
                        try {
                            val stopIntent = Intent(applicationContext, StepCounterService::class.java)
                            applicationContext.stopService(stopIntent)
                            val nm = getSystemService(android.app.NotificationManager::class.java)
                            nm?.cancel(1)
                            Log.d("MainActivity", "🛑 StepCounterService stopped and notification cleared")
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "stopStepService failed: ${e.message}")
                            result.success(false)
                        }
                    }

                    "refreshNotification" -> {
                        // Called by Dart after seeding sleep data so the sticky
                        // notification updates immediately without waiting for the
                        // 1-minute ticker in StepCounterService.
                        try {
                            val refreshIntent =
                                Intent(applicationContext, StepCounterService::class.java)
                            refreshIntent.action = "REFRESH_NOTIFICATION"
                            applicationContext.startService(refreshIntent)
                            Log.d(
                                "MainActivity",
                                "🔔 REFRESH_NOTIFICATION sent to StepCounterService"
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            Log.w(
                                "MainActivity",
                                "refreshNotification: service may not be running: ${e.message}"
                            )
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sleepServiceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSleepService" -> {
                        AlarmHelper.cancelSleepAlarms(this@MainActivity)
                        SleepCalcWorker.scheduleNext(this@MainActivity)
                        Log.d("MainActivity", "Native sleep service disabled; scheduled WorkManager instead")
                        result.success("WorkManager scheduled")
                    }

                    "stopSleepService" -> {
                        androidx.work.WorkManager.getInstance(this@MainActivity).cancelUniqueWork("SLEEP_CALC_WORK")
                        Log.d("MainActivity", "Sleep tracking work cancelled")
                        result.success("SleepCalcWorker stopped")
                    }

                    "updateSleepAlarms" -> {
                        AlarmHelper.scheduleSleepAlarms(this@MainActivity)
                        SleepCalcWorker.scheduleNext(this@MainActivity)
                        Log.d("MainActivity", "Sleep alarms updated and WorkManager scheduled via Flutter")
                        result.success("Sleep alarms scheduled")
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, displayConfigChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDisplayRefreshRate" -> result.success(getCurrentRefreshRate())
                    "getHighestSupportedRefreshRate" ->
                        result.success(getHighestSupportedRefreshRate())
                    "requestHighestRefreshRate" -> result.success(requestHighestRefreshRate())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.coretegra.snevvaa/sync_manager")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "flushAndSync" -> {
                        try {
                            BufferManager.flushStepsToDaily(applicationContext)
                            BufferManager.flushSleepToDaily(applicationContext)
                            result.success("flushed")
                        } catch (e: Exception) {
                            result.error("FLUSH_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Native reminder alarm channel ─────────────────────────────────────
        // Survives Flutter engine kill + device reboot via AlarmManager + SharedPrefs.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, reminderAlarmsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Arm a single alarm ────────────────────────────────────
                    "armAlarm" -> {
                        val alarmId    = call.argument<Int>("alarmId") ?: -1
                        val epochMs    = (call.argument<Long>("epochMs")
                            ?: call.argument<Int>("epochMs")?.toLong()) ?: 0L
                        val groupId    = call.argument<String>("groupId") ?: ""
                        val category   = call.argument<String>("category") ?: ""
                        val title      = call.argument<String>("title") ?: "Reminder"
                        val body       = call.argument<String>("body") ?: ""
                        val intervalMs = (call.argument<Long>("intervalMs")
                            ?: call.argument<Int>("intervalMs")?.toLong()) ?: 0L
                        ReminderArmingHelper.arm(
                            this@MainActivity, alarmId, epochMs, groupId,
                            category, title, body, intervalMs
                        )
                        result.success(true)
                    }

                    // ── Cancel a single alarm ─────────────────────────────────
                    // Also purges the entry from the persisted JSON schedule so
                    // armFromSharedPrefs / BootReceiver cannot re-arm it.
                    "cancelAlarm" -> {
                        val alarmId = call.argument<Int>("alarmId") ?: -1
                        if (alarmId != -1) ReminderArmingHelper.cancel(this@MainActivity, alarmId)
                        result.success(true)
                    }

                    // ── Cancel multiple alarms in one call ────────────────────
                    // Called by NativeAlarmBridge.cancelAlarms() on the Flutter
                    // side. Uses a single SharedPrefs write for efficiency.
                    "cancelAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val rawIds = call.argument<List<*>>("alarmIds")
                        val ids = rawIds?.filterIsInstance<Int>() ?: emptyList()
                        if (ids.isNotEmpty()) {
                            ReminderArmingHelper.cancelAll(this@MainActivity, ids)
                            Log.d("MainActivity", "🗑️ cancelAlarms: removed ${ids.size} alarm(s) → $ids")
                        }
                        result.success(true)
                    }

                    // ── Cancel ALL alarms for a reminder group ────────────────
                    // ✅ NEW — Called by NativeAlarmBridge.cancelByGroupId() on
                    // the Flutter side when the user deletes an event, meal, or
                    // medicine reminder. Sweeps the JSON schedule by groupId so
                    // any alarmId created by rescheduleNext() during a race
                    // condition is also purged. This is the correct delete path
                    // for all multi-alarm reminder types.
                    "cancelByGroupId" -> {
                        val groupId = call.argument<Int>("groupId") ?: -1
                        if (groupId != -1) {
                            ReminderArmingHelper.cancelByGroupId(this@MainActivity, groupId)
                            Log.d("MainActivity", "🗑️ cancelByGroupId=$groupId")
                        }
                        result.success(true)
                    }

                    // ── Cancel ALL persisted alarms (e.g. on logout) ──────────
                    "cancelAllPersisted" -> {
                        ReminderArmingHelper.cancelAllPersisted(this@MainActivity)
                        result.success(true)
                    }

                    // ── Persist the full alarm schedule ───────────────────────
                    "saveSchedule" -> {
                        val json = call.argument<String>("json") ?: "[]"
                        val prefs = getSharedPreferences(
                            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
                        )
                        prefs.edit().putString("flutter.native_reminder_alarms", json).apply()
                        Log.d("MainActivity", "💾 Saved native alarm schedule (${json.length} chars)")
                        result.success(true)
                    }

                    // ── Arm all alarms from JSON or SharedPrefs ───────────────
                    "armAll" -> {
                        val json = call.argument<String>("json")
                        if (json.isNullOrBlank() || json == "[]") {
                            ReminderArmingHelper.armFromSharedPrefs(this@MainActivity)
                            Log.d("MainActivity", "✅ armAll fell back to SharedPreferences schedule")
                        } else {
                            ReminderArmingHelper.armAll(this@MainActivity, json)
                        }
                        result.success(true)
                    }

                    // ── Copy audio assets to internal storage ─────────────────
                    "copyAudioAssets" -> {
                        try {
                            ReminderArmingHelper.copyAudioAssetsIfNeeded(this@MainActivity)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("COPY_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onStart() {
        super.onStart()
        Log.d("Lifecycle", "onStart called")
    }

    override fun onResume() {
        super.onResume()
        requestHighestRefreshRate()
        Thread {
            try {
                BufferManager.flushStepsToDaily(applicationContext)
            } catch (_: Exception) {}
        }.start()
        Log.d("Lifecycle", "onResume called")
    }

    override fun onPause() {
        super.onPause()
        Log.d("Lifecycle", "onPause called")
    }

    override fun onStop() {
        super.onStop()
        Log.d("Lifecycle", "onStop called")
    }

    override fun onRestart() {
        super.onRestart()
        Log.d("Lifecycle", "onRestart called")
    }

    override fun onDestroy() {
        super.onDestroy()
        StepCounterService.flutterEngine = null
        Log.d("Lifecycle", "onDestroy called")
    }

    private fun getCurrentRefreshRate(): Double {
        val currentDisplay = getDisplaySafe()
        val rate = currentDisplay?.refreshRate ?: 60f
        return rate.toDouble()
    }

    private fun getHighestSupportedRefreshRate(): Double {
        val currentDisplay = getDisplaySafe() ?: return getCurrentRefreshRate()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return getCurrentRefreshRate()
        val highestMode = currentDisplay.supportedModes.maxByOrNull { it.refreshRate }
        return highestMode?.refreshRate?.toDouble() ?: getCurrentRefreshRate()
    }

    private fun requestHighestRefreshRate(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val currentDisplay = getDisplaySafe() ?: return false
        val highestMode = currentDisplay.supportedModes.maxByOrNull { it.refreshRate } ?: return false
        val params = window.attributes
        params.preferredDisplayModeId = highestMode.modeId
        params.preferredRefreshRate = highestMode.refreshRate
        window.attributes = params
        return true
    }

    @Suppress("DEPRECATION")
    private fun getDisplaySafe(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
        }
    }

    private fun openAutostartSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase(java.util.Locale.getDefault())
        val intent = Intent()
        try {
            when {
                manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                    intent.component = android.content.ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
                manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> {
                    intent.component = android.content.ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                }
                manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                    intent.component = android.content.ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                }
                manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                    intent.component = android.content.ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity"
                    )
                }
                manufacturer.contains("samsung") -> {
                    intent.component = android.content.ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.ui.battery.BatteryActivity"
                    )
                }
                else -> {
                    intent.action = android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                }
            }
            startActivity(intent)
        } catch (e: Exception) {
            intent.action = android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
            try { startActivity(intent) } catch (ex: Exception) { /* Ignore */ }
        }
    }
}