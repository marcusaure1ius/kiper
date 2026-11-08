package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ScheduleTest {

    private val now = LocalDate.of(2026, 11, 8)

    private fun sub(
        start: LocalDate,
        next: LocalDate = start,
        period: BillingPeriod = BillingPeriod.MONTHLY,
        customDays: Int? = null,
    ): Subscription = Subscription(
        id = "t", name = "T", amount = 100.0, currency = Currency.RUB,
        billingPeriod = period, customPeriodDays = customDays,
        nextBillingDate = next, startDate = start,
    )

    /** Monthly on the 31st stays monthly-correct: Jan 31 → Feb 28 → Mar 31. */
    @Test
    fun monthlyAnchorKeepsDayOfGrid() {
        val s = sub(LocalDate.of(2024, 1, 31))
        assertEquals(LocalDate.of(2024, 2, 29), Schedule.step(LocalDate.of(2024, 1, 31), BillingPeriod.MONTHLY, null, 1))
        assertEquals(LocalDate.of(2024, 3, 31), Schedule.step(LocalDate.of(2024, 1, 31), BillingPeriod.MONTHLY, null, 2))
        assertEquals(LocalDate.of(2024, 1, 31), Schedule.anchor(s))
    }

    /** Anchor falls back to nextBillingDate when it is off the start grid. */
    @Test
    fun anchorOffGridUsesNextDate() {
        val s = sub(start = LocalDate.of(2024, 1, 15), next = LocalDate.of(2024, 3, 20))
        assertEquals(LocalDate.of(2024, 3, 20), Schedule.anchor(s))
    }

    /** History goes back to startDate; nothing between today and nextBillingDate. */
    @Test
    fun datesSkipsTodayToNextWindow() {
        val start = now.minusMonths(2) // 2026-09-08, on the grid
        val next = LocalDate.of(2026, 12, 8) // also on the grid
        val s = sub(start = start, next = next)
        val dates = Schedule.dates(s, start, next.plusDays(10), now)
        // All past grid days present…
        assertTrue(dates.contains(start))
        assertTrue(dates.contains(start.plusMonths(1)))
        // …today and the in-between window (today → next) are empty…
        assertTrue(dates.none { it >= now && it < next })
        // …and the future starts exactly at nextBillingDate.
        assertTrue(dates.contains(next))
    }

    @Test
    fun firstChargeRollsForward() {
        val s = sub(start = LocalDate.of(2024, 1, 31))
        val rolled = Schedule.firstCharge(s, LocalDate.of(2024, 2, 15))
        assertEquals(LocalDate.of(2024, 2, 29), rolled)
    }

    @Test
    fun upcomingStartsAtNext() {
        val s = sub(start = now.minusMonths(1), next = LocalDate.of(2026, 11, 20))
        val upcoming = Schedule.upcoming(s, 3)
        assertEquals(listOf(LocalDate.of(2026, 11, 20), LocalDate.of(2026, 12, 20), LocalDate.of(2027, 1, 20)), upcoming)
    }

    @Test
    fun customPeriodStepsDays() {
        // Grid: start is 90 days back, so `now` lies on it and is the next charge.
        val s = sub(start = now.minusDays(90), next = now, period = BillingPeriod.CUSTOM, customDays = 45)
        val dates = Schedule.upcoming(s, 3)
        assertEquals(now, dates[0])
        assertEquals(now.plusDays(45), dates[1])
        assertEquals(now.plusDays(90), dates[2])
    }
}
