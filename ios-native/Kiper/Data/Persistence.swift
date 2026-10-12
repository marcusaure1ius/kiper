import Foundation

/// Local storage: one JSON file in Application Support, in the same format as
/// backups. The data set is small (dozens of rows), so a whole-file atomic write
/// on each change is simpler and safer than a database.
struct Persistence: Sendable {
    let url: URL

    static let live: Persistence = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return Persistence(url: dir.appendingPathComponent("kiper.json"))
    }()

    /// `nil` on first launch (no file yet). Throws when the file exists but is broken.
    func load() throws -> BackupFile? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try BackupMapper.decode(Data(contentsOf: url))
    }

    func save(_ file: BackupFile) throws {
        try BackupMapper.encode(file).write(to: url, options: [.atomic, .completeFileProtection])
    }
}
