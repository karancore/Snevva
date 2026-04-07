package com.coretegra.snevva

import android.content.Context
import org.json.JSONArray

object SyncQueueStore {
    @Synchronized
    fun readQueue(context: Context): MutableList<String> {
        val file = HealthFilePaths.syncQueueFile(context)
        if (!file.exists()) return mutableListOf()

        return runCatching {
            val array = JSONArray(file.readText())
            MutableList(array.length()) { index -> array.optString(index) }
                .filter { it.isNotBlank() }
                .toMutableList()
        }.getOrElse { mutableListOf() }
    }

    @Synchronized
    fun writeQueue(context: Context, queue: List<String>) {
        val file = HealthFilePaths.syncQueueFile(context)
        file.parentFile?.mkdirs()
        val unique = LinkedHashSet(queue.filter { it.isNotBlank() })
        val json = JSONArray()
        unique.forEach { json.put(it) }
        file.writeText(json.toString())
    }

    fun enqueue(context: Context, dayKey: String) {
        if (dayKey.isBlank()) return
        val queue = readQueue(context)
        if (!queue.contains(dayKey)) {
            queue.add(dayKey)
            writeQueue(context, queue)
        }
    }

    fun remove(context: Context, dayKey: String) {
        val queue = readQueue(context).filterNot { it == dayKey }
        writeQueue(context, queue)
    }

    fun peek(context: Context): String? = readQueue(context).firstOrNull()
}
