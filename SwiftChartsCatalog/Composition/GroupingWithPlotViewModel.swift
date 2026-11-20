import Foundation
import Observation

/// The state of "Grouping with Plot": whether each month's marks are grouped in a `Plot`,
/// and every piece of text that follows from that.
@Observable
final class GroupingWithPlotViewModel {
    /// With a `Plot`, the modifiers are applied once to the group. Without, to each mark.
    var usesPlot = true
    let summary: MonthlyRangeSummary

    init(months: [MonthlySummary] = CafeData.monthlySummaries, locale: Locale = .current) {
        summary = MonthlyRangeSummary(months: months, locale: locale)
    }

    /// The chart's message. The same in both settings: the figure is written on the chart in both.
    var headline: String {
        summary.headline
    }

    /// The code the Code view shows for the current setting.
    var snippets: [SnippetReference] {
        [
            Self.marksSnippet,
            usesPlot ? Self.groupSnippet : Self.eachMarkSnippet,
        ]
    }

    /// What the current setting does, on the chart and for VoiceOver, shown under the switch.
    /// The VoiceOver wording was read from the chart's accessibility elements, not assumed.
    var settingNote: String {
        if usesPlot {
            "Each month's bar and tick are one group. It gets one label, above the whole group, and it is one stop "
                + "for VoiceOver, which reads the label and value given to the Plot: the month, then its range and "
                + "average in cups a day."
        } else {
            "The same modifiers are on the bar and on the tick. Each mark gets its own label, so every average is "
                + "written twice. The accessibility label and value on two marks that share a month are not read: "
                + "VoiceOver gives its own summary of the month, a range of dates and the average with no unit."
        }
    }

    /// Said aloud when the switch changes the chart, for people who cannot see it change.
    var announcement: String {
        guard !summary.isEmpty else { return "No sales to show." }
        return usesPlot
            ? "Chart changed. Each month's average is now written once, above its range bar."
            : "Chart changed. Each month's average is now written twice, above its range bar and above its average tick."
    }

    static let marksSnippet = SnippetReference(name: "grouping-with-plot-marks", title: "The two marks")
    static let groupSnippet = SnippetReference(name: "grouping-with-plot-group", title: "Modifiers on the Plot")
    static let eachMarkSnippet = SnippetReference(name: "grouping-with-plot-each-mark", title: "Modifiers on each mark")
}

/// What the chart of monthly ranges says in words: its headline, each month's accessibility label and value,
/// and the summary the Audio Graph speaks.
nonisolated struct MonthlyRangeSummary {
    let months: [MonthlySummary]
    var locale: Locale = .current

    /// No months, or months in which nothing sold: there is nothing to draw.
    var isEmpty: Bool {
        months.allSatisfy { $0.highestDay == 0 }
    }

    /// The cups axis as drawn, from zero to the highest day rounded up to the axis step (347 → 400): the chart's
    /// scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: months.map(\.highestDay))
    }

    /// Every month with the highest average day, in data order. More than one on a tie.
    var busiestMonths: [MonthlySummary] {
        guard !isEmpty, let most = months.map(\.averageDay).max() else { return [] }
        return months.filter { $0.averageDay == most }
    }

    /// The chart's message in a sentence, carrying a figure that is written on the chart.
    var headline: String {
        guard let most = busiestMonths.first?.averageDay else { return "No sales recorded yet." }
        let names = busiestMonths.map { monthName($0) }.formatted(.list(type: .and).locale(locale))
        return "\(names) had the busiest average day: \(Self.cupsText(most, locale: locale))."
    }

    /// A month written out, in the time zone the data was recorded in: "March 2026".
    func monthName(_ month: MonthlySummary) -> String {
        month.month.formatted(
            Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                .month(.wide).year()
        )
    }

    /// The accessibility label for a month's marks: what they belong to.
    func accessibilityLabel(for month: MonthlySummary) -> String {
        monthName(month)
    }

    /// The accessibility value for a month's marks: the range and the average, with the unit.
    func accessibilityValue(for month: MonthlySummary) -> String {
        "\(month.lowestDay.formatted(.number.locale(locale))) to \(Self.cupsText(month.highestDay, locale: locale)) a day, "
            + "average \(Self.cupsText(month.averageDay, locale: locale))"
    }

    /// Actual values only. The last sentence says where the averages are written in the current setting.
    func audioGraphSummary(usesPlot: Bool) -> String {
        guard !isEmpty,
              let first = months.first, let last = months.last,
              let lowest = months.min(by: { $0.lowestDay < $1.lowestDay }),
              let highest = months.max(by: { $0.highestDay < $1.highestDay }),
              let leastAverage = months.map(\.averageDay).min(),
              let mostAverage = months.map(\.averageDay).max()
        else { return "No sales recorded yet." }
        let span = months.count == 1 ? monthName(first) : "\(monthName(first)) to \(monthName(last))"
        let monthCount = months.count == 1 ? "1 month" : "\(months.count.formatted(.number.locale(locale))) months"
        let averages = leastAverage == mostAverage
            ? "Average day \(Self.cupsText(mostAverage, locale: locale))."
            : "Average day from \(leastAverage.formatted(.number.locale(locale))) to \(Self.cupsText(mostAverage, locale: locale))."
        let written = usesPlot
            ? "Each month's average is written once, above its range bar."
            : "Each month's average is written twice, above its range bar and above its average tick."
        return "\(monthCount), \(span). "
            + "Lowest day \(Self.cupsText(lowest.lowestDay, locale: locale)), in \(monthName(lowest)). "
            + "Highest day \(Self.cupsText(highest.highestDay, locale: locale)), in \(monthName(highest)). "
            + "\(averages) \(written)"
    }

    /// A count with its unit, agreeing in number: "1 cup", "219 cups".
    static func cupsText(_ cups: Int, locale: Locale = .current) -> String {
        cups == 1 ? "\(cups.formatted(.number.locale(locale))) cup" : "\(cups.formatted(.number.locale(locale))) cups"
    }
}
