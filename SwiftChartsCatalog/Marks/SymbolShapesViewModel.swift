import Foundation
import Observation

/// A shape a point can be drawn with: the eight built into Swift Charts, and the screen's own.
nonisolated enum SymbolChoice: String, CaseIterable, Identifiable {
    case circle, square, triangle, diamond, pentagon, plus, cross, asterisk, custom

    var id: String {
        rawValue
    }

    /// The name in the picker.
    var title: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        case .triangle: "Triangle"
        case .diamond: "Diamond"
        case .pentagon: "Pentagon"
        case .plus: "Plus"
        case .cross: "Cross"
        case .asterisk: "Asterisk"
        case .custom: "Custom (a cup)"
        }
    }

    /// The shape named in a sentence about many points: "squares", "cups".
    var plural: String {
        switch self {
        case .circle: "circles"
        case .square: "squares"
        case .triangle: "triangles"
        case .diamond: "diamonds"
        case .pentagon: "pentagons"
        case .plus: "plus signs"
        case .cross: "crosses"
        case .asterisk: "asterisks"
        case .custom: "cups"
        }
    }

    var isCustom: Bool {
        self == .custom
    }
}

/// The orders one accessibility element describes: one café's orders within a band of queue lengths.
nonisolated struct OrderPortion: Identifiable, Hashable {
    let cafe: String
    /// The shortest and longest queue the band covers, whether or not an order had exactly that queue.
    let shortestQueue: Int
    let longestQueue: Int
    let orders: [OrderWait]

    var id: String {
        "\(cafe)-\(shortestQueue)"
    }

    /// Context first: whose orders, and which stretch of the queue axis.
    func accessibilityLabel(locale: Locale) -> String {
        "\(cafe), \(shortestQueue.formatted(.number.locale(locale))) to "
            + "\(OrderWaitSummary.queueText(longestQueue, locale: locale))"
    }

    /// Actual values, with their unit.
    func accessibilityValue(locale: Locale) -> String {
        let waits = orders.map(\.waitSeconds)
        guard let shortest = waits.min(), let longest = waits.max() else { return "No orders" }
        let count = CafeWording.orders(orders.count, locale: locale)
        // One order has one wait, not a range of them.
        if orders.count == 1 {
            return "\(count), wait \(CafeWording.seconds(shortest, locale: locale))"
        }
        return "\(count), waits from \(shortest.formatted(.number.locale(locale))) to \(CafeWording.seconds(longest, locale: locale))"
    }
}

/// One café's orders, split into the portions assistive technologies read.
nonisolated struct CafeOrders: Identifiable, Hashable {
    let name: String
    let portions: [OrderPortion]

    var id: String {
        name
    }

    var orders: [OrderWait] {
        portions.flatMap(\.orders)
    }

    /// How many queue lengths one portion covers.
    static let queueBandWidth = 4

    /// The cafés in the order they first appear, each with its orders grouped into bands of queue length.
    static func grouping(_ orders: [OrderWait]) -> [CafeOrders] {
        var names: [String] = []
        for order in orders where !names.contains(order.store) {
            names.append(order.store)
        }
        return names.map { name in
            let bands = Dictionary(grouping: orders.filter { $0.store == name }) { $0.queueLength / queueBandWidth }
            let portions = bands.keys.sorted().map { band in
                OrderPortion(
                    cafe: name,
                    shortestQueue: band * queueBandWidth,
                    longestQueue: band * queueBandWidth + queueBandWidth - 1,
                    orders: bands[band] ?? []
                )
            }
            return CafeOrders(name: name, portions: portions)
        }
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct OrderWaitSummary {
    let orders: [OrderWait]
    /// The locale numbers are written in: the view's.
    let locale: Locale

    /// The wait axis as drawn, from zero to the longest wait rounded up to the axis step (309 → 400): the chart's
    /// y scale and the descriptor's.
    var waitDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.waitSeconds))
    }

    var longestWait: Int? {
        orders.map(\.waitSeconds).max()
    }

    /// The chart's message in a sentence. True with no orders, with waits of zero, and on a tie.
    var headline: String {
        guard let longest = longestWait else { return "No orders yet." }
        guard longest > 0 else { return "No order had to wait." }
        let slowest = orders.filter { $0.waitSeconds == longest }
        if slowest.count == 1, let order = slowest.first {
            return "The longest wait was \(CafeWording.seconds(longest, locale: locale)), at the \(order.store) café with \(Self.queueText(order.queueLength, locale: locale))."
        }
        return "The longest wait was \(CafeWording.seconds(longest, locale: locale)), on \(CafeWording.orders(slowest.count, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        let queues = orders.map(\.queueLength)
        let waits = orders.map(\.waitSeconds)
        guard let shortQueue = queues.min(), let longQueue = queues.max(),
              let shortWait = waits.min(), let longWait = waits.max()
        else { return "No orders yet." }
        let cafes = CafeOrders.grouping(orders)
        let overall = "\(CafeWording.orders(orders.count, locale: locale)) at \(CafeWording.cafes(cafes.count, locale: locale)). "
            + "Queues from \(number(shortQueue)) to \(CafeWording.people(longQueue, locale: locale)). "
            + "Waits from \(number(shortWait)) to \(CafeWording.seconds(longWait, locale: locale))."
        let perCafe = cafes.map { cafe in
            let cafeWaits = cafe.orders.map(\.waitSeconds)
            return " \(cafe.name): \(CafeWording.orders(cafeWaits.count, locale: locale)), waits from \(number(cafeWaits.min() ?? 0)) "
                + "to \(CafeWording.seconds(cafeWaits.max() ?? 0, locale: locale))."
        }
        return overall + perCafe.joined()
    }

    /// A bare number in the view's locale, for the lower end of a range: "60" in "60 to 320 seconds".
    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    // Seconds, people, orders and cafés come from `CafeWording`, which makes each agree with its number.

    /// A queue as the end of a sentence: "nobody queuing", "1 person queuing", "8 people queuing".
    static func queueText(_ people: Int, locale: Locale) -> String {
        people == 0 ? "nobody queuing" : "\(CafeWording.people(people, locale: locale)) queuing"
    }
}

/// The state behind "Symbol shapes": which shape, filled or outlined, and how much of its square
/// the custom shape fills.
@Observable
final class SymbolShapesViewModel {
    /// The value the slider starts at, and the range it covers. Both stay inside the unit square.
    static let startingUnitScale = 0.75
    static let unitScaleRange = 0.5 ... 1.0
    static let unitScaleStep = 0.05

    let orders: [OrderWait]
    let cafes: [CafeOrders]

    /// The shape of the last café's points.
    var shape = SymbolChoice.square
    var isOutlined = false
    /// The side of the custom shape's `perceptualUnitRect`, as a fraction of the unit square.
    var unitScale = SymbolShapesViewModel.startingUnitScale

    init(orders: [OrderWait] = CafeData.orderWaits) {
        self.orders = orders
        cafes = CafeOrders.grouping(orders)
    }

    /// The chart in words, with numbers written for a locale.
    func summary(locale: Locale) -> OrderWaitSummary {
        OrderWaitSummary(orders: orders, locale: locale)
    }

    var hasOrders: Bool {
        !cafes.isEmpty
    }

    /// The café whose symbol the picker sets: the last one. Empty when there are no orders.
    var pickedCafe: String {
        cafes.last?.name ?? ""
    }

    /// The shape every other café keeps: a circle, or a square when the picked café has the circle,
    /// so that two cafés never differ by colour alone.
    var referenceShape: SymbolChoice {
        shape == .circle ? .square : .circle
    }

    func choice(for cafe: String) -> SymbolChoice {
        cafe == pickedCafe ? shape : referenceShape
    }

    /// The slider only does something while the custom shape is drawn, and with no orders nothing is.
    var isUnitScaleEditable: Bool {
        shape.isCustom && hasOrders
    }

    /// "0.75": the slider's value as it is shown and spoken.
    var unitScaleText: String {
        unitScale.formatted(.number.precision(.fractionLength(2)))
    }

    /// The sentence under the slider, true for the chart as it is drawn.
    var unitScaleNote: String {
        guard hasOrders else {
            return "There are no orders to draw."
        }
        guard shape.isCustom else {
            return "No cups are drawn. Pick Custom to use the slider."
        }
        return "Each cup is drawn in the middle \(unitScaleText) of the width and height a symbol is given. "
            + "The circles beside them are the same symbol size."
    }

    /// What the symbols now are, for the announcement made when a control changes them.
    var symbolDescription: String {
        guard hasOrders else { return "No orders to draw." }
        let fill = isOutlined ? "outlined" : "filled"
        return cafes.map { "\($0.name) café: \(fill) \(choice(for: $0.name).plural)." }.joined(separator: " ")
    }

    /// The code behind the chart as it is now drawn.
    var snippets: [SnippetReference] {
        var snippets = [
            SnippetReference(name: "symbol-shapes-chart", title: "A symbol per café"),
            SnippetReference(name: "symbol-shapes-built-in", title: "The eight built-in shapes"),
        ]
        if isOutlined {
            snippets.append(SnippetReference(name: "symbol-shapes-outlined", title: "Outlined: strokeBorder"))
        }
        if shape.isCustom {
            snippets.append(SnippetReference(name: "symbol-shapes-custom", title: "A custom ChartSymbolShape"))
            if isOutlined {
                snippets.append(SnippetReference(name: "symbol-shapes-custom-outlined", title: "The custom shape, outlined"))
            }
        }
        return snippets
    }
}
