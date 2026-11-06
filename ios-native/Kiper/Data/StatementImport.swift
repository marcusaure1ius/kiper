import Foundation

/// One charge spotted in a bank statement.
struct StatementOccurrence: Hashable {
    let date: Date
    let amount: Double
}

/// A recurring payment detected in a bank export: at least three charges of a
/// similar merchant, evenly spaced, within ±10 % of the median amount.
struct StatementCandidate: Hashable, Identifiable {
    let id: String
    let name: String
    /// Sorted by date, oldest first.
    let occurrences: [StatementOccurrence]
    let medianAmount: Double
    let medianIntervalDays: Int

    var lastDate: Date { occurrences.last!.date }

    var billingPeriod: (period: BillingPeriod, customDays: Int?) {
        switch medianIntervalDays {
        case ...10: (.weekly, nil)
        case 11...20: (.custom, 14)
        case 21...45: (.monthly, nil)
        case 46...120: (.quarterly, nil)
        case 121...250: (.semiannual, nil)
        default: (.annual, nil)
        }
    }

    /// The next expected charge after the last one seen in the statement.
    func nextCharge(now: Date = .now) -> Date {
        let (period, customDays) = billingPeriod
        var next = period.next(after: lastDate, customDays: customDays)
        while next < now { next = period.next(after: next, customDays: customDays) }
        return next
    }
}

/// Turns a bank CSV/TXT export into `StatementCandidate`s. Column layout varies
/// per bank, so columns are detected by content: a date-looking column, a
/// number-looking column and the longest free-text column for the merchant.
enum StatementImporter {
    static func parse(_ text: String) -> [StatementCandidate] {
        // Banks use commas or semicolons as the delimiter.
        let sample = text.prefix { !$0.isNewline }
        let delimiter: Character = sample.filter { $0 == ";" }.count > sample.filter { $0 == "," }.count ? ";" : ","
        let rows = Self.split(text, delimiter: delimiter)
        guard rows.count >= 4 else { return [] } // header + at least 3 charges
        let body = rows.dropFirst()
        let width = body.map(\.count).min() ?? 0
        guard width >= 3 else { return [] }

        // Column roles by content, voting over the body.
        var dateVotes = [Int: Int](), amountVotes = [Int: Int]()
        var textScore = [Int: Int]()
        for row in body.prefix(60) {
            for (i, cell) in row.enumerated() where i < width {
                if Self.date(from: cell) != nil { dateVotes[i, default: 0] += 1 }
                if Self.number(from: cell) != nil { amountVotes[i, default: 0] += 1 }
                textScore[i, default: 0] += cell.count - cell.filter(\.isNumber).count
            }
        }
        guard let (dateCol, dateVoteCount) = dateVotes.max(by: { $0.value < $1.value }), dateVoteCount >= body.count / 2 else { return [] }
        let amountCol = amountVotes
            .filter { $0.key != dateCol }
            .max { $0.value < $1.value }?
            .key
        guard let amountCol else { return [] }
        let textCol = textScore
            .filter { $0.key != dateCol && $0.key != amountCol }
            .max { $0.value < $1.value }?
            .key
        guard let textCol else { return [] }

        // Group charges by normalized merchant name.
        var groups: [String: (name: String, items: [StatementOccurrence])] = [:]
        for row in body where row.count > max(dateCol, amountCol, textCol) {
            guard let date = Self.date(from: row[dateCol]), let amount = Self.number(from: row[amountCol]), amount > 0 else { continue }
            let raw = row[textCol].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            let key = normalize(raw)
            guard !key.isEmpty else { continue }
            groups[key, default: (raw, [])].items.append(StatementOccurrence(date: date, amount: amount))
        }

        let candidates = groups.compactMap { key, group -> StatementCandidate? in
            let items = group.items.sorted { $0.date < $1.date }
            guard items.count >= 3 else { return nil }
            let amounts = items.map(\.amount).sorted()
            let median = amounts[amounts.count / 2]
            // Amounts must stay within ±10 % of the median (no price spikes here).
            guard amounts.allSatisfy({ abs($0 - median) <= median * 0.1 }) else { return nil }
            let gaps = zip(items, items.dropFirst()).map { b, a in Calendar.current.dateComponents([.day], from: b.date, to: a.date).day ?? 0 }
                .sorted()
            let interval = gaps[gaps.count / 2]
            // Even spacing near a plausible billing period.
            guard [7, 14, 30, 31, 90, 365].contains(where: { abs(interval - $0) <= 3 }) else { return nil }
            return StatementCandidate(id: key, name: group.name, occurrences: items, medianAmount: median, medianIntervalDays: interval)
        }
        return candidates.sorted { $0.medianAmount * 12 / Double(max($0.medianIntervalDays, 1)) > $1.medianAmount * 12 / Double(max($1.medianIntervalDays, 1)) }
    }

    /// "ООО ЯНДЕКС.ТАКСИ (CARD 4111 **** 1234)" → "ЯНДЕКС.ТАКСИ" — letters only,
    /// legal forms, card masks and noise words dropped.
    static func normalize(_ raw: String) -> String {
        let noise: Set<String> = ["ООО", "ОАО", "ЗАО", "ИП", "АО", "CARD", "КАРТА", "ПОКУПКА", "ОПЛАТА", "ИНТЕРНЕТ", "ONLINE", "RU", "RUB", "MOSCOW", "МОСКВА", "Г", "Г."]
        let cleaned = raw.replacingOccurrences(of: "\\d", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[\\*•]", with: " ")
        var kept: [String] = []
        for word in cleaned.split(separator: " ") {
            let w = word.trimmingCharacters(in: .punctuationCharacters)
            guard !w.isEmpty else { continue }
            if noise.contains(w.uppercased()) { continue }
            kept.append(w)
        }
        return kept.joined(separator: " ").uppercased()
    }

    /// RFC 4180-ish splitter with a configurable delimiter (quotes, escaped
    /// quotes, newlines inside quotes).
    static func split(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        if chars.first == "\u{FEFF}" { chars.removeFirst() } // BOM
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
                case delimiter: row.append(field); field = ""
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

    // MARK: - Cell parsing

    static func date(from cell: String) -> Date? {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        let formats = ["dd.MM.yyyy", "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm", "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy", "MM/dd/yyyy"]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for format in formats {
            f.dateFormat = format
            if let d = f.date(from: trimmed) { return d }
        }
        return nil
    }

    /// "1 234,56", "-1234.56", "1234.56 ₽", "(1234.56)" → positive magnitude.
    static func number(from cell: String) -> Double? {
        var s = cell.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        let negative = s.hasPrefix("-") || s.hasPrefix("(")
        s = s.replacingOccurrences(of: "[^0-9,.-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        // Both decimal separators accepted; thousands spaces already stripped.
        if s.contains(",") && s.contains(".") {
            s = s.replacingOccurrences(of: ",", with: "") // 1,234.56
        } else {
            s = s.replacingOccurrences(of: ",", with: ".") // 1234,56
        }
        guard let value = Double(s), value != 0 else { return nil }
        return abs(negative ? -value : value)
    }
}
