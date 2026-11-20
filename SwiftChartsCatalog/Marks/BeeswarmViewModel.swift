import Foundation
import Observation

/// One order with the row the beeswarm puts it in.
nonisolated struct BeeswarmPlacedOrder: Identifiable, Hashable {
    let order: OrderWait
    /// Counted from zero at the bottom. It keeps points apart and measures nothing.
    let row: Int

    var id: Int {
        order.id
    }
}

/// The dodging itself: Swift Charts does not place points for you, so the rows are worked out in the data.
nonisolated enum BeeswarmLayout {
    // snippet:beeswarm-rows
    /// Each order with the row it lands in: the first free row among the orders already placed
    /// whose waits are closer than `crowding` seconds to its own.
    static func place(_ orders: [OrderWait], crowding: Double) -> [BeeswarmPlacedOrder] {
        var placed: [BeeswarmPlacedOrder] = []
        // Shortest wait first, so the points, and the VoiceOver elements, run along the axis.
        for order in orders.sorted(by: { ($0.waitSeconds, $0.id) < ($1.waitSeconds, $1.id) }) {
            let taken = Set(
                placed
                    .filter { Double(abs($0.order.waitSeconds - order.waitSeconds)) < crowding }
                    .map(\.row)
            )
            let row = (0...).first { !taken.contains($0) } ?? 0
            placed.append(BeeswarmPlacedOrder(order: order, row: row))
        }
        return placed
    }
    // end
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum BeeswarmWording {
    static let order = "Order"
    static let row = "Row"
    static let seriesName = "Orders, shortest wait first"
    /// The visible caption and the Audio Graph title, one string so they cannot drift apart.
    static let chartTitle = "Order waits"

    /// "Order 12, Harbour": which order, then where.
    static func name(of wait: OrderWait, locale: Locale) -> String {
        "\(order) \((wait.id + 1).formatted(.number.locale(locale))), \(wait.store)"
    }
}

/// What the chart says in words, for the swarm as it is currently drawn.
nonisolated struct BeeswarmSummary {
    let placed: [BeeswarmPlacedOrder]
    /// The crowding the rows were worked out with, in seconds.
    let crowding: Double
    let locale: Locale

    /// The wait axis as drawn, from zero to the longest wait rounded up to the axis step (309 → 400): the chart's
    /// x scale and the descriptor's range.
    var waitDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: placed.map(\.order.waitSeconds))
    }

    /// How many rows the swarm uses: the height of its tallest pile. Zero with no orders.
    var depth: Int {
        (placed.map(\.row).max() ?? -1) + 1
    }

    /// The orders in the top row, shortest wait first: the tops of the tallest piles.
    var peaks: [BeeswarmPlacedOrder] {
        guard let top = placed.map(\.row).max() else { return [] }
        return placed.filter { $0.row == top }
    }

    /// The chart's message. Its figures are ones the swarm shows: how high the tallest pile is and where.
    var headline: String {
        guard let first = peaks.first, let last = peaks.last else { return "No orders yet." }
        guard depth > 1 else {
            return "No two waits are closer than \(crowdingText), so nothing is stacked."
        }
        let height = CafeWording.orders(depth, locale: locale)
        guard peaks.count > 1 else {
            return "The tallest pile is \(height) high, at \(CafeWording.seconds(first.order.waitSeconds, locale: locale))."
        }
        let places = peaks.count.formatted(.number.locale(locale))
        let from = first.order.waitSeconds.formatted(.number.locale(locale))
        let to = CafeWording.seconds(last.order.waitSeconds, locale: locale)
        return "The tallest piles are \(height) high, in \(places) places from \(from) to \(to)."
    }

    /// The crowding with its unit: "10 seconds".
    var crowdingText: String {
        CafeWording.seconds(crowding, locale: locale)
    }

    /// What the crowding slider says: its own value, then the headline for the swarm that value drew.
    /// The slider moves points between rows, so it changes what is drawn; the headline says how high
    /// the tallest pile now is and where. Nothing is announced on each step: the spoken value carries it.
    var spokenCrowding: String {
        guard depth > 0 else { return crowdingText }
        return "\(crowdingText). \(headline)"
    }

    /// Actual values only, for the Audio Graph.
    var audioGraphSummary: String {
        guard let shortest = placed.first?.order.waitSeconds, let longest = placed.last?.order.waitSeconds else {
            return headline
        }
        return "\(CafeWording.orders(placed.count, locale: locale)). "
            + "Shortest wait \(CafeWording.seconds(shortest, locale: locale)), "
            + "longest \(CafeWording.seconds(longest, locale: locale)). "
            + "Orders closer than \(crowdingText) are stacked. \(headline)"
    }
}

/// The state behind the Beeswarm screen: the orders and how close two may be before one is moved.
@Observable
final class BeeswarmViewModel {
    /// The crowding slider's range and step, in seconds.
    static let crowdingRange: ClosedRange<Double> = 2 ... 30
    static let crowdingStep: Double = 1
    static let defaultCrowding: Double = 10

    let orders: [OrderWait]
    /// Two waits closer than this many seconds would overlap, so one is moved to another row.
    var crowding = BeeswarmViewModel.defaultCrowding

    init(orders: [OrderWait] = CafeData.orderWaits) {
        self.orders = orders
    }

    /// The orders with their rows, shortest wait first.
    var placed: [BeeswarmPlacedOrder] {
        BeeswarmLayout.place(orders, crowding: crowding)
    }

    func summary(locale: Locale) -> BeeswarmSummary {
        BeeswarmSummary(placed: placed, crowding: crowding, locale: locale)
    }

    /// The snippets do not depend on the slider: crowding is a value passed to the same code.
    static let snippetNames = ["beeswarm-rows", "beeswarm-chart"]
}
