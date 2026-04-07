package com.coretegra.snevva

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate

class StepCounterService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var screenStateReceiver: ScreenStateReceiver? = null
    private var currentDayKey: String = SleepWindowResolver.formatDayKey(LocalDate.now())
    private var stepsToday: Int = 0

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
        if (!StepServiceStarter.hasRequiredPermissions(this)) {
            Log.w("StepService", "Missing permissions onStartCommand; stopping service.")
            stopSelf()
            return START_NOT_STICKY
        }

        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        if (!StepServiceStarter.hasRequiredPermissions(this)) {
            Log.w("StepService", "Missing permissions onCreate; aborting service startup.")
            stopSelf()
            return
        }

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        MetaStore.ensureCurrentDay(this)
        MetaStore.syncSleepSchedule(this)
        stepsToday = DailyStore.todayStepTotal(this)
        currentDayKey = SleepWindowResolver.formatDayKey(LocalDate.now())

        // Note: tracker_channel is created by the Dart side (app_initializer.dart) before this
        // service starts. We create it here as a safety fallback for boot scenarios where
        // Dart hasn't run yet.
        ensureNotificationChannel()

        val notification = buildNotification(stepsToday)

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (securityException: SecurityException) {
            Log.e("StepService", "Failed to enter foreground mode", securityException)
            stopSelf()
            return
        } catch (exception: Exception) {
            Log.e("StepService", "Unexpected failure entering foreground mode", exception)
            stopSelf()
            return
        }

        try {
            registerStepListener()
            registerScreenStateReceiver()
            scheduleSparseWakeup()
            AlarmHelper.scheduleNextDayChange(this)
        } catch (exception: Exception) {
            Log.e("StepService", "Failed during StepCounterService startup", exception)
            stopSelf()
            return
        }

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

        val newDayKey = SleepWindowResolver.formatDayKey(LocalDate.now())
        if (newDayKey != currentDayKey) {
            BufferManager.flushAll(applicationContext)
            SyncQueueStore.enqueue(applicationContext, currentDayKey)
            currentDayKey = newDayKey
            MetaStore.ensureCurrentDay(applicationContext)
            stepsToday = DailyStore.todayStepTotal(applicationContext)
            Log.d("StepService", "📅 New day detected. Steps rolled to $currentDayKey")
        }

        stepsToday += 1
        BufferManager.appendStepEvent(applicationContext, System.currentTimeMillis(), 1)

        Log.d("StepService", "👣 Steps today: $stepsToday")

        // Update notification only when the Dart isolate is NOT sleeping
        // (Dart isolate will overwrite the notification text during sleep mode)
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        val isSleeping = flutterPrefs.getBoolean("flutter.is_sleeping", false)
        if (!isSleeping) {
            val notifManager = getSystemService(NotificationManager::class.java)
            notifManager.notify(NOTIFICATION_ID, buildNotification(stepsToday))
        }

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
        super.onDestroy()
        if (::sensorManager.isInitialized) {
            sensorManager.unregisterListener(this)
        }
        screenStateReceiver?.let { unregisterReceiver(it) }
        screenStateReceiver = null
        BufferManager.flushAll(applicationContext)
        Log.d("StepService", "🛑 StepCounterService destroyed.")
    }

    private fun registerScreenStateReceiver() {
        if (screenStateReceiver != null) return

        val receiver = ScreenStateReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(receiver, filter)
        screenStateReceiver = receiver
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
        // Set by MainActivity so steps can be sent to the live UI engine
        var flutterEngine: FlutterEngine? = null
    }
}
