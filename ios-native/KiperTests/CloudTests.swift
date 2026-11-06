import CloudKit
import Foundation
import Testing
@testable import Kiper

struct CloudTests {
    private func record(for sub: Subscription) -> CKRecord { CloudSync.record(for: sub) }

    @Test func subscriptionRoundTripsThroughRecord() throws {
        var sub = makeSub(id: "s-1", name: "Netflix", amount: 22.99, currency: .usd,
                          period: .monthly, next: day(2026, 12, 6), start: day(2026, 1, 6),
                          categoryId: "cat-streaming")
        sub.status = .trial
        sub.trialEndDate = day(2026, 12, 6)
        sub.note = "family plan"
        sub.domain = "netflix.com"

        let back = try #require(CloudSync.subscription(from: record(for: sub)))
        #expect(back == sub)
        #expect(record(for: sub).recordID.recordName == "s-1", "recordName is the local id")
    }

    @Test func categoryAndPaymentRoundTrip() throws {
        let cat = Category(id: "c-1", name: "Стриминг", colorHex: 0x7C4DFF, symbol: "play.tv.fill")
        #expect(CloudSync.category(from: CloudSync.record(for: cat)) == cat)

        let payment = PaymentRecord(subscriptionId: "s-1", date: day(2026, 11, 6), amount: 22.99,
                                    currency: .usd, amountRub: 2069.1, kind: .skip, source: .bank)
        #expect(CloudSync.payment(from: CloudSync.record(for: payment)) == payment)
    }

    @Test func corruptRecordsAreSkippedNotFatal() {
        let junk = CKRecord(recordType: CloudSync.RecordType.subscription, recordID: .init(recordName: "junk", zoneID: CloudSync.zone))
        junk["amount"] = 1.0 // name/date missing
        #expect(CloudSync.subscription(from: junk) == nil)
    }

    @MainActor
    @Test func pullMergeUpsertsAndHonorsTombstones() throws {
        let store = makeStore()
        let local = makeSub(id: "keep", name: "Локальная", amount: 100, next: day(2027, 1, 6), start: day(2026, 1, 6))
        let localCat = Category(id: "cat-gone", name: "Удалённая", colorHex: 0xFF0000, symbol: "trash")
        store.upsert(local)
        store.upsertCategory(localCat)
        store.cloudEngine = CloudSyncEngine(defaults: UserDefaults(suiteName: "kiper.tests.\(UUID().uuidString)")!)
        store.deleteCategory("cat-gone")

        let incomingCat = Category(id: "cat-gone", name: "Удалённая", colorHex: 0xFF0000, symbol: "trash")
        let incomingSub = makeSub(id: "keep", name: "Обновлённая с другого устройства", amount: 200,
                                  next: day(2027, 1, 6), start: day(2026, 1, 6))
        let incomingNew = makeSub(id: "from-other", name: "С планшета", amount: 50, next: day(2027, 2, 6), start: day(2026, 2, 6))
        let incomingPayment = PaymentRecord(subscriptionId: "from-other", date: day(2026, 12, 6), amount: 50,
                                            currency: .rub, amountRub: 50)

        CloudSync.merge(subscriptions: [incomingSub, incomingNew], categories: [incomingCat],
                        payments: [incomingPayment], categoryTombstones: ["cat-gone"], into: store)
        store.finishCloudMerge()

        #expect(store.subscription(id: "keep")?.name == "Обновлённая с другого устройства", "id-upsert")
        #expect(store.subscription(id: "from-other") != nil)
        #expect(store.payments.contains { $0.id == incomingPayment.id })
        #expect(store.category(for: "cat-gone") == nil, "tombstoned category must not resurrect")
    }
}
