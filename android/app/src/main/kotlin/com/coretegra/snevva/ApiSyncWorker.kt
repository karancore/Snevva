package com.coretegra.snevva

import android.content.Context
import android.os.Build
import android.util.Base64
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * ApiSyncWorker — pure Kotlin, no Flutter engine needed.
 *
 * Exactly mirrors Dart's ApiService.post(encryptionRequired: true) + AuthHeaderHelper:
 *
 *   1. AES-256-CBC / PKCS7-pad the JSON payload → base64  (EncryptionService.encryptData)
 *   2. SHA-256 the base64 ciphertext                       (x-data-hash header)
 *   3. Build X-Device-Info as base64(jsonEncode(deviceFields)) (DeviceTokenService)
 *   4. POST body: {"data": "<base64>"}
 *   5. Headers: Content-Type, Accept, Authorization, x-data-hash, X-Device-Info
 *
 * Triggered by:
 *  • StepCounterService  — day change  (steps for yesterday)
 *  • SleepCalcWorker     — wake time   (sleep for last night)
 *  • ConnectivityReceiver— net regained (flush + sync)
 */
class ApiSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "ApiSyncWorker"

        // ── Must match EncryptionService.dart exactly ──────────────────────
        private const val AES_KEY = "jc8upb889n3SHP1LTveX0s3tCJOemFYo"   // 32 bytes → AES-256
        private const val AES_IV  = "6LG0mK7sv1SMvyfO"                    // 16 bytes

        // ── API ────────────────────────────────────────────────────────────
        private const val BASE_URL       = "https://abdmstg.coretegra.com"
        private const val STEP_ENDPOINT  = "/api/upsert/addsteprecord"
        private const val SLEEP_ENDPOINT = "/api/upsert/addsleeprecord"
    }

    // ── Worker entry point ─────────────────────────────────────────────────

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        Log.d(TAG, "🔄 ApiSyncWorker started")

        val token = getAuthToken()
        if (token.isNullOrBlank()) {
            Log.w(TAG, "⚠️ No auth token — skipping (user not logged in)")
            return@withContext Result.success()   // don't retry; token arrives after login
        }

        val fsDir = java.io.File(applicationContext.filesDir, "fs")
        val queueFile = java.io.File(fsDir, "sync_queue.json")
        if (!queueFile.exists()) {
            Log.d(TAG, "sync_queue.json not found — nothing to sync")
            return@withContext Result.success()
        }

        val queue = readQueue(queueFile)
        if (queue.isEmpty()) {
            Log.d(TAG, "Sync queue is empty")
            return@withContext Result.success()
        }

        Log.d(TAG, "📋 Queue: $queue")

        val deviceInfoHeader = buildDeviceInfoHeader()
        var allSucceeded = true
        val syncedKeys = mutableListOf<String>()

        for (dateKey in queue) {
            val dailyFile = java.io.File(fsDir, "daily/$dateKey.json")
            if (!dailyFile.exists()) {
                Log.w(TAG, "No daily file for $dateKey — removing from queue")
                syncedKeys.add(dateKey)
                continue
            }

            val json = try {
                JSONObject(dailyFile.readText())
            } catch (e: Exception) {
                Log.e(TAG, "Corrupt daily file for $dateKey: ${e.message}")
                allSucceeded = false
                continue
            }

            val parts = dateKey.split("-")
            if (parts.size != 3) { syncedKeys.add(dateKey); continue }
            val year  = parts[0].toIntOrNull() ?: continue
            val month = parts[1].toIntOrNull() ?: continue
            val day   = parts[2].toIntOrNull() ?: continue

            var daySucceeded = true

            // ── Step sync ─────────────────────────────────────────────────────
            val stepTotal = json.optJSONObject("steps")?.optInt("total") ?: 0
            if (stepTotal > 0) {
                val stepPayload = JSONObject().apply {
                    put("Day",   day)
                    put("Month", month)
                    put("Year",  year)
                    put("Time",  "11:59 PM")
                    put("Count", stepTotal)
                }
                val code = postEncrypted(STEP_ENDPOINT, stepPayload.toString(), token, deviceInfoHeader)
                if (code in 200..299) {
                    val msg = "✅ Steps synced for $dateKey: $stepTotal"
                    Log.d(TAG, msg)
                    appendApiLog("STEP", dateKey, code, msg)
                } else {
                    val msg = "❌ Step sync FAILED for $dateKey"
                    Log.e(TAG, msg)
                    appendApiLog("STEP", dateKey, code, msg)
                    daySucceeded = false
                    allSucceeded = false
                }
            }

            // ── Sleep sync ────────────────────────────────────────────────────
            val sleepObj  = json.optJSONObject("sleep")
            val sleepMins = sleepObj?.optInt("total_sleep_minutes") ?: 0
            if (sleepMins > 0) {
                val segments   = sleepObj?.optJSONArray("segments")
                val sleepStart = segments?.optJSONObject(0)?.optString("start")
                    ?: "${dateKey}T22:00:00.000"
                val sleepEnd   = segments?.let {
                    it.optJSONObject(it.length() - 1)?.optString("end")
                } ?: estimateEnd(sleepStart, sleepMins)

                // Extract HH:mm from ISO timestamps (e.g. "2026-04-11T23:45:00.000" → "23:45")
                val sleepingFrom = extractHHmm(sleepStart)
                val sleepingTo   = extractHHmm(sleepEnd)

                // "Time" = wake-up time in 12-hour AM/PM format, matching Flutter's TimeOfDay.now().format()
                val timeAmPm = toAmPm(sleepingTo)

                val sleepPayload = JSONObject().apply {
                    put("Day",         day)
                    put("Month",       month)
                    put("Year",        year)
                    put("Time",        timeAmPm)
                    put("SleepingFrom", sleepingFrom)
                    put("SleepingTo",  sleepingTo)
                    put("Count",       sleepMins.toString()) // API expects Count as String
                }
                val code = postEncrypted(SLEEP_ENDPOINT, sleepPayload.toString(), token, deviceInfoHeader)
                if (code in 200..299) {
                    val msg = "✅ Sleep synced for $dateKey: ${sleepMins}m"
                    Log.d(TAG, msg)
                    appendApiLog("SLEEP", dateKey, code, msg)
                } else {
                    val msg = "❌ Sleep sync FAILED for $dateKey"
                    Log.e(TAG, msg)
                    appendApiLog("SLEEP", dateKey, code, msg)
                    daySucceeded = false
                    allSucceeded = false
                }
            }

            if (daySucceeded) syncedKeys.add(dateKey)
        }

        if (syncedKeys.isNotEmpty()) {
            removeFromQueue(queueFile, syncedKeys)
            Log.d(TAG, "🗑️ Removed from queue: $syncedKeys")
        }

        return@withContext if (allSucceeded) Result.success() else Result.retry()
    }

    // ── Encryption — mirrors EncryptionService.dart exactly ───────────────

    /**
     * AES-256-CBC / PKCS5 (= PKCS7) encrypt [plainText].
     * Returns a map with:
     *   "encryptedData" → Base64 ciphertext (same as Dart's encrypted.base64)
     *   "Hash"          → sha256(encryptedData) hex string
     */
    private fun encryptPayload(plainText: String): Map<String, String> {
        val keySpec = SecretKeySpec(AES_KEY.toByteArray(Charsets.UTF_8), "AES")
        val ivSpec  = IvParameterSpec(AES_IV.toByteArray(Charsets.UTF_8))

        // "PKCS5Padding" is identical to PKCS7 for block sizes ≤ 256-bit in JVM
        val cipher  = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, keySpec, ivSpec)

        val cipherBytes     = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
        val encryptedBase64 = Base64.encodeToString(cipherBytes, Base64.NO_WRAP)

        val hash = sha256Hex(encryptedBase64)

        return mapOf("encryptedData" to encryptedBase64, "Hash" to hash)
    }

    private fun sha256Hex(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    // ── Device info — mirrors DeviceTokenService.buildDeviceInfoHeader() ──

    /**
     * Returns base64(jsonEncode(deviceFields)) — same logic as Dart's
     * DeviceTokenService._build() / getDeviceHeaders().
     */
    private fun buildDeviceInfoHeader(): String {
        val info = JSONObject().apply {
            put("platform",     "android")
            put("brand",        Build.BRAND   ?: "unknown")
            put("model",        Build.MODEL   ?: "unknown")
            put("device",       Build.DEVICE  ?: "unknown")
            put("product",      Build.PRODUCT ?: "unknown")
            put("hardware",     Build.HARDWARE?: "unknown")
            put("physical",     (!Build.FINGERPRINT.startsWith("generic")).toString())
            put("abi",          Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown")
            put("androidVersion", Build.VERSION.RELEASE ?: "unknown")
            put("sdkInt",       Build.VERSION.SDK_INT.toString())
            put("securityPatch", Build.VERSION.SECURITY_PATCH ?: "unknown")
            put("lowRam",       "false")
        }
        return Base64.encodeToString(
            info.toString().toByteArray(Charsets.UTF_8),
            Base64.NO_WRAP
        )
    }

    // ── HTTP helpers ───────────────────────────────────────────────────────

    /**
     * Encrypts [plainJsonBody] and POSTs it to [endpoint] with all required
     * headers, mirroring ApiService.post(encryptionRequired: true).
     *
     * Returns HTTP response code, or 0 if a network/crypto error occurs.
     */
    private fun postEncrypted(
        endpoint:         String,
        plainJsonBody:    String,
        token:            String,
        deviceInfoHeader: String,
    ): Int {
        return try {
            val encrypted = encryptPayload(plainJsonBody)
            val requestBody = JSONObject().apply {
                put("data", encrypted["encryptedData"])
            }.toString()

            val url  = URL("$BASE_URL$endpoint")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type",   "application/json")
                setRequestProperty("Accept",          "application/json")
                setRequestProperty("Authorization",   "Bearer $token")
                setRequestProperty("x-data-hash",     encrypted["Hash"] ?: "")
                setRequestProperty("X-Device-Info",   deviceInfoHeader)
                doOutput      = true
                connectTimeout = 15_000
                readTimeout    = 15_000
            }

            conn.outputStream.use { it.write(requestBody.toByteArray(Charsets.UTF_8)) }

            val code = conn.responseCode
            if (code !in 200..299) {
                val body = conn.errorStream?.bufferedReader()?.readText() ?: ""
                Log.e(TAG, "HTTP $code from $endpoint: $body")
            }
            conn.disconnect()
            code
        } catch (e: Exception) {
            Log.e(TAG, "postEncrypted error ($endpoint): ${e.message}")
            0
        }
    }

    // ── SharedPreferences helpers ─────────────────────────────────────────

    /**
     * Auth token stored by Dart's shared_preferences as flutter.auth_token
     * in FlutterSharedPreferences (this is what AuthHeaderHelper reads).
     */
    private fun getAuthToken(): String? {
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        return prefs.getString("flutter.auth_token", null)
    }

    // ── Sync queue helpers ─────────────────────────────────────────────────

    private fun readQueue(file: java.io.File): List<String> = try {
        val arr = org.json.JSONArray(file.readText())
        (0 until arr.length()).map { arr.getString(it) }
    } catch (e: Exception) {
        Log.e(TAG, "readQueue error: ${e.message}")
        emptyList()
    }

    private fun removeFromQueue(file: java.io.File, toRemove: List<String>) {
        try {
            val current = readQueue(file).toMutableList()
            current.removeAll(toRemove.toSet())
            file.writeText(org.json.JSONArray(current).toString())
        } catch (e: Exception) {
            Log.e(TAG, "removeFromQueue error: ${e.message}")
        }
    }

    // ── Misc helpers ───────────────────────────────────────────────────────

    /**
     * Extracts "HH:mm" from an ISO timestamp like "2026-04-11T23:45:00.000".
     * Falls back to "00:00" on any parse error.
     */
    private fun extractHHmm(iso: String): String {
        return try {
            // Handles both "2026-04-11T23:45:00.000" and bare "23:45"
            val timePart = if (iso.contains("T")) iso.substringAfter("T") else iso
            timePart.take(5) // "HH:mm"
        } catch (_: Exception) {
            "00:00"
        }
    }

    /**
     * Converts a 24-hour "HH:mm" string into Flutter's TimeOfDay.format() output,
     * e.g. "23:45" → "11:45 PM", "00:30" → "12:30 AM".
     */
    private fun toAmPm(hhmm: String): String {
        return try {
            val parts = hhmm.split(":")
            val hour24 = parts[0].toInt()
            val minute = parts[1].toInt()
            val amPm  = if (hour24 < 12) "AM" else "PM"
            val hour12 = when {
                hour24 == 0  -> 12
                hour24 > 12  -> hour24 - 12
                else         -> hour24
            }
            "%d:%02d %s".format(hour12, minute, amPm)
        } catch (_: Exception) {
            "12:00 AM"
        }
    }

    private fun estimateEnd(startIso: String, durationMins: Int): String {
        return try {
            val fmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
            val startDate = fmt.parse(startIso.take(23)) ?: return "${startIso.take(10)}T06:00:00.000"
            val endMs = startDate.time + durationMins * 60_000L
            fmt.format(java.util.Date(endMs))
        } catch (_: Exception) {
            "${startIso.take(10)}T06:00:00.000"
        }
    }

    private fun appendApiLog(type: String, dateKey: String, code: Int, message: String) {
        try {
            val fsDir = java.io.File(applicationContext.filesDir, "fs")
            val logFile = java.io.File(fsDir, "api_sync_logs.json")
            val fmt = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
            val timestamp = fmt.format(java.util.Date())

            val entry = JSONObject().apply {
                put("timestamp", timestamp)
                put("type", type)
                put("dateKeyDate", dateKey)
                put("responseCode", code)
                put("message", message)
            }

            val array = if (logFile.exists()) {
                try {
                    org.json.JSONArray(logFile.readText())
                } catch (e: Exception) {
                    org.json.JSONArray()
                }
            } else {
                org.json.JSONArray()
            }

            array.put(entry)

            // Keep only latest 100 logs
            val trimmedArray = org.json.JSONArray()
            val startIdx = if (array.length() > 100) array.length() - 100 else 0
            for (i in startIdx until array.length()) {
                trimmedArray.put(array.get(i))
            }

            logFile.writeText(trimmedArray.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write api_sync_logs.json: ${e.message}")
        }
    }
}

