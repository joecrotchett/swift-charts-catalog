import Accessibility
import Foundation
import Observation
import SwiftUI

/// Which form of `.plotDimension` the current padding is written with.
enum ScalePaddingForm: Equatable {
    /// No padding at either end: `.plotDimension`.
    case none
    /// The same padding at both ends: `.plotDimension(padding:)`.
    case bothEnds
    /// A padding for each end: `.plotDimension(startPadding:endPadding:)`.
    case eachEnd

    /// The snippet that shows this form's code.
    var snippetName: String {
        switch self {
        case .none: "scale-padding-none"
        case .bothEnds: "scale-padding-both-ends"
        case .eachEnd: "scale-padding-each-end"
        }
    }

    var snippetTitle: String {
        switch self {
        case .none: "No padding: .plotDimension"
        case .bothEnds: "The same at both ends: padding:"
        case .eachEnd: "Each end its own: startPadding:, endPadding:"
        }
    }
}

/// The state of the "Scale padding" screen: a week of one café's cups, and the padding at each end
/// of the x scale's range.
@Observable
final class ScalePaddingViewModel {
    static let paddingRange: ClosedRange<Double> = 0 ... 40
    static let paddingStep: Double = 2
    static let chartSnippet = SnippetReference(name: "scale-padding-chart", title: "The chart and its x scale's range")

    let days: [DailySales]
    /// Points kept free at the start of the x scale's range.
    var startPadding: Double = 0
    /// Points kept free at the end of the x scale's range.
    var endPadding: Double = 0

    init(days: [DailySales] = Array(CafeData.harbourSales.prefix(7))) {
        self.days = days
    }

    var form: ScalePaddingForm {
        if startPadding == 0, endPadding == 0 { return .none }
        return startPadding == endPadding ? .bothEnds : .eachEnd
    }

    /// The snippets for the current setting: the chart, then the form its range is written in.
    var snippets: [SnippetReference] {
        [Self.chartSnippet, SnippetReference(name: form.snippetName, title: form.snippetTitle)]
    }

    func summary(locale: Locale) -> ScalePaddingSummary {
        ScalePaddingSummary(days: days, locale: locale)
    }

    /// What the slider shows beside its title: "16 points".
    func paddingText(_ padding: Double, locale: Locale) -> String {
        CafeWording.points(padding, locale: locale)
    }

    /// What the slider speaks: the setting, then the headline, so moving the slider tells a VoiceOver
    /// user what the chart says without an announcement on every step.
    func spokenPadding(_ padding: Double, locale: Locale) -> String {
        "\(paddingText(padding, locale: locale)). \(summary(locale: locale).headline)"
    }
}

/// What the chart says in words: the headline, the element text and the Audio Graph's summary.
nonisolated struct ScalePaddingSummary {
    let days: [DailySales]
    /// The locale every number and date is written in; the view passes its environment's.
    let locale: Locale

    /// The cups axis as drawn, from zero to the busiest day rounded up to the axis step (219 → 300): the chart's
    /// y scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    /// A day written out in the time zone the data was counted in: "Saturday, March 7".
    func dayText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// Every day with the most cups, in date order. Empty when there are no days.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max() else { return [] }
        return days.filter { $0.cups == most }
    }

    /// Every day with the fewest cups, in date order.
    var quietestDays: [DailySales] {
        guard let fewest = days.map(\.cups).min() else { return [] }
        return days.filter { $0.cups == fewest }
    }

    /// The chart's message. The padding never changes it: it moves the points, not their values.
    var headline: String {
        guard let most = busiestDays.first?.cups else { return "No days to show yet." }
        if most == 0 { return "No cups sold on any day: \(CafeWording.cups(0, locale: locale)) each day." }
        let cups = CafeWording.cups(most, locale: locale)
        if busiestDays.count == days.count { return "Every day sold \(cups)." }
        // "on A and B" reads the same for one day or a tie, so nothing has to agree with the count.
        return "The most in a day: \(cups), on \(CafeWording.list(busiestDays.map { dayText($0.day) }))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let first = days.first, let last = days.last,
              let most = busiestDays.first?.cups, let fewest = quietestDays.first?.cups
        else { return "No days to show yet." }
        return "\(CafeWording.days(days.count, locale: locale)). "
            + "First day \(CafeWording.cups(first.cups, locale: locale)), last day \(CafeWording.cups(last.cups, locale: locale)). "
            + "Highest \(CafeWording.cups(most, locale: locale)), on \(CafeWording.list(busiestDays.map { dayText($0.day) })). "
            + "Lowest \(CafeWording.cups(fewest, locale: locale)), on \(CafeWording.list(quietestDays.map { dayText($0.day) }))."
    }

    /// "March 1 to March 7", or one day when there is only one.
    var periodText: String {
        guard let first = days.first?.day, let last = days.last?.day else { return "" }
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).day()
        return first == last ? first.formatted(style) : "\(first.formatted(style)) to \(last.formatted(style))"
    }
}

/// The chart for the Audio Graph: one continuous line of cups over written-out days.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ScalePaddingChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = ScalePaddingSummary(days: days, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.dayText($0.day) }
        )
        // The drawn value axis, from zero to its rounded top.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: days.map { AXDataPoint(x: summary.dayText($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the \(CafeWording.harbour) café, \(summary.periodText)",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
