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
    case active, trial, paused, cancelled

    var label: String {
        switch self {
        case .active: "Активна"
        case .trial: "Триал"
        case .paused: "Приостановлена"
        case .cancelled: "Отменена"
        }
    }
}

struct Category: Identifiable, Hashable {
    let id: String
    var name: String
    /// 0xRRGGBB. Stored as ARGB int in backups, like the Android app.
    var colorHex: UInt32
    /// SF Symbol name.
    var symbol: String

    var color: Color { Color(hex: colorHex) }
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
    /// When the free period ends (status == .trial); the first charge follows it.
    var trialEndDate: Date?
    var startDate: Date
    var note: String?
    /// Domain used to fetch a favicon (same source as the Android catalog).
    var domain: String?
    var createdAt: Date = .now
    /// Catalog icon name from the Android app (kept for round-trip compatibility).
    var icon: String?

    var logoURL: URL? {
        domain.flatMap { URL(string: "https://www.google.com/s2/favicons?domain=\($0)&sz=128") }
    }
}

struct PaymentEvent: Identifiable, Hashable {
    let subscription: Subscription
    let date: Date
    /// Set for past charges that were actually recorded (auto or manual).
    var record: PaymentRecord?
    var id: String { "\(subscription.id)-\(date.timeIntervalSince1970)" }
}

/// A charge that actually happened — or was explicitly skipped. Auto records are
/// written when a billing date rolls past while the app is installed; manual ones
/// add or correct from the payments sheet. Records keep the real amount, so price
/// changes survive in history.
struct PaymentRecord: Identifiable, Hashable {
    /// `subscriptionId` + the charge's day: stable across re-planning and devices.
    let id: String
    let subscriptionId: String
    let date: Date
    var amount: Double
    var currency: Currency
    /// RUB snapshot at recording time (the rate that was live when it happened).
    var amountRub: Double
    var kind: Kind
    var source: Source

    enum Kind: String, Hashable { case charge, skip }
    enum Source: String, Hashable { case auto, manual, bank }

    static func makeId(subscriptionId: String, date: Date) -> String {
        "\(subscriptionId)-\(idDay.string(from: date))"
    }

    init(subscriptionId: String, date: Date, amount: Double, currency: Currency, amountRub: Double, kind: Kind = .charge, source: Source = .auto) {
        self.id = Self.makeId(subscriptionId: subscriptionId, date: date)
        self.subscriptionId = subscriptionId
        self.date = date
        self.amount = amount
        self.currency = currency
        self.amountRub = amountRub
        self.kind = kind
        self.source = source
    }

    private static let idDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
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

/// Month-over-month comparison of actually charged money (see `AppStore.monthOverMonth`).
struct MonthDelta: Equatable {
    let current: Double
    let previous: Double
    var delta: Double { current - previous }
}

/// A subscription with its projected year cost (see `AppStore.annualForecast`).
struct AnnualCost: Identifiable {
    let subscription: Subscription
    let perYearRub: Double
    var id: String { subscription.id }
}
