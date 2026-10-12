import Foundation

/// Billing schedule of a subscription — one place for history, upcoming charges,
/// date advancing and reminders.
///
/// Dates are always `anchor + n × period` (never stepped one by one), so a monthly
/// charge on the 31st stays on the 31st (Jan 31 → Feb 28 → Mar 31). The anchor is
/// `startDate` when `nextBillingDate` lies on its grid, otherwise `nextBillingDate`.
enum Schedule {
    static func step(_ base: Date, _ period: BillingPeriod, customDays: Int?, _ n: Int, calendar cal: Calendar = .current) -> Date {
        switch period {
        case .weekly: cal.date(byAdding: .day, value: 7 * n, to: base)!
        case .monthly: cal.date(byAdding: .month, value: n, to: base)!
        case .quarterly: cal.date(byAdding: .month, value: 3 * n, to: base)!
        case .semiannual: cal.date(byAdding: .month, value: 6 * n, to: base)!
        case .annual: cal.date(byAdding: .year, value: n, to: base)!
        case .custom: cal.date(byAdding: .day, value: max(customDays ?? 30, 1) * n, to: base)!
        }
    }

    private static func step(_ sub: Subscription, _ base: Date, _ n: Int, _ cal: Calendar) -> Date {
        step(base, sub.billingPeriod, customDays: sub.customPeriodDays, n, calendar: cal)
    }

    static func anchor(of sub: Subscription, calendar cal: Calendar = .current) -> Date {
        let next = cal.startOfDay(for: sub.nextBillingDate)
        guard sub.startDate <= sub.nextBillingDate else { return sub.nextBillingDate }
        for n in 0..<10_000 {
            let day = cal.startOfDay(for: step(sub, sub.startDate, n, cal))
            if day == next { return sub.startDate }
            if day > next { break }
        }
        return sub.nextBillingDate
    }

    /// Charges in `[from, to)`: history goes back to `startDate`; nothing between today
    /// and `nextBillingDate`; future charges start exactly at `nextBillingDate`.
    static func dates(of sub: Subscription, from: Date, to: Date, now: Date = .now, calendar cal: Calendar = .current) -> [Date] {
        let base = anchor(of: sub, calendar: cal)
        let lower = max(from, cal.startOfDay(for: sub.startDate))
        let today = cal.startOfDay(for: now)
        let next = cal.startOfDay(for: sub.nextBillingDate)
        var n = 0
        while n > -10_000, step(sub, base, n - 1, cal) >= lower { n -= 1 }
        var result: [Date] = []
        while n < 10_000 {
            let date = step(sub, base, n, cal)
            if date >= to { break }
            if date >= lower && !(date >= today && date < next) { result.append(date) }
            n += 1
        }
        return result
    }

    /// First grid date on or after `day` (used to roll a past `nextBillingDate` forward).
    static func firstCharge(of sub: Subscription, onOrAfter day: Date, calendar cal: Calendar = .current) -> Date {
        let base = anchor(of: sub, calendar: cal)
        let target = cal.startOfDay(for: day)
        for n in 0..<10_000 {
            let date = step(sub, base, n, cal)
            if cal.startOfDay(for: date) >= target { return date }
        }
        return sub.nextBillingDate
    }

    /// `nextBillingDate` and the following `count - 1` charges.
    static func upcoming(of sub: Subscription, count: Int, calendar cal: Calendar = .current) -> [Date] {
        let base = anchor(of: sub, calendar: cal)
        let next = cal.startOfDay(for: sub.nextBillingDate)
        var result: [Date] = []
        var n = 0
        while result.count < count && n < 10_000 {
            let date = step(sub, base, n, cal)
            if cal.startOfDay(for: date) >= next { result.append(date) }
            n += 1
        }
        return result
    }
}
