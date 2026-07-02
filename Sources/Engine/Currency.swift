import Foundation

/// Exchange rates, EUR-based (matching the free frankfurter.app API / ECB data).
/// Order of preference: freshly fetched → cached on disk → built-in fallback,
/// so currency lines always produce an answer, even offline on first run.
final class CurrencyRates {
    static let shared = CurrencyRates()

    private(set) var rates: [String: Double]
    private(set) var lastUpdated: Date?

    /// Symbols that can prefix a number, and word-style codes.
    static let symbols: [Character: String] = ["$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY"]
    static let wordCodes: [String: String] = [
        "kr": "SEK", "kronor": "SEK", "dollar": "USD", "dollars": "USD",
        "euro": "EUR", "euros": "EUR", "yen": "JPY",
    ]

    static func code(for word: String) -> String? {
        let w = word.lowercased()
        if let c = wordCodes[w] { return c }
        let upper = w.uppercased()
        return fallback[upper] != nil ? upper : nil
    }

    private static let fallback: [String: Double] = [
        "EUR": 1, "USD": 1.09, "SEK": 11.2, "NOK": 11.6, "DKK": 7.46, "GBP": 0.85,
        "JPY": 168, "CHF": 0.94, "CAD": 1.49, "AUD": 1.66, "NZD": 1.80, "CNY": 7.8,
        "INR": 91, "PLN": 4.3, "CZK": 24.9, "HUF": 392, "ISK": 150, "TRY": 38,
        "ZAR": 20, "BRL": 6.0, "MXN": 19.7, "KRW": 1480, "SGD": 1.45, "HKD": 8.5,
        "THB": 38.8, "ILS": 4.0, "RON": 4.97, "BGN": 1.96, "IDR": 17300,
        "MYR": 5.05, "PHP": 62,
    ]

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tally", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rates.json")
    }

    private init() {
        rates = Self.fallback
        if let data = try? Data(contentsOf: Self.cacheURL),
           let cached = try? JSONDecoder().decode(CachedRates.self, from: data) {
            rates = rates.merging(cached.rates) { _, new in new }
            lastUpdated = cached.date
        }
    }

    func convert(_ amount: Double, from: String, to: String) -> Double? {
        guard let f = rates[from], let t = rates[to] else { return nil }
        return amount / f * t
    }

    /// Fetch today's rates in the background; silently keeps old rates on failure.
    func refresh() {
        guard let url = URL(string: "https://api.frankfurter.app/latest") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let resp = try? JSONDecoder().decode(FrankfurterResponse.self, from: data)
            else { return }
            var r = resp.rates
            r["EUR"] = 1
            DispatchQueue.main.async {
                self.rates = self.rates.merging(r) { _, new in new }
                self.lastUpdated = Date()
                let cached = CachedRates(date: Date(), rates: r)
                if let out = try? JSONEncoder().encode(cached) {
                    try? out.write(to: Self.cacheURL)
                }
            }
        }.resume()
    }

    private struct FrankfurterResponse: Decodable { let rates: [String: Double] }
    private struct CachedRates: Codable {
        let date: Date
        let rates: [String: Double]
    }
}
