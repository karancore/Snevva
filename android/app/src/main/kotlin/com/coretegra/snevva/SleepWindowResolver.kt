package com.coretegra.snevva

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

data class SleepWindow(
    val dayKey: String,
    val start: LocalDateTime,
    val end: LocalDateTime,
) {
    fun contains(moment: LocalDateTime): Boolean =
        (moment.isEqual(start) || moment.isAfter(start)) && moment.isBefore(end)
}

object SleepWindowResolver {
    private val zoneId: ZoneId = ZoneId.systemDefault()
    private val dayFormatter: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE
    private val hmFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

    fun resolveForTimestamp(
        timestampMillis: Long,
        bedtimeMinutes: Int?,
        waketimeMinutes: Int?,
    ): SleepWindow? {
        if (!isValidMinutes(bedtimeMinutes) || !isValidMinutes(waketimeMinutes)) {
            return null
        }

        val moment = Instant.ofEpochMilli(timestampMillis).atZone(zoneId).toLocalDateTime()
        return resolveForMoment(moment, bedtimeMinutes!!, waketimeMinutes!!)
    }

    fun resolveForDayKey(
        dayKey: String,
        bedtimeMinutes: Int?,
        waketimeMinutes: Int?,
    ): SleepWindow? {
        if (!isValidMinutes(bedtimeMinutes) || !isValidMinutes(waketimeMinutes)) {
            return null
        }

        val date = runCatching { LocalDate.parse(dayKey, dayFormatter) }.getOrNull() ?: return null
        val bedtime = LocalTime.of(bedtimeMinutes!! / 60, bedtimeMinutes % 60)
        val waketime = LocalTime.of(waketimeMinutes!! / 60, waketimeMinutes % 60)
        val start = LocalDateTime.of(date, bedtime)
        val end = LocalDateTime.of(date, waketime).let { candidate ->
            if (candidate.isAfter(start)) candidate else candidate.plusDays(1)
        }

        return SleepWindow(dayKey = dayFormatter.format(date), start = start, end = end)
    }

    fun formatDayKey(date: LocalDate): String = dayFormatter.format(date)

    fun formatClock(minutes: Int?): String? {
        if (!isValidMinutes(minutes)) return null
        return hmFormatter.format(LocalTime.of(minutes!! / 60, minutes % 60))
    }

    fun toEpochMillis(value: LocalDateTime): Long =
        value.atZone(zoneId).toInstant().toEpochMilli()

    private fun resolveForMoment(
        moment: LocalDateTime,
        bedtimeMinutes: Int,
        waketimeMinutes: Int,
    ): SleepWindow? {
        val bedtime = LocalTime.of(bedtimeMinutes / 60, bedtimeMinutes % 60)
        val waketime = LocalTime.of(waketimeMinutes / 60, waketimeMinutes % 60)
        val crossesMidnight = waketimeMinutes <= bedtimeMinutes

        val startDate = when {
            !crossesMidnight && moment.toLocalTime().isBefore(bedtime) -> moment.toLocalDate()
                .minusDays(1)

            !crossesMidnight -> moment.toLocalDate()
            moment.toLocalTime().isBefore(waketime) -> moment.toLocalDate().minusDays(1)
            else -> moment.toLocalDate()
        }

        val start = LocalDateTime.of(startDate, bedtime)
        val end = LocalDateTime.of(startDate, waketime).let { candidate ->
            if (candidate.isAfter(start)) candidate else candidate.plusDays(1)
        }
        val window = SleepWindow(dayKey = dayFormatter.format(startDate), start = start, end = end)

        return if (window.contains(moment)) window else null
    }

    private fun isValidMinutes(value: Int?): Boolean = value != null && value in 0 until (24 * 60)
}
