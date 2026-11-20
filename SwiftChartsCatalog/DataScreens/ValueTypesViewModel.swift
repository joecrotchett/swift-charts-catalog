import Accessibility
import Foundation
import Observation
import SwiftUI

/// The type of the value the chart is given on x. Each case plots the same days.
nonisolated enum ValueTypesXType: String, CaseIterable, Identifiable, Hashable {
    case string
    case number
    case date

    var id: String {
        rawValue
    }

    /// The picker's title for the case.
    var title: String {
        switch self {
        case .string: "String"
        case .number: "Number"
        case .date: "Date"
        }
    }

    /// What this type of value makes of the x axis, for the announcement.
    var axisDescription: String {
        switch self {
        case .string: "one band per day, in data order"
        case .number: "a number scale that starts at zero"
        case .date: "a date scale, one day per step"
        }
    }

    /// The snippets the Code view shows for the case.
    var snippets: [SnippetReference] {
        switch self {
        case .string:
            [SnippetReference(name: "value-types-string", title: "A String on x gives bands")]
        case .number:
            [SnippetReference(name: "value-types-number", title: "A number on x gives a number scale")]
        case .date:
            [
                SnippetReference(name: "value-types-date", title: "A Date on x gives a date scale"),
                SnippetReference(name: "value-types-date-axis", title: "The date axis in the data's calendar"),
            ]
        }
    }
}

/// One day of sales, carrying the day in all three types the chart can be given.
nonisolated struct ValueTypesDay: Identifiable, Hashable {
    /// The day as a `Date`: midnight UTC, as the sample data was made.
    let date: Date
    /// The day as a number: 1 for the first day shown.
    let number: Int
    /// The day as a `String`: its short weekday name, such as "Sun".
    let name: String
    let cups: Int

    var id: Date {
        date
    }

    /// The days of `sales`, numbered from 1 and named in `locale`, in the data's own time zone.
    static func days(from sales: [DailySales], locale: Locale) -> [ValueTypesDay] {
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.abbreviated)
        return sales.enumerated().map { index, day in
            ValueTypesDay(date: day.day, number: index + 1, name: day.day.formatted(style), cups: day.cups)
        }
    }
}

/// What the chart says in words for one type of x value: the headline, the elements, the announcement
/// and the Audio Graph's summary. Every day is named the way the chart currently draws it.
nonisolated struct ValueTypesSummary {
    let days: [ValueTypesDay]
    let xType: ValueTypesXType
    let locale: Locale

    private var timeZone: TimeZone {
        CafeData.calendar.timeZone
    }

    /// The day as the chart now positions it, written out: "Sunday", "Day 1" or "Sunday, March 1".
    func spokenDay(_ day: ValueTypesDay) -> String {
        switch xType {
        case .string:
            day.date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.wide))
        case .number:
            "Day \(day.number.formatted(.number.locale(locale)))"
        case .date:
            day.date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.wide).month(.wide).day())
        }
    }

    /// The day as the headline names it, matching a label the reader can find on the axis:
    /// "Saturday" under "Sat", "day 7" over 7, "March 7" under "Mar 7".
    func headlineDay(_ day: ValueTypesDay) -> String {
        switch xType {
        case .string:
            day.date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.wide))
        case .number:
            "day \(day.number.formatted(.number.locale(locale)))"
        case .date:
            day.date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).month(.wide).day())
        }
    }

    /// Where the number axis puts its marks: at every day's number, so the day the headline names
    /// ("day 7") has a label. The default marks choose round numbers and can leave it out.
    var numberAxisValues: [Int] {
        days.map(\.number)
    }

    /// The number axis as drawn, from zero to the last day rounded up to the axis step (7 → 8): the chart's x
    /// scale for the number type and the descriptor's.
    var numberDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.number))
    }

    /// The cups axis as drawn, from zero to the busiest day rounded up to the axis step (219 → 300): the chart's
    /// y scale and the descriptor's.
    var cupsDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    /// Days per label on the date axis: every day at the standard text sizes, every other day at the
    /// accessibility sizes, where seven "Mar 7" labels no longer fit side by side.
    static func daysPerDateLabel(at size: DynamicTypeSize) -> Int {
        size >= .accessibility1 ? 2 : 1
    }

    /// Whether a date label names its month ("Mar 7") or only its day ("7"): from accessibility 3,
    /// "Mar 7" is wider than two days of this week and is cut short, so only the day is written.
    static func dateLabelsNameMonth(at size: DynamicTypeSize) -> Bool {
        size < .accessibility3
    }

    /// The value of a day's element: its cups, agreeing in number.
    func spokenCups(_ day: ValueTypesDay) -> String {
        CafeWording.cups(day.cups, locale: locale)
    }

    private var hasSales: Bool {
        days.contains { $0.cups > 0 }
    }

    /// Every day that sold the most, in data order; empty when nothing sold.
    var busiestDays: [ValueTypesDay] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }
    }

    /// Every day that sold the fewest, in data order; empty when nothing sold.
    var quietestDays: [ValueTypesDay] {
        guard hasSales, let fewest = days.map(\.cups).min() else { return [] }
        return days.filter { $0.cups == fewest }
    }

    /// The chart's message, true for every type of x value, for ties, and for no sales.
    var headline: String {
        if days.isEmpty { return "No days to show." }
        guard let most = busiestDays.first?.cups else { return "No cups sold on any day." }
        // On a tie the figure is each day's own count, not their sum.
        let each = busiestDays.count > 1 ? " each" : ""
        return "Most cups: \(CafeWording.list(busiestDays.map(headlineDay))), \(CafeWording.cups(most, locale: locale))\(each)."
    }

    /// Said when the type changes: what changed, then the headline.
    var announcement: String {
        "Day is now a \(xType.title): \(xType.axisDescription). \(headline)"
    }

    /// The Audio Graph's summary, in actual values.
    var audioGraphSummary: String {
        if days.isEmpty { return "No days to show." }
        let count = CafeWording.days(days.count, locale: locale)
        guard let most = busiestDays.first?.cups, let fewest = quietestDays.first?.cups else {
            return "\(count). No cups sold on any day."
        }
        return "\(count). Most: \(CafeWording.list(busiestDays.map(spokenDay))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(quietestDays.map(spokenDay))), \(CafeWording.cups(fewest, locale: locale))."
    }
}

/// The Audio Graph for the chart as currently drawn: categories for a String or a Date (a date axis has
/// no descriptor type of its own, so the dates are written out), a number axis from zero for a number.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct ValueTypesChartDescriptor: AXChartDescriptorRepresentable {
    let days: [ValueTypesDay]
    let xType: ValueTypesXType
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = ValueTypesSummary(days: days, xType: xType, locale: locale)
        let locale = locale
        let xAxis: any AXDataAxisDescriptor
        let points: [AXDataPoint]
        switch xType {
        case .string, .date:
            let names = days.map(summary.spokenDay)
            xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: names)
            points = zip(names, days).map { AXDataPoint(x: $0, y: Double($1.cups)) }
        case .number:
            // The drawn number scale, from zero.
            xAxis = AXNumericDataAxisDescriptor(
                title: CafeWording.day,
                range: summary.numberDomain,
                gridlinePositions: []
            ) { value in
                guard value.isFinite, let number = Int(exactly: value.rounded()) else { return "" }
                return "Day \(number.formatted(.number.locale(locale)))"
            }
            points = days.map { AXDataPoint(x: Double($0.number), y: Double($0.cups)) }
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(name: CafeWording.harbour, isContinuous: false, dataPoints: points)
        return AXChartDescriptor(
            title: "Cups sold each day at the Harbour café, with the day given as a \(xType.title)",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

/// The screen's state: the type of the x value, over a fixed week of sales.
@Observable
final class ValueTypesViewModel {
    var xType: ValueTypesXType = .string
    let sales: [DailySales]

    /// The Harbour café's first week, 1 to 7 March 2026: seven days with seven different weekday names,
    /// so each can honestly be a name, a number or a date.
    init(sales: [DailySales] = Array(CafeData.harbourSales.prefix(7))) {
        self.sales = sales
    }

    func days(locale: Locale) -> [ValueTypesDay] {
        ValueTypesDay.days(from: sales, locale: locale)
    }

    func summary(locale: Locale) -> ValueTypesSummary {
        ValueTypesSummary(days: days(locale: locale), xType: xType, locale: locale)
    }

    var snippets: [SnippetReference] {
        xType.snippets
    }
}
