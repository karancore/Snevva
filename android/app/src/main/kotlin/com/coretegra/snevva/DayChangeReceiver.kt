package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.time.LocalDate

class DayChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("DayChangeReceiver", "Handling day-change flush")

        val yesterday = SleepWindowResolver.formatDayKey(LocalDate.now().minusDays(1))
        BufferManager.flushAll(context)
        SyncQueueStore.enqueue(context, yesterday)
        MetaStore.ensureCurrentDay(context)
        AlarmHelper.scheduleNextDayChange(context)
        SyncManager.processQueue(context)
    }
}
