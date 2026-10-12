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

    @Test func brokenFileIsNotOverwritten() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiper-\(UUID().uuidString).json")
        try Data("{broken".utf8).write(to: url)
        let store = makeStore(file: url)
        #expect(store.loadError != nil)
        store.upsertCategory(Category(id: "c", name: "X", colorHex: 0, symbol: "star"))
        #expect(try String(contentsOf: url, encoding: .utf8) == "{broken")
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
