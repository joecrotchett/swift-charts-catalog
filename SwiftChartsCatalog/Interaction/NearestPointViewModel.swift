import Foundation
import Observation

/// How far one unit of each axis is on screen, read from the chart's proxy after layout and handed
/// to the view model as plain numbers, so the acceptance radius can be measured in points.
nonisolated struct NearestPointScreenScale: Equatable {
    /// Points on screen between two queue lengths one person apart.
    let pointsPerPerson: Double
    /// Points on screen between two waits one second apart.
    let pointsPerSecond: Double
}

/// The selection on both axes, and which order it accepts.
@Observable
final class NearestPointViewModel {
    // Both domains are fixed rather than left to the scale's default because the view model uses them as
    // plain values: the scale reader measures points per unit between their ends, the finder rejects a
    // selection outside them as outside the plot, and the Audio Graph's axes give the same ranges. The
    // default domain is known only to the chart, through the proxy, which the view model never sees.
    // They hold the sample data with room above it; a change to the data needs a check here
    // (`domainsCoverTheData` in the tests).

    /// The x scale's domain: queues run from 0 to 11 people.
    nonisolated static let queueDomain: ClosedRange<Double> = 0 ... 12
    /// The y scale's domain: waits run from 59 to 309 seconds.
    nonisolated static let waitDomain: ClosedRange<Double> = 0 ... 360
    /// The cafés, in the order the legend and the Audio Graph list them.
    nonisolated static let stores = [CafeWording.harbour, CafeWording.station]
    /// The acceptance radius, in points on screen: about a fingertip by default.
    static let radiusRange: ClosedRange<Double> = 8 ... 60
    static let radiusStep: Double = 2
    static let defaultRadius: Double = 24

    /// Ordered by queue, then wait, then id. VoiceOver does not follow this order: it visits a scatter
    /// plot's points by their place on screen, roughly top to bottom. The order decides only ties in
    /// `NearestPointFinder` and the order the points are drawn in.
    let orders: [OrderWait]
    /// The finger's position on x, in people queuing. `nil` when nothing is touched.
    var selectedQueue: Double?
    /// The finger's position on y, in seconds. `nil` when nothing is touched.
    var selectedWait: Double?
    /// How close, in points, an order must be to the finger to be selected.
    var radius: Double = NearestPointViewModel.defaultRadius
    /// Points per unit on each axis, once the chart has been laid out.
    var screenScale: NearestPointScreenScale?

    init(orders: [OrderWait] = CafeData.orderWaits) {
        self.orders = NearestPointFinder.ordered(orders)
    }

    /// Whether a finger is on the chart: both axes report a position.
    var isSelecting: Bool {
        selectedQueue != nil && selectedWait != nil
    }

    /// The order the selection accepts, or `nil` when none is close enough.
    var accepted: OrderWait? {
        guard let selectedQueue, let selectedWait, let screenScale else { return nil }
        return NearestPointFinder.nearest(
            to: (queue: selectedQueue, wait: selectedWait), in: orders, within: radius, scale: screenScale
        )
    }

    func summary(locale: Locale) -> NearestPointSummary {
        NearestPointSummary(orders: orders, isSelecting: isSelecting, accepted: accepted, radius: radius, locale: locale)
    }

    /// The longest headline the screen can write at the current radius: the one at rest, an accepted
    /// order's for every order, or the one for no order in reach. The headline keeps room for it, so the
    /// chart does not move when a selection appears or clears. Measured in characters, which follows the
    /// width closely enough for the headline to keep its height. `nil` with no orders.
    func reservedHeadline(locale: Locale) -> String? {
        guard !orders.isEmpty else { return nil }
        let atRest = NearestPointSummary(orders: orders, isSelecting: false, accepted: nil, radius: radius, locale: locale)
        let nothingInReach = NearestPointSummary(orders: orders, isSelecting: true, accepted: nil, radius: radius, locale: locale)
        let candidates = [atRest.headline, nothingInReach.headline] + orders.map {
            NearestPointSummary(orders: orders, isSelecting: true, accepted: $0, radius: radius, locale: locale).headline
        }
        return candidates.max { $0.count < $1.count }
    }
}

/// Finds the order nearest a selection, measured in points on screen.
nonisolated enum NearestPointFinder {
    /// Orders by queue, then wait, then id: the order the points are drawn in, and which of two equally
    /// near wins. VoiceOver visits the points by their place on screen, roughly top to bottom, not in this order.
    static func ordered(_ orders: [OrderWait]) -> [OrderWait] {
        orders.sorted { ($0.queueLength, $0.waitSeconds, $0.id) < ($1.queueLength, $1.waitSeconds, $1.id) }
    }

    // snippet:select-the-nearest-point-accept
    /// The order nearest the selection, if it lies within `radius` points of it on screen.
    /// A selection outside the plot accepts nothing. Of two orders equally near, the one listed first wins.
    static func nearest(
        to selection: (queue: Double, wait: Double),
        in orders: [OrderWait],
        within radius: Double,
        scale: NearestPointScreenScale
    ) -> OrderWait? {
        guard NearestPointViewModel.queueDomain.contains(selection.queue),
              NearestPointViewModel.waitDomain.contains(selection.wait) else { return nil }
        /// The axes have different units, so the distance is measured in points, as the finger feels it.
        func distance(_ order: OrderWait) -> Double {
            hypot(
                (Double(order.queueLength) - selection.queue) * scale.pointsPerPerson,
                (Double(order.waitSeconds) - selection.wait) * scale.pointsPerSecond
            )
        }
        return orders
            .filter { distance($0) <= radius }
            .min { distance($0) < distance($1) }
    }
    // end
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct NearestPointSummary {
    let orders: [OrderWait]
    let isSelecting: Bool
    let accepted: OrderWait?
    let radius: Double
    let locale: Locale

    /// Every order with the longest wait, in data order.
    var longest: [OrderWait] {
        guard let most = orders.map(\.waitSeconds).max() else { return [] }
        return orders.filter { $0.waitSeconds == most }
    }

    var shortest: [OrderWait] {
        guard let least = orders.map(\.waitSeconds).min() else { return [] }
        return orders.filter { $0.waitSeconds == least }
    }

    /// "Station, 10 people queuing".
    func context(_ order: OrderWait) -> String {
        "\(order.store), \(CafeWording.people(order.queueLength, locale: locale)) queuing"
    }

    /// The headline: the selected order while one is accepted, else the longest wait.
    var headline: String {
        guard let first = longest.first else { return "No orders to show yet." }
        if let accepted {
            return "Nearest order: \(context(accepted)), \(CafeWording.seconds(accepted.waitSeconds, locale: locale))."
        }
        if isSelecting {
            return "No order within \(CafeWording.points(radius, locale: locale)) of your finger."
        }
        return "The longest wait was \(CafeWording.seconds(first.waitSeconds, locale: locale)): "
            + "\(CafeWording.list(longest.map(context)))."
    }

    /// The text beside the highlighted point.
    var annotation: String? {
        guard let accepted else { return nil }
        return "\(accepted.store): \(CafeWording.seconds(accepted.waitSeconds, locale: locale))"
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = longest.first, let least = shortest.first else { return "No orders to show yet." }
        let stores = Set(orders.map(\.store)).count
        let queues = orders.map(\.queueLength)
        return "\(CafeWording.orders(orders.count, locale: locale)) at \(CafeWording.cafes(stores, locale: locale)). "
            + "Queues from \(CafeWording.people(queues.min() ?? 0, locale: locale)) "
            + "to \(CafeWording.people(queues.max() ?? 0, locale: locale)). "
            + "Shortest wait \(CafeWording.seconds(least.waitSeconds, locale: locale)), \(CafeWording.list(shortest.map(context))). "
            + "Longest wait \(CafeWording.seconds(most.waitSeconds, locale: locale)), \(CafeWording.list(longest.map(context)))."
    }
}
