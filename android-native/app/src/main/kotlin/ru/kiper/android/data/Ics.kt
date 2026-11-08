package ru.kiper.android.data

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * iCalendar (RFC 5545) export of the upcoming charge schedule, so it can live
 * in Google Calendar or any other calendar app. All-day VEVENTs, one per charge.
 */
object Ics {

    private val DAY: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd")
    private val UTC_STAMP: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'")

    /** Pure builder (unit-tested): one all-day VEVENT per given future charge. */
    fun calendar(events: List<PaymentEvent>, now: Instant = Instant.now()): String {
        val lines = mutableListOf(
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Kiper//Subscription Calendar//RU",
            "CALSCALE:GREGORIAN",
        )
        val stamp = now.atOffset(ZoneOffset.UTC).format(UTC_STAMP)
        for (event in events) {
            val sub = event.subscription
            val day = event.date.format(DAY)
            lines += listOf(
                "BEGIN:VEVENT",
                "UID:${sub.id}-$day@kiper",
                "DTSTAMP:$stamp",
                "DTSTART;VALUE=DATE:$day",
                "SUMMARY:${escape("Списание — ${sub.name}")}",
                "DESCRIPTION:${escape("${Fmt.money(sub.amount, sub.currency)} · ${sub.billingPeriod.label}")}",
                "END:VEVENT",
            )
        }
        lines.add("END:VCALENDAR")
        return lines.joinToString("\r\n") + "\r\n"
    }

    /** RFC 5545 §3.3.11: backslash, semicolon, comma and newlines are escaped. */
    fun escape(text: String): String = text
        .replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\n", "\\n")
}
