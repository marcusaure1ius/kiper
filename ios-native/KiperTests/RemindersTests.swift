import Foundation
import Testing
@testable import Kiper

struct RemindersTests {
    @Test func firesDaysBeforeAtChosenTime() throws {
        let sub = makeSub(id: "n", name: "Netflix", amount: 22.99, currency: .usd, next: day(2026, 10, 20), start: day(2024, 1, 20), reminder: 3)
        let plans = Reminders.plan(subscriptions: [sub], hour: 10, minute: 30, now: day(2026, 10, 1))
        let plan = try #require(plans.first)
        #expect(plan.fireDate == Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 10, minute: 30)))
        #expect(plan.id == "sub-n-0" && plan.subscriptionId == "n")
        #expect(plans.count == Reminders.perSubscription, "a few upcoming charges get reminders")
        #expect(plan.body == "Netflix — списание через 3 дня, 22,99 $")
    }

    @Test func skipsPastReminderAndUsesNextCharge() throws {
        // Charge tomorrow, reminder 3 days before → already passed → next month's charge.
        let sub = makeSub(next: day(2026, 10, 13), start: day(2026, 1, 13), reminder: 3)
        let plans = Reminders.plan(subscriptions: [sub], hour: 10, minute: 0, now: day(2026, 10, 12, hour: 12))
        let fire = try #require(plans.first?.fireDate)
        #expect(Calendar.current.dateComponents([.month, .day], from: fire) == DateComponents(month: 11, day: 10))
    }

    @Test func excludesPausedCancelledAndDisabled() {
        let next = day(2026, 10, 20), start = day(2026, 1, 20), now = day(2026, 10, 1)
        let subs = [
            makeSub(id: "p", next: next, start: start, status: .paused),
            makeSub(id: "c", next: next, start: start, status: .cancelled),
            makeSub(id: "off", next: next, start: start, reminder: 0),
            makeSub(id: "on", next: next, start: start, reminder: 1),
        ]
        #expect(Set(Reminders.plan(subscriptions: subs, hour: 9, minute: 0, now: now).map(\.subscriptionId)) == ["on"])
    }

    @Test func tomorrowWordingAndLimit() {
        let start = day(2026, 1, 1), now = day(2026, 10, 1)
        let sub = makeSub(name: "МТС", amount: 890, next: day(2026, 10, 20), start: start, reminder: 1)
        #expect(Reminders.body(for: sub, daysBefore: 1) == "МТС — списание завтра, 890 ₽")
        let many = (0..<80).map { makeSub(id: "\($0)", next: day(2026, 10, 20), start: start) }
        #expect(Reminders.plan(subscriptions: many, hour: 9, minute: 0, now: now).count == Reminders.limit)
    }
}
