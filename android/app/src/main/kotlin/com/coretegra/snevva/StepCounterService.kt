package com.coretegra.snevva

import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.os.SystemClock
import android.text.format.DateFormat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.engine.FlutterEngine

class StepCounterService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private lateinit var prefs: SharedPreferences

    // Single unified channel — same ID used by the Dart foreground service
    private val CHANNEL_ID = "tracker_channel"
    private val NOTIFICATION_ID = 1

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
        } catch (e: Exception) {
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
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        syncTodayState()

        // Note: tracker_channel is created by the Dart side (app_initializer.dart) before this
        // service starts. We create it here as a safety fallback for boot scenarios where
        // Dart hasn't run yet.
        ensureNotificationChannel()

        val stepsToday = prefs.getInt(KEY_TODAY_STEPS, 0)
        val notification = buildNotification(stepsToday)

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Check if we have FOREGROUND_SERVICE_HEALTH permission before starting foreground service
                if (ContextCompat.checkSelfPermission(
                        this,
                        "android.permission.FOREGROUND_SERVICE_HEALTH"
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
                    )
                } else {
                    Log.w(
                        "StepService",
                        "⚠️ Missing FOREGROUND_SERVICE_HEALTH permission. Starting as regular service."
                    )
                    startForeground(NOTIFICATION_ID, notification)
                }
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e("StepService", "Error starting foreground service", e)
            // Fallback: try to start as regular foreground service without health type
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (e2: Exception) {
                Log.e(
                    "StepService",
                    "Failed to start foreground service even without health type",
                    e2
                )
            }
        }

        registerStepListener()
        scheduleSparseWakeup()

        Log.d("StepService", "🚀 StepCounterService started.")
    }

    private fun registerStepListener() {
        stepSensor?.also { sensor ->
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            Log.d("StepService", "✅ Step sensor registered successfully.")
        } ?: run {
            Log.e("StepService", "❌ No TYPE_STEP_COUNTER sensor found on this device.")
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER) return

        val currentSensorSteps = event.values.firstOrNull()?.toInt() ?: return
        syncTodayState()

        val currentDate = todayKey()
        val savedDate = prefs.getString(KEY_DATE, null)
        val savedBaseSteps = prefs.getInt(KEY_BASE_STEPS, -1)
        val savedTodaySteps = prefs.getInt(KEY_TODAY_STEPS, 0)
        val lastRawSteps = prefs.getInt(KEY_LAST_RAW_STEPS, -1)

        val isNewDay = savedDate != currentDate
        val needsRebase = lastRawSteps >= 0 && currentSensorSteps < lastRawSteps

        val baseSteps = when {
            isNewDay -> {
                Log.d("StepService", "📅 New day detected during sensor callback.")
                if (lastRawSteps >= 0) lastRawSteps else currentSensorSteps
            }
            needsRebase -> {
                Log.d("StepService", "🔄 Step counter rebased after reboot/reset.")
                (currentSensorSteps - savedTodaySteps).coerceAtLeast(0)
            }
            savedBaseSteps < 0 && savedTodaySteps > 0 -> {
                (currentSensorSteps - savedTodaySteps).coerceAtLeast(0)
            }
            savedBaseSteps < 0 -> {
                currentSensorSteps
            }
            else -> savedBaseSteps
        }

        val stepsToday = (currentSensorSteps - baseSteps).coerceAtLeast(0)

        Log.d(
            "StepService",
            "👣 raw=$currentSensorSteps base=$baseSteps lastRaw=$lastRawSteps today=$stepsToday date=$currentDate"
        )
        prefs.edit()
            .putInt(KEY_TODAY_STEPS, stepsToday)
            .putInt(KEY_BASE_STEPS, baseSteps)
            .putInt(KEY_LAST_RAW_STEPS, currentSensorSteps)
            .putString(KEY_DATE, currentDate)
            .apply()

        val notifManager = getSystemService(NotificationManager::class.java)
        notifManager.notify(NOTIFICATION_ID, buildNotification(stepsToday))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No action needed
    }

    override fun onDestroy() {
        BufferManager.flushSleepToDaily(applicationContext)
        super.onDestroy()
        sensorManager.unregisterListener(this)
        Log.d("StepService", "🛑 StepCounterService destroyed + buffers flushed.")
    }

    private fun buildNotification(stepsToday: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Snevva Active")
            .setContentText("👟 Steps: $stepsToday")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()
    }

    /** Creates tracker_channel as a safety fallback (e.g. boot before Dart has run). */
    private fun ensureNotificationChannel() {
        val existing = (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .getNotificationChannel(CHANNEL_ID)
        if (existing != null) return // Already created by Dart side — skip

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Health Tracking",
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = "Step & sleep tracking"
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        Log.d("StepService", "✅ tracker_channel created (fallback)")
    }

    companion object {
        private const val TAG = "StepService"
        private const val PREFS_NAME = "steps_prefs"
        private const val KEY_TODAY_STEPS = "today_steps"
        private const val KEY_BASE_STEPS = "base_steps"
        private const val KEY_LAST_RAW_STEPS = "last_raw_sensor_steps"
        private const val KEY_DATE = "last_date"
        // Set by MainActivity so receivers can reach the live Flutter engine.
        var flutterEngine: FlutterEngine? = null

        fun getTodaySteps(context: Context): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val today = todayKey()
            val savedDate = prefs.getString(KEY_DATE, null)

            if (savedDate != today) {
                val lastRaw = prefs.getInt(KEY_LAST_RAW_STEPS, -1)
                prefs.edit()
                    .putString(KEY_DATE, today)
                    .putInt(KEY_TODAY_STEPS, 0)
                    .putInt(KEY_BASE_STEPS, lastRaw)
                    .apply()
            }

            return prefs.getInt(KEY_TODAY_STEPS, 0)
        }

        private fun todayKey(): String {
            return DateFormat.format("yyyy-MM-dd", System.currentTimeMillis()).toString()
        }
    }

    private fun syncTodayState() {
        val today = todayKey()
        val savedDate = prefs.getString(KEY_DATE, null)
        if (savedDate == today) return

        val lastRaw = prefs.getInt(KEY_LAST_RAW_STEPS, -1)
        prefs.edit()
            .putString(KEY_DATE, today)
            .putInt(KEY_TODAY_STEPS, 0)
            .putInt(KEY_BASE_STEPS, lastRaw)
            .apply()
    }
}
