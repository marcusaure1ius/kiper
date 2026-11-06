import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// iCalendar (RFC 5545) export of the upcoming charge schedule, so it can live
/// in Apple Calendar or Google Calendar. All-day VEVENTs, one per charge.
enum ICS {
    /// Pure builder (unit-tested): one all-day VEVENT per given future charge.
    static func calendar(events: [PaymentEvent], now: Date = .now) -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Kiper//Subscription Calendar//RU",
            "CALSCALE:GREGORIAN",
        ]
        let stamp = utcFormatter.string(from: now)
        for event in events {
            let sub = event.subscription
            lines += [
                "BEGIN:VEVENT",
                "UID:\(sub.id)-\(dayFormatter.string(from: event.date))@kiper",
                "DTSTAMP:\(stamp)",
                "DTSTART;VALUE=DATE:\(dayFormatter.string(from: event.date))",
                "SUMMARY:\(escape("Списание — \(sub.name)"))",
                "DESCRIPTION:\(escape("\(Fmt.money(sub.amount, sub.currency)) · \(sub.billingPeriod.label)"))",
                "END:VEVENT",
            ]
        }
        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 5545 §3.3.11: backslash, semicolon, comma and newlines are escaped.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private static let utcFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f
    }()
}

/// Share-sheet payload for the .ics file (same pattern as `JSONExport`/`CSVExport`).
struct ICSExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .calendarEvent) { item in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("kiper.ics")
            try Data(item.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
