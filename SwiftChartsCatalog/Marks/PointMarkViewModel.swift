import Charts
import Foundation
import Observation

/// How many axes the points are given a value on.
nonisolated enum PointAxes: String, CaseIterable, Identifiable {
    /// A value on x and on y: a scatter plot.
    case two
    /// A value on x only: every point on one line.
    case one

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .two: "Two axes"
        case .one: "One axis"
        }
    }
}

/// The state behind the Point screen: whether café is encoded as colour and symbol, and how many axes.
@Observable
final class PointMarkViewModel {
    let orders: [OrderWait]
    /// Colour and symbol by café, on or off together.
    var showsEncodings = true
    var axes = PointAxes.two

    init(orders: [OrderWait] = CafeData.orderWaits) {
        self.orders = orders
    }

    /// The chart in words, for the current setting of both controls, with numbers written for a locale.
    func summary(locale: Locale) -> PointMarkSummary {
        PointMarkSummary(orders: orders, axes: axes, showsEncodings: showsEncodings, locale: locale)
    }

    /// The code the chart is drawn with right now.
    var snippets: [SnippetReference] {
        switch (axes, showsEncodings) {
        case (.two, true):
            [SnippetReference(name: "point-scatter-encoded", title: "A scatter plot, colour and symbol by café")]
        case (.two, false):
            [SnippetReference(name: "point-scatter", title: "A scatter plot")]
        case (.one, true):
            [SnippetReference(name: "point-strip-encoded", title: "Points on one axis, colour and symbol by café")]
        case (.one, false):
            [SnippetReference(name: "point-strip", title: "Points on one axis")]
        }
    }
}

/// A stretch of the chart that is one accessibility element: the orders in it, and what is said for them.
nonisolated struct PointPortion: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let orders: [OrderWait]
    /// The stretch of x the portion covers, both ends included.
    let band: PointBand
}

/// A run of whole numbers the orders are grouped by, both ends included.
nonisolated struct PointBand: Equatable {
    let lower: Int
    let upper: Int
}

/// What the chart says in words for one setting of the controls: the headline, the accessibility
/// elements, the Audio Graph summary and the announcement made when a control changes the chart.
nonisolated struct PointMarkSummary {
    /// How many people of queue one accessibility element covers on the scatter plot.
    static let queueBandSize = 4
    /// How many seconds of wait one accessibility element, and one Audio Graph category, covers on the strip.
    static let waitBandSize = 60

    let orders: [OrderWait]
    let axes: PointAxes
    let showsEncodings: Bool
    /// The locale numbers are written in: the view's.
    let locale: Locale

    /// Only an empty list is no data. Orders that all waited zero seconds are still drawn as points.
    var hasData: Bool {
        !orders.isEmpty
    }

    /// The cafés, in the order they first appear in the data.
    var stores: [String] {
        var seen: [String] = []
        for order in orders where !seen.contains(order.store) {
            seen.append(order.store)
        }
        return seen
    }

    /// The groups the chart tells apart: one per café when café is encoded, otherwise all orders together.
    var groups: [(store: String?, orders: [OrderWait])] {
        guard showsEncodings else { return [(nil, orders)] }
        return stores.map { store in (store, orders.filter { $0.store == store }) }
    }

    var shortestWait: Int {
        orders.map(\.waitSeconds).min() ?? 0
    }

    var longestWait: Int {
        orders.map(\.waitSeconds).max() ?? 0
    }

    var longestQueue: Int {
        orders.map(\.queueLength).max() ?? 0
    }

    var shortestQueue: Int {
        orders.map(\.queueLength).min() ?? 0
    }

    /// The queue axis as drawn, from zero to the longest queue rounded up to the axis step (11 → 15): the scatter
    /// plot's x scale and the descriptor's.
    var queueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.queueLength))
    }

    /// The wait axis as drawn, from zero to the longest wait rounded up (309 → 400): the scatter plot's y scale,
    /// the strip's x scale, and the descriptor's. Never empty, even when every wait is the same.
    var waitDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.waitSeconds))
    }

    // MARK: Headline

    /// The chart's message. It names only what the chart currently draws: the café when café is encoded,
    /// the queue when the queue has an axis.
    var headline: String {
        guard hasData else { return Self.noDataText }
        // Every order is drawn, at zero: there is no longest wait to name.
        guard longestWait > 0 else { return Self.noWaitText }
        let longest = orders.filter { $0.waitSeconds == longestWait }
        // On a tie the longest wait belongs to no one order, so only the range is said.
        guard longest.count == 1, let order = longest.first else { return rangeSentence }
        let figure = "The longest wait, \(CafeWording.seconds(longestWait, locale: locale)),"
        return switch (axes, showsEncodings) {
        case (.two, true): "\(figure) was at \(order.store) with \(Self.queueText(order.queueLength, locale: locale))."
        case (.two, false): "\(figure) came with \(Self.queueText(order.queueLength, locale: locale))."
        case (.one, true): "\(figure) was at \(order.store)."
        case (.one, false): rangeSentence
        }
    }

    /// The spread of waits, true of both forms of the chart.
    var rangeSentence: String {
        shortestWait == longestWait
            ? "Every wait was \(CafeWording.seconds(longestWait, locale: locale))."
            : "Waits ran from \(number(shortestWait)) to \(CafeWording.seconds(longestWait, locale: locale))."
    }

    // MARK: Accessibility elements

    /// The bins the orders are grouped into along x: bands of queue on the scatter plot, of wait on the strip.
    private var bins: NumberBins<Int>? {
        let size = axes == .two ? Self.queueBandSize : Self.waitBandSize
        let values = orders.map(axes == .two ? \.queueLength : \.waitSeconds)
        guard let lowest = values.min(), let highest = values.max() else { return nil }
        // The first threshold is at or below the lowest value and the last is above the highest,
        // so every value falls in a bin that excludes its upper bound.
        let first = Int((Double(lowest) / Double(size)).rounded(.down)) * size
        let last = (Int((Double(highest) / Double(size)).rounded(.down)) + 1) * size
        return NumberBins(thresholds: Array(stride(from: first, through: last, by: size)))
    }

    /// Every band along x, in order, whether or not an order falls in it.
    var bands: [PointBand] {
        guard let bins else { return [] }
        return bins.indices.map { PointBand(lower: bins[$0].lowerBound, upper: bins[$0].upperBound - 1) }
    }

    /// The orders of each group, split into the bands along x. One portion is one accessibility element,
    /// in order along x within each café, so the points are heard as the shape they make.
    var portions: [PointPortion] {
        guard let bins else { return [] }
        let bands = bands
        return groups.flatMap { group -> [PointPortion] in
            let byBand = Dictionary(grouping: group.orders) { order in
                bins.index(for: axes == .two ? order.queueLength : order.waitSeconds)
            }
            return bands.indices.compactMap { index in
                guard let members = byBand[index], !members.isEmpty else { return nil }
                return PointPortion(
                    id: "\(group.store ?? "all")-\(index)",
                    label: portionLabel(store: group.store, band: bands[index]),
                    value: portionValue(members),
                    orders: members,
                    band: bands[index]
                )
            }
        }
    }

    /// Context first: the café if the chart shows it, then where along x.
    private func portionLabel(store: String?, band: PointBand) -> String {
        switch (axes, store) {
        case let (.two, store?): "\(store), \(number(band.lower)) to \(Self.queueText(band.upper, locale: locale))"
        case (.two, nil): "\(number(band.lower)) to \(Self.queueText(band.upper, locale: locale))"
        case let (.one, store?): "\(store), waits of \(Self.bandText(band, locale: locale))"
        case (.one, nil): "Waits of \(Self.bandText(band, locale: locale))"
        }
    }

    private func portionValue(_ members: [OrderWait]) -> String {
        let count = CafeWording.orders(members.count, locale: locale)
        guard axes == .two else { return count }
        let waits = members.map(\.waitSeconds)
        guard let shortest = waits.min(), let longest = waits.max() else { return count }
        return shortest == longest
            ? "\(count), wait \(CafeWording.seconds(longest, locale: locale))"
            : "\(count), waits from \(number(shortest)) to \(CafeWording.seconds(longest, locale: locale))"
    }

    // MARK: Audio Graph

    var audioGraphTitle: String {
        switch (axes, showsEncodings) {
        case (.two, true): "Wait against queue length for each order, by café"
        case (.two, false): "Wait against queue length for each order"
        case (.one, true): "How the waits of orders are spread, by café"
        case (.one, false): "How the waits of orders are spread"
        }
    }

    /// Actual values only, and only what the chart draws.
    var audioGraphSummary: String {
        guard hasData else { return Self.noDataText }
        let count = showsEncodings
            ? "\(CafeWording.orders(orders.count, locale: locale)) at \(CafeWording.list(stores))."
            : "\(CafeWording.orders(orders.count, locale: locale))."
        let waits = shortestWait == longestWait
            ? "Every wait \(CafeWording.seconds(longestWait, locale: locale))."
            : "Waits from \(number(shortestWait)) to \(CafeWording.seconds(longestWait, locale: locale))."
        switch axes {
        case .two:
            return "\(count) Queues from \(number(shortestQueue)) to \(Self.queueText(longestQueue, locale: locale)). \(waits)"
        case .one:
            return "\(count) \(waits) Counted in bands of \(CafeWording.seconds(Self.waitBandSize, locale: locale))."
        }
    }

    /// The series the Audio Graph plays: one per café when café is encoded, otherwise one for every order.
    var seriesNames: [String] {
        showsEncodings ? stores : [Self.allOrdersName]
    }

    /// How many of a group's orders fall in each band, for the strip's Audio Graph.
    func counts(in members: [OrderWait]) -> [Int] {
        guard let bins else { return [] }
        let byBand = Dictionary(grouping: members) { bins.index(for: $0.waitSeconds) }
        return bins.indices.map { byBand[$0]?.count ?? 0 }
    }

    // MARK: Announcement

    /// What is said aloud when a control redraws the chart. It follows both controls.
    var announcement: String {
        guard hasData else { return Self.noDataText }
        let form = switch axes {
        case .two: "Chart changed: a point per order, queue on x and wait on y"
        case .one: "Chart changed: a point per order on one axis, the wait"
        }
        let encoding = showsEncodings ? "colour and symbol by café" : "every point alike"
        return "\(form), \(encoding)."
    }

    // MARK: Words

    static let noDataText = "No orders yet."
    static let noWaitText = "No order had to wait."
    static let allOrdersName = "All orders"

    /// A bare number in the view's locale, for the lower end of a range: "50" in "50 to 260 seconds".
    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    // Seconds, orders and people come from `CafeWording`, which makes each agree with its number.

    /// A queue length as a phrase: "0 people queuing", "1 person queuing", "11 people queuing", worded as the other
    /// queue charts word it.
    static func queueText(_ people: Int, locale: Locale) -> String {
        "\(CafeWording.people(people, locale: locale)) queuing"
    }

    /// A band of waits: "60 to 119 seconds".
    static func bandText(_ band: PointBand, locale: Locale) -> String {
        "\(band.lower.formatted(.number.locale(locale))) to \(CafeWording.seconds(band.upper, locale: locale))"
    }
}
