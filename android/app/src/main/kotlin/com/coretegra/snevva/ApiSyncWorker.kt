package com.coretegra.snevva

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class ApiSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        Log.d("ApiSyncWorker", "Running native ApiSyncWorker for file-backed health sync")

        return try {
            BufferManager.flushAll(applicationContext)
            DailyStore.listPendingDayKeys(applicationContext).forEach { dayKey ->
                SyncQueueStore.enqueue(applicationContext, dayKey)
            }
            SyncManager.processQueue(applicationContext)
            Result.success()
        } catch (e: Exception) {
            Log.e("ApiSyncWorker", "Native sync failed", e)
            Result.retry()
        }
    }
}
