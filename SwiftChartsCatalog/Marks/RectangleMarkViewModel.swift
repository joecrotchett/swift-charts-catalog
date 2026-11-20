import Foundation
import Observation

/// Which job of `RectangleMark` the screen shows.
nonisolated enum RectangleUse: String, CaseIterable, Identifiable {
    case region = "Region"
    case tick = "Tick"

    var id: Self {
        self
    }
}

/// The axes a shaded region is bounded on. On an axis it is not bounded on, it spans the plot.
nonisolated enum RegionBounds: String, CaseIterable, Identifiable {
    case xOnly = "x only"
    case yOnly = "y only"
    case both = "Both"

    var id: Self {
        self
    }
}

/// The state of the Rectangle screen: which use is shown, and which axes bound the region.
@Observable
final class RectangleMarkViewModel {
    var use = RectangleUse.region
    var bounds = RegionBounds.xOnly

    let orders: [OrderWait]
    let months: [MonthlySummary]
    let region: OrderRegion

    init(
        orders: [OrderWait] = CafeData.orderWaits,
        months: [MonthlySummary] = CafeData.monthlySummaries,
        region: OrderRegion = .sample
    ) {
        self.orders = orders
        self.months = months
        self.region = region
    }

    /// The bounds picker only means something while the region is shown.
    var showsBoundsControl: Bool {
        use == .region
    }

    /// The region chart's words in the locale given: the screen passes its environment's.
    func regionSummary(locale: Locale) -> OrderRegionSummary {
        OrderRegionSummary(orders: orders, region: region, bounds: bounds, locale: locale)
    }

    func monthlySummary(locale: Locale) -> MonthlyTickSummary {
        MonthlyTickSummary(months: months, locale: locale)
    }

    var caption: String {
        switch use {
        case .region: "Queue and wait for each order"
        case .tick: CafeWording.monthlyRangesCaption
        }
    }

    /// The headline for the chart as it is now drawn.
    func headline(locale: Locale) -> String {
        switch use {
        case .region: regionSummary(locale: locale).headline
        case .tick: monthlySummary(locale: locale).headline
        }
    }

    var explanation: String {
        switch use {
        case .region:
            """
            RectangleMark shades a region when it is given a start and an end on each axis that bounds it. \
            On an axis it is given nothing for, it spans the whole plot. It is written before the points, \
            so it is drawn behind them, and its fill is kept faint.
            """
        case .tick:
            """
            Given one value on each axis and a fixed height, RectangleMark draws a thin tick, here at each \
            month's average day. The tick takes the same month and the same width as the bar that shows \
            the month's lowest and highest days, so the two share a band and line up.
            """
        }
    }

    /// The code behind the chart as it is now drawn.
    var snippets: [SnippetReference] {
        switch use {
        case .region:
            [
                Self.edgesSnippet(for: bounds),
                SnippetReference(name: "rectangle-region-layer", title: "Written before the points, so it is behind them"),
            ]
        case .tick:
            [SnippetReference(name: "rectangle-tick", title: "A tick on the bar's band")]
        }
    }

    static func edgesSnippet(for bounds: RegionBounds) -> SnippetReference {
        switch bounds {
        case .xOnly: SnippetReference(name: "rectangle-region-x", title: "A region bounded on x")
        case .yOnly: SnippetReference(name: "rectangle-region-y", title: "A region bounded on y")
        case .both: SnippetReference(name: "rectangle-region-both", title: "A region bounded on both axes")
        }
    }

    /// What to say aloud when a control redraws the chart.
    func announcement(locale: Locale) -> String {
        "Chart changed. \(caption). \(headline(locale: locale))"
    }
}

/// The region the screen shades: a range of queue lengths and a range of waits.
nonisolated struct OrderRegion: Hashable {
    /// People in the queue, both ends included.
    let queue: ClosedRange<Int>
    /// Seconds waited, both ends included.
    let wait: ClosedRange<Int>

    static let sample = OrderRegion(queue: 6 ... 9, wait: 100 ... 220)

    /// Queue lengths are whole numbers, so the region's edges are drawn half a person either side:
    /// no point then sits on an edge.
    var queueStart: Double {
        Double(queue.lowerBound) - 0.5
    }

    var queueEnd: Double {
        Double(queue.upperBound) + 0.5
    }

    func contains(_ order: OrderWait, bounds: RegionBounds) -> Bool {
        switch bounds {
        case .xOnly: queue.contains(order.queueLength)
        case .yOnly: wait.contains(order.waitSeconds)
        case .both: queue.contains(order.queueLength) && wait.contains(order.waitSeconds)
        }
    }
}

/// One café's orders in one stretch of queue lengths: what one accessibility element covers.
nonisolated struct RectangleOrderPortion: Identifiable, Hashable {
    let store: String
    let queue: ClosedRange<Int>
    let orders: [OrderWait]
    /// The locale its words are written in, the summary's.
    let locale: Locale

    var id: String {
        "\(store)-\(queue.lowerBound)"
    }

    var label: String {
        "\(store), queues of \(RectangleMarkText.people(queue, locale: locale))"
    }

    var value: String {
        let waits = orders.map(\.waitSeconds)
        guard let shortest = waits.min(), let longest = waits.max() else { return CafeWording.orders(0, locale: locale) }
        if orders.count == 1 {
            return "\(CafeWording.orders(1, locale: locale)), wait \(CafeWording.seconds(longest, locale: locale))"
        }
        return "\(CafeWording.orders(orders.count, locale: locale)), "
            + "waits from \(RectangleMarkText.number(shortest, locale: locale)) to \(CafeWording.seconds(longest, locale: locale))"
    }
}

/// What the scatter plot and its shaded region say in words.
nonisolated struct OrderRegionSummary {
    /// How many queue lengths one accessibility element covers.
    static let queueLengthsPerPortion = 4

    let orders: [OrderWait]
    let region: OrderRegion
    let bounds: RegionBounds

    /// The queue axis as drawn, from zero to the longest queue rounded up to the axis step (11 → 15): the chart's
    /// x scale and the descriptor's.
    var queueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.queueLength))
    }

    /// The wait axis as drawn, from zero to the longest wait rounded up (309 → 400): the chart's y scale and the
    /// descriptor's.
    var waitDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.waitSeconds))
    }

    /// The locale every number and count here is written in. It has no default: the views pass the
    /// environment's, so the headline, the elements and the Audio Graph agree.
    let locale: Locale

    var ordersInRegion: Int {
        orders.count { region.contains($0, bounds: bounds) }
    }

    /// The cafés, in the order they first appear in the data.
    var stores: [String] {
        var seen: [String] = []
        for order in orders where !seen.contains(order.store) {
            seen.append(order.store)
        }
        return seen
    }

    /// What the region covers, on the axes that bound it.
    var regionDescription: String {
        let queues = "queues of \(RectangleMarkText.people(region.queue, locale: locale))"
        let waits = "waits of \(RectangleMarkText.number(region.wait.lowerBound, locale: locale)) "
            + "to \(CafeWording.seconds(region.wait.upperBound, locale: locale))"
        return switch bounds {
        case .xOnly: queues
        case .yOnly: waits
        case .both: "\(queues) and \(waits)"
        }
    }

    var headline: String {
        guard !orders.isEmpty else { return "No orders yet." }
        return "The shaded region holds \(regionValue): \(regionDescription)."
    }

    /// What the region's own accessibility element says.
    var regionLabel: String {
        "Shaded region, \(regionDescription)"
    }

    var regionValue: String {
        "\(RectangleMarkText.number(ordersInRegion, locale: locale)) of \(CafeWording.orders(orders.count, locale: locale))"
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        let queues = orders.map(\.queueLength)
        let waits = orders.map(\.waitSeconds)
        guard let shortestQueue = queues.min(), let longestQueue = queues.max(),
              let shortestWait = waits.min(), let longestWait = waits.max()
        else { return "No orders yet." }
        return "\(CafeWording.orders(orders.count, locale: locale)) at \(RectangleMarkText.cafes(stores.count, locale: locale)). "
            + "Queues from \(RectangleMarkText.number(shortestQueue, locale: locale)) to \(CafeWording.people(longestQueue, locale: locale)), "
            + "waits from \(RectangleMarkText.number(shortestWait, locale: locale)) to \(CafeWording.seconds(longestWait, locale: locale)). "
            + "The shaded region, \(regionDescription), holds \(CafeWording.orders(ordersInRegion, locale: locale))."
    }

    /// Each café's orders, a stretch of queue lengths at a time, in café and then queue order.
    var portions: [RectangleOrderPortion] {
        let size = Self.queueLengthsPerPortion
        return stores.flatMap { store in
            let grouped = Dictionary(grouping: orders.filter { $0.store == store }) { $0.queueLength / size }
            return grouped.keys.sorted().map { index in
                RectangleOrderPortion(
                    store: store,
                    queue: index * size ... index * size + size - 1,
                    orders: (grouped[index] ?? []).sorted { $0.queueLength < $1.queueLength },
                    locale: locale
                )
            }
        }
    }
}

/// What the monthly range chart says in words.
nonisolated struct MonthlyTickSummary {
    let months: [MonthlySummary]
    /// The locale months and numbers are written in. It has no default: the chart passes the one it is drawn in.
    let locale: Locale

    /// Months with nothing sold on any day draw no marks worth a headline: that is no data.
    var hasData: Bool {
        months.contains { $0.highestDay > 0 }
    }

    /// The cups axis as drawn, from zero to the busiest day rounded up to the axis step (347 → 400): the chart's
    /// scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: months.map(\.highestDay))
    }

    /// Every month with the highest average day, in data order. More than one on a tie.
    var busiestMonths: [MonthlySummary] {
        guard hasData, let highest = months.map(\.averageDay).max() else { return [] }
        return months.filter { $0.averageDay == highest }
    }

    var headline: String {
        guard let average = busiestMonths.first?.averageDay else { return "No sales yet." }
        let names = busiestMonths.map { RectangleMarkText.monthName($0.month, locale: locale) }
            .formatted(.list(type: .and).locale(locale))
        return "\(names) had the highest average day: \(CafeWording.cups(average, locale: locale))."
    }

    /// What one month's accessibility element says after its name.
    func value(for month: MonthlySummary) -> String {
        "Lowest day \(CafeWording.cups(month.lowestDay, locale: locale)), "
            + "highest day \(CafeWording.cups(month.highestDay, locale: locale)), "
            + "average day \(CafeWording.cups(month.averageDay, locale: locale))"
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard hasData, let first = months.first, let last = months.last,
              let lowest = months.map(\.lowestDay).min(), let highest = months.map(\.highestDay).max(),
              let lowestAverage = months.map(\.averageDay).min(), let highestAverage = months.map(\.averageDay).max()
        else { return "No sales yet." }
        return "\(CafeWording.months(months.count, locale: locale)), "
            + "\(RectangleMarkText.monthAndYear(first.month, locale: locale)) to "
            + "\(RectangleMarkText.monthAndYear(last.month, locale: locale)). "
            + "Lowest day \(CafeWording.cups(lowest, locale: locale)), "
            + "highest day \(CafeWording.cups(highest, locale: locale)). "
            + "Average day from \(RectangleMarkText.number(lowestAverage, locale: locale)) "
            + "to \(CafeWording.cups(highestAverage, locale: locale))."
    }
}

/// The words this screen adds to `CafeWording`'s counts, and months named in the time zone the data was made in.
nonisolated enum RectangleMarkText {
    /// A range of queue lengths: "6 to 9 people".
    static func people(_ range: ClosedRange<Int>, locale: Locale) -> String {
        "\(number(range.lowerBound, locale: locale)) to \(CafeWording.people(range.upperBound, locale: locale))"
    }

    /// A whole number in the given locale's digits and grouping.
    static func number(_ count: Int, locale: Locale) -> String {
        count.formatted(.number.locale(locale))
    }

    /// "1 café", "2 cafés".
    static func cafes(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) café](inflect: true)", locale: locale).characters)
    }

    /// "July", in the data's time zone, so it names the month that is drawn, and in the given locale.
    static func monthName(_ month: Date, locale: Locale) -> String {
        month.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide))
    }

    /// "July 2026", in the data's time zone and the given locale.
    static func monthAndYear(_ month: Date, locale: Locale) -> String {
        month.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).year())
    }
}
