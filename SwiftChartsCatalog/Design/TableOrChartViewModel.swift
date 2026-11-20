import Foundation
import Observation

/// How the screen shows the four weeks: as a list of values or as a chart with a point.
enum TableOrChartForm: String, CaseIterable, Identifiable {
    case list
    case chart

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .list: "List"
        case .chart: "Chart"
        }
    }
}

/// The order of the list's rows.
enum TableOrChartSort: CaseIterable {
    /// Date order, first day first.
    case byDay
    /// Most cups first; days with the same cups stay in date order.
    case byCups

    /// What a change to this order is announced as.
    var spokenName: String {
        switch self {
        case .byDay: "Sorted by day"
        case .byCups: "Sorted by cups, most first"
        }
    }

    /// The direction the rows run in this order, as the heading's accessibility value says it.
    var direction: String {
        switch self {
        case .byDay: "Earliest first"
        case .byCups: "Most first"
        }
    }

    /// The heading's chevron: up for earliest first, down for most first.
    var symbolName: String {
        switch self {
        case .byDay: "chevron.up"
        case .byCups: "chevron.down"
        }
    }
}

/// One row of the list: a day and its cups, as shown and as spoken.
nonisolated struct TableOrChartRow: Identifiable, Hashable {
    let id: Date
    /// "Sun, Mar 1".
    let dayText: String
    /// "Sunday, March 1".
    let spokenDay: String
    /// "190".
    let cupsText: String
    /// "190 cups".
    let spokenCups: String
}

/// The screen's state: which form is showing and how the list is sorted, with every sentence the screen
/// writes about the data. Each takes the locale the view reads from its environment.
@Observable
final class TableOrChartViewModel {
    let days: [DailySales]
    private(set) var form: TableOrChartForm = .list
    private(set) var sort: TableOrChartSort = .byDay

    init(days: [DailySales] = CafeData.harbourSales) {
        self.days = days
    }

    var summary: TableOrChartSummary {
        TableOrChartSummary(days: days)
    }

    /// Whether there is anything to show in either form. With no days, both forms are placeholders and the
    /// controls change nothing, so they are disabled.
    var hasDays: Bool {
        !days.isEmpty
    }

    /// The caption names the month, so the chart's axis can show day numbers alone at the largest text sizes. For
    /// the café's recorded four weeks it is the shared caption: "Cups sold each day at the Harbour café, March 1 – 28,
    /// 2026", which the invented month's caption is told apart from.
    func caption(locale: Locale) -> String {
        let place = "Cups each day at the \(CafeWording.harbour) café"
        if days == CafeData.harbourSales { return CafeWording.harbourDaysCaption(locale: locale) }
        guard let first = days.map(\.day).min(), let last = days.map(\.day).max() else { return place }
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        let firstMonth = first.formatted(style.month(.wide).year())
        let lastMonth = last.formatted(style.month(.wide).year())
        return firstMonth == lastMonth ? "\(place), \(firstMonth)" : "\(place), \(firstMonth) to \(lastMonth)"
    }

    // MARK: Changes

    /// Shows the other form, and returns what to announce: what changed, then the headline.
    func show(_ newForm: TableOrChartForm, locale: Locale) -> String? {
        guard newForm != form, hasDays else { return nil }
        form = newForm
        let change = switch newForm {
        case .list: "Showing the list, \(sort.spokenName.lowercased())."
        case .chart: "Showing the chart."
        }
        return "\(change) \(headline(locale: locale))"
    }

    /// Sorts the list, and returns what to announce: what changed, then the headline.
    func sortRows(_ newSort: TableOrChartSort, locale: Locale) -> String? {
        guard newSort != sort, hasDays else { return nil }
        sort = newSort
        return "\(newSort.spokenName). \(headline(locale: locale))"
    }

    // MARK: The list

    // snippet:table-or-chart-sort
    /// The days in the list's order. Sorting is the list's job: people looking for a value
    /// put the one they want at the top instead of reading it off a bar.
    var sortedDays: [DailySales] {
        switch sort {
        case .byDay:
            days.sorted { $0.day < $1.day }
        case .byCups:
            // Most first; a tie keeps date order, so the order never shuffles.
            days.sorted { $0.cups != $1.cups ? $0.cups > $1.cups : $0.day < $1.day }
        }
    }

    // end

    func rows(locale: Locale) -> [TableOrChartRow] {
        sortedDays.map { day in
            TableOrChartRow(
                id: day.day,
                dayText: TableOrChartSummary.dayText(day.day, locale: locale),
                spokenDay: TableOrChartSummary.spokenDay(day.day, locale: locale),
                cupsText: day.cups.formatted(.number.locale(locale)),
                spokenCups: CafeWording.cups(day.cups, locale: locale)
            )
        }
    }

    /// Shown over the list at the accessibility sizes, where the panel holds only a few rows:
    /// "28 days: scroll inside the list to see them all."
    func scrollNote(locale: Locale) -> String {
        "\(CafeWording.days(days.count, locale: locale)): scroll inside the list to see them all."
    }

    // MARK: Words

    /// The headline for what is showing now.
    func headline(locale: Locale) -> String {
        headline(form: form, sort: sort, locale: locale)
    }

    func headline(form: TableOrChartForm, sort: TableOrChartSort, locale: Locale) -> String {
        switch form {
        case .chart: summary.chartHeadline(locale: locale)
        case .list: summary.listHeadline(sort: sort, locale: locale)
        }
    }

    /// The code for the form that is showing.
    var snippets: [SnippetReference] {
        switch form {
        case .list:
            [
                SnippetReference(name: "table-or-chart-list", title: "A list to scan and sort"),
                SnippetReference(name: "table-or-chart-sort", title: "Sorting the rows"),
            ]
        case .chart:
            [SnippetReference(name: "table-or-chart-chart", title: "A chart with a point")]
        }
    }
}

/// What the four weeks say in words: the headlines, the average and the Audio Graph's summary.
nonisolated struct TableOrChartSummary {
    let days: [DailySales]

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// Nothing to draw: no days, or only zeros, which would draw axes with no bars.
    var hasNoCups: Bool {
        total == 0
    }

    /// The mean of the days, where the dashed rule is drawn.
    var average: Double {
        days.isEmpty ? 0 : Double(total) / Double(days.count)
    }

    /// The average to the nearest whole cup, as the rule's label and the headline write it.
    var roundedAverage: Int {
        Int(average.rounded())
    }

    /// The value axis, rounded up to the next 50 cups (at least 50). The drawn scale and the descriptor share it.
    var cupsAxis: ClosedRange<Double> {
        0 ... max(50, (Double(days.map(\.cups).max() ?? 0) / 50).rounded(.up) * 50)
    }

    /// Each full seven days' total, in date order. A short last week is left out, so it is not compared.
    var weeklyTotals: [Int] {
        let ordered = days.sorted { $0.day < $1.day }
        return stride(from: 0, to: ordered.count - 6, by: 7).map { start in
            ordered[start ..< start + 7].map(\.cups).reduce(0, +)
        }
    }

    /// The days with the most cups, in date order. Empty when nothing sold.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }.sorted { $0.day < $1.day }
    }

    /// The days with the fewest cups, in date order.
    var quietestDays: [DailySales] {
        guard let fewest = days.map(\.cups).min(), !hasNoCups else { return [] }
        return days.filter { $0.cups == fewest }.sorted { $0.day < $1.day }
    }

    /// "Sales rose every week, averaging 205 cups a day." The figure is the one on the dashed rule.
    func chartHeadline(locale: Locale) -> String {
        if days.isEmpty { return "No days recorded." }
        if hasNoCups { return "No cups sold on any of the \(CafeWording.days(days.count, locale: locale))." }
        let average = "\(CafeWording.cups(roundedAverage, locale: locale)) a day"
        let weeks = weeklyTotals
        guard weeks.count > 1 else { return "An average of \(average)." }
        let pairs = zip(weeks, weeks.dropFirst())
        if pairs.allSatisfy({ $0 < $1 }) { return "Sales rose every week, averaging \(average)." }
        if pairs.allSatisfy({ $0 > $1 }) { return "Sales fell every week, averaging \(average)." }
        return "An average of \(average)."
    }

    /// The list's headline names what its top rows show, in the order they are sorted.
    func listHeadline(sort: TableOrChartSort, locale: Locale) -> String {
        guard let first = days.map(\.day).min(), let last = days.map(\.day).max() else { return "No days recorded." }
        switch sort {
        case .byDay:
            let span = "\(Self.shortDay(first, locale: locale)) to \(Self.shortDay(last, locale: locale))"
            return "\(CafeWording.days(days.count, locale: locale)), \(span), in date order: look up any day."
        case .byCups:
            guard let cups = busiestDays.first?.cups else {
                return "No cups sold on any of the \(CafeWording.days(days.count, locale: locale))."
            }
            let names = CafeWording.list(busiestDays.map { Self.dayText($0.day, locale: locale) })
            let each = busiestDays.count > 1 ? " each" : ""
            return "Busiest first: \(names), with \(CafeWording.cups(cups, locale: locale))\(each)."
        }
    }

    /// Actual values only, with the average rule stated, since a rule is not a series.
    func audioGraphSummary(locale: Locale) -> String {
        guard let first = days.map(\.day).min(), let last = days.map(\.day).max() else { return "No days recorded." }
        let span = "\(CafeWording.days(days.count, locale: locale)), \(Self.longDay(first, locale: locale)) to \(Self.longDay(last, locale: locale))."
        guard let most = busiestDays.first?.cups, let fewest = quietestDays.first?.cups else {
            return "\(span) No cups sold."
        }
        return "\(span) Daily average \(CafeWording.cups(roundedAverage, locale: locale)), drawn as a dashed line. "
            + "Most: \(spokenList(busiestDays, locale: locale)), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(spokenList(quietestDays, locale: locale)), \(CafeWording.cups(fewest, locale: locale))."
    }

    private func spokenList(_ days: [DailySales], locale: Locale) -> String {
        CafeWording.list(days.map { Self.spokenDay($0.day, locale: locale) })
    }

    // MARK: Dates, written in the calendar the sample data was made in

    // The days are midnight UTC. Each format is given the data's time zone, so a device west of
    // Greenwich does not write the day before.

    private static func style(locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
    }

    /// "Sun, Mar 1", for a row.
    static func dayText(_ date: Date, locale: Locale) -> String {
        date.formatted(style(locale: locale).weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "Sunday, March 1", for what is spoken.
    static func spokenDay(_ date: Date, locale: Locale) -> String {
        date.formatted(style(locale: locale).weekday(.wide).month(.wide).day())
    }

    /// "Mar 1", for a span in a headline.
    static func shortDay(_ date: Date, locale: Locale) -> String {
        date.formatted(style(locale: locale).month(.abbreviated).day())
    }

    /// "March 1", for a span that is spoken.
    static func longDay(_ date: Date, locale: Locale) -> String {
        date.formatted(style(locale: locale).month(.wide).day())
    }
}
