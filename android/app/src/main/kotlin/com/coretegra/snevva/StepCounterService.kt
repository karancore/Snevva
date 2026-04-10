package com.coretegra.snevva

import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class StepCounterService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private lateinit var prefs: SharedPreferences

    // Single unified channel — same ID used by the Dart foreground service
    private val CHANNEL_ID = "tracker_channel"
    private val NOTIFICATION_ID = 1

    private val PREFS_NAME = "steps_prefs"
    private val KEY_TODAY_STEPS = "today_steps"
    private val KEY_DATE = "lastDate"

    // 1-minute ticker — keeps sleep duration in the notification fresh
    // without requiring any Dart/Flutter involvement.
    private val notifHandler = Handler(Looper.getMainLooper())
    private val notifRunnable = object : Runnable {
        override fun run() {
            refreshNotification()
            notifHandler.postDelayed(this, 60_000L)
        }
    }

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
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

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
        notifHandler.postDelayed(notifRunnable, 60_000L) // start 1-min ticker

        Log.d("StepService", "🚀 StepCounterService started.")
    }

    private fun registerStepListener() {
        stepSensor?.also { sensor ->
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            Log.d("StepService", "✅ Step sensor registered successfully.")
        } ?: run {
            Log.e("StepService", "❌ No step counter sensor found on this device.")
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_DETECTOR) return

        val currentDate = android.text.format.DateFormat.format("yyyyMMdd", System.currentTimeMillis()).toString()
        val savedDate = prefs.getString(KEY_DATE, currentDate)

        // ── Day boundary crossed ───────────────────────────────────────────────
        // Kotlin is the sole owner of the day-change pipeline.  Do NOT rely on
        // the Dart UI being open for this — it may never open if the user just
        // keeps walking.
        if (currentDate != savedDate) {
            Log.d("StepService", "📅 New day detected. Flushing yesterday and queuing for sync.")

            // Compute yesterday's dateKey from savedDate (yyyyMMdd → YYYY-MM-DD)
            val yesterdayKey = savedDate?.let {
                try {
                    val y = it.substring(0, 4)
                    val m = it.substring(4, 6)
                    val d = it.substring(6, 8)
                    "$y-$m-$d"
                } catch (_: Exception) { null }
            }

            // Run buffer flush + sync enqueue off the sensor callback thread
            Thread {
                try {
                    // 1. Flush yesterday's step buffer → daily JSON
                    BufferManager.flushStepsToDaily(applicationContext)

                    // 2. Queue yesterday for API sync
                    if (yesterdayKey != null) {
                        BufferManager.addToSyncQueue(applicationContext, yesterdayKey)
                        Log.d("StepService", "📤 Queued $yesterdayKey for sync")
                    }

                    // 3. Enqueue ApiSyncWorker (runs only when network is available)
                    val syncRequest = OneTimeWorkRequestBuilder<ApiSyncWorker>()
                        .setConstraints(
                            Constraints.Builder()
                                .setRequiredNetworkType(NetworkType.CONNECTED)
                                .build()
                        )
                        .build()
                    WorkManager.getInstance(applicationContext).enqueue(syncRequest)
                    Log.d("StepService", "✅ ApiSyncWorker enqueued for $yesterdayKey")
                } catch (e: Exception) {
                    Log.e("StepService", "Day-change sync error: ${e.message}")
                }
            }.start()

            // Reset local step counter for the new day
            prefs.edit()
                .putString(KEY_DATE, currentDate)
                .putInt(KEY_TODAY_STEPS, 0)
                .apply()
        }

        var stepsToday = prefs.getInt(KEY_TODAY_STEPS, 0)
        stepsToday += 1
        prefs.edit()
            .putInt(KEY_TODAY_STEPS, stepsToday)
            .putString(KEY_DATE, currentDate)
            .apply()

        // Write to Flutter's SharedPreferences so the Dart poller can read directly
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        flutterPrefs.edit()
            .putLong("flutter.today_steps", stepsToday.toLong())
            .apply()

        Log.d("StepService", "👣 Steps today: $stepsToday")

        // Append to file buffer (primary durable store)
        BufferManager.appendStepEvent(applicationContext, stepsToday)

        // Always refresh the unified notification (shows BOTH steps + sleep).
        // No switching logic needed — collision is impossible.
        refreshNotification()

        // Relay to Flutter UI engine only if alive — fire-and-forget, never block
        val engine = flutterEngine
        if (engine != null && engine.dartExecutor.isExecutingDart) {
            try {
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.coretegra.snevva/step_detector")
                channel.invokeMethod("onStepDetected", stepsToday)
            } catch (e: Exception) {
                Log.w("StepService", "MethodChannel send failed (engine may be detaching): ${e.message}")
            }
        } else if (engine != null && !engine.dartExecutor.isExecutingDart) {
            flutterEngine = null
            Log.w("StepService", "Flutter engine detached, cleared reference")
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No action needed
    }

    override fun onDestroy() {
        // Stop the 1-min ticker first
        notifHandler.removeCallbacks(notifRunnable)
        // Flush buffers before being killed so no step data is lost
        BufferManager.flushStepsToDaily(applicationContext)
        BufferManager.flushSleepToDaily(applicationContext)
        super.onDestroy()
        sensorManager.unregisterListener(this)
        Log.d("StepService", "🛑 StepCounterService destroyed + buffers flushed.")
    }

    /**
     * Reads current steps + sleep from SharedPreferences and posts the unified
     * notification. Always called by Kotlin only — Dart never touches the
     * notification directly.
     */
    private fun refreshNotification() {
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        val steps = flutterPrefs.getLong("flutter.today_steps", 0L).toInt()
        val sleepMinutes = flutterPrefs.getLong("flutter.sleep_elapsed_minutes", 0L).toInt()
        val notifManager = getSystemService(NotificationManager::class.java)
        notifManager.notify(NOTIFICATION_ID, buildNotification(steps, sleepMinutes))
    }

    private fun buildNotification(stepsToday: Int, sleepMinutes: Int = 0): Notification {
        val sleepText = if (sleepMinutes > 0) {
            val h = sleepMinutes / 60
            val m = sleepMinutes % 60
            if (h > 0) "😴 Sleep: ${h}h ${m}m" else "😴 Sleep: ${m}m"
        } else {
            "😴 Sleep: --"
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Snevva Active")
            .setContentText("👟 Steps: $stepsToday   $sleepText")
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
        // Set by MainActivity so steps can be sent to the live UI engine
        var flutterEngine: FlutterEngine? = null
    }
}

