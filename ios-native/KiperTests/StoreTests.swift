import Foundation
import Testing
@testable import Kiper

@MainActor
struct StoreTests {
    @Test func firstLaunchSeedsCategoriesOnly() {
        let store = makeStore(seed: false)
        #expect(store.categories.count == 5)
        #expect(store.subscriptions.isEmpty)
    }

    @Test func persistsAcrossLaunches() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiper-\(UUID().uuidString).json")
        let first = makeStore(file: url)
        let future = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        first.upsert(makeSub(id: "keep", name: "Figma", amount: 1200, next: future, start: .now))
        first.upsertCategory(Category(id: "cat-x", name: "Работа", colorHex: 0x00C853, symbol: "briefcase.fill"))

        let second = makeStore(file: url)
        #expect(second.subscription(id: "keep")?.name == "Figma")
        #expect(second.category(for: "cat-x")?.symbol == "briefcase.fill")
    }

    @Test func brokenFileIsKeptAsideAndAppKeepsWorking() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kiper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("kiper.json")
        try Data("{broken".utf8).write(to: url)

        let store = makeStore(file: url)
        #expect(store.loadError?.contains("kiper.broken-") == true)
        let copies = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("kiper.broken-") }
        #expect(copies.count == 1)
        #expect(try String(contentsOf: dir.appendingPathComponent(copies[0]), encoding: .utf8) == "{broken")

        store.upsertCategory(Category(id: "c", name: "X", colorHex: 0, symbol: "star"))
        #expect(makeStore(file: url).category(for: "c") != nil, "new edits are saved")
    }

    @Test func unreadableRowsSurviveSave() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiper-\(UUID().uuidString).json")
        let json = #"{"version":1,"exportedAt":"","categories":[],"subscriptions":[{"id":"bad","name":"Bad","amount":1,"currency":"RUB","billingPeriod":"monthly","nextBillingDate":"not a date","startDate":"also not"}]}"#
        try Data(json.utf8).write(to: url)
        let store = makeStore(file: url)
        #expect(store.subscriptions.isEmpty)
        store.upsertCategory(Category(id: "c", name: "X", colorHex: 0, symbol: "star"))
        let saved = try BackupMapper.decode(Data(contentsOf: url))
        #expect(saved.subscriptions.map(\.id) == ["bad"])
    }

    @Test func csvImportKeepsLogoAndCreationDate() {
        let store = makeStore(seed: true)
        let created = store.subscription(id: "test-1")!.createdAt
        store.importCSV(CSVCodec.encode(store.subscriptions))
        #expect(store.subscription(id: "test-1")?.domain == "netflix.com")
        // The backup format stores milliseconds.
        #expect(abs(store.subscription(id: "test-1")!.createdAt.timeIntervalSince(created)) < 0.001)
    }

    @Test func deletingCategoryDetachesSubscriptions() {
        let store = makeStore(seed: true)
        store.deleteCategory("cat-ai")
        #expect(store.category(for: "cat-ai") == nil)
        #expect(!store.subscriptions.contains { $0.categoryId == "cat-ai" })
    }

    @Test func cancelIsSoftDelete() {
        let store = makeStore(seed: true)
        store.cancel("test-1")
        #expect(store.subscription(id: "test-1")?.status == .cancelled)
        #expect(!store.active.contains { $0.id == "test-1" })
    }

    @Test func monthlyTotalUsesRatesAndPeriods() {
        let store = makeStore()
        let future = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        store.upsert(makeSub(amount: 10, currency: .usd, next: future, start: .now))           // 900
        store.upsert(makeSub(amount: 1200, period: .annual, next: future, start: .now))         // 100
        #expect(abs(store.monthlyTotalRub - 1000) < 0.001)
    }
}
