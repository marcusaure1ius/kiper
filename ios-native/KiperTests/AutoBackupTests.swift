import Foundation
import Testing
@testable import Kiper

@MainActor
struct AutoBackupTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiper-backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func writesLatestAndDatedCopiesReadableByImport() throws {
        let dir = try folder()
        let backup = AutoBackup(defaults: UserDefaults(suiteName: "ab.\(UUID().uuidString)")!)
        try backup.setFolder(dir)
        #expect(backup.isEnabled && backup.folderName == dir.lastPathComponent)

        let file = BackupMapper.file(subscriptions: SeedData.subscriptions(now: day(2026, 10, 13)), categories: SeedData.categories)
        #expect(backup.run(file, now: day(2026, 10, 13, hour: 12)))

        let latest = try BackupMapper.decode(Data(contentsOf: dir.appendingPathComponent(AutoBackup.latestName)))
        #expect(latest.subscriptions.count == 26)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Кипер 2026-10-13.json").path))
    }

    @Test func keepsOnlyLastWeekOfDatedCopies() throws {
        let dir = try folder()
        let backup = AutoBackup(defaults: UserDefaults(suiteName: "ab.\(UUID().uuidString)")!)
        try backup.setFolder(dir)
        let file = BackupMapper.file(subscriptions: [], categories: SeedData.categories)
        for d in 1...10 { backup.run(file, now: day(2026, 10, d, hour: 12)) }
        let dated = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0 != AutoBackup.latestName }.sorted()
        #expect(dated.count == AutoBackup.keepDays)
        #expect(dated.first == "Кипер 2026-10-04.json" && dated.last == "Кипер 2026-10-10.json")
    }

    @Test func storeBacksUpAfterChanges() async throws {
        let dir = try folder()
        let store = makeStore()
        try store.autoBackup.setFolder(dir)
        store.upsertCategory(Category(id: "c", name: "Работа", colorHex: 0x00C853, symbol: "briefcase.fill"))
        try await Task.sleep(for: .seconds(2.5))
        let latest = try BackupMapper.decode(Data(contentsOf: dir.appendingPathComponent(AutoBackup.latestName)))
        #expect(latest.categories.contains { $0.id == "c" })
    }

    @Test func disableForgetsFolder() throws {
        let defaults = UserDefaults(suiteName: "ab.\(UUID().uuidString)")!
        let backup = AutoBackup(defaults: defaults)
        try backup.setFolder(try folder())
        backup.disable()
        #expect(!backup.isEnabled)
        #expect(!AutoBackup(defaults: defaults).isEnabled)
    }
}
