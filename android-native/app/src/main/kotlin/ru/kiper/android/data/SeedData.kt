package ru.kiper.android.data

import java.time.LocalDate

/** Same categories and demo subscriptions as the iOS `SeedData.swift`. */
object SeedData {

    val categories: List<Category> = listOf(
        Category("cat-streaming", "Стриминг", 0x7C4DFF, "play.tv.fill"),
        Category("cat-ai", "AI-сервисы", 0x2196F3, "sparkles"),
        Category("cat-telecom", "Связь", 0xFF6B35, "antenna.radiowaves.left.and.right"),
        Category("cat-entertainment", "Развлечения", 0xE50914, "gamecontroller.fill"),
        Category("cat-other", "Другое", 0x9E9E9E, "square.grid.2x2.fill"),
    )

    private fun sub(
        id: String, name: String, amount: Double, currency: Currency,
        period: BillingPeriod = BillingPeriod.MONTHLY, cat: String, inDays: Int,
        start: Triple<Int, Int, Int>, domain: String? = null,
        status: SubscriptionStatus = SubscriptionStatus.ACTIVE,
        now: LocalDate = LocalDate.now(),
    ): Subscription = Subscription(
        id = id, name = name, amount = amount, currency = currency, billingPeriod = period,
        categoryId = cat,
        nextBillingDate = now.plusDays(inDays.toLong()),
        status = status,
        startDate = LocalDate.of(start.first, start.second, start.third),
        domain = domain,
    )

    fun subscriptions(now: LocalDate = LocalDate.now()): List<Subscription> = listOf(
        sub("test-1", "Netflix", 22.99, Currency.USD, cat = "cat-streaming", inDays = 5, start = Triple(2024, 3, 1), domain = "netflix.com", now = now),
        sub("test-2", "YouTube Premium", 13.99, Currency.USD, cat = "cat-streaming", inDays = 12, start = Triple(2023, 8, 15), domain = "youtube.com", now = now),
        sub("test-3", "Spotify", 10.99, Currency.USD, cat = "cat-streaming", inDays = 8, start = Triple(2022, 1, 10), domain = "spotify.com", now = now),
        sub("test-4", "Apple Music", 10.99, Currency.USD, cat = "cat-streaming", inDays = 20, start = Triple(2024, 6, 1), domain = "music.apple.com", now = now),
        sub("test-5", "Яндекс Музыка", 299.0, Currency.RUB, cat = "cat-streaming", inDays = 3, start = Triple(2023, 11, 1), domain = "music.yandex.ru", now = now),
        sub("test-6", "Кинопоиск", 269.0, Currency.RUB, cat = "cat-streaming", inDays = 15, start = Triple(2024, 1, 20), domain = "kinopoisk.ru", now = now),
        sub("test-7", "Claude Pro", 20.0, Currency.USD, cat = "cat-ai", inDays = 2, start = Triple(2024, 5, 1), domain = "claude.ai", now = now),
        sub("test-8", "ChatGPT Plus", 20.0, Currency.USD, cat = "cat-ai", inDays = 7, start = Triple(2023, 3, 15), domain = "chatgpt.com", now = now),
        sub("test-9", "Perplexity Pro", 20.0, Currency.USD, cat = "cat-ai", inDays = 18, start = Triple(2024, 9, 1), domain = "perplexity.ai", now = now),
        sub("test-10", "Google AI Premium", 19.99, Currency.USD, cat = "cat-ai", inDays = 25, start = Triple(2025, 1, 10), domain = "gemini.google.com", now = now),
        sub("test-11", "Midjourney", 10.0, Currency.USD, cat = "cat-ai", inDays = 11, start = Triple(2024, 7, 1), domain = "midjourney.com", now = now),
        sub("test-12", "МТС", 890.0, Currency.RUB, cat = "cat-telecom", inDays = 1, start = Triple(2020, 6, 1), domain = "mts.ru", now = now),
        sub("test-13", "Домашний интернет", 750.0, Currency.RUB, cat = "cat-telecom", inDays = 10, start = Triple(2021, 3, 1), now = now),
        sub("test-14", "Мегафон (жена)", 650.0, Currency.RUB, cat = "cat-telecom", inDays = 14, start = Triple(2022, 9, 1), domain = "megafon.ru", now = now),
        sub("test-15", "Ростелеком ТВ", 450.0, Currency.RUB, cat = "cat-telecom", inDays = 22, start = Triple(2023, 1, 15), domain = "rt.ru", now = now),
        sub("test-16", "PlayStation Plus", 59.99, Currency.USD, BillingPeriod.ANNUAL, cat = "cat-entertainment", inDays = 90, start = Triple(2023, 6, 1), domain = "playstation.com", now = now),
        sub("test-17", "Xbox Game Pass", 14.99, Currency.USD, cat = "cat-entertainment", inDays = 6, start = Triple(2024, 2, 1), domain = "xbox.com", now = now),
        sub("test-18", "Nintendo Online", 3.99, Currency.USD, cat = "cat-entertainment", inDays = 16, start = Triple(2024, 11, 1), domain = "nintendo.com", now = now),
        sub("test-19", "Notion Plus", 10.0, Currency.USD, cat = "cat-other", inDays = 4, start = Triple(2024, 4, 1), domain = "notion.so", now = now),
        sub("test-20", "iCloud 200GB", 2.99, Currency.USD, cat = "cat-other", inDays = 9, start = Triple(2022, 5, 1), domain = "icloud.com", now = now),
        sub("test-21", "Фитнес клуб", 3500.0, Currency.RUB, cat = "cat-other", inDays = 13, start = Triple(2025, 1, 1), now = now),
        sub("test-22", "Яндекс Плюс", 399.0, Currency.RUB, cat = "cat-other", inDays = 17, start = Triple(2023, 5, 1), domain = "plus.yandex.ru", now = now),
        sub("test-23", "NordVPN", 99.99, Currency.USD, BillingPeriod.ANNUAL, cat = "cat-other", inDays = 120, start = Triple(2024, 8, 1), domain = "nordvpn.com", now = now),
        sub("test-24", "Dropbox Plus", 11.99, Currency.USD, cat = "cat-other", inDays = 21, start = Triple(2023, 10, 1), domain = "dropbox.com", now = now),
        sub("test-25", "1Password", 2.99, Currency.USD, cat = "cat-other", inDays = 27, start = Triple(2022, 12, 1), domain = "1password.com", now = now),
        sub("test-paused", "Hulu", 17.99, Currency.USD, cat = "cat-streaming", inDays = 30, start = Triple(2024, 2, 1), domain = "hulu.com", status = SubscriptionStatus.PAUSED, now = now),
    )
}
