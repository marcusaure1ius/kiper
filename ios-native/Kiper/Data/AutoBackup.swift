import Foundation

/// Automatic backups into a folder the user picked once in Files (e.g. iCloud Drive/Кипер).
///
/// No iCloud entitlement is needed (works with a free Apple ID): access to the folder is
/// kept with a security-scoped bookmark. Each run overwrites `Кипер — копия.json` and
/// keeps one dated copy per day for the last `keepDays` days.
@MainActor
@Observable
final class AutoBackup {
    static let latestName = "Кипер — копия.json"
    static let datedPrefix = "Кипер "
    static let keepDays = 7

    private(set) var folderName: String?
    private(set) var lastBackup: Date?
    private(set) var lastError: String?

    var isEnabled: Bool { folderName != nil }

    private let defaults: UserDefaults
    private var pending: Task<Void, Never>?

    private enum Keys {
        static let bookmark = "autobackup.bookmark"
        static let last = "autobackup.last"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastBackup = defaults.object(forKey: Keys.last) as? Date
        if let url = resolve() { folderName = Self.displayName(url) }
    }

    // MARK: - Setup

    /// Remembers a folder chosen in `.fileImporter(allowedContentTypes: [.folder])`.
    func setFolder(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: Keys.bookmark)
        folderName = Self.displayName(url)
        lastError = nil
    }

    /// Name as Files shows it (the "On My iPhone" root is internally "File Provider Storage").
    private static func displayName(_ url: URL) -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if url.lastPathComponent == "File Provider Storage" { return "На iPhone" }
        return (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
    }

    func disable() {
        pending?.cancel()
        defaults.removeObject(forKey: Keys.bookmark)
        folderName = nil
        lastError = nil
    }

    private func resolve() -> URL? {
        guard let data = defaults.data(forKey: Keys.bookmark) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(fresh, forKey: Keys.bookmark)
        }
        return url
    }

    // MARK: - Writing

    /// Debounced: many quick edits produce one write.
    func schedule(_ makeFile: @escaping @MainActor () -> BackupFile) {
        guard isEnabled else { return }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            run(makeFile())
        }
    }

    @discardableResult
    func run(_ file: BackupFile, now: Date = .now) -> Bool {
        guard let folder = resolve() else {
            if isEnabled { lastError = "Нет доступа к папке — выберите её заново." }
            return false
        }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            let data = try BackupMapper.encode(file)
            try write(data, to: folder.appendingPathComponent(Self.latestName))
            try write(data, to: folder.appendingPathComponent(Self.datedName(now)))
            prune(folder, now: now)
            lastBackup = now
            defaults.set(now, forKey: Keys.last)
            lastError = nil
            return true
        } catch {
            lastError = "Не удалось сохранить копию: \(error.localizedDescription)"
            return false
        }
    }

    static func datedName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "\(datedPrefix)\(f.string(from: date)).json"
    }

    /// Coordinated write so iCloud Drive picks up the change cleanly.
    private func write(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    /// Keeps dated copies of the last `keepDays` days.
    private func prune(_ folder: URL, now: Date) {
        let keep = Set((0..<Self.keepDays).map { Self.datedName(Calendar.current.date(byAdding: .day, value: -$0, to: now)!) })
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix(Self.datedPrefix) && name != Self.latestName && name.hasSuffix(".json") && !keep.contains(name) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}
