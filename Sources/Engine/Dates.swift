import Foundation

/// Calendar-aware date parsing and arithmetic. Uses Foundation's Calendar so
/// month lengths, leap years and DST are all handled correctly.
enum Dates {
    static var cal: Calendar { Calendar.current }

    static let monthNames: [String: Int] = [
        "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3,
        "apr": 4, "april": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7,
        "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9,
        "oct": 10, "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12,
    ]

    static func make(month: Int, day: Int, year: Int?) -> Date? {
        var c = DateComponents()
        c.year = year ?? cal.component(.year, from: Date())
        c.month = month
        c.day = day
        guard let d = cal.date(from: c), cal.component(.day, from: d) == day else { return nil }
        return d
    }

    static func today() -> Date { cal.startOfDay(for: Date()) }

    static func timeToday(hour: Int, minute: Int) -> Date? {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: today())
    }

    /// date ± quantity. Month/week/day-like units go through Calendar; smaller
    /// units are added as seconds. The result keeps a sensible display style.
    static func add(_ amount: Double, _ unit: Unit, to date: Date,
                    style: DateStyle, sign: Double) -> Value? {
        guard unit.dimension == .time else { return nil }
        let signed = amount * sign
        if let comp = unit.calendar, signed == signed.rounded() {
            guard let d = cal.date(byAdding: comp, value: Int(signed), to: date) else { return nil }
            return .date(d, style)
        }
        let d = date.addingTimeInterval(unit.toBase(signed))
        // Adding hours/minutes to a plain date makes it a date+time.
        let newStyle: DateStyle = (unit.calendar == nil && style == .date) ? .dateTime : style
        return .date(d, newStyle)
    }

    /// Whole days between two dates (calendar difference, not 24h blocks).
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }
}
