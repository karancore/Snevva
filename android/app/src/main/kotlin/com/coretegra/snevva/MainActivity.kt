package com.coretegra.snevva

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Display
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val sleepServiceChannelName = "com.coretegra.snevva/sleep_service"
    private val stepCounterChannelName = "com.coretegra.snevva/step_counter_channel"
    private val stepCounterUpdatesChannelName = "com.coretegra.snevva/step_counter_updates"
    private val displayConfigChannelName = "com.coretegra.snevva/display_config"
    private val oemChannelName = "com.coretegra.snevva/oem_settings"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Reset headless flag for pure UI run
        getSharedPreferences("steps_prefs", android.content.Context.MODE_PRIVATE)
            .edit().putBoolean("is_headless", false).apply()

        startStepCounterService()
        AlarmHelper.cancelSleepAlarms(this)
        requestHighestRefreshRate()
        Log.d("Lifecycle", "onCreate called")
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

        // Give background receivers a reference to the live Flutter engine for
        // non-step wakeup callbacks such as sparse alarm heartbeats.
        StepCounterService.flutterEngine = flutterEngine

        // MethodChannels setup

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            stepCounterChannelName
        )
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startStepService" -> result.success(startStepCounterService())
                    "getTodaySteps" -> result.success(StepCounterService.getTodaySteps(this))
                    else -> result.notImplemented()
                }
            }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            stepCounterUpdatesChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                StepCounterService.stepUpdateSink = events
                events?.success(StepCounterService.getTodaySteps(this@MainActivity))
            }

            override fun onCancel(arguments: Any?) {
                StepCounterService.stepUpdateSink = null
            }
        })

        // Existing channel for SleepNoticingService.
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

                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Channel used by Flutter to detect and request higher refresh rates.
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

        // Sync manager channel: Kotlin → Dart trigger for file-based sync queue
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.coretegra.snevva/sync_manager")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Native code can call "flushAndSync" to force a buffer flush +
                    // schedule an immediate Dart sync run
                    "flushAndSync" -> {
                        try {
                            BufferManager.flushSleepToDaily(applicationContext)
                            result.success("flushed")
                        } catch (e: Exception) {
                            result.error("FLUSH_ERROR", e.message, null)
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
        // Clear the engine reference so StepCounterService stops trying to
        // send MethodChannel messages to the now-detached Flutter engine.
        StepCounterService.flutterEngine = null
        StepCounterService.stepUpdateSink = null
        Log.d("Lifecycle", "onDestroy called")
    }

    private fun getCurrentRefreshRate(): Double {
        val currentDisplay = getDisplaySafe()
        val rate = currentDisplay?.refreshRate ?: 60f
        return rate.toDouble()
    }

    private fun getHighestSupportedRefreshRate(): Double {
        val currentDisplay = getDisplaySafe() ?: return getCurrentRefreshRate()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return getCurrentRefreshRate()
        }

        val highestMode = currentDisplay.supportedModes.maxByOrNull { it.refreshRate }
        return highestMode?.refreshRate?.toDouble() ?: getCurrentRefreshRate()
    }

    private fun requestHighestRefreshRate(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }

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
                    intent.component = android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                }
                manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> {
                    intent.component = android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                }
                manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                    intent.component = android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                }
                manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                    intent.component = android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                }
                manufacturer.contains("samsung") -> {
                    intent.component = android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
                }
                else -> {
                    intent.action = android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                }
            }
            startActivity(intent)
        } catch (e: Exception) {
            intent.action = android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
            try {
                startActivity(intent)
            } catch (ex: Exception) {
                // Ignore
            }
        }
    }
}
