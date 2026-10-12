import SwiftUI

/// Same seed as `AppDatabase._seedCategories` / `_seedTestSubscriptions` in the Android app.
/// Categories are created on first launch; subscriptions only in DEBUG builds.
enum SeedData {
    static let categories: [Category] = [
        Category(id: "cat-streaming", name: "Стриминг", colorHex: 0x7C4DFF, symbol: "play.tv.fill"),
        Category(id: "cat-ai", name: "AI-сервисы", colorHex: 0x2196F3, symbol: "sparkles"),
        Category(id: "cat-telecom", name: "Связь", colorHex: 0xFF6B35, symbol: "antenna.radiowaves.left.and.right"),
        Category(id: "cat-entertainment", name: "Развлечения", colorHex: 0xE50914, symbol: "gamecontroller.fill"),
        Category(id: "cat-other", name: "Другое", colorHex: 0x9E9E9E, symbol: "square.grid.2x2.fill"),
    ]

    static func subscriptions(now: Date = .now) -> [Subscription] {
        func sub(
            _ id: String, _ name: String, _ amount: Double, _ currency: Currency,
            _ period: BillingPeriod = .monthly, cat: String, inDays: Int,
            start: (Int, Int, Int), domain: String? = nil, status: SubscriptionStatus = .active
        ) -> Subscription {
            let cal = Calendar.current
            return Subscription(
                id: id, name: name, amount: amount, currency: currency, billingPeriod: period,
                categoryId: cat,
                nextBillingDate: cal.date(byAdding: .day, value: inDays, to: cal.startOfDay(for: now))!,
                status: status,
                startDate: cal.date(from: DateComponents(year: start.0, month: start.1, day: start.2))!,
                domain: domain
            )
        }

        return [
            sub("test-1", "Netflix", 22.99, .usd, cat: "cat-streaming", inDays: 5, start: (2024, 3, 1), domain: "netflix.com"),
            sub("test-2", "YouTube Premium", 13.99, .usd, cat: "cat-streaming", inDays: 12, start: (2023, 8, 15), domain: "youtube.com"),
            sub("test-3", "Spotify", 10.99, .usd, cat: "cat-streaming", inDays: 8, start: (2022, 1, 10), domain: "spotify.com"),
            sub("test-4", "Apple Music", 10.99, .usd, cat: "cat-streaming", inDays: 20, start: (2024, 6, 1), domain: "music.apple.com"),
            sub("test-5", "Яндекс Музыка", 299, .rub, cat: "cat-streaming", inDays: 3, start: (2023, 11, 1), domain: "music.yandex.ru"),
            sub("test-6", "Кинопоиск", 269, .rub, cat: "cat-streaming", inDays: 15, start: (2024, 1, 20), domain: "kinopoisk.ru"),
            sub("test-7", "Claude Pro", 20, .usd, cat: "cat-ai", inDays: 2, start: (2024, 5, 1), domain: "claude.ai"),
            sub("test-8", "ChatGPT Plus", 20, .usd, cat: "cat-ai", inDays: 7, start: (2023, 3, 15), domain: "chatgpt.com"),
            sub("test-9", "Perplexity Pro", 20, .usd, cat: "cat-ai", inDays: 18, start: (2024, 9, 1), domain: "perplexity.ai"),
            sub("test-10", "Google AI Premium", 19.99, .usd, cat: "cat-ai", inDays: 25, start: (2025, 1, 10), domain: "gemini.google.com"),
            sub("test-11", "Midjourney", 10, .usd, cat: "cat-ai", inDays: 11, start: (2024, 7, 1), domain: "midjourney.com"),
            sub("test-12", "МТС", 890, .rub, cat: "cat-telecom", inDays: 1, start: (2020, 6, 1), domain: "mts.ru"),
            sub("test-13", "Домашний интернет", 750, .rub, cat: "cat-telecom", inDays: 10, start: (2021, 3, 1)),
            sub("test-14", "Мегафон (жена)", 650, .rub, cat: "cat-telecom", inDays: 14, start: (2022, 9, 1), domain: "megafon.ru"),
            sub("test-15", "Ростелеком ТВ", 450, .rub, cat: "cat-telecom", inDays: 22, start: (2023, 1, 15), domain: "rt.ru"),
            sub("test-16", "PlayStation Plus", 59.99, .usd, .annual, cat: "cat-entertainment", inDays: 90, start: (2023, 6, 1), domain: "playstation.com"),
            sub("test-17", "Xbox Game Pass", 14.99, .usd, cat: "cat-entertainment", inDays: 6, start: (2024, 2, 1), domain: "xbox.com"),
            sub("test-18", "Nintendo Online", 3.99, .usd, cat: "cat-entertainment", inDays: 16, start: (2024, 11, 1), domain: "nintendo.com"),
            sub("test-19", "Notion Plus", 10, .usd, cat: "cat-other", inDays: 4, start: (2024, 4, 1), domain: "notion.so"),
            sub("test-20", "iCloud 200GB", 2.99, .usd, cat: "cat-other", inDays: 9, start: (2022, 5, 1), domain: "icloud.com"),
            sub("test-21", "Фитнес клуб", 3500, .rub, cat: "cat-other", inDays: 13, start: (2025, 1, 1)),
            sub("test-22", "Яндекс Плюс", 399, .rub, cat: "cat-other", inDays: 17, start: (2023, 5, 1), domain: "plus.yandex.ru"),
            sub("test-23", "NordVPN", 99.99, .usd, .annual, cat: "cat-other", inDays: 120, start: (2024, 8, 1), domain: "nordvpn.com"),
            sub("test-24", "Dropbox Plus", 11.99, .usd, cat: "cat-other", inDays: 21, start: (2023, 10, 1), domain: "dropbox.com"),
            sub("test-25", "1Password", 2.99, .usd, cat: "cat-other", inDays: 27, start: (2022, 12, 1), domain: "1password.com"),
            sub("test-paused", "Hulu", 17.99, .usd, cat: "cat-streaming", inDays: 30, start: (2024, 2, 1), domain: "hulu.com", status: .paused),
        ]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
