import Accessibility
import Foundation
import Observation
import SwiftUI

/// The two periods the screen switches between: a quiet weekday and a busy weekend day.
nonisolated enum AxisRangePeriod: String, CaseIterable, Identifiable {
    case tuesday = "Tuesday"
    case saturday = "Saturday"

    var id: String {
        rawValue
    }

    /// The name of the day in `CafeData.seatsFilled`, and the day the cups are counted on.
    var dayName: String {
        rawValue
    }

    /// The weekday in `CafeData.calendar`'s numbering (Sunday is 1).
    var weekday: Int {
        switch self {
        case .tuesday: 3
        case .saturday: 7
        }
    }
}

/// What changed, for the announcement.
enum AxisRangeChange {
    case period
    case swap
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum AxisRangeWording {
    static let hour = "Hour"
    static let seatsFilled = "Seats filled"
    static let seatsHeading = "Seats filled (%)"
}

/// A value axis as drawn: its domain, and the step its labels are written at, counting up from the bottom
/// so the baseline is labelled, with the top always labelled too.
nonisolated struct AxisRangeAxis: Equatable {
    let domain: ClosedRange<Double>
    let labelStep: Double

    var top: Double {
        domain.upperBound
    }

    /// The values the axis labels, from the bottom up: the bottom, then every step, then the top. A counted
    /// value less than half a step below the top is left out, so its label does not crowd the top's.
    ///
    /// Thinned, for the accessibility text sizes, where the plot is short and the labels tall: the bottom, the
    /// middle and the top when the middle is round (0, 150, 300); otherwise every second step, with a counted
    /// value less than a whole doubled step below the top left out (0, 100, 250), since 200 under 250 collided
    /// with it at `.accessibility3` (as 400 under 500 did).
    func labels(thinned: Bool) -> [Double] {
        guard labelStep > 0, domain.upperBound > domain.lowerBound else { return [domain.lowerBound, domain.upperBound] }
        guard thinned else { return labels(step: labelStep, clearance: labelStep / 2) }
        let middle = (domain.lowerBound + domain.upperBound) / 2
        if Self.isRound(middle) {
            return [domain.lowerBound, middle, domain.upperBound]
        }
        return labels(step: labelStep * 2, clearance: labelStep * 2)
    }

    /// A value people count in: a multiple of 50 from 100 up, of 10 below it. 250 and 70 are; 125 and 45 are not.
    static func isRound(_ value: Double) -> Bool {
        let unit: Double = value >= 100 ? 50 : 10
        return (value / unit).rounded() * unit == value
    }

    /// The bottom, every `step` above it that is at least `clearance` below the top, and the top.
    private func labels(step: Double, clearance: Double) -> [Double] {
        let counted = stride(from: domain.lowerBound, to: domain.upperBound, by: step)
            .filter { $0 == domain.lowerBound || domain.upperBound - $0 >= clearance }
        return counted + [domain.upperBound]
    }
}

/// The two ways to choose a value axis's range, written once so the chart, the headline and the
/// descriptor all use the same one.
nonisolated enum AxisRangeScales {
    /// Where the cups axis's top is rounded to, and its labels step.
    static let cupsStep = 50.0
    /// The step of a percentage axis's labels when it follows the data, and where its ends are rounded to.
    static let percentLabelStep = 10.0
    /// The step of the fixed percentage axis's labels.
    static let percentFixedLabelStep = 25.0
    /// The step of the fixed cups axis's labels.
    static let cupsFixedLabelStep = 100.0

    // snippet:axes-fixed-or-dynamic-range-fixed
    /// A percentage has a range that means something whatever the data: 0 to 100.
    static let percentRange: ClosedRange<Double> = 0 ... 100
    // end

    // snippet:axes-fixed-or-dynamic-range-dynamic
    /// A count has no top of its own: the axis follows the largest value shown, rounded up to the
    /// next 50 cups (at least 50, so a period with no cups still has an axis).
    static func cupsRange(largest: Int) -> ClosedRange<Double> {
        0 ... max(cupsStep, (Double(largest) / cupsStep).rounded(.up) * cupsStep)
    }

    // end

    // snippet:axes-fixed-or-dynamic-range-mistake-percent
    /// The mistake: a percentage whose axis follows the data, from the ten below the lowest reading
    /// to the ten above the highest, so any day's line fills the plot.
    static func percentRangeFollowingData(lowest: Int, highest: Int) -> ClosedRange<Double> {
        let top = max(percentLabelStep, (Double(highest) / percentLabelStep).rounded(.up) * percentLabelStep)
        let bottom = (Double(lowest) / percentLabelStep).rounded(.down) * percentLabelStep
        return max(0, min(bottom, top - percentLabelStep)) ... top
    }

    // end

    // snippet:axes-fixed-or-dynamic-range-mistake-cups
    /// The mistake: a count under a ceiling chosen once. Nothing makes 500 cups the top of a day.
    static let cupsFixedRange: ClosedRange<Double> = 0 ... 500
    // end
}

/// The state and words of "Axes: fixed or dynamic range": a percentage on a fixed axis and a count on a
/// dynamic one, across two periods, with a switch that swaps the two choices as the mistake.
@Observable
final class AxisRangeViewModel {
    var period: AxisRangePeriod = .tuesday
    /// The mistake: the percentage follows the data and the count is fixed.
    var isSwapped = false

    let seatsFilled: [SeatsFilledDay]
    let sales: [DailySales]

    init(seatsFilled: [SeatsFilledDay] = CafeData.seatsFilled, sales: [DailySales] = CafeData.harbourSales) {
        self.seatsFilled = seatsFilled
        self.sales = sales
    }

    // MARK: Data

    func readings(for period: AxisRangePeriod) -> [SeatsFilledHour] {
        seatsFilled.first { $0.name == period.dayName }?.readings ?? []
    }

    /// Every day of `period`'s weekday in the sales, in date order.
    func cupsDays(for period: AxisRangePeriod) -> [DailySales] {
        sales.filter { CafeData.calendar.component(.weekday, from: $0.day) == period.weekday }
    }

    var readings: [SeatsFilledHour] {
        readings(for: period)
    }

    var cupsDays: [DailySales] {
        cupsDays(for: period)
    }

    /// No seat readings for the period: the seats chart is a placeholder.
    var hasSeats: Bool {
        !readings.isEmpty
    }

    /// No cups, or only zeros, for the period: bars of zero draw nothing, so the cups chart is a placeholder.
    var hasCups: Bool {
        cupsDays.contains { $0.cups > 0 }
    }

    // MARK: Axes

    func seatsAxis(for period: AxisRangePeriod, swapped: Bool) -> AxisRangeAxis {
        let percents = readings(for: period).map(\.percent)
        guard swapped, let lowest = percents.min(), let highest = percents.max() else {
            return AxisRangeAxis(domain: AxisRangeScales.percentRange, labelStep: AxisRangeScales.percentFixedLabelStep)
        }
        return AxisRangeAxis(
            domain: AxisRangeScales.percentRangeFollowingData(lowest: lowest, highest: highest),
            labelStep: AxisRangeScales.percentLabelStep
        )
    }

    func cupsAxis(for period: AxisRangePeriod, swapped: Bool) -> AxisRangeAxis {
        if swapped {
            return AxisRangeAxis(domain: AxisRangeScales.cupsFixedRange, labelStep: AxisRangeScales.cupsFixedLabelStep)
        }
        let largest = cupsDays(for: period).map(\.cups).max() ?? 0
        return AxisRangeAxis(domain: AxisRangeScales.cupsRange(largest: largest), labelStep: AxisRangeScales.cupsStep)
    }

    var seatsAxis: AxisRangeAxis {
        seatsAxis(for: period, swapped: isSwapped)
    }

    var cupsAxis: AxisRangeAxis {
        cupsAxis(for: period, swapped: isSwapped)
    }

    // MARK: Words

    /// The cups chart's heading: "Cups, each Tuesday in March".
    var cupsHeading: String {
        "\(CafeWording.cups), each \(period.dayName) in March"
    }

    /// The headline, true of what is drawn in every setting. Its figures are the axes' top labels.
    func headline(locale: Locale) -> String {
        headline(for: period, swapped: isSwapped, locale: locale)
    }

    func headline(for period: AxisRangePeriod, swapped: Bool, locale: Locale) -> String {
        let day = period.dayName
        let seatsAxis = seatsAxis(for: period, swapped: swapped)
        let seats = if readings(for: period).isEmpty {
            "No seat readings for \(day)"
        } else if swapped {
            "Swapped: the seats axis runs from \(Self.percent(seatsAxis.domain.lowerBound, locale: locale)) "
                + "to \(Self.percent(seatsAxis.top, locale: locale)), so \(day)'s line fills the plot"
        } else {
            "\(day): seats filled on the full "
                + "\(Self.percent(seatsAxis.domain.lowerBound, locale: locale)) to \(Self.percent(seatsAxis.top, locale: locale)) axis"
        }
        let cups: String
        let cupsTop = CafeWording.count(cupsAxis(for: period, swapped: swapped).top, locale: locale)
        if !cupsDays(for: period).contains(where: { $0.cups > 0 }) {
            cups = "no cups recorded on \(day)s"
        } else if swapped {
            cups = "the cups axis is fixed at \(cupsTop)"
        } else {
            cups = "the cups axis stops at \(cupsTop), following the busiest \(day)"
        }
        return "\(seats); \(cups)."
    }

    /// What the screen demonstrates, with the cups axis's tops taken from the data.
    func explanation(locale: Locale) -> String {
        let tops = AxisRangePeriod.allCases.map {
            "\(CafeWording.count(cupsAxis(for: $0, swapped: false).top, locale: locale)) on \($0.dayName)s"
        }
        return "A percentage has a range that means something whatever the data, so give its axis the fixed range "
            + "\(Self.percent(0, locale: locale)) to \(Self.percent(100, locale: locale)): a quiet day's line then stays low. "
            + "A count has no top of its own, so let its axis follow the largest value shown: as chosen, the cups axis "
            + "stops at \(CafeWording.list(tops)), with the bars filling the plot. "
            + "Swapped, a quiet Tuesday looks full and the cups sit under a ceiling nothing chose."
    }

    /// What is spoken after a control changes the chart: what changed, then the headline.
    func announcement(after change: AxisRangeChange, locale: Locale) -> String {
        let what = switch change {
        case .period: "Showing \(period.dayName)."
        case .swap: isSwapped ? "Ranges swapped, the mistake." : "Ranges as chosen by meaning."
        }
        return "\(what) \(headline(locale: locale))"
    }

    /// The snippets for the current setting: the two charts first, then the ranges they are given.
    var snippets: [SnippetReference] {
        let charts = [
            SnippetReference(name: "axes-fixed-or-dynamic-range-seats-chart", title: "The percentage chart and its range"),
            SnippetReference(name: "axes-fixed-or-dynamic-range-cups-chart", title: "The count chart and its range"),
        ]
        if isSwapped {
            return charts + [
                SnippetReference(name: "axes-fixed-or-dynamic-range-mistake-percent", title: "The mistake: a percentage that follows the data"),
                SnippetReference(name: "axes-fixed-or-dynamic-range-mistake-cups", title: "The mistake: a count under a fixed ceiling"),
            ]
        }
        return charts + [
            SnippetReference(name: "axes-fixed-or-dynamic-range-fixed", title: "A percentage: fixed at 0 to 100"),
            SnippetReference(name: "axes-fixed-or-dynamic-range-dynamic", title: "A count: the top follows the largest value"),
        ]
    }

    // MARK: Accessibility

    /// The charts' identity, built from every state that changes what their descriptors return. A chart's
    /// Audio Graph descriptor is fixed with its identity (read on the iPhone 17 simulator).
    var chartIdentity: String {
        "\(period.rawValue)-\(isSwapped)"
    }

    func seatsDescriptor(locale: Locale) -> AxisRangeSeatsDescriptor {
        AxisRangeSeatsDescriptor(dayName: period.dayName, readings: readings, axis: seatsAxis, locale: locale)
    }

    func cupsDescriptor(locale: Locale) -> AxisRangeCupsDescriptor {
        AxisRangeCupsDescriptor(dayName: period.dayName, days: cupsDays, axis: cupsAxis, locale: locale)
    }

    // MARK: Formatting

    /// A whole percentage in the locale's form: "35%".
    nonisolated static func percent(_ value: Double, locale: Locale) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// An hour's start, as VoiceOver says it: "7:00 AM", in the data's calendar.
    nonisolated static func time(_ date: Date, locale: Locale) -> String {
        TimeOfDayWording.time(date, locale: locale)
    }

    /// A day on the cups axis: "3", in the data's calendar. The heading names the month, and four "Mar 3" labels
    /// are truncated in a half-width chart.
    nonisolated static func shortDay(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .day())
    }

    /// A day as VoiceOver says it: "March 3", in the data's calendar.
    nonisolated static func longDay(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month(.wide).day())
    }
}

/// The seats chart for the Audio Graph: hours in order, percentages with their unit, and the range drawn.
nonisolated struct AxisRangeSeatsDescriptor: AXChartDescriptorRepresentable {
    let dayName: String
    let readings: [SeatsFilledHour]
    let axis: AxisRangeAxis
    let locale: Locale

    var title: String {
        "\(AxisRangeWording.seatsFilled) by hour on \(dayName)"
    }

    var summary: String {
        guard let lowest = readings.min(by: { $0.percent < $1.percent }),
              let highest = readings.max(by: { $0.percent < $1.percent }),
              let first = readings.first
        else { return "No seat readings for \(dayName)." }
        let percent = { (value: Int) in AxisRangeViewModel.percent(Double(value), locale: locale) }
        let time = { (date: Date) in AxisRangeViewModel.time(date, locale: locale) }
        return "\(readings.count.formatted(.number.locale(locale))) hourly readings from \(time(first.start)). "
            + "Lowest \(percent(lowest.percent)) at \(time(lowest.start)), highest \(percent(highest.percent)) at \(time(highest.start)). "
            + "The axis runs from \(AxisRangeViewModel.percent(axis.domain.lowerBound, locale: locale)) "
            + "to \(AxisRangeViewModel.percent(axis.top, locale: locale))."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: AxisRangeWording.hour,
            categoryOrder: readings.map { AxisRangeViewModel.time($0.start, locale: locale) }
        )
        let yAxis = AXNumericDataAxisDescriptor(title: AxisRangeWording.seatsHeading, range: axis.domain, gridlinePositions: []) { value in
            value.isFinite ? AxisRangeViewModel.percent(value, locale: locale) : ""
        }
        let series = AXDataSeriesDescriptor(
            name: AxisRangeWording.seatsFilled,
            isContinuous: true,
            dataPoints: readings.map { AXDataPoint(x: AxisRangeViewModel.time($0.start, locale: locale), y: Double($0.percent)) }
        )
        return AXChartDescriptor(title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }
}

/// The cups chart for the Audio Graph: written-out days, cups that agree in number, and the range drawn.
nonisolated struct AxisRangeCupsDescriptor: AXChartDescriptorRepresentable {
    let dayName: String
    let days: [DailySales]
    let axis: AxisRangeAxis
    let locale: Locale

    var title: String {
        "\(CafeWording.cups) on each \(dayName) in March at the \(CafeWording.harbour) café"
    }

    var summary: String {
        guard let fewest = days.min(by: { $0.cups < $1.cups }), let most = days.max(by: { $0.cups < $1.cups }), most.cups > 0 else {
            return "No cups recorded on \(dayName)s."
        }
        let day = { (date: Date) in AxisRangeViewModel.longDay(date, locale: locale) }
        return "\(CafeWording.days(days.count, locale: locale)). "
            + "Fewest \(CafeWording.cups(fewest.cups, locale: locale)) on \(day(fewest.day)), "
            + "most \(CafeWording.cups(most.cups, locale: locale)) on \(day(most.day)). "
            + "The axis runs from 0 to \(CafeWording.count(axis.top, locale: locale))."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { AxisRangeViewModel.longDay($0.day, locale: locale) }
        )
        let yAxis = AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: axis.domain, gridlinePositions: []) { value in
            CafeWording.count(value, locale: locale)
        }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: days.map { AXDataPoint(x: AxisRangeViewModel.longDay($0.day, locale: locale), y: Double($0.cups)) }
        )
        return AXChartDescriptor(title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }
}
