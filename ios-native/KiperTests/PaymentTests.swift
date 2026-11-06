import Foundation
import Testing
@testable import Kiper

@MainActor
struct PaymentTests {
    @Test func missedChargesAreAutoRecorded() throws {
        let store = makeStore()
        let now = Date.now
        // Next billing was due a month ago while the app wasn't opened.
        let sub = makeSub(id: "m", amount: 300,
                          next: Calendar.current.date(byAdding: .month, value: -1, to: now)!,
                          start: Calendar.current.date(byAdding: .month, value: -2, to: now)!)
        store.upsert(sub)

        #expect(store.payments.count == 1, "the charge that slipped past is recorded automatically")
        let record = try #require(store.payments.first)
        #expect(record.subscriptionId == "m" && record.amount == 300 && record.source == .auto)
        #expect(store.subscription(id: "m")!.nextBillingDate >= Calendar.current.startOfDay(for: now))

        // Re-running the roll changes nothing — records dedupe by subscription + day.
        store.advanceBillingDates()
        #expect(store.payments.count == 1)
    }

    @Test func skippedChargeStopsCounting() {
        let store = makeStore()
        // Fixed dates: the charge grid is Oct 6 / Nov 6 / Dec 6; "now" is Nov 10.
        let sub = makeSub(id: "s", amount: 500, next: day(2026, 12, 6), start: day(2026, 10, 6))
        store.upsert(sub)
        #expect(abs(store.monthProgress(now: day(2026, 11, 10)).paid - 500) < 0.001, "inferred when no record yet")

        store.skip(sub, on: day(2026, 11, 6))
        #expect(store.monthProgress(now: day(2026, 11, 10)).paid == 0, "a skipped charge stops counting")
        #expect(store.monthlyTotals(past: 2, future: 0, now: day(2026, 11, 10)).contains { period in
            Calendar.current.isDate(period.start, equalTo: day(2026, 11, 1), toGranularity: .month) && period.amount == 0
        })
    }

    @Test func manualRecordWinsOverAutoAndKeepsPrice() throws {
        let store = makeStore()
        let now = Date.now
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        var sub = makeSub(id: "w", amount: 300,
                          next: lastMonth,
                          start: Calendar.current.date(byAdding: .month, value: -2, to: now)!)
        store.upsert(sub)
        #expect(store.payments.first?.source == .auto)

        sub.amount = 350 // the price actually charged last month
        store.markPaid(sub, on: lastMonth)
        #expect(store.payments.count == 1)
        #expect(store.payments[0].source == .manual && store.payments[0].amount == 350)

        let last = try #require(store.lastCharge(for: store.subscription(id: "w")!))
        #expect(last.amount == 350)
    }

    @Test func backfillInfersHistoryForExistingData() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiper-\(UUID().uuidString).json")
        let now = Date.now
        let start = Calendar.current.date(byAdding: .month, value: -3, to: now)!
        let sub = makeSub(id: "b", amount: 200,
                          next: Calendar.current.date(byAdding: .month, value: 1, to: now)!,
                          start: start)
        try? BackupMapper.encode(BackupMapper.file(subscriptions: [sub], categories: [])).write(to: url)

        let store = makeStore(file: url)
        #expect(store.payments.count >= 3, "a store from before payment history gets its past inferred")
        let reopened = makeStore(file: url)
        #expect(reopened.payments.count == store.payments.count, "backfill runs once — records are persisted")
    }

    @Test func cancelledSubscriptionStaysInHistory() throws {
        let store = makeStore()
        let now = Date.now
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        let sub = makeSub(id: "gone", amount: 400,
                          next: lastMonth,
                          start: Calendar.current.date(byAdding: .month, value: -2, to: now)!)
        store.upsert(sub)
        store.cancel("gone")

        let history = store.pastPayments(now: Calendar.current.date(byAdding: .day, value: 7, to: now)!)
        #expect(history.contains { $0.subscription.id == "gone" && $0.record != nil })
    }
}
