import Foundation
import Testing
@testable import Kiper

struct FormattingTests {
    @Test(arguments: [(1, "подписка"), (2, "подписки"), (5, "подписок"), (11, "подписок"), (21, "подписка"), (22, "подписки"), (112, "подписок")])
    func russianPlural(n: Int, expected: String) {
        #expect(Fmt.plural(n, "подписка", "подписки", "подписок") == expected)
    }

    /// ru_RU groups thousands with a no-break space (good: amounts never wrap).
    private func plain(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func money() {
        #expect(plain(Fmt.money(1234.5, .usd)) == "1 234,50 $")
        #expect(plain(Fmt.rub(26038.4)) == "26 038 ₽")
        #expect(plain(Fmt.money(299, .rub)) == "299 ₽")
    }
}
