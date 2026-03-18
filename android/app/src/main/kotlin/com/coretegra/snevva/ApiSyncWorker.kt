package com.coretegra.snevva

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred

class ApiSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        Log.d("ApiSyncWorker", "Running ApiSyncWorker for background data sync")
        
        val deferredResult = CompletableDeferred<Result>()
        
        // FlutterEngine must be instantiated on the main thread
        Handler(Looper.getMainLooper()).post {
            try {
                val engine = FlutterEngine(applicationContext)
                
                // You can specify a custom entrypoint if you created one in dart, 
                // e.g., @pragma('vm:entry-point') void backgroundSync() { ... }
                // For now, we use the default entry point and a method channel
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )
                
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.coretegra.snevva/background_sync")
                channel.invokeMethod("performSync", null, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.d("ApiSyncWorker", "Dart sync success: $result")
                        deferredResult.complete(Result.success())
                        engine.destroy()
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e("ApiSyncWorker", "Dart sync error: $errorCode - $errorMessage")
                        deferredResult.complete(Result.retry())
                        engine.destroy()
                    }

                    override fun notImplemented() {
                        Log.w("ApiSyncWorker", "Dart sync method not implemented, skipping.")
                        deferredResult.complete(Result.success())
                        engine.destroy()
                    }
                })
            } catch (e: Exception) {
                Log.e("ApiSyncWorker", "Failed to start Flutter engine for sync", e)
                deferredResult.complete(Result.retry())
            }
        }
        
        return deferredResult.await()
    }
}
