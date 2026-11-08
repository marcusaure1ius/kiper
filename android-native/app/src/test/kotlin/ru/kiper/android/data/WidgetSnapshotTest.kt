package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test
import java.nio.file.Files
import java.time.Instant
import java.time.LocalDate

class WidgetSnapshotTest {

    private fun sample(): WidgetSnapshot = WidgetSnapshot(
        upcoming = listOf(
            WidgetSnapshot.Charge("Netflix", "netflix.com", "2026-11-20T00:00:00", 22.99, "USD"),
            WidgetSnapshot.Charge("МТС", null, "2026-11-25T00:00:00", 890.0, "RUB"),
        ),
        monthlyTotalRub = 3400.0,
        paidRub = 500.0,
        remainingRub = 2900.0,
        budgetRub = 12000.0,
        accentHexLight = 0x6A5CF1,
        accentHexDark = 0x8F84FF,
        generatedAt = "2026-11-08T10:00:00Z",
    )

    @Test
    fun storeLoadRoundTrip() {
        val dir = Files.createTempDirectory("kiper-widget").toFile()
        WidgetSnapshot.store(dir, sample())
        val loaded = WidgetSnapshot.load(dir)!!
        assertEquals(2, loaded.upcoming.size)
        assertEquals("Netflix", loaded.upcoming[0].name)
        assertEquals("netflix.com", loaded.upcoming[0].domain)
        assertEquals(3400.0, loaded.monthlyTotalRub, 1e-9)
        assertEquals(12000.0, loaded.budgetRub!!, 1e-9)
        assertEquals(0x6A5CF1, loaded.accentHexLight)
        assertEquals(0x8F84FF, loaded.accentHexDark)
        assertEquals("2026-11-08T10:00:00Z", loaded.generatedAt)
    }

    @Test
    fun corruptFileLoadsAsNull() {
        val dir = Files.createTempDirectory("kiper-widget").toFile()
        java.io.File(dir, WidgetSnapshot.FILE_NAME).writeText("{broken")
        assertNull(WidgetSnapshot.load(dir))
    }

    @Test
    fun nullDirectoryIsANoOp() {
        // Widgets run without a directory in tests; store must not crash.
        WidgetSnapshot.store(null, sample())
    }

    @Test
    fun chargeDateKeepsOnlyTheDay() {
        val charge = WidgetSnapshot.Charge("x", null, "2026-11-20T00:00:00", 1.0, "RUB")
        assertEquals(LocalDate.of(2026, 11, 20), charge.localDate)
    }

    @Test
    fun instantHelpersAreTolerant() {
        assertEquals(Instant.EPOCH, WidgetSnapshot.toInstant("мусор"))
        assertEquals(Instant.parse("2026-11-08T10:00:00Z"), WidgetSnapshot.toInstant("2026-11-08T10:00:00Z"))
        assertEquals("2026-11-08T00:00:00", WidgetSnapshot.isoOf(LocalDate.of(2026, 11, 8)))
        assertFalse(WidgetSnapshot.nowIso().isNullOrEmpty())
    }
}
