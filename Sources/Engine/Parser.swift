import Foundation

/// Semantic tokens: raw tokens with words resolved into things the parser
/// understands (values, units, keywords). Unknown words have been dropped.
enum STok {
    case val(Value)
    case unitWord(Unit)     // a bare unit, e.g. the target of "in miles"
    case currency(String)   // a bare currency code, e.g. the target of "in sek"
    case variable(String)
    case lineRef(Int)       // 1-based
    case op(String)         // + - * / ^ ( )
    case key(String)        // of in off to until ago total aspctof
}

enum Resolver {
    static let keywords: Set<String> = ["of", "in", "off", "to", "until", "ago", "total", "sum"]

    static func resolve(_ tokens: [Token], variables: [String]) -> [STok] {
        // Longest variable names first so "coffee budget" wins over "coffee".
        let varSeqs = variables
            .map { (name: $0, words: $0.split(separator: " ").map(String.init)) }
            .sorted { $0.words.count > $1.words.count }

        var out: [STok] = []
        var i = 0

        func number(at j: Int) -> Double? {
            guard j < tokens.count, case .number(let n) = tokens[j] else { return nil }
            return n
        }
        func word(at j: Int) -> String? {
            guard j < tokens.count, case .word(let w) = tokens[j] else { return nil }
            return w
        }
        func matchVariable(at j: Int) -> (String, Int)? {
            for v in varSeqs {
                var ok = true
                for (k, w) in v.words.enumerated() where word(at: j + k) != w { ok = false; break }
                if ok, !v.words.isEmpty { return (v.name, v.words.count) }
            }
            return nil
        }
        /// Consume an optional year number and return (date, tokens consumed after `next`).
        func makeDate(month: Int, day: Int, next: Int) -> (Date, Int)? {
            var year: Int? = nil
            var end = next
            if let y = number(at: next), y == y.rounded(), y >= 1500, y <= 2600 {
                year = Int(y); end += 1
            }
            guard let d = Dates.make(month: month, day: day, year: year) else { return nil }
            return (d, end)
        }

        while i < tokens.count {
            switch tokens[i] {
            case .number(let n):
                if i + 1 < tokens.count, tokens[i + 1] == .percent {
                    out.append(.val(.percent(n))); i += 2; continue
                }
                if word(at: i + 1) == "percent" {
                    out.append(.val(.percent(n))); i += 2; continue
                }
                // "25 dec [2026]"
                if let w = word(at: i + 1), let month = Dates.monthNames[w],
                   n == n.rounded(), n >= 1, n <= 31,
                   let (d, end) = makeDate(month: month, day: Int(n), next: i + 2) {
                    out.append(.val(.date(d, .date))); i = end; continue
                }
                if let w = word(at: i + 1), let u = Units.find(w) {
                    out.append(.val(.quantity(n, u))); i += 2; continue
                }
                if let w = word(at: i + 1), let code = CurrencyRates.code(for: w) {
                    out.append(.val(.money(n, code))); i += 2; continue
                }
                out.append(.val(.number(n))); i += 1

            case .currencySymbol(let code):
                if let n = number(at: i + 1) {
                    out.append(.val(.money(n, code))); i += 2
                } else {
                    i += 1
                }

            case .time(let h, let m):
                if let d = Dates.timeToday(hour: h, minute: m) {
                    out.append(.val(.date(d, .time)))
                }
                i += 1

            case .percent:
                i += 1  // bare % is only meaningful inside "as a % of"

            case .op(let o):
                if o != "=" { out.append(.op(o)) }
                i += 1

            case .word(let w):
                if let (name, len) = matchVariable(at: i) {
                    out.append(.variable(name)); i += len; continue
                }
                if w.hasPrefix("line"), let n = Int(w.dropFirst(4)), n > 0 {
                    out.append(.lineRef(n)); i += 1; continue
                }
                // "may 5 [2026]"
                if let month = Dates.monthNames[w], let day = number(at: i + 1),
                   day == day.rounded(), day >= 1, day <= 31,
                   let (d, end) = makeDate(month: month, day: Int(day), next: i + 2) {
                    out.append(.val(.date(d, .date))); i = end; continue
                }
                switch w {
                case "today":
                    out.append(.val(.date(Dates.today(), .date))); i += 1; continue
                case "tomorrow":
                    if let d = Dates.cal.date(byAdding: .day, value: 1, to: Dates.today()) {
                        out.append(.val(.date(d, .date)))
                    }
                    i += 1; continue
                case "yesterday":
                    if let d = Dates.cal.date(byAdding: .day, value: -1, to: Dates.today()) {
                        out.append(.val(.date(d, .date)))
                    }
                    i += 1; continue
                case "now":
                    out.append(.val(.date(Date(), .dateTime))); i += 1; continue
                case "plus":  out.append(.op("+")); i += 1; continue
                case "minus": out.append(.op("-")); i += 1; continue
                case "times": out.append(.op("*")); i += 1; continue
                case "divided":
                    i += (word(at: i + 1) == "by") ? 2 : 1
                    out.append(.op("/")); continue
                case "as":
                    // "as [a] % of" / "as [a] percent of" → one aspctof keyword
                    var j = i + 1
                    if word(at: j) == "a" { j += 1 }
                    var isPct = false
                    if j < tokens.count, tokens[j] == .percent { isPct = true; j += 1 }
                    else if word(at: j) == "percent" || word(at: j) == "percentage" { isPct = true; j += 1 }
                    if isPct, word(at: j) == "of" {
                        out.append(.key("aspctof")); i = j + 1; continue
                    }
                    i += 1; continue
                default:
                    break
                }
                if keywords.contains(w) {
                    out.append(.key(w == "sum" ? "total" : w)); i += 1; continue
                }
                if let u = Units.find(w) {
                    out.append(.unitWord(u)); i += 1; continue
                }
                if let code = CurrencyRates.code(for: w) {
                    out.append(.currency(code)); i += 1; continue
                }
                i += 1  // unknown word: skip — this is what lets prose through
            }
        }
        return fold(out)
    }

    /// Merge adjacent same-dimension quantities ("2h 45m" → 2.75 h), including
    /// the "m means minutes next to a time" special case.
    private static func fold(_ toks: [STok]) -> [STok] {
        var out: [STok] = []
        for t in toks {
            if case .val(.quantity(let v2, let u2)) = t,
               case .val(.quantity(let v1, let u1))? = out.last {
                var first = (v1, u1)
                var second = (v2, u2)
                let minUnit = Units.find("min")
                if u1.dimension == .time, u2.name == "m", let minUnit {
                    second = (v2, minUnit)          // 2h 45m
                } else if u2.dimension == .time, u1.name == "m", let minUnit {
                    first = (v1, minUnit)           // 1m 30s
                }
                if first.1.dimension == second.1.dimension, first.1.dimension != .temperature,
                   let conv = Units.convert(second.0, from: second.1, to: first.1) {
                    out.removeLast()
                    out.append(.val(.quantity(first.0 + conv, first.1)))
                    continue
                }
            }
            out.append(t)
        }
        return out
    }
}

// MARK: - Expression tree

indirect enum Expr {
    case lit(Value)
    case variable(String)
    case lineRef(Int)
    case bin(String, Expr, Expr)   // + - * / ^ of off aspctof range
    case neg(Expr)
    case conv(Expr, ConvTarget)
    case daysUntil(Expr)
    case ago(Expr)
}

enum ConvTarget {
    case unit(Unit)
    case currency(String)
}

/// Pratt parser over semantic tokens. Tolerant by design: tokens that don't
/// fit are skipped; leftovers after a complete expression are ignored.
struct Parser {
    let toks: [STok]
    var pos = 0

    init(toks: [STok]) { self.toks = toks }

    static func bp(_ op: String) -> Int {
        switch op {
        case "^": return 50
        case "*", "/": return 40
        case "of", "off": return 38
        case "+", "-": return 30
        case "aspctof": return 25
        case "to", "until": return 22
        case "in": return 10
        default: return 0
        }
    }

    mutating func parse() -> Expr? {
        while pos < toks.count {
            let start = pos
            if let e = expression(0) { return e }
            pos = start + 1
        }
        return nil
    }

    private mutating func expression(_ minBP: Int) -> Expr? {
        guard var lhs = nud() else { return nil }
        loop: while pos < toks.count {
            switch toks[pos] {
            case .op(let o):
                let b = Self.bp(o)
                guard b > minBP else { break loop }
                pos += 1
                guard let rhs = expression(o == "^" ? b - 1 : b) else { break loop }
                lhs = .bin(o, lhs, rhs)
            case .key(let k):
                switch k {
                case "of", "off", "aspctof":
                    let b = Self.bp(k)
                    guard b > minBP else { break loop }
                    pos += 1
                    guard let rhs = expression(b) else { break loop }
                    lhs = .bin(k, lhs, rhs)
                case "to", "until":
                    guard Self.bp("to") > minBP else { break loop }
                    pos += 1
                    guard let rhs = expression(Self.bp("to")) else { break loop }
                    lhs = .bin("range", lhs, rhs)
                case "in":
                    guard Self.bp("in") > minBP else { break loop }
                    pos += 1
                    if pos < toks.count, case .unitWord(let u) = toks[pos] {
                        pos += 1; lhs = .conv(lhs, .unit(u))
                    } else if pos < toks.count, case .currency(let c) = toks[pos] {
                        pos += 1; lhs = .conv(lhs, .currency(c))
                    }
                    // otherwise: prose "in", ignore it
                case "ago":
                    pos += 1
                    lhs = .ago(lhs)
                default:
                    break loop
                }
            default:
                break loop
            }
        }
        return lhs
    }

    private mutating func nud() -> Expr? {
        guard pos < toks.count else { return nil }
        switch toks[pos] {
        case .val(let v): pos += 1; return .lit(v)
        case .variable(let n): pos += 1; return .variable(n)
        case .lineRef(let n): pos += 1; return .lineRef(n)
        case .op("("):
            pos += 1
            let e = expression(0)
            if pos < toks.count, case .op(")") = toks[pos] { pos += 1 }
            return e
        case .op("-"):
            pos += 1
            return expression(45).map(Expr.neg)
        case .op("+"):
            pos += 1
            return expression(45)
        case .unitWord(let u):
            // "days until <date>"
            if u.dimension == .time, pos + 1 < toks.count,
               case .key("until") = toks[pos + 1] {
                pos += 2
                return expression(Self.bp("to")).map(Expr.daysUntil)
            }
            return nil
        case .key("until"):
            pos += 1
            return expression(Self.bp("to")).map(Expr.daysUntil)
        default:
            return nil
        }
    }
}
