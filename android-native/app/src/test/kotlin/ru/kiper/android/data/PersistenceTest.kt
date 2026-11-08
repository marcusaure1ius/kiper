package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.time.LocalDate

class PersistenceTest {

    private fun tempPersistence(): Pair<Persistence, File> {
        val dir = Files.createTempDirectory("kiper-persistence").toFile()
        return Persistence(File(dir, "kiper.json")) to dir
    }

    private fun sampleFile(): BackupFile {
        val sub = Subscription(
            id = "s-1", name = "Netflix", amount = 499.0, currency = Currency.RUB,
            billingPeriod = BillingPeriod.MONTHLY,
            nextBillingDate = LocalDate.of(2026, 12, 1), startDate = LocalDate.of(2026, 1, 1),
        )
        return BackupFile(
            exportedAt = "2026-11-08T10:00:00.000",
            subscriptions = listOf(BackupMapper.dto(sub)),
            settings = mapOf("budgetRub" to "12000"),
        )
    }

    @Test
    fun missingFileMeansFirstLaunch() {
        val (persistence, _) = tempPersistence()
        assertNull(persistence.load())
    }

    @Test
    fun saveLoadRoundTrip() {
        val (persistence, dir) = tempPersistence()
        persistence.save(sampleFile())
        val loaded = persistence.load()!!
        assertEquals("2026-11-08T10:00:00.000", loaded.exportedAt)
        assertEquals(1, loaded.subscriptions.size)
        assertEquals("s-1", loaded.subscriptions[0].id)
        assertEquals("12000", loaded.settings["budgetRub"])
        // The atomic write leaves nothing behind.
        assertFalse(File(dir, "kiper.json.tmp").exists())
        assertEquals(listOf("kiper.json"), dir.listFiles()!!.map { it.name })
    }

    @Test
    fun corruptFileThrows() {
        val (persistence, dir) = tempPersistence()
        File(dir, "kiper.json").writeText("это не json")
        try {
            persistence.load()
            throw AssertionError("must throw on a broken file")
        } catch (_: BackupException) {
            // expected
        }
    }

    @Test
    fun quarantineMovesBrokenFileAside() {
        val (persistence, dir) = tempPersistence()
        File(dir, "kiper.json").writeText("{broken")
        val aside = persistence.quarantine()
        assertTrue(aside.name.startsWith("kiper.broken-"))
        assertTrue(aside.exists())
        assertFalse(File(dir, "kiper.json").exists())
        assertNull(persistence.load()) // back to "first launch"
    }
}
