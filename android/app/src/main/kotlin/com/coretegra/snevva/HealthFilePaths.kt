package com.coretegra.snevva

import android.content.Context
import java.io.File

object HealthFilePaths {
    fun bufferDirectory(context: Context): File =
        File(context.filesDir, "buffer").apply { mkdirs() }

    fun dailyDirectory(context: Context): File =
        File(context.filesDir, "daily").apply { mkdirs() }

    fun stepBufferFile(context: Context): File =
        File(bufferDirectory(context), "steps_buf.tmp")

    fun sleepBufferFile(context: Context): File =
        File(bufferDirectory(context), "sleep_buf.tmp")

    fun syncQueueFile(context: Context): File =
        File(context.filesDir, "sync_queue.json")

    fun metaFile(context: Context): File =
        File(context.filesDir, "meta.json")

    fun dailyFile(context: Context, dayKey: String): File =
        File(dailyDirectory(context), "$dayKey.json")
}
