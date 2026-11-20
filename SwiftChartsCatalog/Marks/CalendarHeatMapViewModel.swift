import Accessibility
import Foundation
import Observation
import SwiftUI

/// The state of the "Calendar heat map" screen: whether the weekday normalisation is left out, and
/// whether the text of the accessibility elements is shown under the chart.
@Observable
final class CalendarHeatMapViewModel {
    /// The mistake: each day's own date on x, which draws the weeks as a staircase.
    var isShowingMistake = false
    /// Whether the screen writes out what the replaced accessibility elements say.
    var isShowingSpokenText = false

    let days: [DailySales]
    let calendar: Calendar

    init(days: [DailySales] = CafeData.tenWeeks, calendar: Calendar = CafeData.calendar) {
        self.days = days
        self.calendar = calendar
    }

    /// Everything the screen says about the chart as it is drawn now, written for a locale.
    func summary(locale: Locale) -> CalendarHeatMapSummary {
        CalendarHeatMapSummary(days: days, calendar: calendar, isStaircase: isShowingMistake, locale: locale)
    }

    /// The code See Code shows for the current setting.
    var snippets: [SnippetReference] {
        [
            isShowingMistake
                ? SnippetReference(name: "calendar-heat-map-staircase", title: "The mistake: the day's own date")
                : SnippetReference(name: "calendar-heat-map-weekday-column", title: "Weekdays as columns"),
            SnippetReference(name: "calendar-heat-map-tile", title: "A tile with a date on both axes"),
            SnippetReference(name: "calendar-heat-map-elements", title: "One element per day"),
        ]
    }
}

/// What one replaced accessibility element says.
nonisolated struct CalendarHeatMapElement: Hashable {
    /// The full date: "Sunday, March 1".
    let label: String
    /// The cups, with the unit: "193 cups".
    let value: String
    /// The first day of a month is a heading, so VoiceOver can jump from month to month.
    let isHeading: Bool

    /// The element as VoiceOver reads it: label, value, then the trait.
    var spokenText: String {
        isHeading ? "\(label), \(value), heading" : "\(label), \(value)"
    }
}

/// The calendar's geometry and its words for one state of the screen: which column and row each day
/// is drawn in, the headline, the element text and the Audio Graph summary.
nonisolated struct CalendarHeatMapSummary {
    let days: [DailySales]
    /// The calendar the days were recorded in. Its first weekday is the first column.
    let calendar: Calendar
    /// True while the mistake is shown: each day is drawn at its own date.
    let isStaircase: Bool
    let locale: Locale

    static let daysPerWeek = 7
    /// How many elements the screen writes out when asked what VoiceOver reads.
    static let spokenPreviewCount = 7
    /// More days than this tied for the most are counted, not listed.
    static let longestListOfDays = 3

    // MARK: Geometry

    private var sortedDays: [DailySales] {
        days.sorted { $0.day < $1.day }
    }

    /// The start of each week the data touches, in order: one per row.
    var weeks: [Date] {
        var starts: [Date] = []
        for day in sortedDays {
            if let start = calendar.dateInterval(of: .weekOfYear, for: day.day)?.start, starts.last != start {
                starts.append(start)
            }
        }
        return starts
    }

    /// A day's position in its week, counted from the calendar's first weekday.
    func weekdayColumn(for date: Date) -> Int {
        (calendar.component(.weekday, from: date) - calendar.firstWeekday + Self.daysPerWeek) % Self.daysPerWeek
    }

    // snippet:calendar-heat-map-weekday-column
    /// The same weekday in the first week of the data. Plotted on x in place of the day's own
    /// date, it gives every Monday one column, every Tuesday the next, and so on.
    func columnDate(for date: Date) -> Date {
        guard let firstWeek = weeks.first else { return date }
        return calendar.date(byAdding: .day, value: weekdayColumn(for: date), to: firstWeek) ?? date
    }

    // end

    // snippet:calendar-heat-map-staircase
    /// The date the chart plots on x for a day. The mistake is the first branch, the day's own date:
    /// each week then starts seven columns further along than the one above it, and no two days
    /// share a column.
    func xDate(for date: Date) -> Date {
        isStaircase ? date : columnDate(for: date)
    }

    // end

    /// What the x value is called in the mark and on the Audio Graph's axis: true of what is plotted.
    var xValueName: String {
        isStaircase ? CafeWording.day : CafeWording.weekday
    }

    /// How many columns the chart is drawn with: seven weekdays, or every day from first to last.
    var columnCount: Int {
        guard isStaircase else { return Self.daysPerWeek }
        guard let first = sortedDays.first?.day, let last = sortedDays.last?.day else { return 0 }
        return (calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: last).day ?? 0) + 1
    }

    /// The column a day is drawn in, in the current state.
    func column(for date: Date) -> Int {
        guard isStaircase else { return weekdayColumn(for: date) }
        guard let first = sortedDays.first?.day else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: date).day ?? 0
    }

    /// The row a day is drawn in: its week.
    func row(for date: Date) -> Int {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        return weeks.firstIndex(of: start) ?? 0
    }

    /// The accessibility elements laid out as the tiles are drawn: one array per row, one entry per
    /// column, `nil` where no tile is drawn.
    var elementRows: [[CalendarHeatMapElement?]] {
        let weeks = weeks
        let columnCount = columnCount
        var rows = [[CalendarHeatMapElement?]](
            repeating: [CalendarHeatMapElement?](repeating: nil, count: columnCount), count: weeks.count
        )
        for day in sortedDays {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: day.day)?.start,
                  let row = weeks.firstIndex(of: start) else { continue }
            let column = column(for: day.day)
            if rows.indices.contains(row), rows[row].indices.contains(column) {
                rows[row][column] = element(for: day)
            }
        }
        return rows
    }

    // MARK: Words

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: calendar.timeZone)
    }

    /// "Sunday, March 1": the full date, for elements and for the headline of the calendar.
    func fullDateText(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.wide).month(.wide).day())
    }

    /// "March 1": a date without its weekday.
    func monthDayText(_ date: Date) -> String {
        date.formatted(dateStyle.month(.wide).day())
    }

    /// "Sunday": the name of a weekday column.
    func weekdayText(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.wide))
    }

    func isFirstOfMonth(_ date: Date) -> Bool {
        calendar.component(.day, from: date) == 1
    }

    func element(for day: DailySales) -> CalendarHeatMapElement {
        CalendarHeatMapElement(
            label: fullDateText(day.day),
            value: CafeWording.cups(day.cups, locale: locale),
            isHeading: isFirstOfMonth(day.day)
        )
    }

    /// Every element in the order VoiceOver meets them: a week at a time, earliest first.
    var elements: [CalendarHeatMapElement] {
        sortedDays.map(element(for:))
    }

    /// The first few elements as VoiceOver reads them.
    var spokenPreview: [String] {
        elements.prefix(Self.spokenPreviewCount).map(\.spokenText)
    }

    /// What the written-out elements leave unsaid: how many there are and where they lie.
    var spokenFootnote: String {
        guard !days.isEmpty else { return "There are no elements: the chart has no days." }
        let count = "\(Self.elementsText(days.count, locale: locale)) in all, one for each day, in date order."
        let headings = "The first day of each month is a heading."
        let place = isStaircase
            ? "Each lies over its tile, so each week's seven sit further along than the week before."
            : "Each lies over its tile, in its weekday's column."
        return "\(count) \(headings) \(place)"
    }

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// Every day that sold the most, in date order. Empty when nothing sold.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return sortedDays.filter { $0.cups == most }
    }

    /// Every day that sold the fewest, in date order.
    var quietestDays: [DailySales] {
        guard let fewest = days.map(\.cups).min() else { return [] }
        return sortedDays.filter { $0.cups == fewest }
    }

    /// The dates of some days as the current chart lets a reader find them: with the weekday while
    /// weekdays are columns, by date alone in the staircase. A long list is counted instead.
    func datesText(_ days: [DailySales]) -> String {
        guard days.count <= Self.longestListOfDays else { return CafeWording.days(days.count, locale: locale) }
        // The dates are written in the view's locale; the list that joins them is English, like the sentence.
        return CafeWording.list(days.map { isStaircase ? monthDayText($0.day) : fullDateText($0.day) })
    }

    /// "March 1 to May 9": the period the chart covers.
    var periodText: String {
        guard let first = sortedDays.first?.day, let last = sortedDays.last?.day else { return "" }
        return "\(monthDayText(first)) to \(monthDayText(last))"
    }

    var caption: String {
        days.isEmpty ? "Cups sold each day" : "Cups sold each day, \(periodText)"
    }

    /// The chart's message. True with no days, with only zeros, on a tie, and in the staircase.
    var headline: String {
        guard !days.isEmpty else { return "No days recorded." }
        guard let most = busiestDays.first?.cups else { return "No cups were sold on any of these days." }
        let figure = "The most sold in a day was \(CafeWording.cups(most, locale: locale)), on \(datesText(busiestDays))."
        return isStaircase
            ? "\(figure) Drawn at its own date, each week starts further along and no weekday lines up."
            : figure
    }

    /// The concept in two or three sentences, true of the chart as it is drawn now.
    var explanation: String {
        let rows = "A calendar is a RectangleMark with a date on both axes. On y the date is plotted as a whole week, so each week is a row."
        return isStaircase
            ? "\(rows) Here x is each day's own date, so every day has a column to itself and each week starts seven "
            + "columns further along. Plotting the same weekday in one reference week instead gives every weekday one column."
            : "\(rows) On x it is not the day's own date but the same weekday in one reference week, so every weekday "
            + "shares a column. The shading of a tile is the day's cups."
    }

    /// What is said aloud when the mistake is switched on or off: what changed, then the headline.
    var announcement: String {
        let change = isStaircase
            ? "Weekday columns off: each day is drawn at its own date."
            : "Weekday columns on: every weekday shares a column."
        return "\(change) \(headline)"
    }

    /// The Audio Graph's summary: how the chart is laid out now, and the extremes in actual values.
    var audioGraphSummary: String {
        guard !days.isEmpty else { return headline }
        let extent = "\(CafeWording.days(days.count, locale: locale)) in \(CafeWording.weeks(weeks.count, locale: locale)), \(periodText)."
        let layout = isStaircase
            ? "Each row is a week and each day is drawn at its own date, across "
            + "\(columnCount.formatted(.number.locale(locale))) columns, so each week starts further along and no weekday shares a column."
            : "Each row is a week and each column a weekday."
        guard let most = busiestDays.first?.cups, let fewest = quietestDays.first?.cups else {
            return "\(extent) \(layout) No cups were sold on any of these days."
        }
        return "\(extent) \(layout) "
            + "Fewest in a day: \(CafeWording.cups(fewest, locale: locale)), on \(datesText(quietestDays)). "
            + "Most in a day: \(CafeWording.cups(most, locale: locale)), on \(datesText(busiestDays))."
    }

    // MARK: Counts that agree in number

    // Days and weeks come from `CafeWording`. It has no elements, so they are written here in the same form.

    /// "1 element", "70 elements".
    static func elementsText(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) element](inflect: true)", locale: locale).characters)
    }
}

/// The calendar for the Audio Graph, which gets none automatically: one series per week. While
/// weekdays are columns each week runs over the seven weekday names; in the staircase each runs over
/// its own dates, as drawn. Not tied to the main actor: the accessibility system calls its value
/// description when it chooses.
nonisolated struct CalendarHeatMapDescriptor: AXChartDescriptorRepresentable {
    let summary: CalendarHeatMapSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let calendar = summary.calendar
        let sorted = summary.days.sorted { $0.day < $1.day }
        let weeks = summary.weeks

        let categories: [String]
        if summary.isStaircase {
            let first = sorted.first.map { calendar.startOfDay(for: $0.day) }
            categories = (0 ..< summary.columnCount).compactMap { offset in
                first.flatMap { calendar.date(byAdding: .day, value: offset, to: $0) }.map(summary.monthDayText)
            }
        } else {
            categories = (0 ..< CalendarHeatMapSummary.daysPerWeek).compactMap { column in
                weeks.first.flatMap { calendar.date(byAdding: .day, value: column, to: $0) }.map(summary.weekdayText)
            }
        }

        let series = weeks.map { week in
            AXDataSeriesDescriptor(
                name: "Week of \(summary.monthDayText(week))",
                isContinuous: false,
                dataPoints: sorted
                    .filter { calendar.dateInterval(of: .weekOfYear, for: $0.day)?.start == week }
                    .map { day in
                        AXDataPoint(
                            x: summary.isStaircase ? summary.monthDayText(day.day) : summary.weekdayText(day.day),
                            y: Double(day.cups)
                        )
                    }
            )
        }

        return AXChartDescriptor(
            title: summary.caption,
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: summary.xValueName,
                categoryOrder: categories
            ),
            // The colour scale runs from near the lowest value, not from zero, and so does the range.
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle,
                range: Double(summary.days.map(\.cups).min() ?? 0) ... Double(summary.days.map(\.cups).max() ?? 0),
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: series
        )
    }
}
