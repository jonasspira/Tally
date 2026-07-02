import Foundation

/// Everything a line can evaluate to.
enum Value {
    case number(Double)
    case percent(Double)          // 15 means "15%"
    case quantity(Double, Unit)   // a number with a unit attached
    case money(Double, String)    // amount + ISO currency code
    case date(Date, DateStyle)
}

enum DateStyle { case date, time, dateTime }

extension Value {
    /// The bare number inside, used for cross-type math like "x as a % of y".
    var raw: Double? {
        switch self {
        case .number(let v), .percent(let v),
             .quantity(let v, _), .money(let v, _): return v
        case .date: return nil
        }
    }

    var formatted: String {
        switch self {
        case .number(let v):
            return Value.fmt(v)
        case .percent(let v):
            return Value.fmt(v) + "%"
        case .quantity(let v, let u):
            return Value.fmt(v) + " " + u.name
        case .money(let v, let code):
            switch code {
            case "USD": return "$" + Value.fmt(v)
            case "EUR": return "€" + Value.fmt(v)
            case "GBP": return "£" + Value.fmt(v)
            default:    return Value.fmt(v) + " " + code
            }
        case .date(let d, let style):
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            switch style {
            case .date:     f.dateFormat = "EEE, MMM d yyyy"
            case .time:     f.dateFormat = "HH:mm"
            case .dateTime: f.dateFormat = "EEE, MMM d yyyy HH:mm"
            }
            return f.string(from: d)
        }
    }

    /// "12,345.67" style formatting; more decimals for small numbers, trimmed zeros.
    static func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        f.minimumFractionDigits = 0
        let a = abs(v)
        f.maximumFractionDigits = a >= 100 ? 2 : (a >= 1 ? 4 : 6)
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
}
