import Foundation

enum Dimension {
    case length, mass, volume, time, data, temperature, speed, area
}

/// A unit of measurement. `factor`/`offset` convert to the dimension's base unit
/// (metres, kilograms, litres, seconds, bytes, kelvin, m/s, m²).
struct Unit: Equatable {
    let name: String                        // display name, e.g. "km"
    let dimension: Dimension
    let factor: Double
    let offset: Double
    let calendar: Calendar.Component?       // set for units used in calendar math

    init(_ name: String, _ dimension: Dimension, _ factor: Double,
         offset: Double = 0, calendar: Calendar.Component? = nil) {
        self.name = name
        self.dimension = dimension
        self.factor = factor
        self.offset = offset
        self.calendar = calendar
    }

    func toBase(_ v: Double) -> Double { v * factor + offset }
    func fromBase(_ v: Double) -> Double { (v - offset) / factor }

    static func == (a: Unit, b: Unit) -> Bool { a.name == b.name }
}

enum Units {
    static func find(_ word: String) -> Unit? { registry[word.lowercased()] }

    static func convert(_ v: Double, from: Unit, to: Unit) -> Double? {
        guard from.dimension == to.dimension else { return nil }
        return to.fromBase(from.toBase(v))
    }

    /// (canonical unit, aliases). Every alias — including the display name — must
    /// be listed; the registry is flat alias → Unit.
    private static let table: [(Unit, [String])] = [
        // Length (base: metre)
        (Unit("mm", .length, 0.001),        ["mm", "millimeter", "millimeters", "millimetre", "millimetres"]),
        (Unit("cm", .length, 0.01),         ["cm", "centimeter", "centimeters", "centimetre", "centimetres"]),
        (Unit("m", .length, 1),             ["m", "meter", "meters", "metre", "metres"]),
        (Unit("km", .length, 1000),         ["km", "kilometer", "kilometers", "kilometre", "kilometres"]),
        (Unit("inches", .length, 0.0254),   ["inch", "inches"]),   // "in" is the conversion keyword
        (Unit("ft", .length, 0.3048),       ["ft", "foot", "feet"]),
        (Unit("yd", .length, 0.9144),       ["yd", "yard", "yards"]),
        (Unit("miles", .length, 1609.344),  ["mi", "mile", "miles"]),
        // Mass (base: kilogram)
        (Unit("mg", .mass, 1e-6),           ["mg", "milligram", "milligrams"]),
        (Unit("g", .mass, 0.001),           ["g", "gram", "grams"]),
        (Unit("kg", .mass, 1),              ["kg", "kilo", "kilos", "kilogram", "kilograms"]),
        (Unit("tonnes", .mass, 1000),       ["ton", "tons", "tonne", "tonnes"]),
        (Unit("oz", .mass, 0.028349523),    ["oz", "ounce", "ounces"]),
        (Unit("lb", .mass, 0.45359237),     ["lb", "lbs", "pound", "pounds"]),
        (Unit("stone", .mass, 6.35029318),  ["stone", "stones"]),
        // Volume (base: litre)
        (Unit("ml", .volume, 0.001),        ["ml", "milliliter", "milliliters", "millilitre", "millilitres"]),
        (Unit("cl", .volume, 0.01),         ["cl"]),
        (Unit("dl", .volume, 0.1),          ["dl"]),
        (Unit("L", .volume, 1),             ["l", "liter", "liters", "litre", "litres"]),
        (Unit("tsp", .volume, 0.00492892),  ["tsp", "teaspoon", "teaspoons"]),
        (Unit("tbsp", .volume, 0.0147868),  ["tbsp", "tablespoon", "tablespoons"]),
        (Unit("cups", .volume, 0.236588),   ["cup", "cups"]),
        (Unit("pints", .volume, 0.473176),  ["pint", "pints"]),
        (Unit("gallons", .volume, 3.78541), ["gal", "gallon", "gallons"]),
        // Time (base: second). Month/year are calendar-aware for date math and
        // use average lengths for plain conversions.
        (Unit("ms", .time, 0.001),          ["ms", "millisecond", "milliseconds"]),
        (Unit("s", .time, 1),               ["s", "sec", "secs", "second", "seconds"]),
        (Unit("min", .time, 60),            ["min", "mins", "minute", "minutes"]),
        (Unit("h", .time, 3600),            ["h", "hr", "hrs", "hour", "hours"]),
        (Unit("days", .time, 86400, calendar: .day),            ["day", "days"]),
        (Unit("weeks", .time, 604800, calendar: .weekOfYear),   ["wk", "week", "weeks"]),
        (Unit("months", .time, 2_629_746, calendar: .month),    ["month", "months"]),
        (Unit("years", .time, 31_556_952, calendar: .year),     ["yr", "yrs", "year", "years"]),
        // Data (base: byte). KB/MB/GB are decimal; KiB/MiB/GiB binary.
        (Unit("bits", .data, 0.125),        ["bit", "bits"]),
        (Unit("B", .data, 1),               ["b", "byte", "bytes"]),
        (Unit("KB", .data, 1e3),            ["kb", "kilobyte", "kilobytes"]),
        (Unit("MB", .data, 1e6),            ["mb", "megabyte", "megabytes"]),
        (Unit("GB", .data, 1e9),            ["gb", "gigabyte", "gigabytes"]),
        (Unit("TB", .data, 1e12),           ["tb", "terabyte", "terabytes"]),
        (Unit("KiB", .data, 1024),          ["kib"]),
        (Unit("MiB", .data, 1_048_576),     ["mib"]),
        (Unit("GiB", .data, 1_073_741_824), ["gib"]),
        (Unit("TiB", .data, 1_099_511_627_776), ["tib"]),
        // Temperature (base: kelvin)
        (Unit("°C", .temperature, 1, offset: 273.15),               ["c", "celsius", "°c"]),
        (Unit("°F", .temperature, 5.0 / 9.0, offset: 255.3722222),  ["f", "fahrenheit", "°f"]),
        (Unit("K", .temperature, 1),                                ["kelvin"]),
        // Speed (base: m/s)
        (Unit("m/s", .speed, 1),            ["m/s"]),
        (Unit("km/h", .speed, 0.2777778),   ["km/h", "kmh", "kph"]),
        (Unit("mph", .speed, 0.44704),      ["mph"]),
        (Unit("knots", .speed, 0.5144444),  ["knot", "knots"]),
        // Area (base: m²)
        (Unit("m²", .area, 1),              ["m2", "sqm"]),
        (Unit("km²", .area, 1e6),           ["km2"]),
        (Unit("ha", .area, 1e4),            ["ha", "hectare", "hectares"]),
        (Unit("acres", .area, 4046.8564),   ["acre", "acres"]),
        (Unit("sqft", .area, 0.09290304),   ["sqft", "ft2"]),
    ]

    private static let registry: [String: Unit] = {
        var r: [String: Unit] = [:]
        for (unit, aliases) in table {
            for a in aliases { r[a] = unit }
        }
        return r
    }()
}
