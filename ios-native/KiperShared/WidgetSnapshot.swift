import Foundation

/// Everything a widget needs, written by the app into the shared App Group
/// container on every data change. Kept tiny on purpose — the widget never
/// reads the full store file.
struct WidgetSnapshot: Codable, Equatable {
    static let appGroupId = "group.ru.kiper"

    /// Upcoming charges, soonest first (up to three).
    var upcoming: [Charge]
    /// Steady-state monthly spending in RUB.
    var monthlyTotalRub: Double
    /// Already charged this month / still to come (RUB).
    var paidRub: Double
    var remainingRub: Double
    /// Monthly budget, when set.
    var budgetRub: Double?
    /// Palette accent as 0xRRGGBB, so widgets match the app tint in both themes.
    var accentHexLight: UInt32
    var accentHexDark: UInt32
    var generatedAt: Date

    struct Charge: Codable, Equatable {
        var name: String
        var domain: String?
        var date: Date
        var amount: Double
        var currency: String
    }

    // MARK: - App Group I/O

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent("widget-snapshot.json")
    }

    /// Silently does nothing when the App Group container is unavailable
    /// (tests, or the entitlement is missing).
    static func store(_ snapshot: WidgetSnapshot) {
        guard let url = containerURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let url = containerURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
