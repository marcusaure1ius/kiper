package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class AppStoreTest {

    private val now = LocalDate.of(2026, 11, 8)

    private fun store(): AppStore = AppStore(
        persistence = null, // keep everything in memory (like iOS previews/tests)
        prefs = null,
        filesDir = null,
        seedDemoData = false,
    )

    private fun sub(id: String, next: LocalDate, period: BillingPeriod = BillingPeriod.MONTHLY): Subscription =
        Subscription(
            id = id, name = "S$id", amount = 1000.0, currency = Currency.RUB,
            billingPeriod = period, nextBillingDate = next,
            startDate = LocalDate.of(2026, 1, 10),
        )

    @Test
    fun firstLaunchSeedsCategories() {
        val s = store()
        assertEquals(SeedData.categories.size, s.categories.size)
        assertEquals(0, s.subscriptions.size)
    }

    @Test
    fun advanceRollsPastDatesAndBackfills() {
        val s = store()
        val past = LocalDate.of(2026, 10, 10) // ~3 monthly charges behind (grid from Jan 10)
        s.upsert(sub("a", past))
        val rolled = s.subscription("a")!!
        assertEquals(LocalDate.of(2026, 11, 10), rolled.nextBillingDate)
        // Missed charges were recorded (Jan 10 … Oct 10 → but only dates >= start and < today).
        val records = s.payments.filter { it.subscriptionId == "a" }
        assertTrue(records.isNotEmpty())
        assertTrue(records.all { it.source == PaymentRecord.Source.AUTO })
        assertTrue(records.none { it.date > LocalDate.of(2026, 10, 10) })
    }

    @Test
    fun markPaidAndSkipAffectMonthProgress() {
        val s = store()
        // Charge yesterday: the auto record counts as paid.
        val sub = sub("b", now.minusDays(1))
        s.upsert(sub)
        val paidBefore = s.monthProgress(now).first
        assertEquals(1000.0, paidBefore, 0.01)
        assertEquals(0.0, s.monthProgress(now).second, 0.01)

        // A manual mark re-records with today's price (manual wins over auto).
        s.markPaid(s.subscription("b")!!, now.minusDays(1))
        assertEquals(1000.0, s.monthProgress(now).first, 0.01)

        // Skipping stops counting it anywhere.
        s.skip(s.subscription("b")!!, now.minusDays(1))
        assertEquals(0.0, s.monthProgress(now).first, 0.01)
    }

    @Test
    fun skipStopsCounting() {
        val s = store()
        val sub = sub("c", now.minusDays(5))
        s.upsert(sub)
        val paidBefore = s.monthProgress(now).first
        assertEquals(1000.0, paidBefore, 0.01) // auto-recorded
        s.skip(s.subscription("c")!!, now.minusDays(5))
        assertEquals(0.0, s.monthProgress(now).first, 0.01)
    }

    @Test
    fun endTrialActivatesOnFirstCharge() {
        val s = store()
        val trial = Subscription(
            id = "t", name = "T", amount = 500.0, currency = Currency.RUB,
            billingPeriod = BillingPeriod.MONTHLY,
            nextBillingDate = LocalDate.of(2026, 11, 15),
            status = SubscriptionStatus.TRIAL,
            trialEndDate = LocalDate.of(2026, 11, 15),
            startDate = LocalDate.of(2026, 11, 15),
        )
        s.upsert(trial)
        s.endTrial("t")
        val after = s.subscription("t")!!
        assertEquals(SubscriptionStatus.ACTIVE, after.status)
        assertEquals(null, after.trialEndDate)
        assertEquals(LocalDate.of(2026, 11, 15), after.startDate)
    }

    @Test
    fun trialEndsWhileAway() {
        val s = store()
        val trial = Subscription(
            id = "t2", name = "T2", amount = 500.0, currency = Currency.RUB,
            billingPeriod = BillingPeriod.MONTHLY,
            nextBillingDate = LocalDate.of(2026, 11, 1),
            status = SubscriptionStatus.TRIAL,
            trialEndDate = LocalDate.of(2026, 11, 1),
            startDate = LocalDate.of(2026, 11, 1),
        )
        s.upsert(trial)
        // Construction already ran advanceBillingDates for "today" (real today),
        // so simulate explicitly:
        s.advanceBillingDates(LocalDate.of(2026, 11, 8))
        val after = s.subscription("t2")!!
        assertEquals(SubscriptionStatus.ACTIVE, after.status)
    }

    @Test
    fun backupImportReplaceAndMerge() {
        val s = store()
        s.upsert(sub("a", now.plusDays(3)))
        val backup = s.backup(now)
        assertEquals(1, backup.subscriptions.size)

        val target = store()
        // MERGE adds.
        val merge = target.importBackup(backup, AppStore.ImportMode.MERGE)
        assertEquals(1, merge.subscriptions)
        assertEquals(1, target.subscriptions.size)
        // REPLACE resets to exactly the file.
        target.upsert(sub("extra", now.plusDays(1)))
        target.importBackup(backup, AppStore.ImportMode.REPLACE)
        assertEquals(1, target.subscriptions.size)
    }

    @Test
    fun budgetTravelsWithBackup() {
        val s = store()
        s.monthlyBudgetRub = 12000.0
        val file = s.backup(now)
        assertEquals("12000.0", file.settings["budgetRub"])
        val target = store()
        target.importBackup(file, AppStore.ImportMode.REPLACE)
        assertEquals(12000.0, target.monthlyBudgetRub!!, 0.01)
    }

    @Test
    fun csvImportMergesById() {
        val s = store()
        s.upsert(sub("csv-key", now.plusDays(2)))
        val csv = CsvCodec.encode(listOf(sub("csv-key", now.plusDays(9))))
        s.importCsv(csv)
        assertEquals(LocalDate.of(2026, 11, 17), s.subscription("csv-key")!!.nextBillingDate)
        assertEquals(1, s.subscriptions.size)
    }

    @Test
    fun duplicateGroupsByDomain() {
        val s = store()
        s.upsert(sub("d1", now.plusDays(1)).also { it.domain = "netflix.com" })
        s.upsert(sub("d2", now.plusDays(2)).also { it.domain = "netflix.com" })
        val groups = s.duplicateGroups()
        assertEquals(1, groups.size)
        assertEquals(2, groups[0].size)
    }

    @Test
    fun cancelIsSoft() {
        val s = store()
        s.upsert(sub("x", now.plusDays(1)))
        s.cancel("x")
        assertEquals(SubscriptionStatus.CANCELLED, s.subscription("x")!!.status)
        assertEquals(0, s.active.size)
        assertEquals(0, s.notCancelled.size)
        // Cancelled rows keep analytics history.
        assertNotNull(s.subscription("x"))
    }

    @Test
    fun monthlyTotalUsesEquivalent() {
        val s = store()
        s.upsert(sub("m", now.plusDays(1)))
        s.upsert(sub("y", now.plusDays(1), BillingPeriod.ANNUAL))
        // 1000 ₽/мес + 1000 ₽/год = 1000 + 83.33
        assertEquals(1000.0 + 1000.0 / 12.0, s.monthlyTotalRub, 0.01)
    }
}
