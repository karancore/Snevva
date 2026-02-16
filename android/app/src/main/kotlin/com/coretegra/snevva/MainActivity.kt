package com.coretegra.snevva

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.coretegra.snevva/sleep_service"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("Lifecycle", "onCreate called")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register existing StepCounterService (if any)
        // StepCounterService.registerWith(this)  // Uncomment if you have this

        // Set up MethodChannel for SleepNoticingService
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSleepService" -> {
                    val intent = Intent(this, SleepNoticingService::class.java)
                    startService(intent)
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
    }

    override fun onStart() {
        super.onStart()
        Log.d("Lifecycle", "onStart called")
    }

    override fun onResume() {
        super.onResume()
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
}