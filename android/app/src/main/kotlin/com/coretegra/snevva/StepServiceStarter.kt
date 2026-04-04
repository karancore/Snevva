package com.coretegra.snevva

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat

object StepServiceStarter {
    private const val TAG = "StepServiceStarter"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val AUTH_TOKEN_KEY = "flutter.auth_token"

    private fun hasActiveSession(context: Context): Boolean {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        return !prefs.getString(AUTH_TOKEN_KEY, "").isNullOrBlank()
    }

    fun hasRequiredPermissions(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACTIVITY_RECOGNITION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Skipping StepCounterService start: ACTIVITY_RECOGNITION not granted")
            return false
        }

        return true
    }

    fun tryStart(
        context: Context,
        source: String,
        requireActiveSession: Boolean = true
    ): Boolean {
        if (requireActiveSession && !hasActiveSession(context)) {
            Log.d(TAG, "Skipping StepCounterService start from $source: no active session")
            return false
        }

        if (!hasRequiredPermissions(context)) {
            Log.d(TAG, "Skipping StepCounterService start from $source: permissions missing")
            return false
        }

        val intent = Intent(context, StepCounterService::class.java)

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            Log.d(TAG, "Started StepCounterService from $source")
            true
        } catch (securityException: SecurityException) {
            Log.e(
                TAG,
                "SecurityException while starting StepCounterService from $source",
                securityException
            )
            false
        } catch (exception: Exception) {
            Log.e(
                TAG,
                "Failed to start StepCounterService from $source",
                exception
            )
            false
        }
    }
}
