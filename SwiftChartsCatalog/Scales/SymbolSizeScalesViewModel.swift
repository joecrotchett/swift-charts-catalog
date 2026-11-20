import Charts
import Foundation
import Observation

/// Which part of the week a weekday falls in: the category the symbol scale gives a shape.
nonisolated enum SymbolSizeScalesDayType: String, Plottable, CaseIterable {
    case weekday = "Monday to Friday"
    case weekend = "Weekend"

    /// The part of the week for one of the sample data's weekday names ("Sat", "Sun" are the weekend).
    init(weekday: String) {
        self = SymbolSizeScalesWording.weekendDays.contains(weekday) ? .weekend : .weekday
    }
}

/// The shapes the picker offers for the weekend. Monday to Friday is always a filled circle.
nonisolated enum SymbolSizeScalesShape: String, CaseIterable, Identifiable {
    case square = "Square"
    case diamond = "Diamond"
    case triangle = "Triangle"
    case outline = "Outline"

    var id: Self {
        self
    }

    /// The shape named in a sentence, in the plural: "Weekend drawn as diamonds."
    var pluralName: String {
        switch self {
        case .square: "squares"
        case .diamond: "diamonds"
        case .triangle: "triangles"
        case .outline: "outlined circles"
        }
    }
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum SymbolSizeScalesWording {
    /// The label of the part-of-the-week category, singular as VoiceOver pluralises it.
    static let dayType = "Day type"
    /// The weekend's names in the sample data.
    static let weekendDays: Set<String> = ["Sat", "Sun"]
    /// The sample data's weekday abbreviations written out, for what is read and spoken.
    static let fullWeekdays = [
        "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday",
        "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday",
    ]

    static func fullName(_ weekday: String) -> String {
        fullWeekdays[weekday] ?? weekday
    }

    /// "1 square point", "300 square points": a symbol's area.
    static func squarePoints(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) square point](inflect: true)", locale: locale).characters)
    }

    /// "1 slot", "42 slots". `CafeWording` has no count for slots, so it is added here in the same form.
    static func slots(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) slot](inflect: true)", locale: locale).characters)
    }

    /// "Tuesday at 8 am".
    static func slotName(_ slot: HourlyOrders) -> String {
        "\(fullName(slot.weekday)) at \(slot.slot)"
    }
}

/// What the chart says in words: its headline and the Audio Graph's summary.
nonisolated struct SymbolSizeScalesSummary {
    let slots: [HourlyOrders]
    /// The locale counts are written in; the view passes its environment's.
    let locale: Locale

    var hasData: Bool {
        !slots.isEmpty
    }

    var mostOrders: Int {
        slots.map(\.orders).max() ?? 0
    }

    var fewestOrders: Int {
        slots.map(\.orders).min() ?? 0
    }

    /// Every slot with the most orders, in data order. Empty when no slot took an order.
    var busiest: [HourlyOrders] {
        guard mostOrders > 0 else { return [] }
        return slots.filter { $0.orders == mostOrders }
    }

    /// Every slot with the fewest orders, in data order.
    var quietest: [HourlyOrders] {
        guard mostOrders > 0 else { return [] }
        return slots.filter { $0.orders == fewestOrders }
    }

    /// The chart's message, with a figure the reader finds as the largest symbol. True on a tie,
    /// with no data, and when every slot is zero.
    var headline: String {
        guard hasData else { return "No orders taken yet." }
        guard !busiest.isEmpty else { return "No orders in any slot, so every symbol is the same size." }
        // Symbols within a few orders of the largest cannot be told apart by size (80 and 79 look the same), so
        // the headline names them together instead of claiming one is drawn largest.
        let leaders = nearlyBusiest
        if leaders.count > busiest.count, let lowest = leaders.map(\.orders).min() {
            return "\(names(leaders)) took the most orders, within a few of each other: "
                + "\(lowest.formatted(.number.locale(locale))) to \(CafeWording.orders(mostOrders, locale: locale))."
        }
        return "Most orders: \(CafeWording.orders(mostOrders, locale: locale)), "
            + "\(names(busiest)), drawn largest."
    }

    /// How close to the most a slot must be to count as level with it, as a share of the most: 3%.
    static let nearTieShare = 0.03

    /// Every slot within `nearTieShare` of the most orders, in data order: the slots whose symbols are the same
    /// size to the eye.
    var nearlyBusiest: [HourlyOrders] {
        guard mostOrders > 0 else { return [] }
        let threshold = Double(mostOrders) * (1 - Self.nearTieShare)
        return slots.filter { Double($0.orders) >= threshold }
    }

    /// Actual values, then what the scales draw: which shape each part of the week has and the size range.
    func audioGraphSummary(weekendShape: SymbolSizeScalesShape, sizeRange: ClosedRange<Double>?) -> String {
        guard hasData else { return "No orders taken yet." }
        let slotCount = SymbolSizeScalesWording.slots(slots.count, locale: locale)
        let shapes = "Monday to Friday drawn as filled circles, the weekend as \(weekendShape.pluralName)."
        let sizes = if let sizeRange {
            // The size scale's domain starts at zero, so the range's low end is the area for zero orders.
            "Symbol areas run from \(SymbolSizeScalesWording.squarePoints(Int(sizeRange.lowerBound), locale: locale)) "
                + "for zero orders to \(SymbolSizeScalesWording.squarePoints(Int(sizeRange.upperBound), locale: locale)) "
                + "for the most."
        } else {
            "Symbol sizes use the framework’s default range, so neighbouring symbols overlap."
        }
        guard !busiest.isEmpty else {
            return "\(slotCount), no orders in any of them. \(shapes)"
        }
        return "\(slotCount). Most orders: \(CafeWording.orders(mostOrders, locale: locale)), \(names(busiest)). "
            + "Fewest: \(CafeWording.orders(fewestOrders, locale: locale)), \(names(quietest)). \(shapes) \(sizes)"
    }

    func names(_ slots: [HourlyOrders]) -> String {
        CafeWording.list(slots.map(SymbolSizeScalesWording.slotName))
    }
}

/// The screen's settings: the weekend's shape and the range of symbol sizes.
@Observable
final class SymbolSizeScalesViewModel {
    static let smallestAreaRange: ClosedRange<Double> = 4 ... 80
    static let largestAreaRange: ClosedRange<Double> = 100 ... 1000

    /// The shape the symbol scale gives the weekend.
    var weekendShape: SymbolSizeScalesShape = .diamond
    /// The area, in square points, of the symbol for zero orders: the size scale's domain starts at zero.
    var smallestArea: Double = 16
    /// The area, in square points, of the symbol for the most orders.
    var largestArea: Double = 300
    /// Shows the mistake: no `chartSymbolSizeScale(range:)`, so the default range is drawn.
    var usesDefaultRange = false

    /// The range passed to `chartSymbolSizeScale(range:)`, or `nil` when the default is shown.
    var sizeRange: ClosedRange<Double>? {
        usesDefaultRange ? nil : smallestArea ... largestArea
    }

    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "symbol-size-scales-marks", title: "Shape and size from the data"),
            usesDefaultRange
                ? SnippetReference(name: "symbol-size-scales-default-range", title: "No size range: the default")
                : SnippetReference(name: "symbol-size-scales-scales", title: "The symbol scale and the size range"),
            SnippetReference(name: "symbol-size-scales-shapes", title: "The shape for each part of the week"),
        ]
    }

    func smallestAreaText(locale: Locale) -> String {
        "\(Int(smallestArea).formatted(.number.locale(locale))) pt²"
    }

    func largestAreaText(locale: Locale) -> String {
        "\(Int(largestArea).formatted(.number.locale(locale))) pt²"
    }

    func smallestAreaSpoken(locale: Locale) -> String {
        SymbolSizeScalesWording.squarePoints(Int(smallestArea), locale: locale)
    }

    func largestAreaSpoken(locale: Locale) -> String {
        SymbolSizeScalesWording.squarePoints(Int(largestArea), locale: locale)
    }

    /// Said when the symbol scale changes: what changed, then the headline.
    func shapeAnnouncement(headline: String) -> String {
        "Weekend now drawn as \(weekendShape.pluralName). \(headline)"
    }

    /// Said when the size scale switches between its set range and the default.
    func rangeAnnouncement(headline: String, locale: Locale) -> String {
        if usesDefaultRange {
            return "Size range left at the default. \(headline)"
        }
        return "Symbol areas from \(smallestAreaSpoken(locale: locale)) to \(largestAreaSpoken(locale: locale)). \(headline)"
    }
}
