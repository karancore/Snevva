package com.coretegra.snevva

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class ResurrectionWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        Log.d("ResurrectionWorker", "Resurrecting StepCounterService")
        StepServiceStarter.tryStart(applicationContext, "resurrection")
        return Result.success()
    }
}
