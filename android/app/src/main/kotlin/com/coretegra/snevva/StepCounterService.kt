package com.coretegra.snevva

import android.app.*
import android.content.*
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class StepCounterService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private lateinit var prefs: SharedPreferences
    private var initialSteps = -1f

    private val CHANNEL_ID = "steps_channel"
    private val PREFS_NAME = "steps_prefs"
    private val KEY_TODAY_STEPS = "todaySteps"
    private val KEY_DATE = "lastDate"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Snevva Step Tracker")
            .setContentText("Counting your steps in background")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()

        startForeground(1, notification)
        registerStepListener()

        Log.d("StepService", "🚀 StepCounterService started.")
    }

    /** Registers the step counter sensor listener, if available. */
    private fun registerStepListener() {
        stepSensor?.also { sensor ->
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            Log.d("StepService", "✅ Step sensor registered successfully.")
        } ?: run {
            Log.e("StepService", "❌ No step counter sensor found on this device.")
        }
    }

    /** Handles sensor updates from the step counter. */
    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER) return

        val totalSteps = event.values[0]
        if (initialSteps < 0) initialSteps = totalSteps

        val currentDate = android.text.format.DateFormat.format("yyyyMMdd", System.currentTimeMillis()).toString()
        val savedDate = prefs.getString(KEY_DATE, currentDate)

        // Reset steps daily
        if (currentDate != savedDate) {
            initialSteps = totalSteps
            prefs.edit().putString(KEY_DATE, currentDate).putInt(KEY_TODAY_STEPS, 0).apply()
            Log.d("StepService", "📅 New day detected. Steps reset.")
        }

        val stepsToday = (totalSteps - initialSteps).toInt()
        prefs.edit()
            .putInt(KEY_TODAY_STEPS, stepsToday)
            .putString(KEY_DATE, currentDate)
            .apply()

        Log.d("StepService", "👣 Steps today: $stepsToday")
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No action needed
    }

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
        Log.d("StepService", "🛑 StepCounterService destroyed.")
    }

    /** Creates the foreground notification channel required for Android 8+. */
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Step Counter Service",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val TAG = "StepService"
        private const val CHANNEL_NAME = "step_counter_service"
        private var flutterEngine: FlutterEngine? = null

        /** Allows Flutter to start the service via MethodChannel */
        fun registerWith(context: Context) {
            val engine = FlutterEngine(context.applicationContext)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            FlutterEngineCache.getInstance().put("step_engine", engine)
            flutterEngine = engine

            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "step_counter_service")
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(context, StepCounterService::class.java)
                        context.startForegroundService(intent)
                        result.success(true)
                    }
                    "stopService" -> {
                        val intent = Intent(context, StepCounterService::class.java)
                        context.stopService(intent)
                        result.success(true)
                    }
                    "getSteps" -> {
                        val prefs = context.getSharedPreferences("steps_prefs", Context.MODE_PRIVATE)
                        val steps = prefs.getInt("todaySteps", 0)
                        result.success(steps)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
