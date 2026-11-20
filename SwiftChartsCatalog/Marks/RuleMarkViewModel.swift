import Foundation
import Observation

/// Which way the rule runs: at a y value across the plot, or at an x value up it.
nonisolated enum RuleDirection: String, CaseIterable, Identifiable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"

    var id: String {
        rawValue
    }
}

/// What the rule stands for.
nonisolated enum RuleUse: String, CaseIterable, Identifiable {
    case threshold = "Threshold"
    case average = "Average"
    case markedOrder = "One order"

    var id: String {
        rawValue
    }
}

/// One order as the chart plots it: its place in the list, the queue it met and the wait that followed.
nonisolated struct RuleMarkOrder: Identifiable, Hashable {
    /// Counted from one, in the order the orders were placed.
    let number: Int
    let queueLength: Int
    let waitSeconds: Int

    var id: Int {
        number
    }

    /// The Harbour café's orders from the sample data, numbered from one.
    static let harbour: [RuleMarkOrder] = CafeData.orderWaits
        .filter { $0.store == "Harbour" }
        .enumerated()
        .map { RuleMarkOrder(number: $0.offset + 1, queueLength: $0.element.queueLength, waitSeconds: $0.element.waitSeconds) }
}

/// The thresholds the screen draws. `CafeData` has none, so they live here.
nonisolated enum RuleMarkThreshold {
    /// The longest an order is meant to take.
    static let targetWaitSeconds = 180
    /// The queue at which the café opens a second till.
    static let queueLimit = 8
}

/// Where the rule's label sits: on which side of the rule, and at which of its ends.
nonisolated struct RuleLabelPlacement: Hashable {
    /// On the side of higher values: above a horizontal rule, after a vertical one. Otherwise below or before it.
    let isOnHigherSide: Bool
    /// At the end where the other axis's values are high: the trailing end of a horizontal rule,
    /// the top of a vertical one. Otherwise at the leading end, or the bottom.
    let isAtHighEnd: Bool

    /// Every placement, the usual one first: above the trailing end of a horizontal rule, beside the top of a
    /// vertical one. The label takes the first of these that no order lies under.
    static let preferred = [
        RuleLabelPlacement(isOnHigherSide: true, isAtHighEnd: true),
        RuleLabelPlacement(isOnHigherSide: true, isAtHighEnd: false),
        RuleLabelPlacement(isOnHigherSide: false, isAtHighEnd: true),
        RuleLabelPlacement(isOnHigherSide: false, isAtHighEnd: false),
    ]
}

/// The room a rule's label is assumed to take, as shares of each axis. The model does not know the chart's
/// size, so these are generous: a placement judged clear here has been clear in every rendering.
nonisolated enum RuleLabelFootprint {
    /// The label's width per character, as a share of the x axis.
    static let widthPerCharacter = 0.028
    /// The label's height, as a share of the y axis.
    static let height = 0.14
    /// Half a point symbol, as a share of either axis: an order this close to the label touches it.
    static let symbolMargin = 0.03
}

/// Everything the chart says in words for one setting of the controls: where the rule is, what it is
/// called, the headline, and what assistive technologies are told.
nonisolated struct RuleMarkSummary: Equatable {
    let orders: [RuleMarkOrder]
    let direction: RuleDirection
    let use: RuleUse
    /// The number of the order the rule marks when `use` is `.markedOrder`.
    let markedNumber: Int
    /// The locale every number and count here is written in. It has no default: the views pass the
    /// environment's, so the headline, the rule's label, the elements and the Audio Graph agree.
    let locale: Locale

    /// No orders, or orders that are all zeros, draw a placeholder and no rule.
    var isEmpty: Bool {
        orders.allSatisfy { $0.queueLength == 0 && $0.waitSeconds == 0 }
    }

    /// The queue axis as drawn: from zero to the longest queue, or a vertical rule beyond it, rounded up to the
    /// axis step (11 → 15). The chart's x scale and the descriptor's.
    var queueDomain: ClosedRange<Double> {
        let rule = direction == .vertical ? ruleValue.map { [$0] } ?? [] : []
        return ChartAxis.valueDomain(for: orders.map { Double($0.queueLength) } + rule)
    }

    /// The wait axis as drawn: from zero to the longest wait, or a horizontal rule beyond it, rounded up (214 →
    /// 300). The chart's y scale and the descriptor's.
    var waitDomain: ClosedRange<Double> {
        let rule = direction == .horizontal ? ruleValue.map { [$0] } ?? [] : []
        return ChartAxis.valueDomain(for: orders.map { Double($0.waitSeconds) } + rule)
    }

    /// The marked order, when the rule marks one and it exists.
    var markedOrder: RuleMarkOrder? {
        guard use == .markedOrder, !isEmpty else { return nil }
        return orders.first { $0.number == markedNumber }
    }

    /// The value the rule is drawn at: seconds for a horizontal rule, people for a vertical one.
    var ruleValue: Double? {
        guard !isEmpty else { return nil }
        switch (use, direction) {
        case (.threshold, .horizontal): return Double(RuleMarkThreshold.targetWaitSeconds)
        case (.threshold, .vertical): return Double(RuleMarkThreshold.queueLimit)
        case (.average, .horizontal): return Self.mean(orders.map(\.waitSeconds))
        case (.average, .vertical): return Self.mean(orders.map(\.queueLength))
        case (.markedOrder, .horizontal): return markedOrder.map { Double($0.waitSeconds) }
        case (.markedOrder, .vertical): return markedOrder.map { Double($0.queueLength) }
        }
    }

    /// What the rule stands for, in a word or two.
    var ruleTitle: String {
        switch (use, direction) {
        case (.threshold, .horizontal): "Target wait"
        case (.threshold, .vertical): "Queue limit"
        case (.average, .horizontal): "Average wait"
        case (.average, .vertical): "Average queue"
        case (.markedOrder, _): markedOrder.map(name) ?? "Order"
        }
    }

    /// The rule's value with its unit: "180 seconds", "5.5 people".
    var ruleValueText: String? {
        ruleValue.map { direction == .horizontal ? Self.secondsText($0, locale: locale) : Self.peopleText($0, locale: locale) }
    }

    /// The label written on the rule: a short name and the bare number, as the axis title gives the unit.
    /// Short, so that some end of the rule has room for it clear of the orders (`labelPlacement`).
    var ruleLabel: String? {
        guard let ruleValue else { return nil }
        let name = switch (use, direction) {
        case (.threshold, .horizontal): "Target"
        case (.threshold, .vertical): "Limit"
        case (.average, _): "Average"
        case (.markedOrder, _): ruleTitle
        }
        return "\(name): \(Self.numberText(ruleValue, locale: locale))"
    }

    /// Where the label goes: the first placement that covers no order and stays inside the plot, or, when
    /// there is none, the one that covers the fewest. `nil` when there is no rule.
    var labelPlacement: RuleLabelPlacement? {
        guard ruleValue != nil else { return nil }
        // `min` keeps the first of equals, so the usual placement wins a tie.
        return RuleLabelPlacement.preferred.min { labelCost($0) < labelCost($1) }
    }

    /// The orders whose points a label placed there would touch.
    func ordersUnderLabel(_ placement: RuleLabelPlacement) -> [RuleMarkOrder] {
        guard let box = labelBox(placement) else { return [] }
        return orders.filter { order in
            let across = Double(direction == .horizontal ? order.waitSeconds : order.queueLength)
            let along = Double(direction == .horizontal ? order.queueLength : order.waitSeconds)
            return box.across.contains(across) && box.along.contains(along)
        }
    }

    /// Whether a label placed there would reach past the end of the rule's own axis, where it is cut off
    /// or stretches the scale to make room.
    func labelLeavesPlot(_ placement: RuleLabelPlacement) -> Bool {
        guard let ruleValue, let extent = labelExtent else { return false }
        return placement.isOnHigherSide
            ? ruleValue + extent.acrossSize > extent.acrossMax
            : ruleValue - extent.acrossSize < 0
    }

    /// Leaving the plot is worse than covering any number of orders.
    private func labelCost(_ placement: RuleLabelPlacement) -> Int {
        ordersUnderLabel(placement).count + (labelLeavesPlot(placement) ? orders.count + 1 : 0)
    }

    /// The label's assumed size in the units of each axis. "Across" is the axis the rule's value is on,
    /// "along" the one the rule runs along. Both scales start at zero and reach the largest value drawn.
    private var labelExtent: (acrossSize: Double, alongSize: Double, acrossMax: Double, alongMax: Double, margin: Double)? {
        guard let ruleValue, let ruleLabel else { return nil }
        let longestQueue = Double(orders.map(\.queueLength).max() ?? 0)
        let longestWait = Double(orders.map(\.waitSeconds).max() ?? 0)
        let width = RuleLabelFootprint.widthPerCharacter * Double(ruleLabel.count)
        switch direction {
        case .horizontal:
            let waitMax = max(longestWait, ruleValue)
            return (
                RuleLabelFootprint.height * waitMax, width * longestQueue, waitMax, longestQueue,
                RuleLabelFootprint.symbolMargin * waitMax
            )
        case .vertical:
            let queueMax = max(longestQueue, ruleValue)
            return (
                width * queueMax, RuleLabelFootprint.height * longestWait, queueMax, longestWait,
                RuleLabelFootprint.symbolMargin * queueMax
            )
        }
    }

    /// The label's assumed rectangle, widened by half a symbol on the rule's side.
    private func labelBox(_ placement: RuleLabelPlacement) -> (across: ClosedRange<Double>, along: ClosedRange<Double>)? {
        guard let ruleValue, let extent = labelExtent else { return nil }
        let across = placement.isOnHigherSide
            ? (ruleValue - extent.margin) ... (ruleValue + extent.acrossSize)
            : (ruleValue - extent.acrossSize) ... (ruleValue + extent.margin)
        let along = placement.isAtHighEnd
            ? (extent.alongMax - extent.alongSize) ... extent.alongMax
            : 0 ... extent.alongSize
        return (across, along)
    }

    /// How many orders lie beyond the rule: waited longer than it, or met a longer queue.
    var ordersBeyondRule: Int {
        guard let ruleValue else { return 0 }
        return orders.count { Double(direction == .horizontal ? $0.waitSeconds : $0.queueLength) > ruleValue }
    }

    /// The chart's message in a sentence. Its figure is the one written on the rule, with the axis's unit.
    var headline: String {
        guard let valueText = ruleValueText else { return "No orders yet." }
        let beyond = "\(ordersBeyondRule.formatted(.number.locale(locale))) of \(Self.ordersText(orders.count, locale: locale))"
        switch (use, direction) {
        case (.threshold, .horizontal):
            return "\(beyond) waited longer than the target of \(valueText)."
        case (.threshold, .vertical):
            return "\(beyond) met a queue longer than the limit of \(valueText)."
        case (.average, .horizontal):
            return "Orders waited \(valueText) on average."
        case (.average, .vertical):
            return "Orders met a queue of \(valueText) on average."
        case (.markedOrder, .horizontal):
            return "\(ruleTitle) waited \(valueText)."
        case (.markedOrder, .vertical):
            return "\(ruleTitle) met a queue of \(valueText)."
        }
    }

    /// What the rule is, for the Audio Graph and for the announcement when a control moves it.
    var ruleDescription: String {
        guard let valueText = ruleValueText else { return "No orders yet." }
        let line = direction == .horizontal ? "A horizontal rule" : "A vertical rule"
        switch use {
        case .threshold, .average:
            return "\(line) marks the \(ruleTitle.lowercased()), \(valueText)."
        case .markedOrder:
            let measure = direction == .horizontal ? "wait" : "queue"
            return "\(line) marks the \(measure) of \(ruleTitle), \(valueText)."
        }
    }

    /// Actual values only: how many orders, the extent of each axis, and the rule.
    var audioGraphSummary: String {
        guard !isEmpty,
              let queues = Self.extent(orders.map(\.queueLength)),
              let waits = Self.extent(orders.map(\.waitSeconds))
        else { return "No orders yet." }
        return "\(Self.ordersText(orders.count, locale: locale)). "
            + "Queues from \(queues.lowerBound.formatted(.number.locale(locale))) to \(CafeWording.people(queues.upperBound, locale: locale)). "
            + "Waits from \(waits.lowerBound.formatted(.number.locale(locale))) to \(CafeWording.seconds(waits.upperBound, locale: locale)). "
            + ruleDescription
    }

    /// What VoiceOver reads for one order's point: where it is on x, then on y.
    func accessibilityValue(for order: RuleMarkOrder) -> String {
        "\(CafeWording.people(order.queueLength, locale: locale)) queuing, waited \(CafeWording.seconds(order.waitSeconds, locale: locale))"
    }

    /// The order's name, saying so when it is the one the rule marks.
    func accessibilityLabel(for order: RuleMarkOrder) -> String {
        order == markedOrder ? "\(name(order)), marked by the rule" : name(order)
    }

    static func mean(_ values: [Int]) -> Double? {
        values.isEmpty ? nil : Double(values.reduce(0, +)) / Double(values.count)
    }

    static func extent(_ values: [Int]) -> ClosedRange<Int>? {
        guard let low = values.min(), let high = values.max() else { return nil }
        return low ... high
    }

    /// The order's name with its number in the summary's locale: "Order 12".
    func name(_ order: RuleMarkOrder) -> String {
        "Order \(order.number.formatted(.number.locale(locale)))"
    }

    /// A number with at most one decimal place: "180", "136.7".
    static func numberText(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
    }

    /// A time with its unit, agreeing in number: "1 second", "136.7 seconds".
    static func secondsText(_ seconds: Double, locale: Locale) -> String {
        CafeWording.seconds(seconds, locale: locale)
    }

    /// A queue with its unit, agreeing in number: "1 person", "5.5 people".
    static func peopleText(_ people: Double, locale: Locale) -> String {
        CafeWording.people(people, locale: locale)
    }

    static func ordersText(_ count: Int, locale: Locale) -> String {
        CafeWording.orders(count, locale: locale)
    }
}

/// The state behind the Rule screen: which way the rule runs, what it stands for, and the order it marks.
@Observable
final class RuleMarkViewModel {
    let orders: [RuleMarkOrder]
    var direction = RuleDirection.horizontal
    var use = RuleUse.threshold
    /// The order the rule marks when it marks one. Set by a control, not by touch.
    var markedNumber: Int

    init(orders: [RuleMarkOrder] = RuleMarkOrder.harbour) {
        self.orders = orders
        markedNumber = orders.first?.number ?? 1
    }

    /// The order numbers the marked-order control can reach.
    var markedNumberRange: ClosedRange<Int> {
        guard let first = orders.first?.number, let last = orders.last?.number, first <= last else { return 1 ... 1 }
        return first ... last
    }

    /// The chart's words in the locale given: the screen passes its environment's.
    func summary(locale: Locale) -> RuleMarkSummary {
        RuleMarkSummary(orders: orders, direction: direction, use: use, markedNumber: markedNumber, locale: locale)
    }

    static let labelPlacementSnippet = SnippetReference(name: "rule-label-placement", title: "Where the label sits")

    /// The code for the rule now drawn, how its label is placed, then the chart it sits in.
    var snippets: [SnippetReference] {
        let initializer = direction == .horizontal ? "RuleMark(y:)" : "RuleMark(x:)"
        let rule = switch (use, direction) {
        case (.threshold, .horizontal):
            SnippetReference(name: "rule-horizontal", title: "A threshold: \(initializer)")
        case (.average, .horizontal):
            SnippetReference(name: "rule-horizontal", title: "An average: \(initializer)")
        case (.threshold, .vertical):
            SnippetReference(name: "rule-vertical", title: "A threshold: \(initializer)")
        case (.average, .vertical):
            SnippetReference(name: "rule-vertical", title: "An average: \(initializer)")
        case (.markedOrder, .horizontal):
            SnippetReference(name: "rule-horizontal-marked", title: "A marked position: \(initializer)")
        case (.markedOrder, .vertical):
            SnippetReference(name: "rule-vertical-marked", title: "A marked position: \(initializer)")
        }
        return [rule, Self.labelPlacementSnippet, SnippetReference(name: "rule-chart", title: "One rule beside the data")]
    }

    /// Said aloud when a control redraws the chart: what the rule now is, then the headline.
    func announcement(locale: Locale) -> String {
        let summary = summary(locale: locale)
        return summary.isEmpty ? summary.headline : "\(summary.ruleDescription) \(summary.headline)"
    }
}
