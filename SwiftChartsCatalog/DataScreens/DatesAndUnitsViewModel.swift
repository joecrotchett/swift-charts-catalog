import Accessibility
import Foundation
import Observation
import SwiftUI

/// The period each bar stands for.
nonisolated enum DatesAndUnitsPeriod: String, CaseIterable, Identifiable {
    case days = "Days"
    case months = "Months"

    var id: String {
        rawValue
    }

    /// The picker's word, read after its title: "Each bar is one Day".
    var title: String {
        switch self {
        case .days: "Day"
        case .months: "Month"
        }
    }

    /// The calendar unit a bar of this period fills.
    var unit: Calendar.Component {
        switch self {
        case .days: .day
        case .months: .month
        }
    }
}

/// One bar: the date that stands for its period and the cups it shows.
nonisolated struct DatesAndUnitsBar: Identifiable, Hashable {
    let date: Date
    let cups: Int

    var id: Date {
        date
    }
}

/// State and words for "Dates and units": which period the bars stand for, and whether the
/// deliberate mistake (the date plotted with no unit) is showing.
@Observable
final class DatesAndUnitsViewModel {
    var period: DatesAndUnitsPeriod = .days
    /// The mistake: the date is plotted as an instant, with no `unit:`.
    var isLeavingOutUnit = false

    let days: [DailySales]
    let months: [MonthlySummary]

    /// Not in `CafeWording`: the monthly bars show a month's average day, not a total.
    static let averageDayTitle = "Average day"
    static let averageDayAxisTitle = "Average cups a day"

    init(days: [DailySales] = CafeData.harbourSales, months: [MonthlySummary] = CafeData.monthlySummaries) {
        self.days = days
        self.months = months
    }

    // MARK: Data

    /// The bars for the current period, in date order.
    var bars: [DatesAndUnitsBar] {
        switch period {
        case .days: days.map { DatesAndUnitsBar(date: $0.day, cups: $0.cups) }
        case .months: months.map { DatesAndUnitsBar(date: $0.month, cups: $0.averageDay) }
        }
    }

    /// False when there are no bars or every bar is zero: bars from zero would draw nothing.
    var hasData: Bool {
        bars.contains { $0.cups > 0 }
    }

    /// Every bar with the most cups, in date order. More than one on a tie; none without data.
    /// The cups axis as drawn, from zero to the tallest bar rounded up to the axis step (282 → 300): the chart's
    /// scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: bars.map(\.cups))
    }

    /// The label written over a bar the headline names: the axis labels a day a week, or every other month at
    /// the largest text sizes, and may not label it. "Mar 28: 282", "Jul: 253".
    func calloutText(for bar: DatesAndUnitsBar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
        let date = switch period {
        case .days: bar.date.formatted(style.month(.abbreviated).day())
        case .months: bar.date.formatted(style.month(.abbreviated))
        }
        return "\(date): \(bar.cups.formatted(.number.locale(locale)))"
    }

    var highestBars: [DatesAndUnitsBar] {
        guard hasData, let most = bars.map(\.cups).max() else { return [] }
        return bars.filter { $0.cups == most }
    }

    /// Every bar with the fewest cups, in date order.
    var lowestBars: [DatesAndUnitsBar] {
        guard hasData, let fewest = bars.map(\.cups).min() else { return [] }
        return bars.filter { $0.cups == fewest }
    }

    // MARK: Labels for the chart

    /// The x value's label: what one bar stands for.
    var xTitle: String {
        switch period {
        case .days: CafeWording.day
        case .months: CafeWording.month
        }
    }

    /// The y value's label.
    var yTitle: String {
        switch period {
        case .days: CafeWording.cups
        case .months: Self.averageDayTitle
        }
    }

    /// Whether each axis label sits under the middle of its bar: only when the bars fill their
    /// period and every period is labelled.
    func axisLabelsCentered(stride: Int) -> Bool {
        !isLeavingOutUnit && stride == 1
    }

    // MARK: Words

    /// What a bar with no unit looks like, true of each period: with 28 days a bar keeps about a day's
    /// width but is shifted half a day; with six months it is a sliver.
    var noUnitShape: String {
        switch period {
        case .days: "each bar is about as wide as a day but centred on midnight, so it is shifted half a day"
        case .months: "each bar is narrow and centred on midnight on the first of its month"
        }
    }

    /// The concept in a few sentences, true of the period showing.
    var explanation: String {
        "A date on its own is an instant. Passing unit: .day or unit: .month plots it as the whole "
            + "calendar period that contains it, so each bar is as wide as its day or month. Without a unit "
            + "\(noUnitShape), and the first and last hang half outside the plot. "
            + "These dates were made in UTC, so the data's calendar goes to the value and to the axis."
    }

    var caption: String {
        switch period {
        case .days: "Cups sold each day at the \(CafeWording.harbour) café"
        case .months: "\(Self.averageDayAxisTitle) at the \(CafeWording.harbour) café, by month"
        }
    }

    /// The date of a bar as written in a sentence, in the data's time zone: "Saturday, March 28", "July 2026".
    func periodName(_ date: Date, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
        switch period {
        case .days: return date.formatted(style.weekday(.wide).month(.wide).day())
        case .months: return date.formatted(style.month(.wide).year())
        }
    }

    /// The instant a bar is drawn at when the unit is left off: "Saturday, March 28 at 12:00 AM".
    func instantName(_ date: Date, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
        switch period {
        case .days: return date.formatted(style.weekday(.wide).month(.wide).day().hour().minute())
        case .months: return date.formatted(style.month(.wide).day().year().hour().minute())
        }
    }

    /// A bar's value with its unit: "274 cups", or "253 cups a day" for a month's average.
    func valueText(_ cups: Int, locale: Locale) -> String {
        switch period {
        case .days: CafeWording.cups(cups, locale: locale)
        case .months: "\(CafeWording.cups(cups, locale: locale)) a day"
        }
    }

    /// What VoiceOver reads for a bar: the period it fills, or the instant it is drawn at.
    func barLabel(_ bar: DatesAndUnitsBar, locale: Locale) -> String {
        isLeavingOutUnit ? instantName(bar.date, locale: locale) : periodName(bar.date, locale: locale)
    }

    func barValue(_ bar: DatesAndUnitsBar, locale: Locale) -> String {
        valueText(bar.cups, locale: locale)
    }

    /// The chart's message, with a figure that is the height of a drawn bar. True on a tie and with no data.
    func headline(locale: Locale) -> String {
        guard let most = highestBars.first?.cups else {
            return "No cups sold in this period."
        }
        let names = CafeWording.list(highestBars.map { periodName($0.date, locale: locale) })
        let each = highestBars.count > 1 ? " each" : ""
        switch period {
        case .days:
            let lead = highestBars.count > 1 ? "Busiest days" : "Busiest day"
            return "\(lead): \(names), \(CafeWording.cups(most, locale: locale))\(each)."
        case .months:
            let lead = highestBars.count > 1 ? "Busiest months" : "Busiest month"
            return "\(lead): \(names), \(valueText(most, locale: locale)) on average\(each)."
        }
    }

    /// What is said when the period changes: what changed, then the headline.
    func periodChangeAnnouncement(locale: Locale) -> String {
        let change = switch period {
        case .days: "Showing one bar per day."
        case .months: "Showing one bar per month."
        }
        return "\(change) \(headline(locale: locale))"
    }

    /// What is said when the mistake is switched on or off: what changed, then the headline.
    func unitChangeAnnouncement(locale: Locale) -> String {
        let period = period == .days ? "day" : "month"
        let change = isLeavingOutUnit
            ? "Unit left off: \(noUnitShape)."
            : "Unit on: each bar fills its \(period)."
        return "\(change) \(headline(locale: locale))"
    }

    // MARK: Snippets

    static let daysSnippet = SnippetReference(name: "dates-and-units-days", title: "A bar per day")
    static let monthsSnippet = SnippetReference(name: "dates-and-units-months", title: "A bar per month")
    static let noUnitSnippet = SnippetReference(name: "dates-and-units-no-unit", title: "The mistake: no unit")
    static let axisSnippet = SnippetReference(name: "dates-and-units-axis", title: "The axis in the data's calendar")

    /// The snippets for the current setting: the mark as it is written now, then the axis.
    var snippets: [SnippetReference] {
        let mark = if isLeavingOutUnit {
            Self.noUnitSnippet
        } else {
            period == .days ? Self.daysSnippet : Self.monthsSnippet
        }
        return [mark, Self.axisSnippet]
    }

    // MARK: Audio Graph

    func chartDescriptor(locale: Locale) -> DatesAndUnitsChartDescriptor {
        let drawn = bars
        let categories = drawn.map { barLabel($0, locale: locale) }
        let title = switch period {
        case .days: "Cups sold each day at the \(CafeWording.harbour) café"
        case .months: "Average cups a day at the \(CafeWording.harbour) café, by month"
        }
        return DatesAndUnitsChartDescriptor(
            title: isLeavingOutUnit ? "\(title), each bar drawn at an instant" : title,
            summary: audioGraphSummary(locale: locale),
            xTitle: xTitle,
            yTitle: period == .days ? CafeWording.cupsAxisTitle : Self.averageDayAxisTitle,
            seriesName: CafeWording.harbour,
            categories: categories,
            values: drawn.map { Double($0.cups) },
            valueRange: valueDomain,
            isMonthlyAverage: period == .months,
            locale: locale
        )
    }

    /// Actual values only. In the mistake it says first that each bar is drawn at an instant.
    func audioGraphSummary(locale: Locale) -> String {
        guard let most = highestBars.first?.cups, let fewest = lowestBars.first?.cups else {
            return "No cups sold in this period."
        }
        let count = period == .days
            ? CafeWording.days(bars.count, locale: locale)
            : CafeWording.months(bars.count, locale: locale)
        let highest = CafeWording.list(highestBars.map { periodName($0.date, locale: locale) })
        let lowest = CafeWording.list(lowestBars.map { periodName($0.date, locale: locale) })
        let values = "\(count). Highest \(highest), \(valueText(most, locale: locale)). "
            + "Lowest \(lowest), \(valueText(fewest, locale: locale))."
        guard isLeavingOutUnit else { return values }
        return "Drawn without a unit: \(noUnitShape), "
            + "and the first and last hang half outside the plot. \(values)"
    }
}

/// The chart for the Audio Graph, built from finished strings and numbers.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct DatesAndUnitsChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let xTitle: String
    let yTitle: String
    let seriesName: String
    let categories: [String]
    let values: [Double]
    /// The value axis as drawn (`chartYScale(domain:)`), not the tallest bar.
    let valueRange: ClosedRange<Double>
    let isMonthlyAverage: Bool
    let locale: Locale

    /// How the Audio Graph says a value: "274 cups", or "253 cups a day".
    func spokenValue(_ value: Double) -> String {
        let cups = CafeWording.count(value, locale: locale)
        guard !cups.isEmpty, isMonthlyAverage else { return cups }
        return "\(cups) a day"
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(title: xTitle, categoryOrder: categories)
        let yAxis = AXNumericDataAxisDescriptor(
            title: yTitle,
            range: valueRange,
            gridlinePositions: []
        ) { value in spokenValue(value) }
        let series = AXDataSeriesDescriptor(
            name: seriesName,
            isContinuous: false,
            dataPoints: zip(categories, values).map { AXDataPoint(x: $0, y: $1) }
        )
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
