package com.coretegra.snevva

import android.content.Context
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

object SyncManager {
    private const val TAG = "SyncManager"
    private val running = AtomicBoolean(false)

    fun processQueue(context: Context) {
        if (!running.compareAndSet(false, true)) {
            return
        }

        try {
            while (true) {
                val dayKey = SyncQueueStore.peek(context) ?: break
                val dailyFile = HealthFilePaths.dailyFile(context, dayKey)

                if (!dailyFile.exists()) {
                    SyncQueueStore.remove(context, dayKey)
                    continue
                }

                val dayJson = DailyStore.readDay(context, dayKey)
                val success = NativeApiClient.syncDay(context, dayKey, dayJson)
                if (!success) {
                    Log.w(TAG, "Stopping queue processing after failed sync for $dayKey")
                    break
                }

                DailyStore.deleteDay(context, dayKey)
                SyncQueueStore.remove(context, dayKey)
                MetaStore.setLastSyncTimestamp(context, System.currentTimeMillis())
            }
        } finally {
            running.set(false)
        }
    }
}
