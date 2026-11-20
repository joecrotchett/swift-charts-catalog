import Foundation
import Observation

/// The four marks whose initializers follow the value, interval or nothing pattern.
nonisolated enum PositionedMark: String, CaseIterable, Identifiable {
    case bar, rectangle, rule, point

    var id: String {
        rawValue
    }

    /// The picker's title, and the word the headline uses: "The bar shows ...".
    var title: String {
        rawValue.capitalized
    }

    var typeName: String {
        "\(title)Mark"
    }
}

/// What a mark is given on one axis.
nonisolated enum AxisInput: String, CaseIterable, Identifiable {
    case value, interval, nothing

    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    /// The choice inside a sentence: "a value on x".
    var phrase: String {
        switch self {
        case .value: "a value"
        case .interval: "an interval"
        case .nothing: "nothing"
        }
    }
}

/// The seven forms of `BarMark`, named by what x is given, then what y is given.
nonisolated enum BarForm: Equatable {
    case valueValue, valueInterval, valueNothing, intervalValue, intervalNothing, nothingValue, nothingInterval
}

/// The nine forms of `RectangleMark`: every combination.
nonisolated enum RectangleForm: Equatable {
    case valueValue, valueInterval, valueNothing
    case intervalValue, intervalInterval, intervalNothing
    case nothingValue, nothingInterval, nothingNothing
}

/// The six forms of `RuleMark`: a rule always has a value or nothing across its own direction.
nonisolated enum RuleForm: Equatable {
    case valueInterval, valueNothing, intervalValue, intervalNothing, nothingValue, nothingInterval
}

/// The three forms of `PointMark`: a point takes no interval.
nonisolated enum PointForm: Equatable {
    case valueValue, valueNothing, nothingValue
}

/// One initializer that exists: a mark and what it is given on each axis.
nonisolated enum PositionForm: Equatable {
    case bar(BarForm), rectangle(RectangleForm), rule(RuleForm), point(PointForm)

    // snippet:how-positions-are-given-combinations
    /// The initializer for a mark given these two things, or `nil` where the mark has none.
    /// A rectangle takes all nine combinations; the other marks take fewer.
    static func form(mark: PositionedMark, x: AxisInput, y: AxisInput) -> PositionForm? {
        switch (mark, x, y) {
        case (.bar, .value, .value): .bar(.valueValue)
        case (.bar, .value, .interval): .bar(.valueInterval)
        case (.bar, .value, .nothing): .bar(.valueNothing)
        case (.bar, .interval, .value): .bar(.intervalValue)
        case (.bar, .interval, .nothing): .bar(.intervalNothing)
        case (.bar, .nothing, .value): .bar(.nothingValue)
        case (.bar, .nothing, .interval): .bar(.nothingInterval)
        // No BarMark takes an interval on both axes, or nothing on both.
        case (.bar, .interval, .interval), (.bar, .nothing, .nothing): nil
        case (.rectangle, .value, .value): .rectangle(.valueValue)
        case (.rectangle, .value, .interval): .rectangle(.valueInterval)
        case (.rectangle, .value, .nothing): .rectangle(.valueNothing)
        case (.rectangle, .interval, .value): .rectangle(.intervalValue)
        case (.rectangle, .interval, .interval): .rectangle(.intervalInterval)
        case (.rectangle, .interval, .nothing): .rectangle(.intervalNothing)
        case (.rectangle, .nothing, .value): .rectangle(.nothingValue)
        case (.rectangle, .nothing, .interval): .rectangle(.nothingInterval)
        case (.rectangle, .nothing, .nothing): .rectangle(.nothingNothing)
        case (.rule, .value, .interval): .rule(.valueInterval)
        case (.rule, .value, .nothing): .rule(.valueNothing)
        case (.rule, .interval, .value): .rule(.intervalValue)
        case (.rule, .interval, .nothing): .rule(.intervalNothing)
        case (.rule, .nothing, .value): .rule(.nothingValue)
        case (.rule, .nothing, .interval): .rule(.nothingInterval)
        // No RuleMark takes the same thing on both axes: two values, two intervals, or nothing at all.
        case (.rule, .value, .value), (.rule, .interval, .interval), (.rule, .nothing, .nothing): nil
        case (.point, .value, .value): .point(.valueValue)
        case (.point, .value, .nothing): .point(.valueNothing)
        case (.point, .nothing, .value): .point(.nothingValue)
        // No PointMark takes an interval, or nothing on both axes.
        case (.point, .interval, _), (.point, _, .interval), (.point, .nothing, .nothing): nil
        }
    }
    // end
}

/// The figures the mark is positioned with: the average and the extremes of the orders' queues and waits.
nonisolated struct OrderSummary: Equatable {
    let count: Int
    /// Rounded to one decimal place, so the figure in the headline is the position the mark is drawn at.
    let averageQueue: Double
    let shortestQueue: Int
    let longestQueue: Int
    /// Rounded to one decimal place, for the same reason.
    let averageWait: Double
    let shortestWait: Int
    let longestWait: Int

    /// `nil` when there are no orders: there is nothing to average.
    init?(orders: [OrderWait]) {
        let queues = orders.map(\.queueLength)
        let waits = orders.map(\.waitSeconds)
        guard let shortestQueue = queues.min(), let longestQueue = queues.max(),
              let shortestWait = waits.min(), let longestWait = waits.max()
        else { return nil }
        count = orders.count
        averageQueue = Self.roundedAverage(queues)
        self.shortestQueue = shortestQueue
        self.longestQueue = longestQueue
        averageWait = Self.roundedAverage(waits)
        self.shortestWait = shortestWait
        self.longestWait = longestWait
    }

    /// The mean to one decimal place: the precision the words give it in.
    private static func roundedAverage(_ values: [Int]) -> Double {
        (Double(values.reduce(0, +)) / Double(values.count) * 10).rounded() / 10
    }
}

/// Everything the screen says in words about one setting of its controls. Plain values, so the chart
/// descriptor can use it from wherever the accessibility system calls.
nonisolated struct PositionsDescription: Equatable {
    static let store = "Harbour"

    let mark: PositionedMark
    let x: AxisInput
    let y: AxisInput
    /// The orders the mark summarises, drawn as points behind it.
    let orders: [OrderWait]
    /// The locale numbers are written in: the view's.
    let locale: Locale

    var summary: OrderSummary? {
        OrderSummary(orders: orders)
    }

    /// The queue axis as drawn, from zero to the longest queue rounded up to the axis step (11 → 15): the chart's
    /// x scale and the descriptor's.
    var queueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.queueLength))
    }

    /// The wait axis as drawn, from zero to the longest wait rounded up (214 → 300): the chart's y scale and the
    /// descriptor's.
    var waitDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.waitSeconds))
    }

    /// The initializer for the current setting, or `nil` when the mark has none.
    var form: PositionForm? {
        PositionForm.form(mark: mark, x: x, y: y)
    }

    /// The setting in words: "a value on x and an interval on y".
    var combination: String {
        switch (x, y) {
        case (.value, .value): "a value on both axes"
        case (.interval, .interval): "an interval on both axes"
        case (.nothing, .nothing): "nothing on either axis"
        default: "\(x.phrase) on x and \(y.phrase) on y"
        }
    }

    /// What the mark says about the queues, or `nil` when it is given nothing on x.
    func queuePhrase(_ summary: OrderSummary) -> String? {
        switch x {
        case .value: "an average queue of \(CafeWording.people(summary.averageQueue, locale: locale))"
        case .interval: "queues from \(number(summary.shortestQueue)) to \(CafeWording.people(summary.longestQueue, locale: locale))"
        case .nothing: nil
        }
    }

    /// What the mark says about the waits, or `nil` when it is given nothing on y.
    func waitPhrase(_ summary: OrderSummary) -> String? {
        switch y {
        case .value: "an average wait of \(CafeWording.seconds(summary.averageWait, locale: locale))"
        case .interval: "waits from \(number(summary.shortestWait)) to \(CafeWording.seconds(summary.longestWait, locale: locale))"
        case .nothing: nil
        }
    }

    /// What the mark shows, as the value VoiceOver reads for it. `nil` when no mark is drawn.
    var markValue: String? {
        guard let summary, form != nil else { return nil }
        let phrases = [queuePhrase(summary), waitPhrase(summary)].compactMap(\.self)
        guard !phrases.isEmpty else { return "all \(CafeWording.orders(summary.count, locale: locale)), with no position given" }
        return phrases.joined(separator: " and ")
    }

    /// The message of what is on screen: the chart, or the sentence that stands in for it.
    var headline: String {
        guard let summary else { return "No \(Self.store) orders to show." }
        guard form != nil else { return "\(mark.typeName) has no initializer with \(combination)." }
        let phrases = [queuePhrase(summary), waitPhrase(summary)].compactMap(\.self)
        guard !phrases.isEmpty else {
            return "Given no position, the \(mark.rawValue) covers the whole plot and all \(CafeWording.orders(summary.count, locale: locale))."
        }
        return "The \(mark.rawValue) shows \(phrases.joined(separator: " and ")) at the \(Self.store) café."
    }

    /// What VoiceOver is told when a control changes the chart: the setting, then what is now shown.
    var announcement: String {
        "\(mark.typeName), \(x.phrase) on x, \(y.phrase) on y. \(headline)"
    }

    /// The Audio Graph's summary: the orders in actual values, then what the mark shows.
    var audioGraphSummary: String {
        guard let summary else { return headline }
        return "\(CafeWording.orders(summary.count, locale: locale)). Queues from \(number(summary.shortestQueue)) to "
            + "\(CafeWording.people(summary.longestQueue, locale: locale)), waits from \(number(summary.shortestWait)) to "
            + "\(CafeWording.seconds(summary.longestWait, locale: locale)). \(headline)"
    }

    /// The snippet for the current setting: its initializer, or the table of combinations when there is none.
    var snippets: [SnippetReference] {
        guard form != nil else {
            return [SnippetReference(name: Self.combinationsSnippetName, title: "Which combinations exist")]
        }
        return [SnippetReference(
            name: "how-positions-are-given-\(mark.rawValue)-\(x.rawValue)-\(y.rawValue)",
            title: "\(mark.typeName): \(x.rawValue) on x, \(y.rawValue) on y"
        )]
    }

    static let combinationsSnippetName = "how-positions-are-given-combinations"

    /// The axis titles, worded as the Rule screen words them for the same orders.
    static let queueAxisTitle = CafeWording.queueAxisTitle
    static let waitAxisTitle = CafeWording.waitAxisTitle
    /// The Audio Graph's axis titles: the drawn titles, as every chart of these orders words them.
    static let queueDescriptorTitle = CafeWording.queueAxisTitle
    static let waitDescriptorTitle = CafeWording.waitAxisTitle

    // People, seconds and orders come from `CafeWording`, which makes each agree with its number and
    // writes an average with at most one decimal place.

    /// A bare number in the view's locale, for the lower end of a range: "1" in "1 to 11 people".
    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}

/// The state of "How positions are given": the mark, and what it is given on each axis.
@Observable
final class HowPositionsAreGivenViewModel {
    var mark = PositionedMark.bar
    var x = AxisInput.value
    var y = AxisInput.interval
    let orders: [OrderWait]

    init(orders: [OrderWait] = CafeData.orderWaits.filter { $0.store == PositionsDescription.store }) {
        self.orders = orders
    }

    /// The current setting in words, with numbers written for a locale.
    func description(locale: Locale) -> PositionsDescription {
        PositionsDescription(mark: mark, x: x, y: y, orders: orders, locale: locale)
    }
}
