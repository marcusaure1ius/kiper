package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

class ExchangeRatesTest {

    /** CBR-shaped feed: comma decimals, Nominal rows, currencies we don't track. */
    private val feed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ValCurs Date="08.11.2026" name="Foreign Currency Market">
    <Valute ID="R01235"><NumCode>840</NumCode><CharCode>USD</CharCode><Nominal>1</Nominal><Name>Доллар США</Name><Value>81,7186</Value></Valute>
    <Valute ID="R01239"><NumCode>978</NumCode><CharCode>EUR</CharCode><Nominal>1</Nominal><Name>Евро</Name><Value>94,8810</Value></Valute>
    <Valute ID="R01350"><NumCode>398</NumCode><CharCode>KZT</CharCode><Nominal>100</Nominal><Name>Тенге</Name><Value>17,1172</Value></Valute>
    <Valute ID="R01700"><NumCode>949</NumCode><CharCode>TRY</CharCode><Nominal>10</Nominal><Name>Турецкая лира</Name><Value>2,40105</Value></Valute>
    </ValCurs>
    """.trimIndent()

    @Test
    fun parsesDecimalCommaAndFiltersUnwanted() {
        val parsed = ExchangeRates.parse(feed.toByteArray())
        assertEquals(LocalDate.of(2026, 11, 8), parsed.date)
        // Only currencies the app knows survive the filter; КZT/TRY are dropped.
        assertEquals(setOf("USD", "EUR"), parsed.rates.keys)
        assertEquals(81.7186, parsed.rates["USD"]!!, 1e-9)
        assertEquals(94.881, parsed.rates["EUR"]!!, 1e-9)
    }

    @Test
    fun dividesByNominal() {
        // A currency quoted per several units must divide, or the rate is wildly wrong.
        val xml = """
        <ValCurs Date="08.11.2026">
        <Valute><CharCode>USD</CharCode><Nominal>2</Nominal><Value>163,4372</Value></Valute>
        <Valute><CharCode>EUR</CharCode><Nominal>100</Nominal><Value>9488,10</Value></Valute>
        </ValCurs>
        """.trimIndent()
        val parsed = ExchangeRates.parse(xml.toByteArray())
        assertEquals(81.7186, parsed.rates["USD"]!!, 1e-9)
        assertEquals(94.881, parsed.rates["EUR"]!!, 1e-9)
    }

    @Test
    fun skipsBrokenRowsAndDefaultsNominal() {
        val xml = """
        <ValCurs Date="08.11.2026">
        <Valute><CharCode>USD</CharCode><Nominal>0</Nominal><Value>81,7186</Value></Valute>
        <Valute><CharCode>USD</CharCode><Value>не число</Value></Valute>
        <Valute><CharCode>USD</CharCode><Value>82,5</Value></Valute>
        <Valute><CharCode>EUR</CharCode><Value>95,0</Value></Valute>
        </ValCurs>
        """.trimIndent()
        val parsed = ExchangeRates.parse(xml.toByteArray())
        // Nominal 0 and a garbage value are skipped; a missing Nominal means 1.
        assertEquals(82.5, parsed.rates["USD"]!!, 1e-9)
        assertEquals(95.0, parsed.rates["EUR"]!!, 1e-9)
    }

    @Test
    fun quoteDateIsTolerant() {
        assertTrue(ExchangeRates.parse("<ValCurs><Valute><CharCode>USD</CharCode><Value>1,0</Value></Valute></ValCurs>".toByteArray()).date == null)
        assertTrue(ExchangeRates.parse("<ValCurs Date=\"не дата\"></ValCurs>".toByteArray()).date == null)
    }

    @Test
    fun snapshotRateFallsBackLikeTheContract() {
        // RUB is always 1; a live snapshot wins; missing currencies use the
        // documented fallback (USD 90 / EUR 98).
        assertEquals(1.0, RateSnapshot.fallback.rate(Currency.RUB), 1e-9)
        assertEquals(90.0, RateSnapshot.fallback.rate(Currency.USD), 1e-9)
        assertEquals(98.0, RateSnapshot.fallback.rate(Currency.EUR), 1e-9)
        val live = RateSnapshot(rates = mapOf("USD" to 95.0), isFallback = false)
        assertEquals(95.0, live.rate(Currency.USD), 1e-9)
        assertEquals(98.0, live.rate(Currency.EUR), 1e-9)
    }

    @Test
    fun cacheRoundTripAndCorruptRecovery() {
        val snapshot = RateSnapshot(
            rates = mapOf("USD" to 91.5, "EUR" to 99.5),
            quoteDate = "2026-11-08",
            fetchedAt = "2026-11-08T12:00:00Z",
            isFallback = false,
        )
        val stored = ExchangeRates.store(snapshot)
        val restored = ExchangeRates.cached(stored)
        assertEquals(91.5, restored.rates["USD"]!!, 1e-9)
        assertEquals("2026-11-08", restored.quoteDate)
        assertEquals(false, restored.isFallback)
        // Anything unreadable degrades to the fallback, never to a crash.
        assertEquals(true, ExchangeRates.cached(null).isFallback)
        assertEquals(true, ExchangeRates.cached("  ").isFallback)
        assertEquals(true, ExchangeRates.cached("{broken json").isFallback)
    }

    @Test
    fun badTimestampBecomesEpoch() {
        assertEquals(Instant.EPOCH, RateSnapshot(fetchedAt = "мусор").fetchedAtTime)
        assertEquals(Instant.parse("2026-11-08T12:00:00Z"), RateSnapshot(fetchedAt = "2026-11-08T12:00:00Z").fetchedAtTime)
    }
}
