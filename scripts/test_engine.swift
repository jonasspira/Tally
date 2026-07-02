import Foundation

// Engine smoke test. Compile together with the engine sources:
//   swiftc -parse-as-library Sources/Engine/*.swift scripts/test_engine.swift -o build/tally_test && ./build/tally_test

@main
struct TestMain {
    static var passed = 0
    static var failed = 0

    /// Evaluate `lines` as one sheet and compare the LAST line's formatted answer.
    static func check(_ lines: [String], _ expected: String) {
        let results = TallyEngine.evaluate(lines)
        let actual = results.last!.map { $0.formatted } ?? "nil"
        if actual == expected {
            passed += 1
        } else {
            failed += 1
            print("✗ \(lines.joined(separator: " ⏎ "))")
            print("    got \(actual), expected \(expected)")
        }
    }

    static func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, MMM d yyyy"
        return f.string(from: d)
    }

    static func main() {
        let cal = Calendar.current

        // Basic math
        check(["2 + 3 * 4"], "14")
        check(["(2 + 3) * 4"], "20")
        check(["10 / 4"], "2.5")
        check(["2 ^ 10"], "1,024")
        check(["1,000 + 500"], "1,500")
        check(["-5 + 12"], "7")
        check(["10 × 3 ÷ 2"], "15")

        // Prose mixed with math
        check(["rent is 1500 + 200 for parking"], "1,700")
        check(["bought 3 coffees at 45 kr", "// hmm"], "nil")
        check(["// full comment line"], "nil")
        check(["just words no math"], "nil")

        // Percentages
        check(["15% of 490"], "73.5")
        check(["490 + 15%"], "563.5")
        check(["490 - 15%"], "416.5")
        check(["15% off 490"], "416.5")
        check(["120 as a % of 480"], "25%")
        check(["25% of 200 + 10"], "60")

        // Variables
        check(["rent = 1500", "rent + 200"], "1,700")
        check(["coffee budget = 90", "coffee budget * 2"], "180")
        check(["a = 10", "b = 4", "a * b"], "40")

        // Totals
        check(["100", "200", "50", "total"], "350")
        check(["100", "200", "", "50", "total"], "50")
        check(["10", "20", "sum"], "30")

        // Units
        let mi = Units.convert(5000, from: Units.find("m")!, to: Units.find("miles")!)!
        check(["5 km in miles"], Value.fmt(mi) + " miles")
        check(["2 h in min"], "120 min")
        check(["3 kg + 500 g"], "3.5 kg")
        check(["90 min in h"], "1.5 h")
        let c = Units.convert(72, from: Units.find("f")!, to: Units.find("c")!)!
        check(["72 f in c"], Value.fmt(c) + " °C")
        check(["1 GB in MB"], "1,000 MB")
        check(["1 GiB in MiB"], "1,024 MiB")
        let mph = Units.convert(100, from: Units.find("km/h")!, to: Units.find("mph")!)!
        check(["100 km/h in mph"], Value.fmt(mph) + " mph")

        // Money (expected computed through the same rates the engine uses)
        check(["$120 * 2"], "$240")
        let eurUsd = CurrencyRates.shared.convert(100, from: "EUR", to: "USD")!
        check(["100 eur in usd"], "$" + Value.fmt(eurUsd))
        let usdSek = CurrencyRates.shared.convert(120, from: "USD", to: "SEK")!
        check(["$120 in sek"], Value.fmt(usdSek) + " SEK")
        check(["1500 kr + 300 kr"], "1,800 SEK")

        // Dates
        let year = cal.component(.year, from: Date())
        let may5 = cal.date(from: DateComponents(year: year, month: 5, day: 5))!
        let plus43 = cal.date(byAdding: .day, value: 43, to: may5)!
        check(["May 5 + 43 days"], dateString(plus43))
        let dec25 = cal.date(from: DateComponents(year: year, month: 12, day: 25))!
        let untilDays = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                           to: dec25).day!
        check(["days until dec 25"], Value.fmt(Double(untilDays)) + " days")
        let in3w = cal.date(byAdding: .weekOfYear, value: 3, to: cal.startOfDay(for: Date()))!
        check(["today + 3 weeks"], dateString(in3w))
        let jan10 = cal.date(from: DateComponents(year: year, month: 1, day: 10))!
        let mar4 = cal.date(from: DateComponents(year: year, month: 3, day: 4))!
        let range = cal.dateComponents([.day], from: jan10, to: mar4).day!
        check(["jan 10 to mar 4"], Value.fmt(Double(range)) + " days")

        // Times
        check(["9:30 + 2h 45m"], "12:15")
        check(["14:00 - 90 min"], "12:30")

        // Line references
        check(["100", "line1 * 2"], "200")
        check(["50", "80", "line1 + line2"], "130")

        print(failed == 0 ? "✓ all \(passed) tests passed"
                          : "\(failed) FAILED, \(passed) passed")
        exit(failed == 0 ? 0 : 1)
    }
}
