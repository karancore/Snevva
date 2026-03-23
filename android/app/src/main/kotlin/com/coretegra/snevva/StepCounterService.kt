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
import android.content.pm.ServiceInfo
import android.os.SystemClock
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

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

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.e("StepService", "Swipe-to-kill detected. Trying to resurrect via AlarmManager & WorkManager.")
        
        // Resurrection mechanism via AlarmManager
        val restartIntent = Intent(applicationContext, StepCounterService::class.java)
        val pendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 5000,
                pendingIntent
            )
        } catch (e: Exception) {
            Log.e("StepService", "Alarm setup failed", e)
        }
        
        // Fallback resurrection via WorkManager
        val workRequest = OneTimeWorkRequestBuilder<ResurrectionWorker>().build()
        WorkManager.getInstance(applicationContext).enqueue(workRequest)
    }

    private fun scheduleSparseWakeup() {
        val alarmIntent = Intent(this, SparseWakeupReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 15 * 60 * 1000,
                pendingIntent
            )
        } catch(e: Exception) {
             Log.e("StepService", "Alarm setup failed", e)
        }
    }


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Snevva Step Tracker")
            .setContentText("Counting your steps in background")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(1, notification)
        }
        registerStepListener()
        scheduleSparseWakeup()

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
        if (event?.sensor?.type != Sensor.TYPE_STEP_DETECTOR) return

        val currentDate = android.text.format.DateFormat.format("yyyyMMdd", System.currentTimeMillis()).toString()
        val savedDate = prefs.getString(KEY_DATE, currentDate)

        // Reset steps daily
        if (currentDate != savedDate) {
            prefs.edit().putString(KEY_DATE, currentDate).putInt(KEY_TODAY_STEPS, 0).apply()
            Log.d("StepService", "📅 New day detected. Steps reset.")
        }

        var stepsToday = prefs.getInt(KEY_TODAY_STEPS, 0)
        stepsToday += 1 // 1 physically detected step
        
        prefs.edit()
            .putInt(KEY_TODAY_STEPS, stepsToday)
            .putString(KEY_DATE, currentDate)
            .apply()

        Log.d("StepService", "👣 Steps today: $stepsToday")
        
        flutterEngine?.let { engine ->
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.coretegra.snevva/step_detector")
            channel.invokeMethod("onStepDetected", stepsToday)
        }
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
        var flutterEngine: FlutterEngine? = null

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
