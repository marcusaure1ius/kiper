import Foundation
import UIKit

/// Backup / storage format. Same shape as `BackupData` in the Android app
/// (`lib/features/settings/widgets/export_import_section.dart`), so files move
/// between platforms both ways. iOS-only fields (`domain`) are extra keys that
/// Android simply ignores.
struct BackupFile: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: String
    var subscriptions: [SubscriptionDTO]
    var categories: [CategoryDTO]
    var settings: [String: String]

    init(version: Int = BackupFile.currentVersion, exportedAt: String, subscriptions: [SubscriptionDTO], categories: [CategoryDTO], settings: [String: String] = [:]) {
        self.version = version
        self.exportedAt = exportedAt
        self.subscriptions = subscriptions
        self.categories = categories
        self.settings = settings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        guard version <= Self.currentVersion else { throw BackupError.unsupportedVersion(version) }
        exportedAt = try c.decodeIfPresent(String.self, forKey: .exportedAt) ?? ""
        subscriptions = try c.decodeIfPresent([SubscriptionDTO].self, forKey: .subscriptions) ?? []
        categories = try c.decodeIfPresent([CategoryDTO].self, forKey: .categories) ?? []
        // Android writes `{}` today; tolerate any non-string values.
        settings = (try? c.decodeIfPresent([String: String].self, forKey: .settings)) ?? [:]
    }
}

struct SubscriptionDTO: Codable, Equatable {
    var id: String
    var name: String
    var icon: String?
    var amount: Double
    var currency: String
    var billingPeriod: String
    var customPeriodDays: Int?
    var categoryId: String?
    var nextBillingDate: String
    var startDate: String
    var status: String?
    var reminderDaysBefore: Int?
    var note: String?
    var createdAt: String?
    var domain: String?
}

struct CategoryDTO: Codable, Equatable {
    var id: String
    var name: String
    /// ARGB int, e.g. 0xFF7C4DFF.
    var color: Int
    /// Material icon name (Android) or SF Symbol name (iOS).
    var icon: String
}

enum BackupError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v): "Файл из более новой версии приложения (формат \(v))."
        case .unreadable: "Не удалось прочитать файл. Нужен JSON или CSV, экспортированный из Кипера."
        }
    }
}

// MARK: - Mapping

enum BackupMapper {
    /// Dart's `DateTime.toIso8601String()` for local times: `2024-03-01T00:00:00.000`.
    private static let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return f
    }()

    static func string(from date: Date) -> String { localFormatter.string(from: date) }

    /// Accepts Dart local ISO strings (with or without millis/micros), plain dates
    /// and full ISO 8601 with a zone.
    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        // Only strings that carry a zone are absolute; everything else is local time
        // (a bare "2026-10-13" must not become UTC midnight = previous day west of UTC).
        if trimmed.range(of: #"(Z|[+-]\d{2}:?\d{2})$"#, options: .regularExpression) != nil, trimmed.count > 10 {
            if let d = try? Date(trimmed, strategy: .iso8601) { return d }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: trimmed) { return d }
        }
        // Local time without zone; Dart may emit 3 or 6 fractional digits (keep millis).
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for (format, length) in [("yyyy-MM-dd'T'HH:mm:ss.SSS", 23), ("yyyy-MM-dd'T'HH:mm:ss", 19), ("yyyy-MM-dd HH:mm:ss", 19)] {
            f.dateFormat = format
            if let d = f.date(from: String(trimmed.prefix(length))) { return d }
        }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(trimmed.prefix(10)))
    }

    static func dto(_ s: Subscription) -> SubscriptionDTO {
        SubscriptionDTO(
            id: s.id, name: s.name, icon: s.icon, amount: s.amount, currency: s.currency.rawValue,
            billingPeriod: s.billingPeriod.rawValue, customPeriodDays: s.customPeriodDays,
            categoryId: s.categoryId, nextBillingDate: string(from: s.nextBillingDate),
            startDate: string(from: s.startDate), status: s.status.rawValue,
            reminderDaysBefore: s.reminderDaysBefore, note: s.note,
            createdAt: string(from: s.createdAt), domain: s.domain
        )
    }

    static func subscription(_ d: SubscriptionDTO) -> Subscription? {
        guard let next = date(from: d.nextBillingDate), let start = date(from: d.startDate) else { return nil }
        return Subscription(
            id: d.id, name: d.name, amount: d.amount,
            currency: Currency(rawValue: d.currency.uppercased()) ?? .rub,
            billingPeriod: BillingPeriod(rawValue: d.billingPeriod) ?? .monthly,
            customPeriodDays: d.customPeriodDays, categoryId: d.categoryId,
            nextBillingDate: next, reminderDaysBefore: d.reminderDaysBefore ?? 1,
            status: d.status.flatMap(SubscriptionStatus.init(rawValue:)) ?? .active,
            startDate: start, note: d.note,
            domain: d.domain ?? CatalogEntry.all.first { $0.name.caseInsensitiveCompare(d.name) == .orderedSame }?.domain,
            createdAt: d.createdAt.flatMap(date(from:)) ?? .now,
            icon: d.icon
        )
    }

    static func dto(_ c: Category) -> CategoryDTO {
        CategoryDTO(id: c.id, name: c.name, color: Int(0xFF00_0000 | c.colorHex), icon: IconMap.material(for: c.symbol))
    }

    static func category(_ d: CategoryDTO) -> Category {
        Category(id: d.id, name: d.name, colorHex: UInt32(truncatingIfNeeded: d.color) & 0xFF_FFFF, symbol: IconMap.symbol(for: d.icon))
    }

    static func file(subscriptions: [Subscription], categories: [Category], settings: [String: String] = [:], now: Date = .now) -> BackupFile {
        BackupFile(
            exportedAt: string(from: now),
            subscriptions: subscriptions.map(dto),
            categories: categories.map(dto),
            settings: settings
        )
    }

    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        do {
            return try JSONDecoder().decode(BackupFile.self, from: data)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.unreadable
        }
    }
}

/// Material icon names used by the Android app ↔ SF Symbols used here.
enum IconMap {
    private static let pairs: [(material: String, symbol: String)] = [
        ("movie", "play.tv.fill"),
        ("smart_toy", "sparkles"),
        ("phone_android", "antenna.radiowaves.left.and.right"),
        ("sports_esports", "gamecontroller.fill"),
        ("category", "square.grid.2x2.fill"),
        ("music_note", "music.note"),
        ("book", "book.fill"),
        ("cloud", "cloud.fill"),
        ("security", "lock.shield.fill"),
        ("shopping_bag", "bag.fill"),
    ]

    static let fallbackSymbol = "square.grid.2x2.fill"

    static func material(for symbol: String) -> String {
        pairs.first { $0.symbol == symbol }?.material ?? symbol
    }

    static func symbol(for icon: String) -> String {
        if let mapped = pairs.first(where: { $0.material == icon })?.symbol { return mapped }
        return UIImage(systemName: icon) != nil ? icon : fallbackSymbol
    }
}

// MARK: - CSV

/// Same columns and quoting as `CsvExporter` in the Android app.
enum CSVCodec {
    static let headers = [
        "id", "name", "amount", "currency", "billingPeriod",
        "customPeriodDays", "categoryId", "nextBillingDate",
        "startDate", "status", "reminderDaysBefore", "note",
    ]

    static func encode(_ subscriptions: [Subscription]) -> String {
        var lines = [headers.joined(separator: ",")]
        for s in subscriptions {
            let d = BackupMapper.dto(s)
            let values: [String?] = [
                d.id, d.name, Self.number(d.amount), d.currency, d.billingPeriod,
                d.customPeriodDays.map(String.init), d.categoryId, d.nextBillingDate,
                d.startDate, d.status, d.reminderDaysBefore.map(String.init), d.note,
            ]
            lines.append(values.map { escape($0 ?? "") }.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Rows that have at least `id` and `name`; invalid rows are skipped (like Android).
    static func decode(_ text: String) -> [Subscription] {
        let rows = parse(text)
        guard let header = rows.first else { return [] }
        return rows.dropFirst().compactMap { row in
            var map: [String: String] = [:]
            for (i, key) in header.enumerated() where i < row.count && !row[i].isEmpty {
                map[key.trimmingCharacters(in: .whitespaces)] = row[i]
            }
            guard let id = map["id"], let name = map["name"] else { return nil }
            let dto = SubscriptionDTO(
                id: id, name: name, icon: nil,
                amount: Double(map["amount"] ?? "") ?? 0,
                currency: map["currency"] ?? "RUB",
                billingPeriod: map["billingPeriod"] ?? "monthly",
                customPeriodDays: map["customPeriodDays"].flatMap { Int($0) },
                categoryId: map["categoryId"],
                nextBillingDate: map["nextBillingDate"] ?? BackupMapper.string(from: Calendar.current.date(byAdding: .day, value: 30, to: .now)!),
                startDate: map["startDate"] ?? BackupMapper.string(from: .now),
                status: map["status"],
                reminderDaysBefore: map["reminderDaysBefore"].flatMap { Int($0) },
                note: map["note"], createdAt: nil, domain: nil
            )
            return BackupMapper.subscription(dto)
        }
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.1f", value) : String(value)
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// RFC 4180-ish parser: quoted fields, escaped quotes, newlines inside quotes.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        if chars.first == "\u{FEFF}" { chars.removeFirst() }
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n":
                    row.append(field); field = ""
                    if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                    row = []
                default: field.append(ch)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
