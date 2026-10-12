import Foundation
import Testing
@testable import Kiper

@MainActor
struct ScheduleTests {
    @Test func futureChargesStartAtNextBillingDate() {
        let store = makeStore()
        let today = Calendar.current.startOfDay(for: .now)
        let next = Calendar.current.date(byAdding: .month, value: 1, to: today)!
        let sub = makeSub(next: next, start: today)
        let dates = store.billingDates(of: sub, from: today, to: Calendar.current.date(byAdding: .day, value: 40, to: today)!)
        #expect(dates == [next], "a subscription started today must not show a charge today")
    }

    @Test func historyGoesBackToStartDate() {
        let store = makeStore()
        let sub = makeSub(next: day(2026, 3, 15), start: day(2025, 12, 15))
        let dates = store.billingDates(of: sub, from: day(2025, 1, 1), to: day(2026, 3, 1))
        #expect(dates == [day(2025, 12, 15), day(2026, 1, 15), day(2026, 2, 15)])
    }

    @Test func monthlyStepsDoNotDrift() {
        let store = makeStore()
        let sub = makeSub(next: day(2025, 1, 31), start: day(2025, 1, 31))
        let dates = store.billingDates(of: sub, from: day(2025, 1, 1), to: day(2025, 5, 1))
        // Jan 31 → Feb 28 → Mar 31 (not Mar 28) → Apr 30.
        #expect(dates.map { Calendar.current.component(.day, from: $0) } == [31, 28, 31, 30])
    }

    @Test func pastDatesOfActiveSubscriptionsAreAdvanced() {
        let store = makeStore()
        let now = Calendar.current.startOfDay(for: .now)
        let past = Calendar.current.date(byAdding: .day, value: -40, to: now)!
        store.upsert(makeSub(id: "a", next: past, start: past))
        store.upsert(makeSub(id: "p", next: past, start: past, status: .paused))
        #expect(store.subscription(id: "a")!.nextBillingDate >= now)
        #expect(store.subscription(id: "p")!.nextBillingDate == past, "paused rows are left alone, like Android")
    }

    @Test func advancingKeepsMonthEnd() throws {
        let store = makeStore()
        // Started on the 31st, next charge long ago → rolled forward on the original grid.
        store.upsert(makeSub(id: "m", next: day(2025, 1, 31), start: day(2025, 1, 31)))
        let next = try #require(store.subscription(id: "m")?.nextBillingDate)
        let d = Calendar.current.component(.day, from: next)
        let lastDay = Calendar.current.range(of: .day, in: .month, for: next)!.count
        #expect(d == min(31, lastDay), "stays on the 31st (or the month's last day), no drift")
    }

    @Test func upcomingFollowsAnchor() {
        let sub = makeSub(next: day(2026, 2, 28), start: day(2026, 1, 31))
        let dates = Schedule.upcoming(of: sub, count: 3)
        #expect(dates.map { Calendar.current.component(.day, from: $0) } == [28, 31, 30])
    }

    @Test func weeklyAndCustomPeriods() {
        #expect(BillingPeriod.weekly.next(after: day(2026, 1, 1), customDays: nil) == day(2026, 1, 8))
        #expect(BillingPeriod.custom.next(after: day(2026, 1, 1), customDays: 10) == day(2026, 1, 11))
        #expect(BillingPeriod.annual.monthlyEquivalent == 1.0 / 12.0)
    }
}
