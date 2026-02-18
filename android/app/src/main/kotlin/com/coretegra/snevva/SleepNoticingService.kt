package com.coretegra.snevva

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.*

class SleepNoticingService : Service() {

    private var screenReceiver: ScreenReceiver? = null
    private lateinit var prefs: SharedPreferences

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startInForeground()
        // Use Flutter's SharedPreferences to match Dart code
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        Log.d("SleepNoticingService", "Service created")
        recoverIfScreenOffPending()
    }

    private fun startInForeground() {
        val channelId = "sleep_tracking"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Sleep Tracking",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
        val notification =
            NotificationCompat.Builder(this, channelId).setContentTitle("Snevva Sleep Tracking")
                .setContentText("Monitoring sleep activity").setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true).build()
        startForeground(101, notification)
    }

    private fun recoverIfScreenOffPending() {
        val window = computeActiveSleepWindow() ?: return

        val windowKey = window.dateKey
        val lastOffKey = "flutter.last_screen_off_$windowKey"
        val lastOffStr = prefs.getString(lastOffKey, null) ?: return

        try {
            val lastOff = Date(lastOffStr)

            // If now is already after wake time → assume slept till wake
            if (Date().after(window.end)) {

                val start = if (lastOff.before(window.start)) window.start else lastOff
                val end = window.end

                val intervalStr = "${start.toInstant()}|${end.toInstant()}"
                val intervalsKey = "flutter.sleep_intervals_$windowKey"

                val existing = prefs.getString(intervalsKey, "") ?: ""
                val updated = if (existing.isEmpty()) intervalStr else "$existing,$intervalStr"

                prefs.edit()
                    .putString(intervalsKey, updated)
                    .remove(lastOffKey)
                    .apply()

                Log.d("SleepNoticingService", "Recovered lost sleep interval")
            }

        } catch (_: Exception) {
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {


        Log.d("SleepNoticingService", "Service started")

        recoverIfScreenOffPending()

        try {
            screenReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}

        screenReceiver = ScreenReceiver { event ->
            handleScreenEvent(event)
        }
        
        // 🔥 Make this a Foreground Service to prevent killing
        // We can reuse the channel created by flutter_background_service or create one
        // ideally, we should create our own or use a shared hidden one.
        // For now, we will assume the channel exists or post to the same one.
        /*
          NOTE: To be fully correct, we should create a specific channel for this if needed.
          But strictly, `startForeground` needs a notification.
        */
        // Simple placeholder notification - in a real app, you might want to sync this with the main service
        // or just keep it silent/minimized.
        // For this fix, we are ensuring the service STAYS ALIVE.
        
        /* 
           Uncommenting this block would make it a true foreground service. 
           However, we already have `WrapperService` (Unified) running as FG.
           If this service is started *independently*, it needs its own startForeground.
           
           If this service is just a helper, it might not need to be FG if the main app is FG.
           But the user complained about "killing", so lets be safe.
        */
        
        // val channelId = "sleep_noticing_channel"
        // val channel = NotificationChannel(channelId, "Sleep Monitor", NotificationManager.IMPORTANCE_LOW)
        // getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        
        // val notification = Notification.Builder(this, channelId)
        //    .setContentTitle("Sleep Service Active")
        //    .setContentText("Monitoring screen state for sleep accuracy")
        //    .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
        //    .build()
            
        // startForeground(888, notification)

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenReceiver, filter)
            }
            Log.d("SleepNoticingService", "Screen receiver registered")
        } catch (e: Exception) {
            Log.e("SleepNoticingService", "Failed to register receiver", e)
        }

        return START_REDELIVER_INTENT


    }



//    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//        Log.d("SleepNoticingService", "Service started")
//
//
//        // Register screen receiver
//        if (screenReceiver == null) {
//            screenReceiver = ScreenReceiver { event ->
//                handleScreenEvent(event)
//            }
//
//            val filter = IntentFilter().apply {
//                addAction(Intent.ACTION_SCREEN_ON)
//                addAction(Intent.ACTION_SCREEN_OFF)
//            }
//
//            try {
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
//                    registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
//                } else {
//                    registerReceiver(screenReceiver, filter)
//                }
//                Log.d("SleepNoticingService", "Screen receiver registered")
//            } catch (e: Exception) {
//                Log.e("SleepNoticingService", "Failed to register receiver", e)
//            }
//        }
//
//        return START_REDELIVER_INTENT
//    }

    private fun handleScreenEvent(event: String) {
        // Check if sleep tracking is active (use Flutter-prefixed key)
        val isSleeping = prefs.getBoolean("flutter.is_sleeping", false)
        if (!isSleeping) {
            Log.d("SleepNoticingService", "Screen event ignored: sleep tracking not active")
            return
        }

        // Get sleep window
        val window = computeActiveSleepWindow()
        if (window == null) {
            Log.w("SleepNoticingService", "No sleep window available")
            return
        }

        val now = Date()
        if (!isWithinWindow(now, window.start, window.end)) {
            Log.d("SleepNoticingService", "Screen event outside window: ignoring")
            return
        }

        val windowKey = window.dateKey
        val lastOffKey = "flutter.last_screen_off_$windowKey"
        val intervalsKey = "flutter.sleep_intervals_$windowKey"

        when (event) {
            "screen_off" -> {
                // Record the screen off time
                prefs.edit().putString(lastOffKey, now.toString()).apply()
                Log.d("SleepNoticingService", "Screen off recorded at $now for window $windowKey")
            }

            "screen_on" -> {
                // Check for pending screen off
                val lastOffStr = prefs.getString(lastOffKey, null)
                if (lastOffStr != null) {
                    try {
                        val lastOff = Date(lastOffStr)

                        // Clamp interval to window
                        val start = if (lastOff.before(window.start)) window.start else lastOff
                        val end = if (now.after(window.end)) window.end else now

                        if (!end.after(start)) {
                            Log.d("SleepNoticingService", "Invalid interval: $start -> $end")
                            return
                        }

                        val durationMinutes = (end.time - start.time) / (1000 * 60)  // Minutes
                        if (durationMinutes < 3) {  // Minimum gap
                            Log.d(
                                "SleepNoticingService",
                                "Interval too short: $durationMinutes min"
                            )
                            return
                        }

                        // Save interval in ISO format
                        val intervalStr =
                            "${start.toInstant().toString()}|${end.toInstant().toString()}"
                        val existing = prefs.getString(intervalsKey, "") ?: ""
                        val updated =
                            if (existing.isEmpty()) intervalStr else "$existing,$intervalStr"
                        prefs.edit().putString(intervalsKey, updated).apply()

                        // Clear pending off time
                        prefs.edit().remove(lastOffKey).apply()

                        Log.d(
                            "SleepNoticingService",
                            "Interval saved: $intervalStr for window $windowKey"
                        )
                    } catch (e: Exception) {
                        Log.e("SleepNoticingService", "Error processing screen on", e)
                    }
                } else {
                    Log.d("SleepNoticingService", "Screen on: no pending screen off")
                }
            }
        }
    }

    private fun computeActiveSleepWindow(): SleepWindow? {
        // Get bedtime/waketime from prefs (Flutter-prefixed keys)
        val bedMin = prefs.getInt("flutter.user_bedtime_ms", -1)
        val wakeMin = prefs.getInt("flutter.user_waketime_ms", -1)
        if (bedMin == -1 || wakeMin == -1) return null

        val bedHour = bedMin / 60
        val bedMinute = bedMin % 60
        val wakeHour = wakeMin / 60
        val wakeMinute = wakeMin % 60

        val now = Calendar.getInstance()
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, bedHour.toInt())
            set(Calendar.MINUTE, bedMinute.toInt())
        }
        // If bedtime is in the future, shift to yesterday
        if (start.after(now)) start.add(Calendar.DAY_OF_MONTH, -1)

        val end = Calendar.getInstance().apply {
            time = start.time
            set(Calendar.HOUR_OF_DAY, wakeHour.toInt())
            set(Calendar.MINUTE, wakeMinute.toInt())
        }
        // If wake time is before start, shift to next day
        if (!end.after(start)) end.add(Calendar.DAY_OF_MONTH, 1)

        // Fixed: Use padStart instead of padLeft
        val key = "${start.get(Calendar.YEAR)}-${
            (start.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
        }-${start.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')}"
        return SleepWindow(start.time, end.time, key)
    }

    private fun isWithinWindow(t: Date, start: Date, end: Date): Boolean {
        return !t.before(start) && t.before(end)
    }

    override fun onDestroy() {
        try {
            if (screenReceiver != null) {
                unregisterReceiver(screenReceiver)
                Log.d("SleepNoticingService", "Receiver unregistered")
            }
        } catch (e: Exception) {
            Log.e("SleepNoticingService", "Error unregistering receiver", e)
        }

        screenReceiver = null
        Log.d("SleepNoticingService", "Service destroyed")
        super.onDestroy()
    }

    data class SleepWindow(val start: Date, val end: Date, val dateKey: String)
}

class ScreenReceiver(private val callback: (String) -> Unit) : android.content.BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        val km = context?.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val unlocked = !km.isKeyguardLocked

        if (intent?.action == Intent.ACTION_SCREEN_ON && !unlocked) return

        when (intent?.action) {
            Intent.ACTION_SCREEN_OFF -> callback("screen_off")
            Intent.ACTION_SCREEN_ON -> callback("screen_on")
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isSleeping = prefs.getBoolean("flutter.is_sleeping", false)

            if (isSleeping) {
                val serviceIntent = Intent(context, SleepNoticingService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    context.startForegroundService(serviceIntent)
                else
                    context.startService(serviceIntent)
            }
        }
    }
}
