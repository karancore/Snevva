package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * ConnectivityReceiver
 *
 * Fires when the device gains network connectivity.
 * Triggers a flush of step/sleep buffers and then calls the Dart-side
 * SyncManager via MethodChannel to process the sync_queue.json.
 *
 * Registration: declared in AndroidManifest.xml with CONNECTIVITY_CHANGE intent filter.
 * Note: On Android 7+ this must be registered dynamically from a long-lived component
 * (StepCounterService does this at start). The manifest registration is kept for
 * pre-Nougat devices.
 */
class ConnectivityReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ConnectivityReceiver"
        const val SYNC_CHANNEL = "com.coretegra.snevva/sync"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (!isNetworkAvailable(context)) return

        Log.d(TAG, "Network available — triggering buffer flush + sync")

        // Flush any buffered step/sleep data into daily JSON files before sync
        BufferManager.flushStepsToDaily(context)
        BufferManager.flushSleepToDaily(context)

        // Trigger the Dart-side SyncManager via MethodChannel (if engine is alive)
        val engine = StepCounterService.flutterEngine
        if (engine != null) {
            try {
                MethodChannel(engine.dartExecutor.binaryMessenger, SYNC_CHANNEL)
                    .invokeMethod("processQueue", null)
                Log.d(TAG, "processQueue invoked on Dart SyncManager")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to invoke processQueue: ${e.message}")
            }
        } else {
            Log.d(TAG, "Flutter engine not available — sync will fire on next app open")
        }
    }

    private fun isNetworkAvailable(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                    caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        } else {
            @Suppress("DEPRECATION")
            cm.activeNetworkInfo?.isConnected == true
        }
    }
}
