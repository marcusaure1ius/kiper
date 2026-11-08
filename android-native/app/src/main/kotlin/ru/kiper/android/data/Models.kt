package ru.kiper.android.data

import java.time.LocalDate
import java.util.UUID

/** Raw values match the strings used in backup files across platforms. */
enum class Currency(val code: String) {
    RUB("RUB"), USD("USD"), EUR("EUR");

    val symbol: String
        get() = when (this) {
            RUB -> "₽"; USD -> "$"; EUR -> "€"
        }

    companion object {
        fun of(value: String): Currency = entries.firstOrNull { it.code == value.uppercase() } ?: RUB
    }
}

/** Raw values match the strings used in backup files across platforms. */
enum class BillingPeriod(val raw: String) {
    WEEKLY("weekly"), MONTHLY("monthly"), QUARTERLY("quarterly"),
    SEMIANNUAL("semiannual"), ANNUAL("annual"), CUSTOM("custom");

    /** Multiplier bringing the period to a month (52/12 weeks, 1/12 year…). */
    val monthlyEquivalent: Double
        get() = when (this) {
            WEEKLY -> 52.0 / 12.0
            MONTHLY -> 1.0
            QUARTERLY -> 1.0 / 3.0
            SEMIANNUAL -> 1.0 / 6.0
            ANNUAL -> 1.0 / 12.0
            CUSTOM -> 1.0
        }

    val label: String
        get() = when (this) {
            WEEKLY -> "Еженедельно"
            MONTHLY -> "Ежемесячно"
            QUARTERLY -> "Раз в квартал"
            SEMIANNUAL -> "Раз в полгода"
            ANNUAL -> "Ежегодно"
            CUSTOM -> "Свой период"
        }

    fun next(after: LocalDate, customDays: Int? = null): LocalDate = when (this) {
        WEEKLY -> after.plusDays(7)
        MONTHLY -> after.plusMonths(1)
        QUARTERLY -> after.plusMonths(3)
        SEMIANNUAL -> after.plusMonths(6)
        ANNUAL -> after.plusYears(1)
        CUSTOM -> after.plusDays(maxOf(customDays ?: 30, 1).toLong())
    }

    companion object {
        fun of(raw: String?): BillingPeriod = entries.firstOrNull { it.raw == raw } ?: MONTHLY
    }
}

enum class SubscriptionStatus(val raw: String) {
    ACTIVE("active"), TRIAL("trial"), PAUSED("paused"), CANCELLED("cancelled");

    val label: String
        get() = when (this) {
            ACTIVE -> "Активна"; TRIAL -> "Триал"; PAUSED -> "Приостановлена"; CANCELLED -> "Отменена"
        }

    companion object {
        fun of(raw: String?): SubscriptionStatus = entries.firstOrNull { it.raw == raw } ?: ACTIVE
    }
}

class Category(
    val id: String,
    var name: String,
    /** 0xRRGGBB. Stored as ARGB int in backups, like the Android app. */
    var colorHex: Int,
    /** SF Symbol name (cross-platform storage); rendered via [IconMap]. */
    var symbol: String,
)

class Subscription(
    val id: String,
    var name: String,
    var amount: Double,
    var currency: Currency,
    var billingPeriod: BillingPeriod,
    var customPeriodDays: Int? = null,
    var categoryId: String? = null,
    var nextBillingDate: LocalDate,
    var reminderDaysBefore: Int = 1,
    var status: SubscriptionStatus = SubscriptionStatus.ACTIVE,
    /** When the free period ends (status == TRIAL); the first charge follows it. */
    var trialEndDate: LocalDate? = null,
    var startDate: LocalDate,
    var note: String? = null,
    /** Domain used to fetch a favicon (same source as the Android catalog). */
    var domain: String? = null,
    var createdAt: LocalDate = LocalDate.now(),
    /** Catalog icon name from the Android app (kept for round-trip compatibility). */
    var icon: String? = null,
) {
    val logoUrl: String?
        get() = domain?.let { "https://www.google.com/s2/favicons?domain=$it&sz=128" }
}

class PaymentEvent(
    val subscription: Subscription,
    val date: LocalDate,
    /** Set for past charges that were actually recorded (auto or manual). */
    val record: PaymentRecord? = null,
)

/**
 * A charge that actually happened — or was explicitly skipped. Auto records are
 * written when a billing date rolls past while the app is installed; manual ones
 * add or correct from the payments sheet. Records keep the real amount, so price
 * changes survive in history.
 */
class PaymentRecord(
    val subscriptionId: String,
    val date: LocalDate,
    var amount: Double,
    var currency: Currency,
    /** RUB snapshot at recording time (the rate that was live when it happened). */
    var amountRub: Double,
    var kind: Kind = Kind.CHARGE,
    var source: Source = Source.AUTO,
) {
    enum class Kind(val raw: String) { CHARGE("charge"), SKIP("skip"); }
    enum class Source(val raw: String) { AUTO("auto"), MANUAL("manual"), BANK("bank"); }

    /** `subscriptionId` + the charge's day: stable across re-planning and devices. */
    val id: String
        get() = makeId(subscriptionId, date)

    companion object {
        fun makeId(subscriptionId: String, date: LocalDate): String =
            "$subscriptionId-${date}"
    }
}

class PeriodTotal(val start: LocalDate, val amount: Double, val isForecast: Boolean)

class CategoryShare(val category: Category?, val paid: Double, val total: Double)

/** Month-over-month comparison of actually charged money (see `AppStore.monthOverMonth`). */
class MonthDelta(val current: Double, val previous: Double) {
    val delta: Double get() = current - previous
}

/** A subscription with its projected year cost (see `AppStore.annualForecast`). */
class AnnualCost(val subscription: Subscription, val perYearRub: Double)

fun newId(): String = UUID.randomUUID().toString().uppercase()
