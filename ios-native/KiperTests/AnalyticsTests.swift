import Foundation
import Testing
@testable import Kiper

@MainActor
struct AnalyticsTests {
    @Test func monthOverMonthComparesSameSpan() throws {
        let store = makeStore()
        // Grid: Oct 6 / Nov 6 / Dec 6.
        let sub = makeSub(id: "m", amount: 500, next: day(2026, 12, 6), start: day(2026, 10, 6))
        store.upsert(sub)

        let delta = try #require(store.monthOverMonth(now: day(2026, 11, 10)))
        #expect(abs(delta.current - 500) < 0.001, "the Nov 6 charge is inside the span")
        #expect(abs(delta.previous - 500) < 0.001, "Oct 6 falls inside the same span last month")
        #expect(abs(delta.delta) < 0.001)

        // A skipped charge last month shows as a drop.
        store.skip(sub, on: day(2026, 10, 6))
        let after = try #require(store.monthOverMonth(now: day(2026, 11, 10)))
        #expect(after.previous == 0 && abs(after.delta - 500) < 0.001)
    }

    @Test func monthOverMonthHiddenWithoutLastMonth() {
        let store = makeStore()
        let future = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        store.upsert(makeSub(amount: 500, next: future, start: .now))
        #expect(store.monthOverMonth() == nil)
    }

    @Test func annualForecastRanksTopSpenders() {
        let store = makeStore()
        let future = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        store.upsert(makeSub(id: "big", name: "Big", amount: 10, currency: .usd, next: future, start: .now))   // 900/мес → 10800/год
        store.upsert(makeSub(id: "small", name: "Small", amount: 1000, period: .annual, next: future, start: .now)) // 83/мес → 1000/год
        store.upsert(makeSub(id: "mid", name: "Mid", amount: 500, next: future, start: .now))                    // 500/мес → 6000/год

        let forecast = store.annualForecast()
        #expect(abs(forecast.totalRub - 17_800) < 0.001)
        #expect(forecast.top.map(\.subscription.id) == ["big", "mid", "small"])
    }

    @Test func findsDuplicatesByDomainAndName() {
        let store = makeStore()
        let now = Date.now
        let future = Calendar.current.date(byAdding: .month, value: 1, to: now)!

        var a = makeSub(id: "a", name: "Netflix", amount: 22.99, currency: .usd, next: future, start: now, categoryId: "c1")
        a.domain = "netflix.com"
        var b = makeSub(id: "b", name: "Netflix Premium", amount: 29.99, currency: .usd, next: future, start: now, categoryId: "c1")
        b.domain = "netflix.com"
        let other = makeSub(id: "o", name: "Claude Pro", amount: 20, currency: .usd, next: future, start: now, categoryId: "c2")
        var pro = makeSub(id: "p", name: "Claude Pro Max", amount: 100, currency: .usd, next: future, start: now, categoryId: "c2")
        pro.domain = "anthropic.com"
        let unrelated = makeSub(id: "u", name: "МТС", amount: 890, next: future, start: now, categoryId: "c3")
        store.upsert(a); store.upsert(b); store.upsert(other); store.upsert(pro); store.upsert(unrelated)

        let groups = store.duplicateGroups()
        #expect(groups.count == 2)
        #expect(groups.contains { $0.map(\.id) == ["a", "b"] }, "same domain groups first")
        #expect(groups.contains { Set($0.map(\.id)) == ["o", "p"] }, "name containment within a category")
        #expect(!groups.flatMap(\.self).contains { $0.id == "u" })
    }
}
