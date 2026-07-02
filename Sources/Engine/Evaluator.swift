import Foundation

/// Evaluates a whole sheet top to bottom, carrying variables and line answers.
struct SheetEvaluator {
    let rates = CurrencyRates.shared

    func evaluate(_ texts: [String]) -> [Value?] {
        var vars: [String: Value] = [:]
        var results: [Value?] = []
        var totals = Array(repeating: false, count: texts.count)

        for (idx, text) in texts.enumerated() {
            let value = evalLine(text, idx: idx, texts: texts,
                                 vars: &vars, results: results, totals: &totals)
            results.append(value)
        }
        return results
    }

    private func evalLine(_ text: String, idx: Int, texts: [String],
                          vars: inout [String: Value],
                          results: [Value?], totals: inout [Bool]) -> Value? {
        let tokens = Tokenizer.tokenize(text)
        guard !tokens.isEmpty else { return nil }

        // Assignment: leading words, "=", then an expression.
        if let eq = tokens.firstIndex(of: .op("=")), eq > 0,
           tokens[0..<eq].allSatisfy({ if case .word = $0 { return true } else { return false } }) {
            let name = tokens[0..<eq]
                .compactMap { if case .word(let w) = $0 { return w } else { return nil } }
                .joined(separator: " ")
            let value = evalTokens(Array(tokens[(eq + 1)...]), vars: vars, results: results)
            if let value { vars[name] = value }
            return value
        }

        let stoks = Resolver.resolve(tokens, variables: Array(vars.keys))
        guard !stoks.isEmpty else { return nil }

        // A line saying just "total"/"sum" (no values of its own) sums the block above.
        let hasValue = stoks.contains {
            switch $0 {
            case .val, .variable, .lineRef: return true
            default: return false
            }
        }
        let hasTotal = stoks.contains {
            if case .key("total") = $0 { return true } else { return false }
        }
        if hasTotal, !hasValue {
            totals[idx] = true
            return totalOfBlock(above: idx, texts: texts, results: results, totals: totals)
        }

        var parser = Parser(toks: stoks)
        guard let expr = parser.parse() else { return nil }
        return eval(expr, vars: vars, results: results)
    }

    private func evalTokens(_ tokens: [Token], vars: [String: Value],
                            results: [Value?]) -> Value? {
        let stoks = Resolver.resolve(tokens, variables: Array(vars.keys))
        var parser = Parser(toks: stoks)
        guard let expr = parser.parse() else { return nil }
        return eval(expr, vars: vars, results: results)
    }

    /// Sum the consecutive block of answered lines directly above `idx`,
    /// stopping at a blank line or an earlier total.
    private func totalOfBlock(above idx: Int, texts: [String],
                              results: [Value?], totals: [Bool]) -> Value? {
        var start = idx
        var j = idx - 1
        while j >= 0 {
            if texts[j].trimmingCharacters(in: .whitespaces).isEmpty { break }
            if totals[j] { break }
            start = j
            j -= 1
        }
        var acc: Value? = nil
        for k in start..<idx {
            guard let v = results[k] else { continue }
            acc = acc == nil ? v : (add(acc!, v) ?? acc)
        }
        return acc
    }

    // MARK: - Expression evaluation

    private func eval(_ e: Expr, vars: [String: Value], results: [Value?]) -> Value? {
        switch e {
        case .lit(let v):
            return v
        case .variable(let n):
            return vars[n]
        case .lineRef(let n):
            let i = n - 1
            return (i >= 0 && i < results.count) ? results[i] : nil
        case .neg(let x):
            return eval(x, vars: vars, results: results).flatMap { scale($0, -1) }
        case .conv(let x, let target):
            return eval(x, vars: vars, results: results).flatMap { convert($0, to: target) }
        case .daysUntil(let x):
            guard case .date(let d, _)? = eval(x, vars: vars, results: results),
                  let dayUnit = Units.find("days") else { return nil }
            return .quantity(Double(Dates.daysBetween(Date(), d)), dayUnit)
        case .ago(let x):
            guard case .quantity(let v, let u)? = eval(x, vars: vars, results: results),
                  u.dimension == .time else { return nil }
            return Dates.add(v, u, to: Dates.today(), style: .date, sign: -1)
        case .bin(let op, let l, let r):
            guard let a = eval(l, vars: vars, results: results),
                  let b = eval(r, vars: vars, results: results) else { return nil }
            switch op {
            case "+": return add(a, b)
            case "-": return sub(a, b)
            case "*": return mul(a, b)
            case "/": return div(a, b)
            case "^":
                guard let x = a.raw, let y = b.raw else { return nil }
                return .number(Foundation.pow(x, y))
            case "of":
                guard case .percent(let p) = a else { return nil }
                return scale(b, p / 100)
            case "off":
                guard case .percent(let p) = a else { return nil }
                return scale(b, 1 - p / 100)
            case "aspctof":
                guard let r = ratio(a, b) else { return nil }
                return .percent(r * 100)
            case "range":
                guard case .date(let d1, _) = a, case .date(let d2, _) = b,
                      let dayUnit = Units.find("days") else { return nil }
                return .quantity(Double(Dates.daysBetween(d1, d2)), dayUnit)
            default:
                return nil
            }
        }
    }

    // MARK: - Arithmetic on Values

    private func scale(_ v: Value, _ f: Double) -> Value? {
        switch v {
        case .number(let x): return .number(x * f)
        case .percent(let x): return .percent(x * f)
        case .quantity(let x, let u): return .quantity(x * f, u)
        case .money(let x, let c): return .money(x * f, c)
        case .date: return nil
        }
    }

    private func ratio(_ a: Value, _ b: Value) -> Double? {
        switch (a, b) {
        case (.quantity(let x, let u), .quantity(let y, let v)) where u.dimension == v.dimension:
            let yb = v.toBase(y)
            return yb == 0 ? nil : u.toBase(x) / yb
        case (.money(let x, let c), .money(let y, let d)):
            guard let yc = rates.convert(y, from: d, to: c), yc != 0 else { return nil }
            return x / yc
        default:
            guard let x = a.raw, let y = b.raw, y != 0 else { return nil }
            return x / y
        }
    }

    private func add(_ a: Value, _ b: Value) -> Value? {
        switch (a, b) {
        case (.number(let x), .number(let y)): return .number(x + y)
        case (.percent(let x), .percent(let y)): return .percent(x + y)
        case (_, .percent(let p)): return scale(a, 1 + p / 100)
        case (.quantity(let x, let u), .quantity(let y, let v)):
            guard let yc = Units.convert(y, from: v, to: u) else { return nil }
            return .quantity(x + yc, u)
        case (.quantity(let x, let u), .number(let y)): return .quantity(x + y, u)
        case (.number(let x), .quantity(let y, let u)): return .quantity(x + y, u)
        case (.money(let x, let c), .money(let y, let d)):
            guard let yc = rates.convert(y, from: d, to: c) else { return nil }
            return .money(x + yc, c)
        case (.money(let x, let c), .number(let y)): return .money(x + y, c)
        case (.number(let x), .money(let y, let c)): return .money(x + y, c)
        case (.date(let d, let s), .quantity(let v, let u)):
            return Dates.add(v, u, to: d, style: s, sign: 1)
        case (.quantity(let v, let u), .date(let d, let s)):
            return Dates.add(v, u, to: d, style: s, sign: 1)
        default:
            return nil
        }
    }

    private func sub(_ a: Value, _ b: Value) -> Value? {
        switch (a, b) {
        case (.date(let d1, _), .date(let d2, _)):
            guard let dayUnit = Units.find("days") else { return nil }
            return .quantity(Double(Dates.daysBetween(d2, d1)), dayUnit)
        case (.date(let d, let s), .quantity(let v, let u)):
            return Dates.add(v, u, to: d, style: s, sign: -1)
        case (.percent(let x), .percent(let y)): return .percent(x - y)
        case (_, .percent(let p)): return scale(a, 1 - p / 100)
        default:
            return scale(b, -1).flatMap { add(a, $0) }
        }
    }

    private func mul(_ a: Value, _ b: Value) -> Value? {
        switch (a, b) {
        case (.number(let x), .number(let y)): return .number(x * y)
        case (.percent(let p), _): return scale(b, p / 100)
        case (_, .percent(let p)): return scale(a, p / 100)
        case (.quantity(let x, let u), .number(let y)): return .quantity(x * y, u)
        case (.number(let x), .quantity(let y, let u)): return .quantity(x * y, u)
        case (.money(let x, let c), .number(let y)): return .money(x * y, c)
        case (.number(let x), .money(let y, let c)): return .money(x * y, c)
        default: return nil
        }
    }

    private func div(_ a: Value, _ b: Value) -> Value? {
        switch (a, b) {
        case (.number(let x), .number(let y)):
            return y == 0 ? nil : .number(x / y)
        case (.quantity(let x, let u), .quantity(let y, let v)) where u.dimension == v.dimension:
            guard let yc = Units.convert(y, from: v, to: u), yc != 0 else { return nil }
            return .number(x / yc)
        case (.quantity(let x, let u), .number(let y)):
            return y == 0 ? nil : .quantity(x / y, u)
        case (.money(let x, let c), .money(let y, let d)):
            guard let yc = rates.convert(y, from: d, to: c), yc != 0 else { return nil }
            return .number(x / yc)
        case (.money(let x, let c), .number(let y)):
            return y == 0 ? nil : .money(x / y, c)
        default:
            return nil
        }
    }

    private func convert(_ v: Value, to target: ConvTarget) -> Value? {
        switch (v, target) {
        case (.quantity(let x, let u), .unit(let t)):
            guard let c = Units.convert(x, from: u, to: t) else { return nil }
            return .quantity(c, t)
        case (.money(let x, let c), .currency(let t)):
            guard let converted = rates.convert(x, from: c, to: t) else { return nil }
            return .money(converted, t)
        default:
            return nil
        }
    }
}

/// Public entry point used by the UI and the test runner.
enum TallyEngine {
    static func evaluate(_ lines: [String]) -> [Value?] {
        SheetEvaluator().evaluate(lines)
    }
}
