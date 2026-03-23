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

    private val CHANNEL_ID = "snevva_foreground"
    private val PREFS_NAME = "steps_prefs"
    private val KEY_TODAY_STEPS = "today_steps"
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
            .setContentTitle("Snevva Active")
            .setContentText("Step tracking running...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // HEALTH type is required on Android 14+ for motion/step sensor access
            startForeground(888, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(888, notification)
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

        // Also write to Flutter's SharedPreferences so Dart poller can read directly
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        flutterPrefs.edit()
            .putLong("flutter.today_steps", stepsToday.toLong())
            .apply()

        Log.d("StepService", "👣 Steps today: $stepsToday")

        // Update the foreground notification with the live step count
        val notifManager = getSystemService(NotificationManager::class.java)
        val updatedNotification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Snevva Active")
            .setContentText("$stepsToday steps today")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()
        notifManager.notify(888, updatedNotification)

        // Send to Flutter UI engine only if it is still alive
        val engine = flutterEngine
        if (engine != null) {
            if (engine.dartExecutor.isExecutingDart) {
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.coretegra.snevva/step_detector")
                channel.invokeMethod("onStepDetected", stepsToday)
            } else {
                // Engine is detached — clear reference to avoid repeated FlutterJNI errors
                flutterEngine = null
                Log.w("StepService", "Flutter engine detached, cleared reference")
            }
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
        // Set by MainActivity so steps can be sent to the live UI engine
        var flutterEngine: FlutterEngine? = null
    }
}
