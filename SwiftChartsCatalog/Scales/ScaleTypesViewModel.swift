import Charts
import Foundation
import Observation

/// The scale type the picker chooses.
nonisolated enum ScaleTypesKind: String, CaseIterable, Identifiable {
    case linear
    case log
    case squareRoot
    case symmetricLog

    var id: String {
        rawValue
    }

    /// The name in the picker.
    var title: String {
        switch self {
        case .linear: "Linear"
        case .log: "Log"
        case .squareRoot: "Square root"
        case .symmetricLog: "Symmetric log"
        }
    }

    /// The name inside a sentence: "a log scale".
    var inSentence: String {
        switch self {
        case .linear: "linear"
        case .log: "log"
        case .squareRoot: "square-root"
        case .symmetricLog: "symmetric log"
        }
    }

    /// What the chart plots on this scale. Yearly cups are all positive, which every type but
    /// symmetric log is shown with; the change on last year crosses zero, which only symmetric log
    /// (and linear) can draw.
    var measure: ScaleTypesMeasure {
        self == .symmetricLog ? .change : .yearlyCups
    }

    /// Whether a change to another type may be animated: only when the points still stand for the same
    /// measure. Moving yearly cups to where a change on last year belongs would show a motion that means nothing.
    func animatesChange(to other: ScaleTypesKind) -> Bool {
        measure == other.measure
    }
}

/// The value each café is placed by.
nonisolated enum ScaleTypesMeasure: Hashable {
    case yearlyCups
    case change

    var axisTitle: String {
        switch self {
        case .yearlyCups: CafeWording.yearlyCupsAxisTitle
        case .change: CafeWording.yearlyChangeAxisTitle
        }
    }

    func value(of cafe: ChainCafe) -> Int {
        switch self {
        case .yearlyCups: cafe.yearlyCups
        case .change: cafe.change
        }
    }
}

/// One café as the chart draws it.
nonisolated struct ScaleTypesPoint: Identifiable, Hashable {
    let name: String
    let value: Int

    var id: String {
        name
    }
}

/// The x scale for one setting: its type, its domain, and the values the axis marks.
nonisolated struct ScaleTypesScale {
    let type: ScaleType
    let domain: ClosedRange<Int>
    /// Values with a grid line, a tick and a label.
    let labelledValues: [Int]
    /// Values with a grid line only, between labels that would otherwise collide.
    let gridOnlyValues: [Int]

    /// The scale for a setting, fitted to the values it draws. The domain is fixed rather than left
    /// automatic so that the chart descriptor's range is the range the axis actually shows.
    static func make(for kind: ScaleTypesKind, values: [Int]) -> ScaleTypesScale {
        let largest = values.max() ?? 0
        switch kind {
        case .linear:
            // snippet:scale-types-linear
            // Linear, the default for numbers: equal differences get equal room, from zero up.
            let upper = roundUp(largest)
            return ScaleTypesScale(
                type: .linear,
                domain: 0 ... upper,
                labelledValues: Array(stride(from: 0, through: upper, by: max(upper / 5, 1))),
                gridOnlyValues: []
            )
        // end
        case .log:
            // snippet:scale-types-log
            // Log: every power of ten gets equal room. It cannot reach zero, so the domain runs
            // between the powers of ten around the data, and only positive values are drawn.
            let positives = values.filter { $0 > 0 }
            let lower = powerOfTen(atOrBelow: positives.min() ?? 1)
            let upper = max(powerOfTen(atOrAbove: positives.max() ?? 1), lower * 10)
            return ScaleTypesScale(
                type: .log,
                domain: lower ... upper,
                labelledValues: Array(sequence(first: lower) { $0 < upper ? $0 * 10 : nil }),
                gridOnlyValues: []
            )
        // end
        case .squareRoot:
            // snippet:scale-types-square-root
            // Square root: compresses large values less than a log does, and can start at zero.
            let upper = roundUp(largest)
            return ScaleTypesScale(
                type: .squareRoot,
                domain: 0 ... upper,
                labelledValues: Array(Set([0, upper / 50, upper / 5, upper / 2, upper])).sorted(),
                gridOnlyValues: []
            )
        // end
        case .symmetricLog:
            // snippet:scale-types-symmetric-log
            // Symmetric log: log-like on both sides of zero and linear near it, so values that
            // cross zero can be drawn. Labels zero and every other power of ten counted down from the
            // largest, never 10, which sits too close to zero; grid lines at the rest.
            let smallest = values.min() ?? 0
            let lower = smallest < 0 ? -roundUp(-smallest) : 0
            let upper = largest > 0 ? roundUp(largest) : 0
            let domain = lower == upper ? -10 ... 10 : lower ... upper
            let powers = Array(sequence(first: 10) { $0 * 10 }.prefix { $0 <= max(-domain.lowerBound, domain.upperBound) })
            let top = powers.count
            var labelled = [0]
            var gridOnly: [Int] = []
            for (index, power) in powers.enumerated() {
                let exponent = index + 1
                let isLabelled = exponent >= 2 && (top - exponent).isMultiple(of: 2)
                for value in [-power, power] where domain.contains(value) {
                    if isLabelled { labelled.append(value) } else { gridOnly.append(value) }
                }
            }
            return ScaleTypesScale(
                type: .symmetricLog,
                domain: domain,
                labelledValues: labelled.sorted(),
                gridOnlyValues: gridOnly.sorted()
            )
            // end
        }
    }

    /// The same scale with fewer labels, for the accessibility text sizes, where all of them collide:
    /// every other label counted from the last, or every third when there are six or more. The
    /// labels taken away keep their grid lines. A domain that runs below zero keeps one label there,
    /// the most negative power of ten in it, so a fall can still be read off the axis.
    func thinned() -> ScaleTypesScale {
        let step = labelledValues.count >= 6 ? 3 : 2
        let fromLast = Array(labelledValues.reversed().enumerated())
        var kept = fromLast.filter { $0.offset.isMultiple(of: step) }.map(\.element)
        var lines = gridOnlyValues + fromLast.filter { !$0.offset.isMultiple(of: step) }.map(\.element)
        if domain.lowerBound <= -10, !kept.contains(where: { $0 < 0 }) {
            let negative = -Self.powerOfTen(atOrBelow: -domain.lowerBound)
            kept.append(negative)
            lines.removeAll { $0 == negative }
        }
        return ScaleTypesScale(
            type: type,
            domain: domain,
            labelledValues: kept.sorted(),
            gridOnlyValues: lines.sorted()
        )
    }

    /// The smallest of 1, 2 or 5 times a power of ten at or above the value, and at least 10.
    static func roundUp(_ value: Int) -> Int {
        guard value > 10 else { return 10 }
        var power = 1
        while power * 10 < value {
            power *= 10
        }
        return [1, 2, 5, 10].map { $0 * power }.first { $0 >= value } ?? power * 10
    }

    static func powerOfTen(atOrBelow value: Int) -> Int {
        var power = 1
        while power * 10 <= value {
            power *= 10
        }
        return power
    }

    static func powerOfTen(atOrAbove value: Int) -> Int {
        var power = 1
        while power < value {
            power *= 10
        }
        return power
    }
}

/// Everything the chart says in words, for one setting. Not tied to the main actor, so the chart
/// descriptor can use it.
nonisolated struct ScaleTypesSummary {
    let cafes: [ChainCafe]
    let kind: ScaleTypesKind
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    var measure: ScaleTypesMeasure {
        kind.measure
    }

    /// The cafés in the order they are drawn, top to bottom: by yearly cups, largest first, the same
    /// on every setting so a café does not move rows when the scale changes.
    var ordered: [ChainCafe] {
        cafes.sorted { $0.yearlyCups > $1.yearlyCups }
    }

    /// What the chart draws. A log scale cannot place zero or a negative value, so those are left out.
    var points: [ScaleTypesPoint] {
        ordered
            .map { ScaleTypesPoint(name: $0.name, value: measure.value(of: $0)) }
            .filter { kind != .log || $0.value > 0 }
    }

    /// Cafés with data that the current scale cannot draw.
    var undrawnCount: Int {
        cafes.count - points.count
    }

    var scale: ScaleTypesScale {
        ScaleTypesScale.make(for: kind, values: points.map(\.value))
    }

    /// A zero line, where the values cross zero.
    var showsZeroLine: Bool {
        measure == .change && !points.isEmpty
    }

    // MARK: Words

    var caption: String {
        switch measure {
        case .yearlyCups: "Cups a year at each café"
        case .change: "Change in cups on last year, at each café"
        }
    }

    /// The chart's message in a sentence, true of what is drawn on every setting.
    var headline: String {
        if cafes.isEmpty { return "No cafés to show." }
        switch kind {
        case .linear: return linearHeadline
        case .log: return logHeadline
        case .squareRoot: return squareRootHeadline
        case .symmetricLog: return changeHeadline
        }
    }

    /// Said when the picker changes the scale: what changed, then the headline.
    var announcement: String {
        let change = kind == .symmetricLog
            ? "Scale changed to symmetric log, showing the change on last year."
            : "Scale changed to \(kind.inSentence), showing cups a year."
        return "\(change) \(headline)"
    }

    /// Actual values only, for the Audio Graph.
    var audioGraphSummary: String {
        guard !points.isEmpty else { return headline }
        var parts = [CafeWording.cafes(points.count, locale: locale) + "."]
        switch measure {
        case .yearlyCups:
            if let most = points.map(\.value).max(), let fewest = points.map(\.value).min() {
                parts.append("Most: \(names(withValue: most)), \(spokenYearly(most)).")
                parts.append("Fewest: \(names(withValue: fewest)), \(spokenYearly(fewest)).")
            }
        case .change:
            parts.append(riseAndFall(prefix: "Largest"))
        }
        if showsZeroLine {
            parts.append("A line marks no change.")
        }
        if undrawnCount > 0 {
            parts.append("Not drawn on a log scale: \(CafeWording.cafes(undrawnCount, locale: locale)) with 0 cups.")
        }
        parts.append("Drawn on a \(kind.inSentence) scale.")
        return parts.joined(separator: " ")
    }

    /// An element's value: "480,000 cups a year", "38,000 cups fewer than last year".
    func spokenValue(_ value: Int) -> String {
        switch measure {
        case .yearlyCups: spokenYearly(value)
        case .change: spokenChange(value)
        }
    }

    func spokenYearly(_ cups: Int) -> String {
        "\(CafeWording.cups(cups, locale: locale)) a year"
    }

    func spokenChange(_ change: Int) -> String {
        if change == 0 { return "the same as last year" }
        let cups = CafeWording.cups(abs(change), locale: locale)
        return change > 0 ? "\(cups) more than last year" : "\(cups) fewer than last year"
    }

    // MARK: Headlines

    private var linearHeadline: String {
        guard let most = points.map(\.value).max(), most > 0 else {
            return "Every café sold 0 cups this year, so every point sits at zero."
        }
        // A fifth of the domain: the first grid line after zero, drawn at every text size.
        let fifth = scale.domain.upperBound / 5
        let below = points.count { $0.value < fifth }
        // The headline is the chart's message; what a linear scale does is the explanation's, below the chart.
        return "\(names(withValue: most)), at \(CafeWording.cups(most, locale: locale)) a year, sets the axis, "
            + "leaving \(CafeWording.cafes(below, locale: locale)) in its first fifth."
    }

    private var logHeadline: String {
        guard let most = points.map(\.value).max(), let fewest = points.map(\.value).min() else {
            return "A log scale cannot draw 0 cups, and no café sold any this year."
        }
        var sentence = most == fewest
            ? "On a log scale every café drawn sits at \(CafeWording.cups(most, locale: locale))."
            : "\(names(withValue: fewest)), at \(CafeWording.cups(fewest, locale: locale)), and "
            + "\(names(withValue: most)), at \(number(most)), can both be read."
        if undrawnCount > 0 {
            sentence += " \(CafeWording.cafes(undrawnCount, locale: locale)) with 0 cups cannot be drawn on it."
        }
        return sentence
    }

    private var squareRootHeadline: String {
        guard let most = points.map(\.value).max(), most > 0 else {
            return "Every café sold 0 cups this year, so every point sits at zero."
        }
        let fifth = scale.domain.upperBound / 5
        let below = points.count { $0.value < fifth }
        return "The \(number(fifth)) grid line sits nearly halfway along the axis, "
            + "giving the \(CafeWording.cafes(below, locale: locale)) below it more room."
    }

    private var changeHeadline: String {
        let values = points.map(\.value)
        guard let lowest = values.min(), let highest = values.max(), lowest < 0 || highest > 0 else {
            return "No café's cups changed on last year, so every point sits at zero."
        }
        if lowest < 0, highest > 0 {
            return "Falls and rises on one axis: "
                + "\(names(withValue: lowest)) fell by \(CafeWording.cups(-lowest, locale: locale)) "
                + "and \(names(withValue: highest)) rose by \(number(highest))."
        }
        return "On a symmetric log scale: " + riseAndFall(prefix: "Largest")
    }

    /// "Largest rise: Central, 120,000 cups. Largest fall: Airport, 38,000 cups."
    private func riseAndFall(prefix: String) -> String {
        let values = points.map(\.value)
        var parts: [String] = []
        if let highest = values.max(), highest > 0 {
            parts.append("\(prefix) rise: \(names(withValue: highest)), \(CafeWording.cups(highest, locale: locale)).")
        } else {
            parts.append("No café rose.")
        }
        if let lowest = values.min(), lowest < 0 {
            parts.append("\(prefix) fall: \(names(withValue: lowest)), \(CafeWording.cups(-lowest, locale: locale)).")
        } else {
            parts.append("No café fell.")
        }
        return parts.joined(separator: " ")
    }

    /// Every drawn café with this value, in drawn order: more than one on a tie.
    private func names(withValue value: Int) -> String {
        CafeWording.list(points.filter { $0.value == value }.map(\.name))
    }

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}

/// The screen's state: which scale type is drawn.
@Observable
final class ScaleTypesViewModel {
    var kind: ScaleTypesKind = .linear
    let cafes: [ChainCafe]

    init(cafes: [ChainCafe] = CafeData.chainCafes) {
        self.cafes = cafes
    }

    func summary(locale: Locale) -> ScaleTypesSummary {
        ScaleTypesSummary(cafes: cafes, kind: kind, locale: locale)
    }

    /// The code for the current setting: the chart, then the scale type it uses.
    var snippets: [SnippetReference] {
        Self.snippets(for: kind)
    }

    static func snippets(for kind: ScaleTypesKind) -> [SnippetReference] {
        let scale = switch kind {
        case .linear: SnippetReference(name: "scale-types-linear", title: "Linear scale")
        case .log: SnippetReference(name: "scale-types-log", title: "Log scale")
        case .squareRoot: SnippetReference(name: "scale-types-square-root", title: "Square-root scale")
        case .symmetricLog: SnippetReference(name: "scale-types-symmetric-log", title: "Symmetric log scale")
        }
        return [SnippetReference(name: "scale-types-chart", title: "The scale on the chart"), scale]
    }
}
