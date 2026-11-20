import Accessibility
import Foundation
import Observation
import SwiftUI

/// How much of the four weeks the x scale's domain covers. The narrower ones sit inside the data,
/// so days fall outside the domain on both sides.
enum PlotClippingRange: String, CaseIterable, Identifiable {
    case fourWeeks
    case twoWeeks
    case oneWeek

    var id: Self {
        self
    }

    var weekCount: Int {
        switch self {
        case .fourWeeks: 4
        case .twoWeeks: 2
        case .oneWeek: 1
        }
    }

    /// The first and last day of the domain, as days after the data's first day.
    var dayOffsets: ClosedRange<Int> {
        switch self {
        case .fourWeeks: 0 ... 27
        case .twoWeeks: 7 ... 20
        case .oneWeek: 10 ... 16
        }
    }

    /// Days between two labelled days on the x axis at ordinary text sizes.
    var labelStep: Int {
        switch self {
        case .fourWeeks: 7
        case .twoWeeks: 4
        case .oneWeek: 2
        }
    }

    /// "1 week", "4 weeks", for the picker.
    func title(locale: Locale) -> String {
        CafeWording.weeks(weekCount, locale: locale)
    }
}

/// Dates written in the calendar and time zone the sample days were made in (UTC), so the words name
/// the day that is drawn wherever the device is.
nonisolated enum PlotClippingDates {
    static func style(locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
    }

    /// "Saturday, March 14".
    static func dayName(_ date: Date, locale: Locale) -> String {
        date.formatted(style(locale: locale).weekday(.wide).month(.wide).day())
    }

    /// "March 14".
    static func monthDay(_ date: Date, locale: Locale) -> String {
        date.formatted(style(locale: locale).month(.wide).day())
    }

    /// The x axis's labels: "Mar 14", or the day alone ("14") at the accessibility text sizes.
    static func axisFormat(locale: Locale, isLargeText: Bool) -> Date.FormatStyle {
        isLargeText ? style(locale: locale).day() : style(locale: locale).month(.abbreviated).day()
    }
}

/// The state of "Clipping the plot area": which stretch of days the x scale's domain covers, and
/// whether the plot area is clipped. The days outside the domain keep their marks either way; only
/// the clip decides whether they are drawn.
@Observable
final class PlotClippingViewModel {
    let days: [DailySales]
    var range: PlotClippingRange = .oneWeek
    /// The mistake: a domain narrower than the data, with the plot area left unclipped.
    var isShowingMistake = false

    init(days: [DailySales] = CafeData.harbourSales) {
        self.days = days.sorted { $0.day < $1.day }
    }

    var clipsPlotArea: Bool {
        !isShowingMistake
    }

    var hasData: Bool {
        !days.isEmpty
    }

    /// Whether leaving the plot unclipped would be a mistake: only when some days fall outside the
    /// domain. At four weeks the domain equals the data, and the clip only trims the end points.
    var canShowMistake: Bool {
        !daysOutsideDomain.isEmpty
    }

    /// The x scale's domain: the range's days, counted from the data's first day. `nil` with no data.
    var domain: ClosedRange<Date>? {
        guard let first = days.first?.day else { return nil }
        let start = date(offset: range.dayOffsets.lowerBound, from: first)
        let end = date(offset: range.dayOffsets.upperBound, from: first)
        return start ... end
    }

    func isInsideDomain(_ day: DailySales) -> Bool {
        domain?.contains(day.day) ?? false
    }

    /// Whether the day's mark can be seen: inside the domain, or outside it on an unclipped plot.
    func isDrawn(_ day: DailySales) -> Bool {
        isInsideDomain(day) || !clipsPlotArea
    }

    /// The days the axis covers.
    var daysInDomain: [DailySales] {
        days.filter(isInsideDomain)
    }

    /// The days that have marks but lie outside the domain.
    var daysOutsideDomain: [DailySales] {
        days.filter { !isInsideDomain($0) }
    }

    /// The days whose marks can be seen, in date order.
    var drawnDays: [DailySales] {
        days.filter(isDrawn)
    }

    /// Changes whenever the element text changes while the data's ids do not, so the chart is rebuilt
    /// and VoiceOver reads the new words.
    var chartIdentity: String {
        "\(range.rawValue)-\(clipsPlotArea)"
    }

    // MARK: Axis

    /// The days the x axis labels. The last few days of the domain are left unlabelled, as a date label
    /// sits after its grid line and one at the plot's trailing edge has no room. Half as many at the
    /// accessibility text sizes.
    func axisDays(isLargeText: Bool) -> [Date] {
        guard let first = days.first?.day else { return [] }
        let step = range.labelStep * (isLargeText ? 2 : 1)
        let room = (step + 1) / 2
        let offsets = range.dayOffsets
        return stride(from: offsets.lowerBound, through: offsets.upperBound - room, by: step).map {
            date(offset: $0, from: first)
        }
    }

    // MARK: Words

    /// "March 11 to March 17".
    func domainText(locale: Locale) -> String {
        guard let domain else { return "" }
        return "\(PlotClippingDates.monthDay(domain.lowerBound, locale: locale)) to "
            + PlotClippingDates.monthDay(domain.upperBound, locale: locale)
    }

    /// The busiest day or days inside the domain: what the plot shows whether or not it is clipped.
    var busiestDays: [DailySales] {
        guard let most = daysInDomain.map(\.cups).max(), most > 0 else { return [] }
        return daysInDomain.filter { $0.cups == most }
    }

    /// The chart's message, about the days inside the domain. True on a tie, and when nothing sold.
    func headline(locale: Locale) -> String {
        guard hasData else { return "No daily sales to show yet." }
        let stretch = domainText(locale: locale)
        guard let cups = busiestDays.first?.cups else { return "No cups sold from \(stretch)." }
        let names = CafeWording.list(busiestDays.map { PlotClippingDates.dayName($0.day, locale: locale) })
        return "Most in a day from \(stretch): \(CafeWording.cups(cups, locale: locale)), on \(names)."
    }

    /// What the clip is doing to the chart as it is now drawn, for the line under the controls.
    func plotNote(locale: Locale) -> String {
        let outside = daysOutsideDomain.count
        guard hasData else { return "With no data there is nothing to clip." }
        guard outside > 0 else {
            // The first and last days sit on the plot's edges, so a clip cuts their symbols in half.
            return clipsPlotArea
                ? "Every day is inside the x scale's domain, so clipping only trims the first and last points, which sit on the plot's edges."
                : "Every day is inside the x scale's domain, so the plot is unclipped and the first and last points, which sit on the plot's edges, are drawn whole."
        }
        let count = CafeWording.days(outside, locale: locale)
        return clipsPlotArea
            ? "Outside the domain: \(count), cut off at the plot area's edge."
            : "Outside the domain: \(count), drawn past the plot area, over the axis labels and beyond the chart."
    }

    /// An element's label: the day first, then where it is drawn when that is outside the plot.
    func elementLabel(for day: DailySales, locale: Locale) -> String {
        let name = PlotClippingDates.dayName(day.day, locale: locale)
        return isInsideDomain(day) ? name : "\(name), drawn outside the plot area"
    }

    func elementValue(for day: DailySales, locale: Locale) -> String {
        CafeWording.cups(day.cups, locale: locale)
    }

    // MARK: Announcements

    /// Said when the domain changes: what changed, then the headline.
    func rangeAnnouncement(locale: Locale) -> String {
        "X scale domain now \(domainText(locale: locale)). \(headline(locale: locale))"
    }

    /// Said when the clip is turned on or off: what changed, then the headline.
    func clippingAnnouncement(locale: Locale) -> String {
        let change = clipsPlotArea ? "Plot area clipped." : "Plot area not clipped."
        return "\(change) \(plotNote(locale: locale)) \(headline(locale: locale))"
    }

    // MARK: Code

    static let domainSnippet = SnippetReference(
        name: "clipping-the-plot-area-domain", title: "A domain narrower than the data"
    )
    static let clipSnippet = SnippetReference(
        name: "clipping-the-plot-area-clip", title: "Clipping the plot area"
    )

    /// The code behind the chart as drawn: the mistake is the narrowed domain with no clip.
    var snippets: [SnippetReference] {
        clipsPlotArea ? [Self.domainSnippet, Self.clipSnippet] : [Self.domainSnippet]
    }

    // MARK: Audio Graph

    /// The value axis as drawn and as given to the descriptor: 0 to the most cups of any day, the days outside the
    /// x domain included, rounded up to a tidy step. It stays put as the domain narrows.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    func descriptor(locale: Locale) -> PlotClippingChartDescriptor {
        let drawn = drawnDays
        let outsideDrawn = drawn.count(where: { !isInsideDomain($0) })
        let highest = drawn.map(\.cups).max() ?? 0
        let highestDays = drawn.filter { $0.cups == highest }.map { PlotClippingDates.dayName($0.day, locale: locale) }
        var summary = "\(CafeWording.days(drawn.count, locale: locale)) drawn. "
        if let first = drawn.first, let last = drawn.last {
            summary += "First day \(CafeWording.cups(first.cups, locale: locale)), "
                + "last day \(CafeWording.cups(last.cups, locale: locale)), "
                + "highest \(CafeWording.cups(highest, locale: locale)) on \(CafeWording.list(highestDays))."
        }
        if outsideDrawn > 0 {
            summary += " Drawn outside the plot area, beyond the x axis's range: \(CafeWording.days(outsideDrawn, locale: locale))."
        }
        return PlotClippingChartDescriptor(
            title: "Daily cups at the \(CafeWording.harbour) café, x axis from \(domainText(locale: locale))",
            summary: summary,
            points: drawn.map { (PlotClippingDates.monthDay($0.day, locale: locale), $0.cups) },
            // The y scale is the chart's own: every day's cups, the ones outside the x domain included, from zero.
            valueDomain: valueDomain,
            locale: locale
        )
    }

    private func date(offset: Int, from first: Date) -> Date {
        CafeData.calendar.date(byAdding: .day, value: offset, to: first) ?? first
    }
}

/// The chart for the Audio Graph: the days whose marks can be seen, as one connected line.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PlotClippingChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    /// Each drawn day, written out, and its cups, in date order.
    let points: [(day: String, cups: Int)]
    let valueDomain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: points.map(\.day))
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: points.map { AXDataPoint(x: $0.day, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series]
        )
    }
}
