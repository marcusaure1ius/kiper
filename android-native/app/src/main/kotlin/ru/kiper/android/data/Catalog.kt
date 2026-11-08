package ru.kiper.android.data

import java.time.LocalDate

/** Shared service catalog: same entries as the iOS `CatalogData.swift`. */
class CatalogEntry(
    val name: String,
    val currency: Currency,
    val period: BillingPeriod,
    val categoryId: String,
    val domain: String,
) {
    fun asSubscription(now: LocalDate = LocalDate.now()): Subscription = Subscription(
        id = name, name = name, amount = 0.0, currency = currency, billingPeriod = period,
        categoryId = categoryId, nextBillingDate = now, startDate = now, domain = domain,
    )

    companion object {
        /** Catalog sections (fixed, independent of user-editable categories), same as on iOS. */
        val groups = listOf(
            "cat-streaming" to "Стриминг",
            "cat-ai" to "AI-сервисы",
            "cat-telecom" to "Связь",
            "cat-entertainment" to "Развлечения",
        )

        val all: List<CatalogEntry> = listOf(
            CatalogEntry("Netflix", Currency.USD, BillingPeriod.MONTHLY, "cat-streaming", "netflix.com"),
            CatalogEntry("YouTube Premium", Currency.USD, BillingPeriod.MONTHLY, "cat-streaming", "youtube.com"),
            CatalogEntry("Spotify", Currency.USD, BillingPeriod.MONTHLY, "cat-streaming", "spotify.com"),
            CatalogEntry("Apple Music", Currency.USD, BillingPeriod.MONTHLY, "cat-streaming", "music.apple.com"),
            CatalogEntry("Яндекс Музыка", Currency.RUB, BillingPeriod.MONTHLY, "cat-streaming", "music.yandex.ru"),
            CatalogEntry("Кинопоиск", Currency.RUB, BillingPeriod.MONTHLY, "cat-streaming", "kinopoisk.ru"),
            CatalogEntry("Claude", Currency.USD, BillingPeriod.MONTHLY, "cat-ai", "claude.ai"),
            CatalogEntry("ChatGPT", Currency.USD, BillingPeriod.MONTHLY, "cat-ai", "chatgpt.com"),
            CatalogEntry("Perplexity", Currency.USD, BillingPeriod.MONTHLY, "cat-ai", "perplexity.ai"),
            CatalogEntry("Google AI (Gemini)", Currency.USD, BillingPeriod.MONTHLY, "cat-ai", "gemini.google.com"),
            CatalogEntry("МТС", Currency.RUB, BillingPeriod.MONTHLY, "cat-telecom", "mts.ru"),
            CatalogEntry("Билайн", Currency.RUB, BillingPeriod.MONTHLY, "cat-telecom", "beeline.ru"),
            CatalogEntry("Мегафон", Currency.RUB, BillingPeriod.MONTHLY, "cat-telecom", "megafon.ru"),
            CatalogEntry("Tele2", Currency.RUB, BillingPeriod.MONTHLY, "cat-telecom", "tele2.ru"),
            CatalogEntry("Ростелеком", Currency.RUB, BillingPeriod.MONTHLY, "cat-telecom", "rt.ru"),
            CatalogEntry("PlayStation Plus", Currency.USD, BillingPeriod.MONTHLY, "cat-entertainment", "playstation.com"),
            CatalogEntry("Xbox Game Pass", Currency.USD, BillingPeriod.MONTHLY, "cat-entertainment", "xbox.com"),
            CatalogEntry("Steam", Currency.USD, BillingPeriod.MONTHLY, "cat-entertainment", "steampowered.com"),
        )
    }
}
