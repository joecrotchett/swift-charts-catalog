import Foundation
import Observation

/// Which day the screen highlights, if any.
enum ControlFlowHighlight: String, CaseIterable, Identifiable {
    case none = "None"
    case busiest = "Busiest"
    case quietest = "Quietest"
    case latest = "Latest"

    var id: String {
        rawValue
    }
}

/// The state of "Control flow in a chart": whether the average is shown, and which day is highlighted.
@Observable
final class ControlFlowInAChartViewModel {
    static let forEachSnippet = SnippetReference(
        name: "control-flow-in-a-chart-for-each", title: "ForEach: a mark per day"
    )
    static let ifSnippet = SnippetReference(
        name: "control-flow-in-a-chart-if", title: "if: a rule only while the switch is on"
    )
    static let ifLetSnippet = SnippetReference(
        name: "control-flow-in-a-chart-if-let", title: "if let: a point only while a day is highlighted"
    )

    let days: [DailySales]
    let locale: Locale
    /// The optional overlay: an average line that exists only while this is on.
    var showsAverage = false
    /// What the optional value is made from.
    var highlight = ControlFlowHighlight.none

    init(days: [DailySales] = CafeData.harbourSales, locale: Locale = .autoupdatingCurrent) {
        self.days = days
        self.locale = locale
    }

    /// The optional value a mark depends on: the day to highlight, or `nil` when there is none.
    /// On a tie the earliest such day.
    var highlightedDay: DailySales? {
        guard days.contains(where: { $0.cups > 0 }) else { return nil }
        switch highlight {
        case .none:
            return nil
        case .busiest:
            guard let most = days.map(\.cups).max() else { return nil }
            return days.first { $0.cups == most }
        case .quietest:
            guard let fewest = days.map(\.cups).min() else { return nil }
            return days.first { $0.cups == fewest }
        case .latest:
            return days.last
        }
    }

    /// The chart's words for the current setting of the controls.
    var summary: ControlFlowSummary {
        ControlFlowSummary(
            days: days, showsAverage: showsAverage, highlight: highlight, highlighted: highlightedDay, locale: locale
        )
    }

    var headline: String {
        summary.headline
    }

    /// The code behind the chart. The controls choose which branches run, not which code exists,
    /// so every setting shows the same three regions.
    var snippets: [SnippetReference] {
        [Self.forEachSnippet, Self.ifSnippet, Self.ifLetSnippet]
    }
}

/// What the chart says in words, for the chart as it is currently drawn.
nonisolated struct ControlFlowSummary {
    let days: [DailySales]
    var showsAverage = false
    var highlight = ControlFlowHighlight.none
    var highlighted: DailySales?
    var locale = Locale.autoupdatingCurrent

    /// Nothing sold is no data: the chart shows a placeholder in place of an empty plot.
    var hasData: Bool {
        days.contains { $0.cups > 0 }
    }

    var lowest: Int? {
        hasData ? days.map(\.cups).min() : nil
    }

    var highest: Int? {
        hasData ? days.map(\.cups).max() : nil
    }

    /// The cups axis as drawn, off zero: the lowest and highest day rounded out to the axis step (152 to 282 →
    /// 150 to 300). The chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups), includesZero: false)
    }

    /// The mean cups a day, unrounded. `nil` with no data.
    var average: Double? {
        guard hasData else { return nil }
        return Double(days.map(\.cups).reduce(0, +)) / Double(days.count)
    }

    /// The average to the nearest cup: where its rule is drawn, and the figure written on it and spoken.
    var roundedAverage: Int? {
        average.map { Int($0.rounded()) }
    }

    /// The average rule exists only while the switch is on and there is something to average.
    /// Its value is the rounded one, so the rule sits exactly where its label says.
    var drawnAverage: Int? {
        showsAverage ? roundedAverage : nil
    }

    /// The chart's message in a sentence. Its figures are ones the chart is showing in this state.
    var headline: String {
        guard let lowest, let highest else { return "No cups sold in this period." }
        let averageText = showsAverage ? roundedAverage.map(Self.cupsText) : nil
        if let highlighted {
            let day = dayText(highlighted.day)
            let cups = Self.cupsText(highlighted.cups)
            let lead = switch highlight {
            case .busiest: "The busiest day was \(day): \(cups)"
            case .quietest: "The quietest day was \(day): \(cups)"
            case .latest, .none: "The latest day was \(day): \(cups)"
            }
            return averageText.map { "\(lead), against a daily average of \($0)." } ?? "\(lead)."
        }
        if let averageText {
            return "The Harbour café averaged \(averageText) a day."
        }
        if lowest == highest {
            return "Every day sold \(Self.cupsText(lowest))."
        }
        return "Daily sales ranged from \(lowest.formatted(.number.locale(locale))) to \(Self.cupsText(highest))."
    }

    /// Actual values only, and only what is drawn: the average and the highlight are said while they exist.
    var audioGraphSummary: String {
        guard let lowest, let highest, let first = days.first, let last = days.last else {
            return "No cups sold in this period."
        }
        var sentences = [
            "\(days.count.formatted(.number.locale(locale))) days, \(dayText(first.day)) to \(dayText(last.day)).",
            "Lowest \(Self.cupsText(lowest)), highest \(Self.cupsText(highest)).",
        ]
        if showsAverage, let roundedAverage {
            sentences.append("An average line is drawn at \(Self.cupsText(roundedAverage)).")
        }
        if let highlighted {
            sentences.append("Highlighted: \(dayText(highlighted.day)), \(Self.cupsText(highlighted.cups)).")
        }
        return sentences.joined(separator: " ")
    }

    /// What VoiceOver says for one day's value: the cups, and that it is the highlighted day when it is.
    func accessibilityValue(for day: DailySales) -> String {
        day == highlighted ? "\(Self.cupsText(day.cups)), highlighted" : Self.cupsText(day.cups)
    }

    /// A day written out in the data's time zone: "Saturday, March 28".
    func dayText(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// A day for the label on the highlighted point: "Mar 28".
    func shortDayText(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month().day())
    }

    /// A count with its unit, agreeing in number: "1 cup", "164 cups".
    static func cupsText(_ cups: Int) -> String {
        cups == 1 ? "\(cups.formatted()) cup" : "\(cups.formatted()) cups"
    }
}
