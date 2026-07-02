import Foundation

enum Token: Equatable {
    case number(Double)
    case time(Int, Int)          // 9:30
    case op(String)              // + - * / ^ ( ) =
    case percent                 // %
    case currencySymbol(String)  // "$" → USD
    case word(String)            // lowercased
}

/// Turns a raw line into tokens. Anything it doesn't recognise is simply
/// skipped — that's what lets prose and math live on the same line.
enum Tokenizer {
    static func tokenize(_ line: String) -> [Token] {
        // Strip // comments.
        var text = line
        if let r = text.range(of: "//") { text = String(text[..<r.lowerBound]) }

        let chars = Array(text)
        var tokens: [Token] = []
        var i = 0

        func isDigit(_ c: Character) -> Bool { c.isNumber && c.isASCII }

        while i < chars.count {
            let c = chars[i]

            if isDigit(c) {
                // Try a time literal first: 1–2 digits, ':', exactly 2 digits.
                var j = i
                while j < chars.count, isDigit(chars[j]) { j += 1 }
                if j - i <= 2,
                   j + 2 < chars.count, chars[j] == ":",
                   isDigit(chars[j + 1]), isDigit(chars[j + 2]),
                   j + 3 >= chars.count || !isDigit(chars[j + 3]),
                   let h = Int(String(chars[i..<j])),
                   let m = Int(String(chars[(j + 1)...(j + 2)])),
                   h < 24, m < 60 {
                    tokens.append(.time(h, m))
                    i = j + 3
                    continue
                }
                // Plain number; commas count as grouping only before 3 digits.
                var digits = ""
                while i < chars.count {
                    let ch = chars[i]
                    if isDigit(ch) {
                        digits.append(ch); i += 1
                    } else if ch == ",", i + 3 < chars.count,
                              isDigit(chars[i + 1]), isDigit(chars[i + 2]), isDigit(chars[i + 3]),
                              i + 4 >= chars.count || !isDigit(chars[i + 4]) {
                        i += 1  // skip grouping comma
                    } else if ch == ".", i + 1 < chars.count, isDigit(chars[i + 1]),
                              !digits.contains(".") {
                        digits.append(ch); i += 1
                    } else {
                        break
                    }
                }
                if let v = Double(digits) { tokens.append(.number(v)) }
                continue
            }

            if c.isLetter {
                var word = ""
                while i < chars.count, chars[i].isLetter || chars[i].isNumber {
                    word.append(chars[i]); i += 1
                }
                // Allow one slash inside a word for km/h, m/s.
                if i < chars.count, chars[i] == "/", i + 1 < chars.count, chars[i + 1].isLetter {
                    word.append("/"); i += 1
                    while i < chars.count, chars[i].isLetter { word.append(chars[i]); i += 1 }
                }
                tokens.append(.word(word.lowercased()))
                continue
            }

            switch c {
            case "+": tokens.append(.op("+"))
            case "-", "−", "–", "—": tokens.append(.op("-"))
            case "*", "×", "·": tokens.append(.op("*"))
            case "/", "÷": tokens.append(.op("/"))
            case "^": tokens.append(.op("^"))
            case "(", ")": tokens.append(.op(String(c)))
            case "=": tokens.append(.op("="))
            case "%": tokens.append(.percent)
            case "°":
                // Merge with a following c/f into °c / °f.
                if i + 1 < chars.count, chars[i + 1] == "c" || chars[i + 1] == "f" {
                    tokens.append(.word("°" + String(chars[i + 1])))
                    i += 1
                }
            default:
                if let code = CurrencyRates.symbols[c] {
                    tokens.append(.currencySymbol(code))
                }
                // everything else (.,;:?!'" etc.) is skipped
            }
            i += 1
        }
        return tokens
    }
}
