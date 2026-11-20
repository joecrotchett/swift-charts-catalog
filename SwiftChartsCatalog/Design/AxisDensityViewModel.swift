import Accessibility
import Foundation
import Observation
import SwiftUI

/// How long the value axis's labels are: every digit ("5,000") or compact ("5K").
enum AxisDensityLabelLength: String, CaseIterable, Identifiable {
    case full
    case short

    var id: Self {
        self
    }

    /// The picker's segment, showing what the label looks like.
    var title: String {
        switch self {
        case .full: "Full (5,000)"
        case .short: "Short (5K)"
        }
    }
}

/// The words this screen needs that `CafeWording` does not have.
nonisolated enum AxisDensityWording {
    /// The `.value` label and the descriptor's y axis title: the running total, not one day's cups.
    static let cupsSoFar = "Cups so far"
}

/// The state of "Axes: density and weight": how many grid lines the value axis asks for, whether the
/// axes are heavy or quiet, how long the value labels are, and the plot's width as last laid out.
@Observable
final class AxisDensityViewModel {
    /// The counts the stepper offers.
    static let countRange = 2 ... 12

    /// The number of values passed to `.automatic(desiredCount:)`. The framework may draw a different number.
    var requestedCount = 3
    /// Heavy: solid, darker grid lines, ticks and primary labels. Quiet: pale grid lines and labels, no ticks.
    var isHeavy = false
    var labelLength: AxisDensityLabelLength = .short
    /// The plot area's width in points, read from the chart's proxy after layout. `nil` until laid out.
    var plotWidth: Double?

    let days: [DailySales]

    init(days: [DailySales] = CafeData.thirtyDays) {
        self.days = days
    }

    func totals(locale: Locale) -> AxisDensityTotals {
        AxisDensityTotals(days: days, locale: locale)
    }

    /// The value labels' format, in the view's locale. An explicit format carries its own locale.
    func valueFormat(locale: Locale) -> IntegerFormatStyle<Int> {
        switch labelLength {
        case .full:
            // snippet:axes-density-and-weight-full-labels
            IntegerFormatStyle<Int>.number.locale(locale)
        // end
        case .short:
            // snippet:axes-density-and-weight-short-labels
            // Compact notation: "5K", not "5,000". The unit is in the chart's heading.
            IntegerFormatStyle<Int>.number.notation(.compactName).locale(locale)
            // end
        }
    }

    /// The stepper's text: the count asked for, which is not always the count drawn.
    func countText(locale: Locale) -> String {
        "Grid lines asked for: \(requestedCount.formatted(.number.locale(locale)))"
    }

    /// "Plot width: 291 points", as measured on this device. `nil` before the chart is laid out.
    func plotWidthText(locale: Locale) -> String? {
        guard let plotWidth, plotWidth.isFinite, plotWidth > 0 else { return nil }
        return "Plot width: \(CafeWording.points(plotWidth.rounded(), locale: locale))"
    }

    /// The snippets for the current weight and label length.
    var snippets: [SnippetReference] {
        let weight = isHeavy
            ? SnippetReference(name: "axes-density-and-weight-heavy", title: "Heavy grid lines and labels")
            : SnippetReference(name: "axes-density-and-weight-quiet", title: "Quiet grid lines and labels")
        let labels = switch labelLength {
        case .full: SnippetReference(name: "axes-density-and-weight-full-labels", title: "Full value labels")
        case .short: SnippetReference(name: "axes-density-and-weight-short-labels", title: "Short value labels")
        }
        return [weight, labels]
    }
}

/// One day of the running total: the cups sold from the first day up to and including this one.
nonisolated struct AxisDensityDay: Identifiable, Hashable {
    let day: Date
    let cupsSoFar: Int

    var id: Date {
        day
    }
}

/// One week of the running total, one accessibility element.
nonisolated struct AxisDensityWeek: Identifiable, Hashable {
    let days: [AxisDensityDay]

    var id: Date {
        days.first?.day ?? .distantPast
    }

    var start: Date {
        days.first?.day ?? .distantPast
    }

    var end: Date {
        days.last?.day ?? .distantPast
    }
}

/// What the chart shows and says: the running total, its weeks, its value axis, headline and summary.
nonisolated struct AxisDensityTotals {
    let days: [DailySales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The running total, a day at a time.
    var running: [AxisDensityDay] {
        var total = 0
        return days.map { day in
            total += day.cups
            return AxisDensityDay(day: day.day, cupsSoFar: total)
        }
    }

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    var hasData: Bool {
        !days.isEmpty
    }

    /// The value axis as drawn: from zero to the next thousand cups above the total (at least a thousand).
    /// The chart and the descriptor share it.
    var valueDomain: ClosedRange<Int> {
        0 ... max(1000, Int((Double(total) / 1000).rounded(.up)) * 1000)
    }

    /// The running total in weeks of seven days; the last may be shorter.
    var weeks: [AxisDensityWeek] {
        let running = running
        return stride(from: 0, to: running.count, by: 7).map {
            AxisDensityWeek(days: Array(running[$0 ..< min($0 + 7, running.count)]))
        }
    }

    /// "March 1", in the calendar the dates were made in, so the device's time zone cannot shift it.
    func dayName(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(
            locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone
        ).month(.wide).day())
    }

    /// The format of the date axis's labels: "Mar 1", or the day alone ("15") at the accessibility text
    /// sizes, where "Mar 15" was cut to "Mar…" on a phone. The month is in the caption.
    func axisDateFormat(accessibilitySize: Bool) -> Date.FormatStyle {
        let format = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return accessibilitySize ? format.day() : format.month(.abbreviated).day()
    }

    /// The chart's caption, naming the month the days fall in: "Cups sold so far at the Harbour café, March 2026"
    /// ("Invented sample: cups sold so far ..." for the shared invented month).
    /// The caption. The shared invented month says it is invented, as `CafeWording.inventedDaysCaption` does, so
    /// it is not taken for the café's recorded March.
    var caption: String {
        guard let first = days.first?.day else { return "Cups sold so far at the \(CafeWording.harbour) café" }
        let month = first.formatted(CafeWording.monthYear(locale: locale))
        let place = "sold so far at the \(CafeWording.harbour) café, \(month)"
        return days == CafeData.thirtyDays ? "Invented sample: cups \(place)" : "Cups \(place)"
    }

    /// Context first: "March 1 to March 7", or one day's name for a week of one day.
    func label(for week: AxisDensityWeek) -> String {
        week.days.count > 1 ? "\(dayName(week.start)) to \(dayName(week.end))" : dayName(week.start)
    }

    /// Actual values with their unit: "From 174 cups to 1,141 cups so far".
    func value(for week: AxisDensityWeek) -> String {
        guard let first = week.days.first, let last = week.days.last else { return "" }
        if week.days.count == 1 { return "\(CafeWording.cups(last.cupsSoFar, locale: locale)) so far" }
        return "From \(CafeWording.cups(first.cupsSoFar, locale: locale)) to "
            + "\(CafeWording.cups(last.cupsSoFar, locale: locale)) so far"
    }

    /// What the screen demonstrates. With data, it names the top of the value axis, which a request for two or
    /// three lines leaves unmarked: what the reader sees when the count is only a wish.
    var explanation: String {
        let top = valueDomain.upperBound.formatted(.number.locale(locale))
        let topSentence = hasData
            ? "Ask for two or three and nothing marks the top of the axis at \(top): the round values the framework picks stop below it. "
            : ""
        return "Grid lines help people estimate a value, and each one also competes with the data. "
            + "AxisMarks(values: .automatic(desiredCount:)) asks for about that many values, and the framework "
            + "picks round ones near it, so count the lines it draws. \(topSentence)"
            + "With the total written at the end of the line, three pale grid lines are enough. Short labels such as 5K, "
            + "with the unit in the heading, leave more of the chart's width to the plot: compare the plot width below "
            + "with each label length."
    }

    /// The chart's message, its figure the one written at the end of the line.
    var headline: String {
        guard hasData else { return "No days recorded yet." }
        return "\(CafeWording.cups(total, locale: locale)) sold in \(CafeWording.days(days.count, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let first = running.first, let last = running.last else { return "No days recorded yet." }
        return "\(CafeWording.days(days.count, locale: locale)), \(dayName(first.day)) to \(dayName(last.day)). "
            + "Cups so far: \(CafeWording.cups(first.cupsSoFar, locale: locale)) after the first day, "
            + "\(CafeWording.cups(last.cupsSoFar, locale: locale)) after the last."
    }
}

/// The running total for the Audio Graph: written-out days, cups with their unit, one connected line.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct AxisDensityChartDescriptor: AXChartDescriptorRepresentable {
    let totals: AxisDensityTotals

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = totals.locale
        let running = totals.running
        let domain = totals.valueDomain
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: running.map { totals.dayName($0.day) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: AxisDensityWording.cupsSoFar,
            range: Double(domain.lowerBound) ... Double(domain.upperBound),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: running.map { AXDataPoint(x: totals.dayName($0.day), y: Double($0.cupsSoFar)) }
        )
        return AXChartDescriptor(
            title: "Cups sold so far at the Harbour café, day by day",
            summary: totals.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
