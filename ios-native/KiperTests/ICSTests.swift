import Foundation
import Testing
@testable import Kiper

struct ICSTests {
    @Test func buildsAllDayEventsWithEscaping() {
        let netflix = makeSub(id: "n", name: "Plan, \"Pro\"", amount: 22.99, currency: .usd,
                              next: day(2026, 12, 6), start: day(2026, 1, 6))
        let mts = makeSub(id: "m", name: "МТС", amount: 890,
                          next: day(2026, 12, 13), start: day(2026, 1, 13))
        let text = ICS.calendar(events: [PaymentEvent(subscription: netflix, date: day(2026, 12, 6)),
                                         PaymentEvent(subscription: mts, date: day(2026, 12, 13))])

        let lines = text.components(separatedBy: "\r\n")
        #expect(lines.first == "BEGIN:VCALENDAR")
        #expect(text.hasSuffix("END:VCALENDAR\r\n"))
        #expect(text.contains("VERSION:2.0") && text.contains("CALSCALE:GREGORIAN"))
        #expect(text.contains("DTSTART;VALUE=DATE:20261206"))
        #expect(text.contains("DTSTART;VALUE=DATE:20261213"))
        #expect(text.contains("UID:n-20261206@kiper"))
        #expect(text.contains("UID:m-20261213@kiper"), "one stable UID per subscription + day")
        #expect(text.contains("SUMMARY:Списание — Plan\\, \"Pro\""), "commas are escaped")
        #expect(text.contains("DESCRIPTION:22\\,99 $ · Ежемесячно"))
        #expect(text.range(of: "DTSTAMP:\\d{8}T\\d{6}Z", options: .regularExpression) != nil)
        #expect(text.components(separatedBy: "BEGIN:VEVENT").count == 3, "two events (+1 for the header)")
    }

    @Test func escapingCoversSpecialCharacters() {
        #expect(ICS.escape("a;b,c\nd\\e") == "a\\;b\\,c\\nd\\\\e")
    }
}
