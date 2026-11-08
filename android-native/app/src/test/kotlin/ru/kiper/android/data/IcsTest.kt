package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

class IcsTest {

    private val now = Instant.parse("2026-11-08T12:34:56Z")

    private fun event(id: String, day: LocalDate, name: String = "YouTube"): PaymentEvent {
        val sub = Subscription(
            id = id, name = name, amount = 13.99, currency = Currency.USD,
            billingPeriod = BillingPeriod.MONTHLY,
            nextBillingDate = day, startDate = LocalDate.of(2026, 1, 1),
        )
        return PaymentEvent(sub, day)
    }

    @Test
    fun buildsAllDayEventsWithStableUids() {
        val text = Ics.calendar(listOf(event("yt", LocalDate.of(2026, 12, 1))), now)
        assertTrue(text.startsWith("BEGIN:VCALENDAR\r\nVERSION:2.0"))
        assertTrue(text.endsWith("END:VCALENDAR\r\n"))
        assertTrue(text.contains("UID:yt-20261201@kiper"))
        assertTrue(text.contains("DTSTART;VALUE=DATE:20261201"))
        // DTSTAMP is UTC with a fixed `now`, so the output is deterministic.
        assertTrue(text.contains("DTSTAMP:20261108T123456Z"))
        assertTrue(text.contains("SUMMARY:Списание — YouTube"))
        assertTrue(text.contains("DESCRIPTION:13\\,99\u00A0$ · Ежемесячно")) // RFC-escaped comma
        assertTrue(text.contains("PRODID:-//Kiper//Subscription Calendar//RU"))
        // RFC 5545 requires CRLF — no bare newlines anywhere.
        assertFalse(text.replace("\r\n", "").contains('\n'))
    }

    @Test
    fun oneEventPerCharge() {
        val text = Ics.calendar(
            listOf(
                event("yt", LocalDate.of(2026, 12, 1)),
                event("yt", LocalDate.of(2026, 12, 15)),
            ),
            now,
        )
        assertEquals(2, Regex("BEGIN:VEVENT").findAll(text).count())
        assertTrue(text.contains("UID:yt-20261201@kiper"))
        assertTrue(text.contains("UID:yt-20261215@kiper"))
    }

    @Test
    fun escapingCoversSpecialCharacters() {
        assertEquals("a\\\\b\\;c\\,d\\ne", Ics.escape("a\\b;c,d\ne"))
        val text = Ics.calendar(listOf(event("x;1", LocalDate.of(2026, 12, 1), name = "A,B\\C")), now)
        assertTrue(text.contains("SUMMARY:Списание — A\\,B\\\\C"))
    }
}
