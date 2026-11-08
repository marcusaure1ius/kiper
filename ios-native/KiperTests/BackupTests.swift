import Foundation
import Testing
@testable import Kiper

@MainActor
struct BackupTests {
    /// A file as written by the Android app (`ExportImportHelper.exportJson`).
    static let androidJSON = """
    {
      "version": 1,
      "exportedAt": "2026-10-01T12:30:00.123456",
      "subscriptions": [
        {"id": "test-1", "name": "Netflix", "icon": null, "amount": 22.99, "currency": "USD",
         "billingPeriod": "monthly", "customPeriodDays": null, "categoryId": "cat-streaming",
         "nextBillingDate": "2026-10-17T00:00:00.000", "startDate": "2024-03-01T00:00:00.000",
         "status": "active", "reminderDaysBefore": 3, "note": "family, plan",
         "createdAt": "2026-01-01T09:00:00.000"},
        {"id": "x", "name": "Gym", "amount": 3500, "currency": "RUB", "billingPeriod": "custom",
         "customPeriodDays": 28, "categoryId": "cat-missing",
         "nextBillingDate": "2026-10-20T00:00:00.000", "startDate": "2026-01-01T00:00:00.000",
         "status": "paused"}
      ],
      "categories": [
        {"id": "cat-streaming", "name": "Стриминг", "color": 4286336511, "icon": "movie"},
        {"id": "cat-books", "name": "Книги", "color": 4280391411, "icon": "book"}
      ],
      "settings": {}
    }
    """

    @Test func decodesAndroidBackup() throws {
        let file = try BackupMapper.decode(Data(Self.androidJSON.utf8))
        #expect(file.subscriptions.count == 2)
        #expect(file.payments == nil, "Android files predate payment history")
        let netflix = try #require(BackupMapper.subscription(file.subscriptions[0]))
        #expect(netflix.currency == .usd)
        #expect(netflix.reminderDaysBefore == 3)
        #expect(netflix.domain == "netflix.com", "domain is recovered from the catalog by name")
        #expect(Calendar.current.dateComponents([.year, .month, .day], from: netflix.nextBillingDate) == DateComponents(year: 2026, month: 10, day: 17))
        let gym = try #require(BackupMapper.subscription(file.subscriptions[1]))
        #expect(gym.billingPeriod == .custom && gym.customPeriodDays == 28 && gym.status == .paused)
        let streaming = BackupMapper.category(file.categories[0])
        #expect(streaming.colorHex == 0x7C4DFF)
        #expect(streaming.symbol == "play.tv.fill")
        #expect(BackupMapper.category(file.categories[1]).symbol == "book.fill")
    }

    @Test func exportIsReadableByAndroidShape() throws {
        let cat = Category(id: "c", name: "Кино", colorHex: 0x7C4DFF, symbol: "play.tv.fill")
        let sub = makeSub(id: "s", name: "Кинопоиск", amount: 269, next: day(2026, 11, 1), start: day(2025, 1, 1), categoryId: "c")
        let data = try BackupMapper.encode(BackupMapper.file(subscriptions: [sub], categories: [cat]))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == 1)
        let c = try #require((json["categories"] as? [[String: Any]])?.first)
        #expect(c["color"] as? Int == 0xFF7C4DFF)
        #expect(c["icon"] as? String == "movie", "SF Symbol is mapped back to the Material name")
        let s = try #require((json["subscriptions"] as? [[String: Any]])?.first)
        #expect(s["nextBillingDate"] as? String == "2026-11-01T00:00:00.000", "Dart DateTime.parse format")
        #expect(s["billingPeriod"] as? String == "monthly")
    }

    @Test func roundTrip() throws {
        let original = BackupMapper.file(
            subscriptions: SeedData.subscriptions(now: day(2026, 10, 12)),
            categories: SeedData.categories,
            now: day(2026, 10, 12, hour: 9)
        )
        let decoded = try BackupMapper.decode(BackupMapper.encode(original))
        #expect(decoded == original)
    }

    @Test func plainDatesAreLocal() throws {
        let d = try #require(BackupMapper.date(from: "2026-10-13"))
        #expect(Calendar.current.dateComponents([.year, .month, .day, .hour], from: d) == DateComponents(year: 2026, month: 10, day: 13, hour: 0))
        let utc = try #require(BackupMapper.date(from: "2026-10-13T00:00:00Z"))
        #expect(utc.timeIntervalSince1970 == 1_791_849_600)
    }

    @Test func rejectsNewerVersion() {
        #expect(throws: BackupError.unsupportedVersion(2)) {
            try BackupMapper.decode(Data(#"{"version": 2, "exportedAt": "", "subscriptions": [], "categories": []}"#.utf8))
        }
        #expect(throws: BackupError.unreadable) { try BackupMapper.decode(Data("not json".utf8)) }
    }

    @Test func replaceAndMergeImport() throws {
        let store = makeStore(seed: true)
        let file = try BackupMapper.decode(Data(Self.androidJSON.utf8))

        let merged = store.importBackup(file, mode: .merge)
        #expect(merged.subscriptions == 2)
        #expect(store.subscriptions.count == 27, "26 seeded (test-1 updated in place) + 1 new")
        #expect(store.subscription(id: "test-1")?.reminderDaysBefore == 3)
        #expect(store.subscription(id: "x")?.categoryId == nil, "link to a missing category is dropped")

        store.importBackup(file, mode: .replace)
        #expect(store.subscriptions.count == 2)
        #expect(store.categories.map(\.id) == ["cat-streaming", "cat-books"])
    }

    @Test func paymentsRoundTripThroughBackup() throws {
        let record = PaymentRecord(subscriptionId: "p", date: day(2026, 11, 1), amount: 22.99,
                                   currency: .usd, amountRub: 2069.1, kind: .charge, source: .manual)
        let skipped = PaymentRecord(subscriptionId: "p", date: day(2026, 12, 1), amount: 22.99,
                                    currency: .usd, amountRub: 2069.1, kind: .skip, source: .bank)
        let sub = makeSub(id: "p", amount: 22.99, currency: .usd, next: day(2027, 1, 1), start: day(2026, 1, 1))
        let data = try BackupMapper.encode(BackupMapper.file(subscriptions: [sub], categories: [], payments: [record, skipped]))

        let file = try BackupMapper.decode(data)
        #expect(file.payments?.count == 2)
        #expect(BackupMapper.payment(file.payments![0]) == record)
        #expect(BackupMapper.payment(file.payments![1]) == skipped)
    }

    @Test func trialRoundTripsThroughBackup() throws {
        var sub = makeSub(id: "t", name: "Figma", amount: 600, next: day(2026, 12, 1), start: day(2026, 11, 1))
        sub.status = .trial
        sub.trialEndDate = day(2026, 12, 1)
        let data = try BackupMapper.encode(BackupMapper.file(subscriptions: [sub], categories: []))

        let dto = try BackupMapper.decode(data).subscriptions[0]
        #expect(dto.status == "trial" && dto.trialEndDate == "2026-12-01T00:00:00.000")
        let model = try #require(BackupMapper.subscription(dto))
        #expect(model.status == .trial)
        #expect(model.trialEndDate == day(2026, 12, 1))
    }

    @Test func unknownEnumValuesFallBack() throws {
        // A newer app may write values this version doesn't know; the import must
        // degrade gracefully (same rule as Android / web).
        let json = """
        {"version": 1, "exportedAt": "", "subscriptions": [
          {"id": "x", "name": "X", "amount": 5, "currency": "GBP", "billingPeriod": "biweekly",
           "nextBillingDate": "2026-12-01T00:00:00.000", "startDate": "2026-01-01T00:00:00.000",
           "status": "archived"}],
         "categories": [], "payments": [
          {"subscriptionId": "x", "date": "2026-11-13T00:00:00.000", "amount": 5, "currency": "CHF",
           "amountRub": 450, "kind": "refund", "source": "carrier"}]}
        """
        let file = try BackupMapper.decode(Data(json.utf8))
        let sub = try #require(BackupMapper.subscription(file.subscriptions[0]))
        #expect(sub.currency == .rub)
        #expect(sub.billingPeriod == .monthly)
        #expect(sub.status == .active)
        #expect(sub.reminderDaysBefore == 1, "missing optional field takes the default")
        let dto = try #require(file.payments?.first)
        let payment = try #require(BackupMapper.payment(dto))
        #expect(payment.kind == .charge && payment.source == .auto && payment.currency == .rub)
    }

    @Test func offsetZoneDatesAreInstants() throws {
        let d = try #require(BackupMapper.date(from: "2026-10-13T12:00:00+05:00"))
        #expect(d.timeIntervalSince1970 == 1_791_874_800, "07:00 UTC — absolute, not device-local")
    }

    @Test func spaceSeparatedDatesAreLocal() throws {
        let d = try #require(BackupMapper.date(from: "2026-10-13 12:30:00"))
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        #expect(comps == DateComponents(year: 2026, month: 10, day: 13, hour: 12, minute: 30))
    }

    @Test func versionlessFileIsAccepted() throws {
        // A minimal file without a version key predates versioning — accept it.
        let json = #"{"exportedAt": "", "subscriptions": [], "categories": [], "settings": {}}"#
        let file = try BackupMapper.decode(Data(json.utf8))
        #expect(file.subscriptions.isEmpty)
    }

    @Test func settingsWithNonStringValuesDoNotBreakImport() throws {
        // Android historically wrote numbers/booleans into settings.
        let json = #"{"version": 1, "exportedAt": "", "subscriptions": [], "categories": [], "settings": {"budgetRub": 12000, "flag": true}}"#
        let file = try BackupMapper.decode(Data(json.utf8))
        #expect(file.settings.isEmpty, "unreadable settings are dropped, the file still imports")
    }

    @Test func oneBrokenPaymentRowDropsOnlyItself() throws {
        let json = """
        {"version": 1, "exportedAt": "", "subscriptions": [], "categories": [],
         "payments": [
           {"subscriptionId": "p", "date": "2026-11-01T00:00:00.000", "amount": "22.99",
            "currency": "USD", "amountRub": 2069.1, "kind": "charge", "source": "manual"},
           {"subscriptionId": "q", "date": "2026-11-02T00:00:00.000", "amount": 9.99,
            "currency": "EUR", "amountRub": 947.8, "kind": "charge", "source": "auto"}]}
        """
        let file = try BackupMapper.decode(Data(json.utf8))
        #expect(file.payments?.count == 1, "the amount-as-string row is skipped, the history survives")
        #expect(file.payments?.first?.subscriptionId == "q")
    }
}
