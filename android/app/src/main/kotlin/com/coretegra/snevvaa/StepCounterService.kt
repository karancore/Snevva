package com.coretegra.snevvaa

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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Bounds of a single sleep-tracking window. */
private data class SleepWindow(val start: Calendar, val end: Calendar)

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

    /** Tracks whether startForeground() has already been called this lifecycle.
     *  Prevents double-posting when both onCreate() and onStartCommand() are called
     *  (normal start), and ensures it IS called when only onStartCommand() fires (sticky restart). */
    private var isForegroundStarted = false

    /** Dynamically-registered receiver that tracks sleep intervals natively. */
    private var screenReceiver: ScreenStateReceiver? = null

    /** ISO-8601 formatter shared by handleScreenOff / handleScreenOn. */
    private val isoFmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.e("StepService", "Swipe-to-kill detected. Checking login state before resurrection.")

        // ── Logged-out guard ───────────────────────────────────────────────────
        // If forceLogout() has run, flutter.auth_token is gone.  Do NOT resurrect
        // the foreground service — the sticky notification must stay dismissed.
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        if (!flutterPrefs.contains("flutter.auth_token")) {
            Log.d("StepService", "User logged out — skipping resurrection on task removal.")
            return
        }
        // ──────────────────────────────────────────────────────────────────────

        Log.e("StepService", "Trying to resurrect via AlarmManager & WorkManager.")

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
        // Handle explicit REFRESH_NOTIFICATION action — sent by seedTodaySteps()
        // after writing the new step count so the notification updates immediately
        // without waiting for the next sensor event or 1-min ticker.
        if (intent?.action == "REFRESH_NOTIFICATION") {
            refreshNotification()
            return START_STICKY
        }

        // On sticky restarts (after OOM kill), Android re-delivers onStartCommand()
        // WITHOUT calling onCreate() again. We must call startForeground() here too,
        // otherwise the service times out and throws ForegroundServiceDidNotStopInTimeException.
        // Guard with isRunningAsForeground flag to avoid double-posting on normal starts.
        if (!isForegroundStarted) {
            val stepsToday = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getInt(KEY_TODAY_STEPS, 0)
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
                isForegroundStarted = true
            } catch (e: Exception) {
                Log.e("StepService", "startForeground in onStartCommand failed", e)
                try { startForeground(NOTIFICATION_ID, notification) } catch (_: Exception) {}
            }
        }
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

        // ── Post-logout user-switch guard ──────────────────────────────────────
        // forceLogout() calls FlutterSharedPreferences.clear() which removes
        // "flutter.today_steps". Our own steps_prefs is a different file and
        // is NOT cleared on logout, so User B would inherit User A's step count.
        // If the key is absent → fresh login → reset our counter to 0.
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE
        )
        if (!flutterPrefs.contains("flutter.today_steps")) {
            Log.d("StepService", "🔄 flutter.today_steps absent (post-logout). Resetting step counter for new user.")
            prefs.edit()
                .putInt(KEY_TODAY_STEPS, 0)
                .remove(KEY_DATE)   // force a fresh date so day-reset logic is clean
                .apply()
            // Also zero out the Flutter-visible key immediately so the notification
            // shows 0 right away, before any API seed arrives.
            flutterPrefs.edit()
                .putLong("flutter.today_steps", 0L)
                .apply()
        }
        // ── End guard ──────────────────────────────────────────────────────────

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
            isForegroundStarted = true
        } catch (e: Exception) {
            Log.e("StepService", "Error starting foreground service", e)
            // Fallback: try to start as regular foreground service without health type
            try {
                startForeground(NOTIFICATION_ID, notification)
                isForegroundStarted = true
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

        // ── Native screen-state receiver for sleep window tracking ──────────────
        // Must be registered dynamically — ACTION_SCREEN_OFF/ON are not deliverable
        // to manifest-declared receivers.  This keeps working even when Dart is dead.
        screenReceiver = ScreenStateReceiver()
        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, screenFilter)
        Log.d("StepService", "📱 ScreenStateReceiver registered for native sleep tracking")

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
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.coretegra.snevvaa/step_detector")
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

    /**
     * Android 15 (API 35) safety net.
     *
     * onTimeout() is called when the system decides this foreground service has
     * exceeded the allowed runtime for its declared type.  Now that we use the
     * `health` type (no time limit), this should never fire in practice — but
     * we implement it defensively so the service stops gracefully rather than
     * being killed with ForegroundServiceDidNotStopInTimeException.
     *
     * We flush the step buffer before stopping so no data is lost.
     */
    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(
            "StepService",
            "⚠️ onTimeout(startId=$startId, fgsType=$fgsType) — stopping gracefully"
        )
        try {
            BufferManager.flushStepsToDaily(applicationContext)
        } catch (e: Exception) {
            Log.e("StepService", "onTimeout: flush failed: ${e.message}")
        }
        stopSelf()
    }

    override fun onDestroy() {
        // Stop the 1-min ticker first
        notifHandler.removeCallbacks(notifRunnable)
        // Unregister sensor BEFORE super.onDestroy() to release hardware resources promptly.
        // This prevents the OS from marking us as "did not stop in time" while we hold the sensor.
        sensorManager.unregisterListener(this)
        // Unregister the native screen-state receiver
        screenReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        screenReceiver = null
        isForegroundStarted = false
        // Call super BEFORE blocking I/O — the OS stop deadline is on the Binder thread;
        // blocking here AFTER super is safe because the service is already deregistered.
        super.onDestroy()
        // Flush buffers after super so we don't hold the service-alive contract during I/O
        try {
            BufferManager.flushStepsToDaily(applicationContext)
            BufferManager.flushSleepToDaily(applicationContext)
        } catch (e: Exception) {
            Log.e("StepService", "Buffer flush on destroy failed: ${e.message}")
        }
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
        val steps        = flutterPrefs.getLong("flutter.today_steps", 0L).toInt()
        val sleepMinutes = computeSleepDisplayMinutes(flutterPrefs)
        val notifManager = getSystemService(NotificationManager::class.java)
        notifManager.notify(NOTIFICATION_ID, buildNotification(steps, sleepMinutes))
    }

    private fun buildNotification(stepsToday: Int, sleepMinutes: Int = 0): Notification {
        val stepsFormatted = String.format(Locale.US, "%,d", stepsToday)

        val sleepText = if (sleepMinutes > 0) {
            val h = sleepMinutes / 60
            val m = sleepMinutes % 60
            if (h > 0) "${h}h ${m}m sleep" else "${m}m sleep"
        } else {
            "no sleep logged"
        }

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tracking your day")
            .setContentText("$stepsFormatted steps  ·  $sleepText")
            .setSmallIcon(R.drawable.ic_stat_notification_bg)
            .setContentIntent(pendingIntent)
            .setColor(0xFFFFFFFF.toInt())
            .setOngoing(true)
            .build()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NATIVE SCREEN-STATE SLEEP TRACKING
    // Runs entirely in Kotlin inside the foreground service — no Dart engine needed.
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Receives ACTION_SCREEN_OFF and ACTION_SCREEN_ON.
     * Registered dynamically in onCreate() so it works even when Dart is dead.
     */
    private inner class ScreenStateReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> handleScreenOff()
                Intent.ACTION_SCREEN_ON  -> handleScreenOn()
            }
        }
    }

    /**
     * Screen turned OFF.
     * If the current time is inside the configured sleep window, record an anchor
     * timestamp and mark is_sleeping = true so the notification shows live data.
     */
    private fun handleScreenOff() {
        val window = getSleepWindowBounds() ?: return
        val now    = Calendar.getInstance()

        // Only engage if we are actually inside the sleep window
        if (!isWithinSleepWindow(now, window.start, window.end)) return

        val dateKey = getSleepDateKey(window.start)
        val isoNow  = isoFmt.format(now.time)

        applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.last_screen_off_$dateKey", isoNow)
            .putBoolean("flutter.is_sleeping", true)
            .apply()

        Log.d(TAG, "📴 Screen OFF → anchor set [$dateKey] at $isoNow")
    }

    /**
     * Screen turned ON.
     * Closes the open sleep interval (from the anchor written by handleScreenOff),
     * clamps it to the window bounds, and appends it to the durable sleep buffer.
     * Also accumulates flutter.sleep_elapsed_minutes so the notification shows a
     * live running total throughout the night.
     *
     * Note: even if this fires after the wake time (e.g. user turns phone on at 10 AM),
     * the interval is clamped to window.end, so no over-counting occurs.
     * SleepCalcWorker already cleared the anchor at wake time, so this is a no-op then.
     */
    private fun handleScreenOn() {
        val window  = getSleepWindowBounds() ?: return
        val dateKey = getSleepDateKey(window.start)

        val prefs      = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lastOffIso = prefs.getString("flutter.last_screen_off_$dateKey", null) ?: return

        try {
            val rawOff = isoFmt.parse(lastOffIso.take(23)) ?: return

            // Clamp start — don't count time before bedtime
            val intervalStart = if (rawOff.before(window.start.time)) window.start.time else rawOff

            // Clamp end — don't count time after wake time
            val now         = Calendar.getInstance()
            val intervalEnd = if (now.after(window.end)) window.end.time else now.time

            val diffMin = ((intervalEnd.time - intervalStart.time) / 60_000).toInt()

            if (diffMin >= MIN_SLEEP_GAP_MIN) {
                val startIso = isoFmt.format(intervalStart)
                val endIso   = isoFmt.format(intervalEnd)

                // Persist to the durable buffer file (survives process death)
                BufferManager.appendSleepInterval(applicationContext, dateKey, startIso, endIso)

                // Accumulate running elapsed so the 1-min ticker notification stays live
                val current = prefs.getLong("flutter.sleep_elapsed_minutes", 0L).toInt()
                prefs.edit()
                    .putLong("flutter.sleep_elapsed_minutes", (current + diffMin).toLong())
                    .apply()

                Log.d(TAG, "😴 Sleep interval recorded: ${diffMin}m  [$startIso → $endIso]")
            } else {
                Log.d(TAG, "😴 Interval too short (${diffMin}m < ${MIN_SLEEP_GAP_MIN}m) — skipped")
            }
        } catch (e: Exception) {
            Log.e(TAG, "handleScreenOn error: $e")
        }

        // Always clear the anchor to prevent double-counting.
        // SleepCalcWorker also removes it at wake time (belt-and-suspenders).
        prefs.edit().remove("flutter.last_screen_off_$dateKey").apply()
    }

    /**
     * Determines which sleep value to show in the notification.
     *
     *  Case 1 — is_sleeping = true           → live elapsed (grows through the night)
     *  Case 2 — sleep_final_date == today     → final total written by SleepCalcWorker
     *  Case 3 — no active / recent session   → 0  (notification shows "--")
     */
    private fun computeSleepDisplayMinutes(prefs: SharedPreferences): Int {
        // Case 1: actively inside the sleep window
        if (prefs.getBoolean("flutter.is_sleeping", false)) {
            return prefs.getLong("flutter.sleep_elapsed_minutes", 0L).toInt()
        }

        // Case 2: session finished today — keep showing the final result all day
        val finalDate = prefs.getString("flutter.sleep_final_date", null)
        if (finalDate != null) {
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            if (finalDate == today) {
                return prefs.getLong("flutter.sleep_final_minutes", 0L).toInt()
            }
        }

        // Case 3: nothing relevant
        return 0
    }

    /**
     * Computes the bounds of the current (or most-recently-started) sleep window
     * from bedtime + wake-time values stored by the Dart SleepController.
     * Returns null when no sleep window has been configured by the user.
     */
    private fun getSleepWindowBounds(): SleepWindow? {
        val prefs   = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val bedMin  = prefs.getLong("flutter.user_bedtime_ms",  -1L)
        val wakeMin = prefs.getLong("flutter.user_waketime_ms", -1L)
        if (bedMin == -1L || wakeMin == -1L) return null

        val bedHour    = (bedMin  / 60).toInt()
        val bedMinute  = (bedMin  % 60).toInt()
        val wakeHour   = (wakeMin / 60).toInt()
        val wakeMinute = (wakeMin % 60).toInt()

        val now = Calendar.getInstance()

        // Resolve the most recently started bedtime
        // (shift back one day if tonight's bedtime hasn't arrived yet)
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, bedHour)
            set(Calendar.MINUTE,      bedMinute)
            set(Calendar.SECOND,      0)
            set(Calendar.MILLISECOND, 0)
        }
        if (start.after(now)) start.add(Calendar.DAY_OF_MONTH, -1)

        // Wake time is always strictly after bedtime (overnight windows cross midnight)
        val end = (start.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, wakeHour)
            set(Calendar.MINUTE,      wakeMinute)
            set(Calendar.SECOND,      0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!end.after(start)) end.add(Calendar.DAY_OF_MONTH, 1)

        return SleepWindow(start, end)
    }

    /** Returns true when [now] falls within [start, end] (both inclusive). */
    private fun isWithinSleepWindow(now: Calendar, start: Calendar, end: Calendar): Boolean =
        !now.before(start) && !now.after(end)

    /**
     * Returns the YYYY-MM-DD key for the bed-date (the window's start day).
     * This matches the key used by BufferManager and the daily JSON files.
     */
    private fun getSleepDateKey(windowStart: Calendar): String = "%04d-%02d-%02d".format(
        windowStart.get(Calendar.YEAR),
        windowStart.get(Calendar.MONTH) + 1,
        windowStart.get(Calendar.DAY_OF_MONTH)
    )

    // ══════════════════════════════════════════════════════════════════════════

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
        // Minimum screen-off duration (minutes) to count as a sleep interval.
        // Mirrors Dart's SleepNoticingService.minSleepGap.
        private const val MIN_SLEEP_GAP_MIN = 3
        // Set by MainActivity so steps can be sent to the live UI engine
        var flutterEngine: FlutterEngine? = null
    }
}

