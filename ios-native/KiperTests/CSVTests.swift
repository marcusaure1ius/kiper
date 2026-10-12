import Foundation
import Testing
@testable import Kiper

struct CSVTests {
    @Test func roundTripWithAwkwardText() {
        var sub = makeSub(id: "1", name: "Plan, \"Pro\"", amount: 9.99, currency: .eur, next: day(2026, 11, 5), start: day(2026, 1, 5))
        sub.note = "line one\nline two"
        let text = CSVCodec.encode([sub])
        #expect(text.hasPrefix("id,name,amount,currency,billingPeriod,customPeriodDays,categoryId,nextBillingDate,startDate,status,reminderDaysBefore,note\n"))
        let back = CSVCodec.decode(text)
        #expect(back.count == 1)
        #expect(back[0].name == "Plan, \"Pro\"")
        #expect(back[0].note == "line one\nline two")
        #expect(back[0].amount == 9.99 && back[0].currency == .eur)
    }

    @Test func androidCSVAndBadRows() {
        let text = """
        id,name,amount,currency,billingPeriod,customPeriodDays,categoryId,nextBillingDate,startDate,status,reminderDaysBefore,note
        a,МТС,890.0,RUB,monthly,,cat-telecom,2026-10-13T00:00:00.000,2020-06-01T00:00:00.000,active,1,
        ,no id,1,RUB,monthly,,,,,,,
        b,Annual,59.99,USD,annual,,,2027-01-01T00:00:00.000,2024-01-01T00:00:00.000,active,7,"a ""quoted"" note"
        """
        let subs = CSVCodec.decode(text)
        #expect(subs.map(\.id) == ["a", "b"])
        #expect(subs[0].amount == 890 && subs[0].categoryId == "cat-telecom")
        #expect(subs[1].billingPeriod == .annual && subs[1].reminderDaysBefore == 7)
        #expect(subs[1].note == "a \"quoted\" note")
    }
}
