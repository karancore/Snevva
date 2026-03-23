import re

file_path = r'd:\Git\Snevva\android\app\src\main\kotlin\com\coretegra\snevva\StepCounterService.kt'
with open(file_path, 'r', encoding='utf-8') as f:
    orig = f.read()
    
content = orig

# Add imports
content = content.replace("import android.content.pm.ServiceInfo", "import android.content.pm.ServiceInfo\nimport android.os.SystemClock\nimport androidx.work.OneTimeWorkRequestBuilder\nimport androidx.work.WorkManager")

# Change sensor to TYPE_STEP_DETECTOR
content = content.replace("getDefaultSensor(Sensor.TYPE_STEP_COUNTER)", "getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)")
content = content.replace("if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER) return", "if (event?.sensor?.type != Sensor.TYPE_STEP_DETECTOR) return")

# Add scheduleSparseWakeup()
content = content.replace("registerStepListener()", "registerStepListener()\n        scheduleSparseWakeup()")

# Add the new methods
methods_str = """
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
"""
content = content.replace("override fun onBind(intent: Intent?): IBinder? = null", "override fun onBind(intent: Intent?): IBinder? = null\n" + methods_str)


# Replace logic in onSensorChanged
old_sensor_logic = """        val totalSteps = event.values[0]
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

        Log.d("StepService", "👣 Steps today: $stepsToday")"""

new_sensor_logic = """        val currentDate = android.text.format.DateFormat.format("yyyyMMdd", System.currentTimeMillis()).toString()
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
        }"""

content = content.replace(old_sensor_logic, new_sensor_logic)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")
