package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class StatementImportTest {

    /** Three monthly charges of the same merchant + noise rows. */
    private val statement = listOf(
        "01.10.2026;Оплата;ООО ЯНДЕКС.ТАКСИ (CARD 4111 **** 1234);-799,00",
        "05.10.2026;Покупка;Кофейня Утро;350,00",
        "31.10.2026;Оплата;ООО ЯНДЕКС.ТАКСИ (CARD 4111 **** 1234);-799,00",
        "12.10.2026;Покупка;Пятерочка;1 234,56",
        "30.11.2026;Оплата;ООО ЯНДЕКС.ТАКСИ (CARD 4111 **** 1234);-799,00",
        "13.10.2026;Покупка;Кофейня Утро;340,00",
    ).let { rows -> listOf("Дата;Операция;Описание;Сумма") + rows }.joinToString("\n")

    @Test
    fun detectsMonthlyRecurring() {
        val candidates = StatementImporter.parse(statement)
        assertEquals(1, candidates.size)
        val c = candidates.first()
        // The display name keeps the raw merchant (like the iOS app); the id is normalized.
        assertEquals("ООО ЯНДЕКС.ТАКСИ (CARD 4111 **** 1234)", c.name)
        assertEquals("ЯНДЕКС.ТАКСИ", c.id)
        assertEquals(3, c.occurrences.size)
        assertEquals(799.0, c.medianAmount, 0.01)
        assertEquals(30, c.medianIntervalDays)
        assertEquals(BillingPeriod.MONTHLY, c.billingPeriod.first)
    }

    @Test
    fun nextChargeRollsPastDatesForward() {
        val c = StatementCandidate(
            id = "x", name = "X",
            occurrences = listOf(
                StatementOccurrence(LocalDate.of(2026, 8, 1), 100.0),
                StatementOccurrence(LocalDate.of(2026, 9, 1), 100.0),
                StatementOccurrence(LocalDate.of(2026, 10, 1), 100.0),
            ),
            medianAmount = 100.0, medianIntervalDays = 30,
        )
        assertEquals(LocalDate.of(2026, 12, 1), c.nextCharge(LocalDate.of(2026, 11, 25)))
        assertEquals(LocalDate.of(2026, 11, 1), c.nextCharge(LocalDate.of(2026, 10, 15)))
    }

    @Test
    fun twoOccurrencesAreNotEnough() {
        val text = listOf(
            "Дата;Описание;Сумма",
            "01.10.2026;ООО ЯНДЕКС.ТАКСИ;799,00",
            "31.10.2026;ООО ЯНДЕКС.ТАКСИ;799,00",
        ).joinToString("\n")
        assertTrue(StatementImporter.parse(text).isEmpty())
    }

    @Test
    fun priceSpikeDisqualifies() {
        val text = listOf(
            "Дата;Описание;Сумма",
            "01.08.2026;Музыка Плюс;299,00",
            "01.09.2026;Музыка Плюс;299,00",
            "01.10.2026;Музыка Плюс;2990,00",
        ).joinToString("\n")
        assertTrue(StatementImporter.parse(text).isEmpty())
    }

    @Test
    fun normalizeStripsNoise() {
        assertEquals("ЯНДЕКС.ТАКСИ", StatementImporter.normalize("ООО ЯНДЕКС.ТАКСИ (CARD 4111 **** 1234)"))
        assertEquals("NETFLIX.COM", StatementImporter.normalize("NETFLIX.COM 866-579-7172 ONLINE"))
        assertTrue(StatementImporter.normalize("   ").isEmpty())
    }

    @Test
    fun numberParsing() {
        assertEquals(799.0, StatementImporter.number("-799,00")!!, 1e-9)
        assertEquals(1234.56, StatementImporter.number("1 234,56 ₽")!!, 1e-9)
        assertEquals(1234.56, StatementImporter.number("(1234.56)")!!, 1e-9)
        assertEquals(1500.0, StatementImporter.number("1,500.00")!!, 1e-9)
        assertNull(StatementImporter.number("0,00"))
        assertNull(StatementImporter.number("—"))
    }

    @Test
    fun dateParsingFormats() {
        assertEquals(LocalDate.of(2026, 11, 8), StatementImporter.date("08.11.2026"))
        assertEquals(LocalDate.of(2026, 11, 8), StatementImporter.date("08.11.2026 12:30:00"))
        assertEquals(LocalDate.of(2026, 11, 8), StatementImporter.date("2026-11-08"))
        assertEquals(LocalDate.of(2026, 11, 8), StatementImporter.date("2026-11-08 12:30:00"))
        assertNull(StatementImporter.date("не дата"))
    }

    @Test
    fun delimiterSniffing() {
        val semicolon = "a;b\nc;d"
        val rows = StatementImporter.split(semicolon, ';')
        assertEquals(2, rows.size)
        assertEquals(listOf("a", "b"), rows[0])
        assertNotNull(StatementImporter.parse("x"))
    }
}
