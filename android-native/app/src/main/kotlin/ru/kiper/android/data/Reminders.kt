package ru.kiper.android.data

import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Local reminders before charges. Up to `PER_SUBSCRIPTION` pending reminders per
 * subscription; the whole set is rebuilt on every change. The pure `plan` step is
 * unit-tested; system scheduling lives in `ReminderScheduler`.
 */
object Reminders {
    const val PREFIX = "sub-"
    const val SUBSCRIPTION_ID_KEY = "subscriptionId"

    /** Keep the iOS policy (60 pending) for identical behaviour. */
    const val LIMIT = 60

    /** Upcoming charges per subscription that get a reminder (so reminders keep
     * coming even if the app isn't opened for a while). */
    const val PER_SUBSCRIPTION = 3

    data class Plan(
        val id: String,
        val subscriptionId: String,
        val fireDate: LocalDateTime,
        val title: String,
        val body: String,
    )

    /** Pure planning step (unit-tested): which reminder fires when. */
    fun plan(
        subscriptions: List<Subscription>,
        hour: Int,
        minute: Int,
        now: LocalDateTime = LocalDateTime.now(),
    ): List<Plan> {
        val plans = mutableListOf<Plan>()
        for (sub in subscriptions) {
            if (sub.status == SubscriptionStatus.ACTIVE && sub.reminderDaysBefore > 0) {
                // Next few charges whose reminder is still in the future.
                val charges = Schedule.upcoming(of = sub, count = PER_SUBSCRIPTION + 1)
                val fires = charges.mapNotNull { fireDate(it, sub.reminderDaysBefore, hour, minute) }
                fires.filter { it > now }
                    .take(PER_SUBSCRIPTION)
                    .forEachIndexed { n, fire ->
                        plans.add(
                            Plan(
                                id = "$PREFIX${sub.id}-$n",
                                subscriptionId = sub.id,
                                fireDate = fire,
                                title = "Напоминание о подписке",
                                body = body(sub, sub.reminderDaysBefore),
                            )
                        )
                    }
            }
        }
        // A trial gets a single reminder before it ends and the first charge hits.
        for (sub in subscriptions) {
            if (sub.status == SubscriptionStatus.TRIAL && sub.reminderDaysBefore > 0) {
                val end = sub.trialEndDate ?: continue
                val fire = fireDate(end, sub.reminderDaysBefore, hour, minute)
                if (fire > now) {
                    plans.add(
                        Plan(
                            id = "$PREFIX${sub.id}-0",
                            subscriptionId = sub.id,
                            fireDate = fire,
                            title = "Напоминание о подписке",
                            body = trialBody(sub, sub.reminderDaysBefore),
                        )
                    )
                }
            }
        }
        return plans.sortedBy { it.fireDate }.take(LIMIT)
    }

    fun fireDate(charge: LocalDate, daysBefore: Int, hour: Int, minute: Int): LocalDateTime =
        charge.minusDays(daysBefore.toLong()).atTime(hour, minute).withSecond(0).withNano(0)

    fun body(sub: Subscription, daysBefore: Int): String {
        val whenStr = if (daysBefore == 1) "завтра"
        else "через $daysBefore ${Fmt.plural(daysBefore, "день", "дня", "дней")}"
        return "${sub.name} — списание $whenStr, ${Fmt.money(sub.amount, sub.currency)}"
    }

    fun trialBody(sub: Subscription, daysBefore: Int): String {
        val whenStr = if (daysBefore == 1) "завтра"
        else "через $daysBefore ${Fmt.plural(daysBefore, "день", "дня", "дней")}"
        return "${sub.name} — триал заканчивается $whenStr, спишется ${Fmt.money(sub.amount, sub.currency)}"
    }
}
