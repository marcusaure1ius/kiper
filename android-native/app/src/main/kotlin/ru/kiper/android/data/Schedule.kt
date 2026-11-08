package ru.kiper.android.data

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Billing schedule of a subscription — one place for history, upcoming charges,
 * date advancing and reminders.
 *
 * Dates are always `anchor + n × period` (never stepped one by one), so a monthly
 * charge on the 31st stays on the 31st (Jan 31 → Feb 28 → Mar 31). The anchor is
 * `startDate` when `nextBillingDate` lies on its grid, otherwise `nextBillingDate`.
 * `LocalDate.plusMonths` clamps like Foundation's `Calendar` (Jan 31 → Feb 28/29),
 * so the arithmetic is identical to `Schedule.swift`.
 */
object Schedule {

    fun step(base: LocalDate, period: BillingPeriod, customDays: Int?, n: Int): LocalDate =
        when (period) {
            BillingPeriod.WEEKLY -> base.plusDays((7L * n))
            BillingPeriod.MONTHLY -> base.plusMonths(n.toLong())
            BillingPeriod.QUARTERLY -> base.plusMonths(3L * n)
            BillingPeriod.SEMIANNUAL -> base.plusMonths(6L * n)
            BillingPeriod.ANNUAL -> base.plusYears(n.toLong())
            BillingPeriod.CUSTOM -> base.plusDays(maxOf(customDays ?: 30, 1).toLong() * n)
        }

    private fun step(sub: Subscription, base: LocalDate, n: Int): LocalDate =
        step(base, sub.billingPeriod, sub.customPeriodDays, n)

    fun anchor(of: Subscription): LocalDate {
        val next = of.nextBillingDate
        if (of.startDate > next) return next
        for (n in 0 until 10_000) {
            val day = step(of, of.startDate, n)
            if (day == next) return of.startDate
            if (day > next) break
        }
        return next
    }

    /**
     * Charges in `[from, to)`: history goes back to `startDate`; nothing between today
     * and `nextBillingDate`; future charges start exactly at `nextBillingDate`.
     */
    fun dates(of: Subscription, from: LocalDate, to: LocalDate, now: LocalDate = LocalDate.now()): List<LocalDate> {
        val base = anchor(of)
        val lower = maxOf(from, of.startDate)
        val today = now
        val next = of.nextBillingDate
        var n = 0
        while (n > -10_000 && step(of, base, n - 1) >= lower) n -= 1
        val result = ArrayList<LocalDate>()
        while (n < 10_000) {
            val date = step(of, base, n)
            if (date >= to) break
            if (date >= lower && !(date >= today && date < next)) result.add(date)
            n += 1
        }
        return result
    }

    /** First grid date on or after `day` (used to roll a past `nextBillingDate` forward). */
    fun firstCharge(of: Subscription, onOrAfter: LocalDate): LocalDate {
        val base = anchor(of)
        for (n in 0 until 10_000) {
            val date = step(of, base, n)
            if (date >= onOrAfter) return date
        }
        return of.nextBillingDate
    }

    /** `nextBillingDate` and the following `count - 1` charges. */
    fun upcoming(of: Subscription, count: Int): List<LocalDate> {
        val base = anchor(of)
        val next = of.nextBillingDate
        val result = ArrayList<LocalDate>()
        var n = 0
        while (result.size < count && n < 10_000) {
            val date = step(of, base, n)
            if (date >= next) result.add(date)
            n += 1
        }
        return result
    }

    fun daysBetween(from: LocalDate, to: LocalDate): Int =
        ChronoUnit.DAYS.between(from, to).toInt()
}
