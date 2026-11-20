import Foundation
import Observation

/// How long each bar on the "Ranges as values" screen is.
nonisolated enum RangesAsValuesPeriod: String, CaseIterable, Identifiable {
    case halfHour
    case twoHours
    case named

    var id: Self {
        self
    }

    /// The picker's word for the period.
    var title: String {
        switch self {
        case .halfHour: "Half hour"
        case .twoHours: "Two hours"
        case .named: "Named"
        }
    }

    /// What one bar stands for, after "orders per".
    var perWhat: String {
        switch self {
        case .halfHour: "half hour"
        case .twoHours: "two hours"
        case .named: "named period"
        }
    }

    /// What one bar stands for, after "the most in one".
    var inOneWhat: String {
        switch self {
        case .halfHour: "half hour"
        case .twoHours: "two-hour stretch"
        case .named: "named period"
        }
    }
}

/// One bar: the period it covers, as a range of dates, and the orders taken in it.
nonisolated struct RangesAsValuesBar: Identifiable, Hashable {
    /// The café's name for the period, for the named periods only.
    let name: String?
    let time: Range<Date>
    let orders: Int

    var id: Date {
        time.lowerBound
    }
}

/// The bars for each period, built from the half-hour orders. Every total is a sum of half hours.
nonisolated enum RangesAsValuesData {
    /// The length of one row of `CafeData.halfHourOrders`.
    static let halfHour: TimeInterval = 30 * 60
    static let twoHours: TimeInterval = 2 * 60 * 60

    static func bars(
        for period: RangesAsValuesPeriod, halfHours: [HalfHourOrders], servicePeriods: [ServicePeriod]
    ) -> [RangesAsValuesBar] {
        switch period {
        case .halfHour: halfHourBars(halfHours)
        case .twoHours: twoHourBars(halfHours)
        case .named: namedBars(servicePeriods, halfHours: halfHours)
        }
    }

    // snippet:ranges-as-values-half-hours
    /// A half hour is not a calendar unit, so each row's range is built: its start to 30 minutes later.
    static func halfHourBars(_ rows: [HalfHourOrders]) -> [RangesAsValuesBar] {
        rows.map { row in
            RangesAsValuesBar(name: nil, time: row.start ..< row.start.addingTimeInterval(halfHour), orders: row.orders)
        }
    }

    // end

    // snippet:ranges-as-values-two-hours
    /// Two-hour ranges from the first half hour to the end of the last, each the sum of the half hours in it.
    static func twoHourBars(_ rows: [HalfHourOrders]) -> [RangesAsValuesBar] {
        guard let first = rows.first?.start, let last = rows.last?.start else { return [] }
        let end = last.addingTimeInterval(halfHour)
        return stride(from: first, to: end, by: twoHours).map { start in
            let time = start ..< min(start.addingTimeInterval(twoHours), end)
            return RangesAsValuesBar(name: nil, time: time, orders: total(of: rows, in: time))
        }
    }

    // end

    // snippet:ranges-as-values-named-periods
    /// Each named period is already a start and an end: the range is simply start ..< end.
    static func namedBars(_ periods: [ServicePeriod], halfHours: [HalfHourOrders]) -> [RangesAsValuesBar] {
        periods.map { period in
            let time = period.start ..< period.end
            return RangesAsValuesBar(name: period.name, time: time, orders: total(of: halfHours, in: time))
        }
    }

    // end

    /// The orders of every half hour that starts inside the range.
    static func total(of rows: [HalfHourOrders], in time: Range<Date>) -> Int {
        rows.filter { time.contains($0.start) }.map(\.orders).reduce(0, +)
    }
}

/// What the chart says in words, for one set of bars, in the locale the view is shown in.
nonisolated struct RangesAsValuesSummary {
    let bars: [RangesAsValuesBar]
    let period: RangesAsValuesPeriod
    let locale: Locale

    var total: Int {
        bars.map(\.orders).reduce(0, +)
    }

    /// The orders axis as drawn, from zero to the busiest period rounded up to the axis step (57 → 60): the
    /// chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: bars.map(\.orders))
    }

    /// No orders at all: the chart shows a placeholder, and the words say so.
    var isEmpty: Bool {
        total == 0
    }

    /// Every bar with the most orders, in time order. More than one on a tie; none when nothing was ordered.
    var busiest: [RangesAsValuesBar] {
        guard let most = bars.map(\.orders).max(), most > 0 else { return [] }
        return bars.filter { $0.orders == most }
    }

    /// Every bar with the fewest orders, in time order.
    var quietest: [RangesAsValuesBar] {
        guard let fewest = bars.map(\.orders).min(), !isEmpty else { return [] }
        return bars.filter { $0.orders == fewest }
    }

    /// A time of day as the sample data recorded it, in UTC, in the view's locale: "8:00 AM".
    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).hour().minute())
    }

    /// "8:00 AM to 8:30 AM".
    func span(_ bar: RangesAsValuesBar) -> String {
        "\(time(bar.time.lowerBound)) to \(time(bar.time.upperBound))"
    }

    /// What a bar is called, aloud and in the Audio Graph: its name, if it has one, then its times.
    func label(_ bar: RangesAsValuesBar) -> String {
        if let name = bar.name {
            "\(name), \(span(bar))"
        } else {
            span(bar)
        }
    }

    /// "62 orders".
    func orders(_ count: Int) -> String {
        CafeWording.orders(count, locale: locale)
    }

    var caption: String {
        "Orders per \(period.perWhat)"
    }

    /// The concept in two or three sentences. With the named periods the bars differ in width, so it
    /// adds that the height is what carries the total: a wide bar is not a bigger one.
    var explanation: String {
        let concept = "Each bar's x value is a range of dates, start ..< end, and the bar spans exactly that period. "
            + "Half hours and the café's named periods are not calendar units, so unit: cannot draw them; a range can, "
            + "and a period of two and a half hours gets a bar five times as wide as a half hour."
        guard period == .named else { return concept }
        return concept + " The height of each bar is its total, not its area: a wide bar with a lower top took fewer orders."
    }

    /// The Audio Graph's title: the caption and the day, written in UTC as the data was: "Orders per half hour, March 1".
    var title: String {
        guard let first = bars.first?.time.lowerBound else { return caption }
        let day = first.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).day())
        return "\(caption), \(day)"
    }

    /// The chart's message, with the figure of its tallest bar. True on a tie and when nothing was ordered.
    var headline: String {
        guard let most = busiest.first?.orders else { return "No orders taken yet." }
        let places = CafeWording.list(busiest.map { bar in
            if let name = bar.name { "\(name), from \(span(bar))" } else { "from \(span(bar))" }
        })
        return "The most in one \(period.inOneWhat): \(orders(most)), \(places)."
    }

    /// What is said when the period changes: what changed, then the headline.
    var announcement: String {
        "Showing orders per \(period.perWhat). \(headline)"
    }

    /// The Audio Graph's summary, in actual values only.
    var audioGraphSummary: String {
        guard let most = busiest.first?.orders, let fewest = quietest.first?.orders else {
            return "No orders taken yet."
        }
        return "\(CafeWording.bars(bars.count, locale: locale)), \(orders(total)) in total. "
            + "Most: \(CafeWording.list(busiest.map(label))), \(orders(most)). "
            + "Fewest: \(CafeWording.list(quietest.map(label))), \(orders(fewest))."
    }
}

/// The screen's state: which period the bars cover.
@Observable
final class RangesAsValuesViewModel {
    var period: RangesAsValuesPeriod = .halfHour
    let halfHours: [HalfHourOrders]
    let servicePeriods: [ServicePeriod]

    init(halfHours: [HalfHourOrders] = CafeData.halfHourOrders, servicePeriods: [ServicePeriod] = CafeData.servicePeriods) {
        self.halfHours = halfHours
        self.servicePeriods = servicePeriods
    }

    var bars: [RangesAsValuesBar] {
        RangesAsValuesData.bars(for: period, halfHours: halfHours, servicePeriods: servicePeriods)
    }

    func summary(locale: Locale) -> RangesAsValuesSummary {
        RangesAsValuesSummary(bars: bars, period: period, locale: locale)
    }

    /// The chart's code, then how the current period's ranges are made.
    var snippets: [SnippetReference] {
        let chart = SnippetReference(name: "ranges-as-values-chart", title: "A range of dates as x")
        return switch period {
        case .halfHour: [chart, SnippetReference(name: "ranges-as-values-half-hours", title: "Half-hour ranges")]
        case .twoHours: [chart, SnippetReference(name: "ranges-as-values-two-hours", title: "Two-hour ranges")]
        case .named: [chart, SnippetReference(name: "ranges-as-values-named-periods", title: "Named-period ranges")]
        }
    }
}
