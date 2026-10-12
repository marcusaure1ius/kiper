import SwiftUI

/// Mirrors `lib/features/subscriptions/catalog/catalog_data.dart`.
struct CatalogEntry: Identifiable, Hashable {
    let name: String
    let currency: Currency
    let period: BillingPeriod
    let categoryId: String
    let domain: String
    var id: String { name }

    var asSubscription: Subscription {
        Subscription(id: id, name: name, amount: 0, currency: currency, billingPeriod: period,
                     categoryId: categoryId, nextBillingDate: .now, startDate: .now, domain: domain)
    }

    /// Catalog sections (fixed, independent of user-editable categories), as in the Android app.
    static let groups: [(id: String, name: String)] = [
        ("cat-streaming", "Стриминг"),
        ("cat-ai", "AI-сервисы"),
        ("cat-telecom", "Связь"),
        ("cat-entertainment", "Развлечения"),
    ]

    static let all: [CatalogEntry] = [
        .init(name: "Netflix", currency: .usd, period: .monthly, categoryId: "cat-streaming", domain: "netflix.com"),
        .init(name: "YouTube Premium", currency: .usd, period: .monthly, categoryId: "cat-streaming", domain: "youtube.com"),
        .init(name: "Spotify", currency: .usd, period: .monthly, categoryId: "cat-streaming", domain: "spotify.com"),
        .init(name: "Apple Music", currency: .usd, period: .monthly, categoryId: "cat-streaming", domain: "music.apple.com"),
        .init(name: "Яндекс Музыка", currency: .rub, period: .monthly, categoryId: "cat-streaming", domain: "music.yandex.ru"),
        .init(name: "Кинопоиск", currency: .rub, period: .monthly, categoryId: "cat-streaming", domain: "kinopoisk.ru"),
        .init(name: "Claude", currency: .usd, period: .monthly, categoryId: "cat-ai", domain: "claude.ai"),
        .init(name: "ChatGPT", currency: .usd, period: .monthly, categoryId: "cat-ai", domain: "chatgpt.com"),
        .init(name: "Perplexity", currency: .usd, period: .monthly, categoryId: "cat-ai", domain: "perplexity.ai"),
        .init(name: "Google AI (Gemini)", currency: .usd, period: .monthly, categoryId: "cat-ai", domain: "gemini.google.com"),
        .init(name: "МТС", currency: .rub, period: .monthly, categoryId: "cat-telecom", domain: "mts.ru"),
        .init(name: "Билайн", currency: .rub, period: .monthly, categoryId: "cat-telecom", domain: "beeline.ru"),
        .init(name: "Мегафон", currency: .rub, period: .monthly, categoryId: "cat-telecom", domain: "megafon.ru"),
        .init(name: "Tele2", currency: .rub, period: .monthly, categoryId: "cat-telecom", domain: "tele2.ru"),
        .init(name: "Ростелеком", currency: .rub, period: .monthly, categoryId: "cat-telecom", domain: "rt.ru"),
        .init(name: "PlayStation Plus", currency: .usd, period: .monthly, categoryId: "cat-entertainment", domain: "playstation.com"),
        .init(name: "Xbox Game Pass", currency: .usd, period: .monthly, categoryId: "cat-entertainment", domain: "xbox.com"),
        .init(name: "Steam", currency: .usd, period: .monthly, categoryId: "cat-entertainment", domain: "steampowered.com"),
    ]
}
