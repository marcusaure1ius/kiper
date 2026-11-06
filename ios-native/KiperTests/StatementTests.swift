import Foundation
import Testing
@testable import Kiper

struct StatementTests {
    /// A T-Bank-style export: date, amount, description — different decimal
    /// styles, card masks and legal forms in the merchant column.
    static let tbankCSV = """
    Дата операции;Сумма;Описание
    01.09.2026 12:04:11;-890,00;ООО "МТС" (CARD 4111 **** 1234)
    05.09.2026 09:15:00;-19 590,00;Ноутбук ASUS
    01.10.2026 12:11:37;-890,00;ООО "МТС" (CARD 4111 **** 1234)
    02.10.2026 18:40:02;-1 250,50;Пятёрочка
    01.11.2026 12:09:58;-890,00;ООО "МТС" (CARD 4111 **** 1234)
    03.11.2026 20:02:41;-2 340;ЯНДЕКС.ПЛЮС
    """

    @Test func detectsRecurringMerchant() throws {
        let candidates = StatementImporter.parse(Self.tbankCSV)
        let mts = try #require(candidates.first { $0.name.contains("МТС") })
        #expect(mts.occurrences.count == 3)
        #expect(mts.medianAmount == 890)
        #expect(mts.medianIntervalDays == 30, "statement timestamps are 12:04 → 12:11 → 12:09")
        #expect(Calendar.current.dateComponents([.day], from: mts.lastDate, to: day(2026, 11, 1)).day == 0)
        #expect(mts.billingPeriod.period == .monthly)
    }

    @Test func ignoresOneOffsAndPriceSpikes() {
        let candidates = StatementImporter.parse(Self.tbankCSV)
        #expect(!candidates.contains { $0.name.contains("Ноутбук") })
        #expect(!candidates.contains { $0.name.contains("Пятёрочка") })

        // Three occurrences, but one amount is way off the median → not a candidate.
        let spiky = """
        Дата;Сумма;Описание
        01.09.2026;-500;Спортзал
        01.10.2026;-500;Спортзал
        15.10.2026;-5000;Спортзал
        01.11.2026;-500;Спортзал
        """
        #expect(StatementImporter.parse(spiky).isEmpty)
    }

    @Test func weeklyAndAnnualIntervals() {
        let weekly = """
        Дата;Сумма;Описание
        01.09.2026;-299;Кинотеатр
        08.09.2026;-299;Кинотеатр
        15.09.2026;-299;Кинотеатр
        22.09.2026;-299;Кинотеатр
        """
        let found = StatementImporter.parse(weekly)
        #expect(found.first?.billingPeriod.period == .weekly)
        #expect(found.first?.medianIntervalDays == 7)

        let annual = """
        Дата;Сумма;Описание
        01.09.2023;-3990;Хранилище
        01.09.2024;-3990;Хранилище
        01.09.2025;-3990;Хранилище
        01.09.2026;-3990;Хранилище
        """
        let yearly = StatementImporter.parse(annual)
        #expect(yearly.first?.billingPeriod.period == .annual)
        #expect(yearly.first?.medianIntervalDays == 365)
    }

    @Test func merchantNormalizationDropsNoise() {
        #expect(StatementImporter.normalize("ООО \"ЯНДЕКС.ТАКСИ\" (CARD 4111 **** 1234)") == "ЯНДЕКС.ТАКСИ")
        #expect(StatementImporter.normalize("ПОКУПКА ИП Смирнов А.А.") == "СМИРНОВ А.А")
    }

    @Test func numberParsesBothStyles() {
        #expect(StatementImporter.number(from: "1 234,56") == 1234.56)
        #expect(StatementImporter.number(from: "-1234.56") == 1234.56)
        #expect(StatementImporter.number(from: "(500,00)") == 500)
        #expect(StatementImporter.number(from: "abc") == nil)
    }

    @MainActor
    @Test func createFromCandidateBackfillsHistory() throws {
        let store = makeStore()
        let candidate = StatementCandidate(
            id: "МТС", name: "МТС",
            occurrences: [StatementOccurrence(date: day(2026, 9, 1), amount: 890),
                          StatementOccurrence(date: day(2026, 10, 1), amount: 890),
                          StatementOccurrence(date: day(2026, 11, 1), amount: 890)],
            medianAmount: 890, medianIntervalDays: 31)

        let sub = store.createFromCandidate(candidate, now: day(2026, 11, 6))
        #expect(sub.billingPeriod == .monthly)
        #expect(sub.nextBillingDate == day(2026, 12, 1), "next charge after the last seen one")
        let history = store.payments.filter { $0.subscriptionId == sub.id }
        #expect(history.count == 3 && history.allSatisfy { $0.source == .bank })
        #expect(abs(store.monthProgress(now: day(2026, 11, 6)).paid - 890) < 0.001, "the Nov 1 charge is this month's paid part")
    }

    @MainActor
    @Test func attachToExistingSubscription() throws {
        let store = makeStore()
        let existing = makeSub(id: "mts", name: "МТС", amount: 890, next: day(2026, 11, 13), start: day(2026, 1, 13))
        store.upsert(existing)
        let candidate = StatementCandidate(
            id: "МТС", name: "МТС",
            occurrences: [StatementOccurrence(date: day(2026, 10, 1), amount: 890),
                          StatementOccurrence(date: day(2026, 11, 1), amount: 890),
                          StatementOccurrence(date: day(2026, 12, 1), amount: 890)],
            medianAmount: 890, medianIntervalDays: 31)

        store.attachStatement(candidate, to: "mts", now: day(2026, 12, 6))
        #expect(store.payments.filter { $0.subscriptionId == "mts" && $0.source == .bank }.count == 3)
        // The bank knows a Dec 1 charge we didn't: the grid moves to the bank's truth.
        let updated = try #require(store.subscription(id: "mts"))
        #expect(updated.nextBillingDate == day(2027, 1, 1))
    }
}
