// package com.coretegra.snevvaa

// import android.content.Context
// import android.util.Log
// import androidx.work.*
// import org.json.JSONArray
// import org.json.JSONObject
// import java.util.concurrent.TimeUnit
// import java.text.SimpleDateFormat
// import java.util.Date
// import java.util.Locale
// import java.util.ArrayList

// /**
//  * PeriodSyncWorker
//  *
//  * Fires the /api/upsert/editperioddata endpoint in the background whenever
//  * a new menstrual cycle is detected on the Flutter side.
//  *
//  * The Flutter controller writes the pending payload to FlutterSharedPreferences
//  * under the key "flutter.pending_period_sync", then enqueues this worker.
//  * On success the key is cleared. On failure WorkManager retries with
//  * exponential back-off (requires network connectivity).
//  *
//  * Payload shape written by Flutter (JSON string):
//  * {
//  *   "StartDay": 11, "StartMonth": 5, "StartYear": 2026,
//  *   "PredictedDay": 8, "PredictedMonth": 6, "PredictedYear": 2026,
//  *   "IsMatched": false
//  * }
//  */
// class PeriodSyncWorker(context: Context, params: WorkerParameters) :
//     CoroutineWorker(context, params) {

//     private fun appendLog(prefs: android.content.SharedPreferences, message: String) {
//         try {
//             val currentLogs = prefs.getString("flutter.period_sync_debug_logs", "[]") ?: "[]"
//             val array = JSONArray(currentLogs)
//             val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            
//             val list = ArrayList<String>()
//             for (i in 0 until array.length()) {
//                 list.add(array.getString(i))
//             }
//             list.add("[$timestamp] Worker: $message")
//             if (list.size > 100) {
//                 list.removeAt(0)
//             }
            
//             val newArray = JSONArray()
//             for (item in list) {
//                 newArray.put(item)
//             }
//             prefs.edit().putString("flutter.period_sync_debug_logs", newArray.toString()).apply()
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to append log", e)
//         }
//     }

//     companion object {
//         private const val TAG = "PeriodSyncWorker"
//         private const val PREF_KEY = "flutter.pending_period_sync"
//         private const val WORK_NAME = "PERIOD_SYNC_WORK"

//         /**
//          * Called from Flutter via MethodChannel (or directly after writing prefs).
//          * Enqueues a one-shot worker that requires network, with exponential back-off.
//          */
//         fun enqueue(context: Context) {
//             val request = OneTimeWorkRequestBuilder<PeriodSyncWorker>()
//                 .setConstraints(
//                     Constraints.Builder()
//                         .setRequiredNetworkType(NetworkType.CONNECTED)
//                         .build()
//                 )
//                 .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
//                 .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
//                 .build()

//             WorkManager.getInstance(context)
//                 .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, request)

//             Log.d(TAG, "PeriodSyncWorker enqueued")
//         }
//     }

//     override suspend fun doWork(): Result {
//         Log.d(TAG, "doWork started")

//         val prefs = applicationContext.getSharedPreferences(
//             "FlutterSharedPreferences", Context.MODE_PRIVATE
//         )

//         val payloadJson = prefs.getString(PREF_KEY, null)
//         if (payloadJson.isNullOrBlank()) {
//             Log.d(TAG, "No pending period sync payload — nothing to do")
//             appendLog(prefs, "No pending period sync payload — nothing to do")
//             return Result.success()
//         }
//         appendLog(prefs, "Found pending payload: $payloadJson")

//         return try {
//             val payload = JSONObject(payloadJson)

//             // Read auth token stored by Flutter
//             val token = prefs.getString("flutter.authToken", null)
//                 ?: prefs.getString("flutter.token", null)
//                 ?: run {
//                     Log.w(TAG, "No auth token found — will retry")
//                     appendLog(prefs, "No auth token found — will retry")
//                     return Result.retry()
//                 }

//             val baseUrl = prefs.getString("flutter.baseUrl", "https://abdmstg.coretegra.com")
//                 ?: "https://abdmstg.coretegra.com"

//             val url = java.net.URL("$baseUrl/api/upsert/editperioddata")
//             val connection = url.openConnection() as java.net.HttpURLConnection
//             connection.apply {
//                 requestMethod = "POST"
//                 setRequestProperty("Content-Type", "application/json")
//                 setRequestProperty("Accept", "application/json")
//                 setRequestProperty("Authorization", "Bearer $token")
//                 connectTimeout = 15_000
//                 readTimeout = 15_000
//                 doOutput = true
//             }

//             connection.outputStream.bufferedWriter().use { it.write(payload.toString()) }

//             val responseCode = connection.responseCode
//             val responseBody = try {
//                 connection.inputStream.bufferedReader().readText()
//             } catch (_: Exception) {
//                 connection.errorStream?.bufferedReader()?.readText() ?: ""
//             }

//             Log.d(TAG, "editperioddata response $responseCode: $responseBody")
//             appendLog(prefs, "API Response $responseCode: $responseBody")

//             if (responseCode in 200..299) {
//                 // Clear the pending payload on success
//                 prefs.edit().remove(PREF_KEY).apply()
//                 Log.d(TAG, "✅ Period sync successful — payload cleared")
//                 appendLog(prefs, "✅ Period sync successful — payload cleared")
//                 Result.success()
//             } else {
//                 Log.w(TAG, "⚠️ Period sync failed ($responseCode) — will retry")
//                 appendLog(prefs, "⚠️ Period sync failed ($responseCode) — will retry")
//                 Result.retry()
//             }
//         } catch (e: Exception) {
//             Log.e(TAG, "❌ Period sync exception: ${e.message}")
//             appendLog(prefs, "❌ Period sync exception: ${e.message}")
//             Result.retry()
//         }
//     }
// }