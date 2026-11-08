package ru.kiper.android.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

class FmtTest {

    @Test
    fun moneyFormatsRussianStyle() {
        assertEquals("1\u00A0234\u00A0567\u00A0₽", Fmt.money(1234567.0, Currency.RUB))
        assertEquals("99\u00A0₽", Fmt.money(99.0, Currency.RUB))
        assertEquals("22,99\u00A0$", Fmt.money(22.99, Currency.USD))
        assertEquals("-50\u00A0₽", Fmt.money(-50.0, Currency.RUB))
        assertEquals("1,50\u00A0€", Fmt.money(1.5, Currency.EUR))
    }

    @Test
    fun russianPlural() {
        assertEquals("списание", Fmt.plural(1, "списание", "списания", "списаний"))
        assertEquals("списания", Fmt.plural(2, "списание", "списания", "списаний"))
        assertEquals("списания", Fmt.plural(4, "списание", "списания", "списаний"))
        assertEquals("списаний", Fmt.plural(5, "списание", "списания", "списаний"))
        assertEquals("списаний", Fmt.plural(11, "списание", "списания", "списаний"))
        assertEquals("списание", Fmt.plural(21, "списание", "списания", "списаний"))
        assertEquals("дня", Fmt.plural(3, "день", "дня", "дней"))
    }

    @Test
    fun relativeDays() {
        val now = LocalDate.of(2026, 11, 8)
        assertEquals("Сегодня", Fmt.relative(now, now))
        assertEquals("Завтра", Fmt.relative(now.plusDays(1), now))
        assertEquals("Вчера", Fmt.relative(now.minusDays(1), now))
        assertEquals("Через 5 дн.", Fmt.relative(now.plusDays(5), now))
        assertEquals("3 дн. назад", Fmt.relative(now.minusDays(3), now))
    }

    @Test
    fun monthNames() {
        val october = LocalDate.of(2026, 10, 15)
        assertEquals("Октябрь", Fmt.monthName(october))
        assertEquals("октябре", Fmt.monthPrepositional(october))
    }
}

class RemindersPlanTest {

    private fun activeSub(id: String, next: LocalDate, daysBefore: Int = 1): Subscription =
        Subscription(
            id = id, name = "Подписка $id", amount = 100.0, currency = Currency.RUB,
            billingPeriod = BillingPeriod.MONTHLY, nextBillingDate = next,
            reminderDaysBefore = daysBefore, startDate = LocalDate.of(2024, 1, 1),
        )

    @Test
    fun plansThreePerSubscription() {
        val next = LocalDate.of(2026, 11, 20)
        val plans = Reminders.plan(
            subscriptions = listOf(activeSub("a", next)),
            hour = 10, minute = 0,
            now = LocalDateTime.of(2026, 11, 8, 12, 0),
        )
        assertEquals(3, plans.size)
        // Sorted by fire date; the first is the day before the next charge.
        assertEquals(LocalDateTime.of(2026, 11, 19, 10, 0), plans[0].fireDate)
        assertEquals(LocalDateTime.of(2026, 12, 19, 10, 0), plans[1].fireDate)
        assertTrue(plans.all { it.id.startsWith("sub-a-") })
        assertEquals("Подписка a — списание завтра, 100\u00A0₽", plans[0].body)
    }

    @Test
    fun reminderDaysZeroMeansOff() {
        val plans = Reminders.plan(
            subscriptions = listOf(activeSub("a", LocalDate.of(2026, 11, 20), daysBefore = 0)),
            hour = 10, minute = 0,
            now = LocalDateTime.of(2026, 11, 8, 12, 0),
        )
        assertEquals(0, plans.size)
    }

    @Test
    fun trialGetsOneReminderBeforeEnd() {
        val trial = Subscription(
            id = "t", name = "Триал", amount = 20.0, currency = Currency.USD,
            billingPeriod = BillingPeriod.MONTHLY,
            nextBillingDate = LocalDate.of(2026, 11, 22),
            reminderDaysBefore = 1, status = SubscriptionStatus.TRIAL,
            trialEndDate = LocalDate.of(2026, 11, 22),
            startDate = LocalDate.of(2026, 11, 22),
        )
        val plans = Reminders.plan(
            subscriptions = listOf(trial),
            hour = 10, minute = 0,
            now = LocalDateTime.of(2026, 11, 8, 12, 0),
        )
        assertEquals(1, plans.size)
        assertEquals(LocalDateTime.of(2026, 11, 21, 10, 0), plans[0].fireDate)
        assertEquals("Триал — триал заканчивается завтра", plans[0].body.substringBefore(','))
    }
}

class CsvCodecTest {

    @Test
    fun roundTrip() {
        val subs = listOf(
            Subscription(
                id = "csv-1", name = "Имя, с запятой", amount = 299.0, currency = Currency.RUB,
                billingPeriod = BillingPeriod.MONTHLY, nextBillingDate = LocalDate.of(2026, 12, 1),
                startDate = LocalDate.of(2026, 1, 1), note = "текст \"в кавычках\"",
            ),
        )
        val csv = CsvCodec.encode(subs)
        assertTrue(csv.contains("\"Имя, с запятой\""))
        val decoded = CsvCodec.decode(csv)
        assertEquals(1, decoded.size)
        assertEquals("Имя, с запятой", decoded[0].name)
        assertEquals("текст \"в кавычках\"", decoded[0].note)
    }

    @Test
    fun decodesForeignCsv() {
        val csv = listOf(
            "id,name,amount,currency,billingPeriod,customPeriodDays,categoryId,nextBillingDate,startDate,status,reminderDaysBefore,note,trialEndDate",
            "f-1,YouTube Premium,13.99,USD,monthly,,cat-streaming,2026-11-25T00:00:00.000,2024-08-15T00:00:00.000,active,1,,",
        ).joinToString("\n")
        val decoded = CsvCodec.decode(csv)
        assertEquals(1, decoded.size)
        assertEquals("YouTube Premium", decoded[0].name)
        assertEquals(LocalDate.of(2026, 11, 25), decoded[0].nextBillingDate)
    }
}
