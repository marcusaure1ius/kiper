import Foundation
import Testing
@testable import Kiper

@MainActor
struct WidgetTests {
    @Test func snapshotCarriesUpcomingAndBudget() throws {
        let store = makeStore()
        let now = Date.now
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: now)!
        store.upsert(makeSub(id: "w", name: "Netflix", amount: 19.99, currency: .usd, next: nextMonth, start: now))
        store.monthlyBudgetRub = 25_000

        let snap = store.widgetSnapshot(now: now)
        #expect(snap.upcoming.first?.name == "Netflix")
        #expect(snap.upcoming.first?.currency == "USD")
        #expect(snap.budgetRub == 25_000)
        #expect(snap.monthlyTotalRub > 0)
        #expect(snap.accentHexLight == 0x6A5CF1, "default lavender accent")
        #expect(snap.accentHexDark == 0x8F84FF)
    }

    @Test func trialFirstChargeShowsUpcoming() {
        let store = makeStore()
        let inTwoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
        var sub = makeSub(id: "t", name: "Figma", amount: 600, next: inTwoWeeks, start: .now)
        sub.status = .trial
        sub.trialEndDate = inTwoWeeks
        store.upsert(sub)

        let snap = store.widgetSnapshot()
        #expect(snap.upcoming.first?.name == "Figma", "a trial's first charge is a real upcoming payment")
        #expect(snap.paidRub == 0)
    }

    @Test func snapshotRoundTripsThroughCodable() throws {
        let store = makeStore()
        // Whole seconds everywhere: the wire format (ISO 8601) drops fractions,
        // and charge dates are derived from startDate on the grid.
        let now = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded())
        let nextMonth = Date(timeIntervalSince1970: Calendar.current.date(byAdding: .month, value: 1, to: now)!.timeIntervalSince1970.rounded())
        store.upsert(makeSub(id: "c", name: "МТС", amount: 890, next: nextMonth, start: now))
        var snap = store.widgetSnapshot()
        // The wire format (ISO 8601) keeps whole seconds only.
        snap.generatedAt = Date(timeIntervalSince1970: snap.generatedAt.timeIntervalSince1970.rounded())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(snap))
        #expect(back == snap)
    }
}
