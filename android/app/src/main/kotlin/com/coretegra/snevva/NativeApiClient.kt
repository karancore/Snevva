package com.coretegra.snevva

import android.content.Context
import android.os.Build
import android.util.Base64
import android.util.Log
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

object NativeApiClient {
    private const val TAG = "NativeApiClient"
    private const val BASE_URL = "https://abdmstg.coretegra.com"
    private const val STEP_ENDPOINT = "/api/upsert/addsteprecord"
    private const val SLEEP_ENDPOINT = "/api/upsert/addsleeprecord"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY = "jc8upb889n3SHP1LTveX0s3tCJOemFYo"
    private const val IV = "6LG0mK7sv1SMvyfO"

    fun syncDay(context: Context, dayKey: String, dayJson: JSONObject): Boolean {
        val steps = dayJson.optJSONObject("steps")
        val sleep = dayJson.optJSONObject("sleep")

        val dateParts = dayKey.split("-")
        if (dateParts.size != 3) return false
        val year = dateParts[0].toIntOrNull() ?: return false
        val month = dateParts[1].toIntOrNull() ?: return false
        val day = dateParts[2].toIntOrNull() ?: return false

        if ((steps?.optInt("total", 0) ?: 0) > 0) {
            val stepPayload = JSONObject().apply {
                put("Day", day)
                put("Month", month)
                put("Year", year)
                put("Time", "23:59")
                put("Count", steps!!.optInt("total", 0))
            }

            if (!postEncrypted(context, STEP_ENDPOINT, stepPayload)) {
                return false
            }
        }

        val sleepMinutes = sleep?.optInt("total_sleep_minutes", 0) ?: 0
        if (sleepMinutes > 0) {
            val sleepingFrom = sleep.optString("window_start", "")
            val sleepingTo = sleep.optString("window_end", "")
            val sleepPayload = JSONObject().apply {
                put("Day", day)
                put("Month", month)
                put("Year", year)
                put("Time", sleepingTo.ifBlank { "06:00" })
                put("SleepingFrom", sleepingFrom.ifBlank { "22:00" })
                put("SleepingTo", sleepingTo.ifBlank { "06:00" })
                put("Count", sleepMinutes.toString())
            }

            if (!postEncrypted(context, SLEEP_ENDPOINT, sleepPayload)) {
                return false
            }
        }

        return true
    }

    private fun postEncrypted(context: Context, endpoint: String, payload: JSONObject): Boolean {
        val token = context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString("flutter.auth_token", null)
            ?.takeIf { it.isNotBlank() }
            ?: return false

        val encrypted = encrypt(payload.toString())
        val requestBody = JSONObject().put("data", encrypted.first).toString()
        val url = URL("$BASE_URL$endpoint")

        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 20000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("x-data-hash", encrypted.second)
            setRequestProperty("X-Device-Info", buildDeviceInfoHeader())
        }

        return runCatching {
            BufferedOutputStream(connection.outputStream).use { output ->
                output.write(requestBody.toByteArray(Charsets.UTF_8))
                output.flush()
            }

            val responseCode = connection.responseCode
            val body = runCatching {
                (if (responseCode in 200..299) connection.inputStream else connection.errorStream)
                    ?.bufferedReader()
                    ?.use { it.readText() }
                    .orEmpty()
            }.getOrDefault("")

            if (responseCode !in 200..299) {
                Log.e(TAG, "Sync failed $endpoint -> HTTP $responseCode $body")
                false
            } else {
                if (body.isNotBlank()) {
                    runCatching {
                        val json = JSONObject(body)
                        val responseData = json.optString("data")
                        val responseHash = connection.getHeaderField("x-data-hash")
                        if (responseData.isNotBlank() && !responseHash.isNullOrBlank()) {
                            decrypt(responseData, responseHash)
                        }
                    }
                }
                true
            }
        }.getOrElse { error ->
            Log.e(TAG, "Sync request crashed for $endpoint", error)
            false
        }.also {
            connection.disconnect()
        }
    }

    private fun encrypt(plainText: String): Pair<String, String> {
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        val secretKey = SecretKeySpec(KEY.toByteArray(Charsets.UTF_8), "AES")
        val ivSpec = IvParameterSpec(IV.toByteArray(Charsets.UTF_8))
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, ivSpec)
        val encryptedBytes = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
        val encryptedText = Base64.encodeToString(encryptedBytes, Base64.NO_WRAP)
        val hash = sha256(encryptedText)
        return encryptedText to hash
    }

    private fun decrypt(encryptedText: String, hash: String): String? {
        if (sha256(encryptedText) != hash) return null

        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        val secretKey = SecretKeySpec(KEY.toByteArray(Charsets.UTF_8), "AES")
        val ivSpec = IvParameterSpec(IV.toByteArray(Charsets.UTF_8))
        cipher.init(Cipher.DECRYPT_MODE, secretKey, ivSpec)
        val decodedBytes = Base64.decode(encryptedText, Base64.DEFAULT)
        return String(cipher.doFinal(decodedBytes), Charsets.UTF_8)
    }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(value.toByteArray(Charsets.UTF_8))
        return bytes.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    private fun buildDeviceInfoHeader(): String {
        val payload = JSONObject().apply {
            put("platform", "android")
            put("brand", Build.BRAND ?: "unknown")
            put("model", Build.MODEL ?: "unknown")
            put("device", Build.DEVICE ?: "unknown")
            put("product", Build.PRODUCT ?: "unknown")
            put("hardware", Build.HARDWARE ?: "unknown")
            put("physical", true.toString())
            put("abi", Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown")
            put("androidVersion", Build.VERSION.RELEASE ?: "unknown")
            put("sdkInt", Build.VERSION.SDK_INT.toString())
            put("securityPatch", Build.VERSION.SECURITY_PATCH ?: "unknown")
            put("lowRam", "false")
        }
        return Base64.encodeToString(payload.toString().toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
    }
}
