import Foundation
import Testing
@testable import Kiper

struct RatesTests {
    /// Real-shaped CBR feed, encoded in windows-1251 like the server sends it.
    static let xml = """
    <?xml version="1.0" encoding="windows-1251"?>
    <ValCurs Date="11.10.2026" name="Foreign Currency Market">
    <Valute ID="R01235"><NumCode>840</NumCode><CharCode>USD</CharCode><Nominal>1</Nominal><Name>Доллар США</Name><Value>81,7186</Value><VunitRate>81,7186</VunitRate></Valute>
    <Valute ID="R01239"><NumCode>978</NumCode><CharCode>EUR</CharCode><Nominal>1</Nominal><Name>Евро</Name><Value>94,8810</Value><VunitRate>94,881</VunitRate></Valute>
    <Valute ID="R01335"><NumCode>398</NumCode><CharCode>KZT</CharCode><Nominal>100</Nominal><Name>Тенге</Name><Value>15,1234</Value><VunitRate>0,151234</VunitRate></Valute>
    </ValCurs>
    """

    @Test func parsesWindows1251Feed() throws {
        let data = try #require(Self.xml.data(using: .windowsCP1251))
        let parsed = try ExchangeRates.parse(data)
        #expect(parsed.rates == ["USD": 81.7186, "EUR": 94.881])
        #expect(parsed.date.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) } == DateComponents(year: 2026, month: 10, day: 11))
    }

    @Test func snapshotFallsBack() {
        #expect(RateSnapshot.fallback.rate(.usd) == 90)
        #expect(RateSnapshot.fallback.rate(.rub) == 1)
        let partial = RateSnapshot(rates: ["USD": 80], quoteDate: nil, fetchedAt: .now, isFallback: false)
        #expect(partial.rate(.eur) == 98, "missing currency uses the fallback rate")
    }

    @Test func cacheRoundTrip() {
        let defaults = UserDefaults(suiteName: "kiper.rates.\(UUID().uuidString)")!
        #expect(ExchangeRates.cached(defaults: defaults) == .fallback)
        let snap = RateSnapshot(rates: ["USD": 81.5, "EUR": 95], quoteDate: day(2026, 10, 11), fetchedAt: day(2026, 10, 11, hour: 12), isFallback: false)
        ExchangeRates.store(snap, defaults: defaults)
        #expect(ExchangeRates.cached(defaults: defaults) == snap)
    }
}
