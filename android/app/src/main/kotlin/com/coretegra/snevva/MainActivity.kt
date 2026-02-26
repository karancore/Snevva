package com.coretegra.snevva

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val sleepServiceChannelName = "com.coretegra.snevva/sleep_service"
    private val displayConfigChannelName = "com.coretegra.snevva/display_config"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
        Log.d("Lifecycle", "onCreate called")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register existing StepCounterService (if any)
        // StepCounterService.registerWith(this)  // Uncomment if you have this

        // Existing channel for SleepNoticingService.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sleepServiceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSleepService" -> {
                        val intent = Intent(this, SleepNoticingService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        }
                        Log.d("MainActivity", "SleepNoticingService started")
                        result.success("SleepNoticingService started")
                    }

                    "stopSleepService" -> {
                        val intent = Intent(this, SleepNoticingService::class.java)
                        stopService(intent)
                        Log.d("MainActivity", "SleepNoticingService stopped")
                        result.success("SleepNoticingService stopped")
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
}
