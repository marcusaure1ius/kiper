import SwiftUI

/// Mirrors `lib/core/currency/currency.dart`. Raw values match the DB strings.
enum Currency: String, CaseIterable, Identifiable, Codable {
    case rub = "RUB"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }
    var code: String { rawValue }

    var symbol: String {
        switch self {
        case .rub: "₽"
        case .usd: "$"
        case .eur: "€"
        }
    }
}

/// Mirrors `lib/features/subscriptions/models/billing_period.dart`.
enum BillingPeriod: String, CaseIterable, Identifiable, Codable {
    case weekly, monthly, quarterly, semiannual, annual, custom

    var id: String { rawValue }

    var monthlyEquivalent: Double {
        switch self {
        case .weekly: 52.0 / 12.0
        case .monthly: 1
        case .quarterly: 1.0 / 3.0
        case .semiannual: 1.0 / 6.0
        case .annual: 1.0 / 12.0
        case .custom: 1
        }
    }

    var label: String {
        switch self {
        case .weekly: "Еженедельно"
        case .monthly: "Ежемесячно"
        case .quarterly: "Раз в квартал"
        case .semiannual: "Раз в полгода"
        case .annual: "Ежегодно"
        case .custom: "Свой период"
        }
    }

    func next(after date: Date, customDays: Int?) -> Date {
        let cal = Calendar.current
        return switch self {
        case .weekly: cal.date(byAdding: .day, value: 7, to: date)!
        case .monthly: cal.date(byAdding: .month, value: 1, to: date)!
        case .quarterly: cal.date(byAdding: .month, value: 3, to: date)!
        case .semiannual: cal.date(byAdding: .month, value: 6, to: date)!
        case .annual: cal.date(byAdding: .year, value: 1, to: date)!
        case .custom: cal.date(byAdding: .day, value: max(customDays ?? 30, 1), to: date)!
        }
    }
}

enum SubscriptionStatus: String, CaseIterable, Codable {
    case active, paused, cancelled

    var label: String {
        switch self {
        case .active: "Активна"
        case .paused: "Приостановлена"
        case .cancelled: "Отменена"
        }
    }
}

struct Category: Identifiable, Hashable {
    let id: String
    var name: String
    var color: Color
    var symbol: String
}

struct Subscription: Identifiable, Hashable {
    let id: String
    var name: String
    var amount: Double
    var currency: Currency
    var billingPeriod: BillingPeriod
    var customPeriodDays: Int?
    var categoryId: String?
    var nextBillingDate: Date
    var reminderDaysBefore: Int = 1
    var status: SubscriptionStatus = .active
    var startDate: Date
    var note: String?
    /// Domain used to fetch a favicon (same source as the Android catalog).
    var domain: String?

    var logoURL: URL? {
        domain.flatMap { URL(string: "https://www.google.com/s2/favicons?domain=\($0)&sz=128") }
    }
}

struct PaymentEvent: Identifiable, Hashable {
    let subscription: Subscription
    let date: Date
    var id: String { "\(subscription.id)-\(date.timeIntervalSince1970)" }
}

struct PeriodTotal: Identifiable {
    let start: Date
    let amount: Double
    let isForecast: Bool
    var id: Date { start }
}

struct CategoryShare: Identifiable {
    let category: Category?
    let paid: Double
    let total: Double
    var id: String { category?.id ?? "none" }
}
