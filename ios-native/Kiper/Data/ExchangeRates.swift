import Foundation

/// Rates to RUB from the Central Bank of Russia daily XML, with cache and fallback
/// (mirrors `ExchangeRateService` in the Android app).
struct RateSnapshot: Codable, Equatable, Sendable {
    var rates: [String: Double]
    /// Date of the CBR quote (from the XML `Date` attribute).
    var quoteDate: Date?
    var fetchedAt: Date
    var isFallback: Bool

    func rate(_ currency: Currency) -> Double {
        if currency == .rub { return 1 }
        return rates[currency.rawValue] ?? ExchangeRates.fallback[currency] ?? 1
    }

    static let fallback = RateSnapshot(
        rates: Dictionary(uniqueKeysWithValues: ExchangeRates.fallback.map { ($0.key.rawValue, $0.value) }),
        quoteDate: nil, fetchedAt: .distantPast, isFallback: true
    )
}

enum ExchangeRates {
    static let url = URL(string: "https://www.cbr.ru/scripts/XML_daily.asp")!
    static let fallback: [Currency: Double] = [.usd: 90, .eur: 98]
    private static let cacheKey = "rates.snapshot"
    /// Refresh at most this often; CBR publishes once a day.
    static let maxAge: TimeInterval = 6 * 3600

    static func cached(defaults: UserDefaults = .standard) -> RateSnapshot {
        guard let data = defaults.data(forKey: cacheKey),
              let snapshot = try? JSONDecoder().decode(RateSnapshot.self, from: data)
        else { return .fallback }
        return snapshot
    }

    static func store(_ snapshot: RateSnapshot, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: cacheKey) }
    }

    static func fetch(session: URLSession = .shared) async throws -> RateSnapshot {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Kiper/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let parsed = try parse(data)
        guard !parsed.rates.isEmpty else { throw URLError(.cannotParseResponse) }
        return RateSnapshot(rates: parsed.rates, quoteDate: parsed.date, fetchedAt: .now, isFallback: false)
    }

    /// Parses `ValCurs` XML. The feed is windows-1251; XMLParser honours the
    /// encoding declared in the prolog. Values use a decimal comma and a `Nominal`.
    static func parse(_ data: Data) throws -> (rates: [String: Double], date: Date?) {
        let delegate = CBRParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }
        return (delegate.rates, delegate.date)
    }
}

private final class CBRParser: NSObject, XMLParserDelegate {
    var rates: [String: Double] = [:]
    var date: Date?

    private var code = ""
    private var nominal = ""
    private var value = ""
    private var element = ""
    private static let wanted = Set(Currency.allCases.map(\.rawValue))

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        element = name
        switch name {
        case "ValCurs":
            if let raw = attributes["Date"] {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "dd.MM.yyyy"
                date = f.date(from: raw)
            }
        case "Valute":
            code = ""; nominal = ""; value = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch element {
        case "CharCode": code += string
        case "Nominal": nominal += string
        case "Value": value += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "Valute" {
            let c = code.trimmingCharacters(in: .whitespacesAndNewlines)
            let n = Double(nominal.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            let v = Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
            if Self.wanted.contains(c), let v, n > 0 { rates[c] = v / n }
        }
        element = ""
    }
}
