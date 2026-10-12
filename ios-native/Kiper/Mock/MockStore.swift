import SwiftUI

/// In-memory stand-in for the Drift database + Riverpod providers of the Android app.
/// Calculations mirror `home_providers.dart` and `analytics_provider.dart`.
@MainActor
@Observable
final class MockStore {
    var subscriptions: [Subscription]
    var categories: [Category]
    var rates: [Currency: Double]
    var remindersEnabled = true
    var reminderTime = Calendar.current.date(from: DateComponents(hour: 10))!
    /// Transient confirmation shown at the top of the app.
    var toast: Toast?

    func show(_ text: String, symbol: String = "checkmark.circle.fill", tint: Color = .green) {
        withAnimation(.bouncy) { toast = Toast(text: text, symbol: symbol, tint: tint) }
    }

    init() {
        subscriptions = MockData.subscriptions()
        categories = MockData.categories
        rates = MockData.rates
    }

    // MARK: - Lookup

    func category(for id: String?) -> Category? {
        categories.first { $0.id == id }
    }

    func subscription(id: String) -> Subscription? {
        subscriptions.first { $0.id == id }
    }

    func toRub(_ amount: Double, _ currency: Currency) -> Double {
        amount * (rates[currency] ?? 1)
    }

    var active: [Subscription] { subscriptions.filter { $0.status == .active } }
    var notCancelled: [Subscription] { subscriptions.filter { $0.status != .cancelled } }

    // MARK: - Mutations

    func upsert(_ sub: Subscription) {
        if let i = subscriptions.firstIndex(where: { $0.id == sub.id }) {
            subscriptions[i] = sub
        } else {
            subscriptions.append(sub)
        }
    }

    func togglePause(_ id: String) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[i].status = subscriptions[i].status == .paused ? .active : .paused
    }

    /// Soft delete, same as Android: row stays for analytics.
    func cancel(_ id: String) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[i].status = .cancelled
    }

    func upsertCategory(_ cat: Category) {
        if let i = categories.firstIndex(where: { $0.id == cat.id }) {
            categories[i] = cat
        } else {
            categories.append(cat)
        }
    }

    /// Same rule as Android: detach subscriptions first, then drop the category.
    func deleteCategory(_ id: String) {
        for i in subscriptions.indices where subscriptions[i].categoryId == id {
            subscriptions[i].categoryId = nil
        }
        categories.removeAll { $0.id == id }
    }

    // MARK: - Home

    var monthlyTotalRub: Double {
        active.reduce(0) { $0 + toRub($1.amount, $1.currency) * $1.billingPeriod.monthlyEquivalent }
    }

    func monthProgress(now: Date = .now) -> (paid: Double, remaining: Double) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let month = cal.dateInterval(of: .month, for: now)!
        var paid = 0.0, remaining = 0.0
        for sub in active {
            for date in billingDates(of: sub, from: month.start, to: month.end) {
                let rub = toRub(sub.amount, sub.currency)
                if date < today { paid += rub } else { remaining += rub }
            }
        }
        return (paid, remaining)
    }

    func pastPayments(days: Int = 90, now: Date = .now) -> [PaymentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: today)!
        return active
            .flatMap { sub in billingDates(of: sub, from: start, to: today).map { PaymentEvent(subscription: sub, date: $0) } }
            .sorted { $0.date > $1.date }
    }

    func futurePayments(days: Int = 90, now: Date = .now) -> [PaymentEvent] {
        let today = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: days, to: today)!
        return active
            .flatMap { sub in billingDates(of: sub, from: today, to: end).map { PaymentEvent(subscription: sub, date: $0) } }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Analytics

    func monthlyTotals(past: Int = 6, future: Int = 3, now: Date = .now) -> [PeriodTotal] {
        let cal = Calendar.current
        let current = cal.dateInterval(of: .month, for: now)!.start
        let starts = (-past...future).map { cal.date(byAdding: .month, value: $0, to: current)! }
        return totals(buckets: starts, end: cal.date(byAdding: .month, value: 1, to: starts.last!)!, current: current) {
            cal.dateInterval(of: .month, for: $0)!.start
        }
    }

    func weeklyTotals(past: Int = 6, future: Int = 4, now: Date = .now) -> [PeriodTotal] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let current = cal.dateInterval(of: .weekOfYear, for: now)!.start
        let starts = (-past...future).map { cal.date(byAdding: .weekOfYear, value: $0, to: current)! }
        return totals(buckets: starts, end: cal.date(byAdding: .weekOfYear, value: 1, to: starts.last!)!, current: current) {
            cal.dateInterval(of: .weekOfYear, for: $0)!.start
        }
    }

    /// Per-category charges inside `interval` (RUB), split into already paid (before today)
    /// and total. Uses the same subscriptions as the bar chart, so totals add up to the bar.
    func categoryShares(in interval: DateInterval, now: Date = .now) -> [CategoryShare] {
        let today = Calendar.current.startOfDay(for: now)
        var paid: [String?: Double] = [:], total: [String?: Double] = [:]
        for sub in notCancelled {
            for date in billingDates(of: sub, from: interval.start, to: interval.end) {
                let rub = toRub(sub.amount, sub.currency)
                total[sub.categoryId, default: 0] += rub
                if date < today { paid[sub.categoryId, default: 0] += rub }
            }
        }
        return total
            .map { CategoryShare(category: category(for: $0.key), paid: paid[$0.key] ?? 0, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Helpers

    private func totals(buckets: [Date], end: Date, current: Date, bucketOf: (Date) -> Date) -> [PeriodTotal] {
        var sums = Dictionary(uniqueKeysWithValues: buckets.map { ($0, 0.0) })
        for sub in notCancelled {
            for date in billingDates(of: sub, from: buckets.first!, to: end) {
                sums[bucketOf(date), default: 0] += toRub(sub.amount, sub.currency)
            }
        }
        return buckets.map { PeriodTotal(start: $0, amount: sums[$0] ?? 0, isForecast: $0 >= current) }
    }

    /// Billing dates in `[from, to)`, anchored on `nextBillingDate` and stepping by multiples
    /// of the period in both directions (never before `startDate`). Multiples avoid
    /// day-of-month drift such as Jan 31 → Feb 28 → Mar 28.
    func billingDates(of sub: Subscription, from: Date, to: Date) -> [Date] {
        let cal = Calendar.current
        let lower = max(from, cal.startOfDay(for: sub.startDate))
        // Nothing is charged between today and the next billing date: past occurrences
        // are history (before today), future ones start exactly at nextBillingDate.
        let today = cal.startOfDay(for: .now)
        let next = cal.startOfDay(for: sub.nextBillingDate)
        var n = 0
        while n > -10_000, step(sub, n - 1, cal) >= lower { n -= 1 }
        var result: [Date] = []
        while n < 10_000 {
            let date = step(sub, n, cal)
            if date >= to { break }
            if date >= lower && !(date >= today && date < next) { result.append(date) }
            n += 1
        }
        return result
    }

    private func step(_ sub: Subscription, _ n: Int, _ cal: Calendar) -> Date {
        let s = sub.nextBillingDate
        return switch sub.billingPeriod {
        case .weekly: cal.date(byAdding: .day, value: 7 * n, to: s)!
        case .monthly: cal.date(byAdding: .month, value: n, to: s)!
        case .quarterly: cal.date(byAdding: .month, value: 3 * n, to: s)!
        case .semiannual: cal.date(byAdding: .month, value: 6 * n, to: s)!
        case .annual: cal.date(byAdding: .year, value: n, to: s)!
        case .custom: cal.date(byAdding: .day, value: max(sub.customPeriodDays ?? 30, 1) * n, to: s)!
        }
    }
}
