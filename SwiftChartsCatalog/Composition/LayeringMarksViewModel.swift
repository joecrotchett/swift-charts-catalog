import Foundation
import Observation

/// Which of the chart's three layers are drawn.
nonisolated struct LayeringMarksLayers: Equatable {
    /// The faint bar from each month's lowest day to its highest.
    var range = true
    /// The thin tick at each month's average day.
    var tick = true
    /// The rule across the plot at the average of the monthly averages.
    var rule = true

    /// Whether anything is drawn per month, which is what gives the chart its month axis.
    var showsMonthMarks: Bool {
        range || tick
    }

    var isEmpty: Bool {
        !range && !tick && !rule
    }
}

/// The state behind "Layering marks": a switch per layer, and what each setting shows.
@Observable
final class LayeringMarksViewModel {
    static let rangeSnippet = SnippetReference(name: "layering-marks-range", title: "Range: BarMark")
    static let tickSnippet = SnippetReference(name: "layering-marks-tick", title: "Tick: RectangleMark")
    static let ruleSnippet = SnippetReference(name: "layering-marks-rule", title: "Average: RuleMark")
    static let allSnippets = [rangeSnippet, tickSnippet, ruleSnippet]

    let months: [MonthlySummary]
    var layers = LayeringMarksLayers()

    init(months: [MonthlySummary] = CafeData.monthlySummaries) {
        self.months = months
    }

    /// The chart's words for the current setting.
    var summary: LayeringMarksSummary {
        LayeringMarksSummary(months: months, layers: layers)
    }

    /// The code of each layer that is drawn, in drawing order. With every layer off there is no
    /// chart code on screen, so See Code shows the whole composition.
    var snippets: [SnippetReference] {
        guard !layers.isEmpty else { return Self.allSnippets }
        var shown: [SnippetReference] = []
        if layers.range { shown.append(Self.rangeSnippet) }
        if layers.tick { shown.append(Self.tickSnippet) }
        if layers.rule { shown.append(Self.ruleSnippet) }
        return shown
    }
}

/// What the chart says in words for one setting of the layers: the headline, what each
/// accessibility element reads, and the summary the Audio Graph speaks.
nonisolated struct LayeringMarksSummary {
    let months: [MonthlySummary]
    let layers: LayeringMarksLayers

    /// Months with no cups at all are no data: the chart shows a placeholder instead of zeros.
    var hasData: Bool {
        months.contains { $0.highestDay > 0 }
    }

    /// The mean of the monthly average days, rounded to a whole cup. `nil` without data.
    var overallAverage: Int? {
        guard hasData else { return nil }
        let total = months.map(\.averageDay).reduce(0, +)
        return Int((Double(total) / Double(months.count)).rounded())
    }

    /// Where the rule is drawn, when its layer is on.
    var ruleValue: Int? {
        layers.rule ? overallAverage : nil
    }

    /// The highest value any layer can draw, kept on the scale so it does not move as layers go.
    var highestValue: Int {
        months.map(\.highestDay).max() ?? 0
    }

    /// The cups axis as drawn, from zero to the highest day rounded up to the axis step (347 → 400), whichever
    /// layers are on: the chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [highestValue])
    }

    /// What the rule is called: "6-month average".
    var ruleName: String {
        "\(months.count.formatted())-month average"
    }

    /// Every month with the highest average day, in data order. More than one on a tie.
    var monthsWithHighestAverage: [MonthlySummary] {
        guard hasData, let most = months.map(\.averageDay).max() else { return [] }
        return months.filter { $0.averageDay == most }
    }

    /// Every month that had the single busiest day, in data order.
    var monthsWithBusiestDay: [MonthlySummary] {
        guard hasData else { return [] }
        return months.filter { $0.highestDay == highestValue }
    }

    /// The months whose value the headline quotes, so the chart can write that value on them.
    /// Empty while the rule is drawn: the rule carries its own label, and one thing is emphasised at a time.
    var calloutMonths: [MonthlySummary] {
        guard !layers.rule else { return [] }
        if layers.tick { return monthsWithHighestAverage }
        if layers.range { return monthsWithBusiestDay }
        return []
    }

    /// The value written on the callout months: the average day when ticks are drawn, else the highest day.
    func calloutValue(for month: MonthlySummary) -> Int {
        layers.tick ? month.averageDay : month.highestDay
    }

    /// The chart's message in a sentence. Its figure is one the chart is currently drawing and labelling.
    var headline: String {
        guard hasData, let overallAverage else { return "No sales to show yet." }
        if layers.isEmpty { return "Every layer is switched off." }
        if layers.rule {
            return "The \(ruleName) is \(Self.cupsText(overallAverage)) a day."
        }
        if layers.tick, let most = monthsWithHighestAverage.first?.averageDay {
            return "\(Self.names(monthsWithHighestAverage)) had the highest average day: \(Self.cupsText(most))."
        }
        return "\(Self.names(monthsWithBusiestDay)) had the busiest day: \(Self.cupsText(highestValue))."
    }

    /// What one month's accessibility element reads as its value: only the layers that are drawn.
    func accessibilityValue(for month: MonthlySummary) -> String {
        var parts: [String] = []
        if layers.range {
            parts.append("Lowest day: \(Self.cupsText(month.lowestDay))")
            parts.append("Highest day: \(Self.cupsText(month.highestDay))")
        }
        if layers.tick {
            parts.append("Average day: \(Self.cupsText(month.averageDay))")
        }
        return parts.joined(separator: ", ")
    }

    /// The layers on screen, for announcing a change: "Showing the range bars and the average rule."
    var shownLayersText: String {
        var shown: [String] = []
        if layers.range { shown.append("the range bars") }
        if layers.tick { shown.append("the average ticks") }
        if layers.rule { shown.append("the average rule") }
        guard !shown.isEmpty else { return "Showing no layers." }
        return "Showing \(shown.formatted(.list(type: .and)))."
    }

    /// What is said aloud when a layer is switched: what the chart now shows, then its message.
    var changeAnnouncement: String {
        "\(shownLayersText) \(headline)"
    }

    /// Actual values only, for the layers that are drawn.
    var audioGraphSummary: String {
        guard hasData, let overallAverage, let first = months.first, let last = months.last else {
            return "No sales to show yet."
        }
        if layers.isEmpty { return "Every layer is switched off." }
        var sentences: [String] = []
        if layers.showsMonthMarks {
            sentences.append("\(months.count.formatted()) months, \(Self.monthName(first.month)) to \(Self.monthName(last.month)).")
        }
        if layers.range, let lowest = months.map(\.lowestDay).min() {
            let lowestMonths = months.filter { $0.lowestDay == lowest }
            sentences.append(
                "Lowest day: \(Self.cupsText(lowest)), in \(Self.names(lowestMonths)). "
                    + "Highest day: \(Self.cupsText(highestValue)), in \(Self.names(monthsWithBusiestDay))."
            )
        }
        if layers.tick, let most = monthsWithHighestAverage.first?.averageDay {
            sentences.append("Highest average day: \(Self.cupsText(most)), in \(Self.names(monthsWithHighestAverage)).")
        }
        if layers.rule {
            sentences.append("\(ruleName): \(Self.cupsText(overallAverage)) a day.")
        }
        return sentences.joined(separator: " ")
    }

    /// A month written out in the time zone the data was recorded in: "March 2026".
    static func monthName(_ month: Date) -> String {
        month.formatted(Date.FormatStyle(timeZone: CafeData.calendar.timeZone).month(.wide).year())
    }

    static func names(_ months: [MonthlySummary]) -> String {
        months.map { monthName($0.month) }.formatted(.list(type: .and))
    }

    /// A count with its unit, agreeing in number: "1 cup", "197 cups".
    static func cupsText(_ cups: Int) -> String {
        cups == 1 ? "\(cups.formatted()) cup" : "\(cups.formatted()) cups"
    }
}
