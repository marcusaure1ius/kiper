import Foundation
@testable import Kiper

func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}

func makeSub(
    id: String = UUID().uuidString, name: String = "Test", amount: Double = 100, currency: Currency = .rub,
    period: BillingPeriod = .monthly, next: Date, start: Date, status: SubscriptionStatus = .active,
    categoryId: String? = nil, reminder: Int = 1
) -> Subscription {
    Subscription(id: id, name: name, amount: amount, currency: currency, billingPeriod: period,
                 categoryId: categoryId, nextBillingDate: next, reminderDaysBefore: reminder,
                 status: status, startDate: start)
}

@MainActor
func makeStore(seed: Bool = false, file: URL? = nil) -> AppStore {
    let defaults = UserDefaults(suiteName: "kiper.tests.\(UUID().uuidString)")!
    let url = file ?? FileManager.default.temporaryDirectory.appendingPathComponent("kiper-\(UUID().uuidString).json")
    return AppStore(persistence: Persistence(url: url), defaults: defaults, seedDemoData: seed, systemReminders: false)
}
