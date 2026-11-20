import Foundation
import Observation

/// The three marks the screen can draw the same days with.
nonisolated enum MarkMeaningMark: String, CaseIterable, Identifiable {
    case bars
    case line
    case points

    var id: Self {
        self
    }

    /// The picker's title for the mark.
    var title: String {
        switch self {
        case .bars: "Bars"
        case .line: "Line"
        case .points: "Points"
        }
    }

    /// The mark as it is said inside a sentence: "Showing a line."
    var spokenName: String {
        switch self {
        case .bars: "bars"
        case .line: "a line"
        case .points: "points"
        }
    }
}

/// The state of "Marks: what each communicates": which mark draws the days, whether the line carries its
/// points, and every sentence the screen writes about what is drawn.
@Observable
final class MarkMeaningViewModel {
    /// The snippet names, one per state of the controls.
    static let barsSnippet = "marks-what-each-communicates-bars"
    static let lineSnippet = "marks-what-each-communicates-line"
    static let linePointsSnippet = "marks-what-each-communicates-line-points"
    static let pointsSnippet = "marks-what-each-communicates-points"

    /// Every snippet the screen can show, for registering it.
    static let allSnippets: [SnippetReference] = [
        SnippetReference(name: barsSnippet, title: "Bars: amounts to compare"),
        SnippetReference(name: lineSnippet, title: "A line: change over time"),
        SnippetReference(name: linePointsSnippet, title: "Points on the line, with symbol"),
        SnippetReference(name: pointsSnippet, title: "Points: single readings"),
    ]

    let days: [DailySales]
    var mark: MarkMeaningMark
    /// The combine toggle. It is kept when another mark is picked, and acts only on the line.
    var pointsOnLine: Bool

    init(days: [DailySales] = CafeData.thirtyDays, mark: MarkMeaningMark = .bars, pointsOnLine: Bool = false) {
        self.days = days
        self.mark = mark
        self.pointsOnLine = pointsOnLine
    }

    /// Whether the line is drawn with a symbol at each day.
    var showsPointsOnLine: Bool {
        mark == .line && pointsOnLine
    }

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// No days draws nothing; days of only zeros draw no bars, as bars grow from zero. A line and points at
    /// zero are still drawn, so they are a chart, not an empty state.
    var showsPlaceholder: Bool {
        days.isEmpty || (mark == .bars && total == 0)
    }

    /// Why the placeholder shows: no days at all, or days with no cups to draw as bars.
    var placeholderTitle: String {
        days.isEmpty ? "No days recorded" : "No cups sold"
    }

    var placeholderDescription: String {
        days.isEmpty
            ? "Each day's cups appear here, one mark per day."
            : "Bars grow from zero, so days of no cups draw none. A line or points show them."
    }

    /// With no days at all, no control changes what is drawn. With only zeros the mark picker stays on,
    /// since a line or points draw those zeros.
    var isMarkPickerDisabled: Bool {
        days.isEmpty
    }

    /// The combine toggle acts only on a drawn line.
    var isCombineToggleDisabled: Bool {
        mark != .line || showsPlaceholder
    }

    /// The value axis, from zero for every mark so that only the mark changes, rounded up to the next
    /// 50 cups (at least 50). The chart and the Audio Graph share it.
    var cupsAxis: ClosedRange<Double> {
        0 ... max(50, (Double(days.map(\.cups).max() ?? 0) / 50).rounded(.up) * 50)
    }

    /// The snippet for the current setting of the controls.
    var snippets: [SnippetReference] {
        let name = switch mark {
        case .bars: Self.barsSnippet
        case .line: showsPointsOnLine ? Self.linePointsSnippet : Self.lineSnippet
        case .points: Self.pointsSnippet
        }
        return Self.allSnippets.filter { $0.name == name }
    }

    /// The caption names the month, so the axis can show day numbers alone at the largest text sizes. For the
    /// shared invented month it is the shared caption, which says the days are invented ("Invented sample: cups a
    /// day at the Harbour café, March 2026"), so they are not taken for the café's recorded March.
    func caption(locale: Locale) -> String {
        let place = "Cups sold each day at the \(CafeWording.harbour) café"
        if days == CafeData.thirtyDays { return CafeWording.inventedDaysCaption(locale: locale) }
        guard let first = days.first?.day, let last = days.last?.day else { return place }
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month(.wide).year()
        let firstMonth = first.formatted(style)
        let lastMonth = last.formatted(style)
        return firstMonth == lastMonth ? "\(place), \(firstMonth)" : "\(place), \(firstMonth) to \(lastMonth)"
    }

    func headline(locale: Locale) -> String {
        MarkMeaningSummary(days: days, locale: locale).headline(mark: mark, pointsOnLine: showsPointsOnLine)
    }

    /// The longest headline any setting writes, so the chart does not move when the setting changes.
    func longestHeadline(locale: Locale) -> String {
        let summary = MarkMeaningSummary(days: days, locale: locale)
        let headlines = MarkMeaningMark.allCases.map { summary.headline(mark: $0, pointsOnLine: false) }
            + [summary.headline(mark: .line, pointsOnLine: true)]
        return headlines.max { $0.count < $1.count } ?? ""
    }

    /// What this mark makes easy to see, as sentences the reader can check against the chart.
    var explanation: String {
        let opening = "The same days, drawn three ways. Choose the mark for what the reader should see. "
        let detail = switch mark {
        case .bars:
            """
            Bars make amounts easy to compare: every bar rises from zero, so their lengths compare honestly, and \
            each weekend's Saturday and Sunday stand taller than the weekdays beside them. No bar is joined to the next.
            """
        case .line where showsPointsOnLine:
            """
            Points on the line show the change and each day's reading together. They are the line's own symbols, \
            so the chart still has one mark per day and no second layer of the same data.
            """
        case .line:
            """
            A line makes change easy to see: the eye follows one shape from the first day to the last, a climb \
            across the month with a rise each weekend. It hides the single day: no reading stands out on its own.
            """
        case .points:
            """
            Points make single readings easy to pick out: each day is a dot joined to nothing, so one reading, \
            like the highest day labelled with its cups, can be found and read on its own. The climb is still \
            there, but the reader has to see it in the dots.
            """
        }
        return opening + detail
    }

    /// Said when the mark picker changes the chart: what changed, then the headline.
    func markChangeAnnouncement(locale: Locale) -> String {
        "Showing \(mark.spokenName). \(headline(locale: locale))"
    }

    /// Said when the combine toggle changes the chart: what changed, then the headline.
    func pointsChangeAnnouncement(locale: Locale) -> String {
        let change = showsPointsOnLine ? "Points added to the line." : "Points taken off the line."
        return "\(change) \(headline(locale: locale))"
    }

    func descriptor(locale: Locale) -> MarkMeaningChartDescriptor {
        MarkMeaningChartDescriptor(days: days, mark: mark, cupsAxis: cupsAxis, locale: locale)
    }
}

/// What the days say in words, for any mark. Not tied to the main actor, so the chart descriptor can use it.
nonisolated struct MarkMeaningSummary {
    let days: [DailySales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// "29 March" or "March 29", in the UTC calendar the days were made in.
    func dayText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .day().month(.wide))
    }

    /// "Sunday, 1 March": an element's label, context first.
    func elementLabel(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .weekday(.wide).day().month(.wide))
    }

    func elementValue(_ cups: Int) -> String {
        CafeWording.cups(cups, locale: locale)
    }

    /// Every day with the given number of cups, written as a list: "3 March", "1 and 8 March".
    private func dayList(with cups: Int) -> String {
        CafeWording.list(days.filter { $0.cups == cups }.map { dayText($0.day) })
    }

    var highest: Int? {
        days.map(\.cups).max()
    }

    var lowest: Int? {
        days.map(\.cups).min()
    }

    /// Whether every day has the same cups: then no one day stands out to be named or labelled.
    var isFlat: Bool {
        highest == lowest
    }

    /// The days whose cups are written on the chart, above their bar or point: the highest days, which the
    /// bars' and points' headlines name. None for a line, none when nothing was sold, and none when every day
    /// is the same, since then no day stands out.
    func labelledDays(mark: MarkMeaningMark) -> [DailySales] {
        guard mark != .line, let highest, highest > 0, !isFlat else { return [] }
        return days.filter { $0.cups == highest }
    }

    /// The figure written above a labelled day: "230".
    func labelText(_ cups: Int) -> String {
        cups.formatted(.number.locale(locale))
    }

    /// Every figure here can be found in the chart as drawn: a date on the axis or at the line's ends, a
    /// highest day's cups in the label above it, and 0 on the zero line. Values the axis cannot resolve
    /// (174 against grid lines at 0, 100 and 200) are left out.
    func headline(mark: MarkMeaningMark, pointsOnLine: Bool) -> String {
        guard let first = days.first, let last = days.last, let highest else {
            return "No days recorded yet."
        }
        switch mark {
        case .bars:
            guard highest > 0 else { return "No cups sold on any of these days." }
            if isFlat { return "Every bar is the same length." }
            let longest = days.count(where: { $0.cups == highest }) > 1 ? "Longest bars" : "Longest bar"
            return "\(longest): \(dayList(with: highest)), \(CafeWording.cups(highest, locale: locale))."
        case .line:
            let shape: String
            if days.count == 1 {
                shape = "The line is one day, \(dayText(first.day)): a single point, with no change to show."
            } else if first.cups == last.cups {
                let level = first.cups == 0 ? "at 0 cups" : "at the same height"
                shape = "The line starts and ends \(level), on \(dayText(first.day)) and \(dayText(last.day))."
            } else {
                let direction = last.cups > first.cups ? "rises" : "falls"
                shape = "The line \(direction) from its first day, \(dayText(first.day)), to its last, \(dayText(last.day))."
            }
            guard pointsOnLine else { return shape }
            return "\(shape) Its points mark all \(CafeWording.days(days.count, locale: locale))."
        case .points:
            if isFlat {
                return highest == 0 ? "Every point sits at 0 cups." : "Every point sits at the same height."
            }
            return "Each point is one day. Highest: \(dayList(with: highest)), \(CafeWording.cups(highest, locale: locale))."
        }
    }

    /// Actual values only, with no judgement of them, the same for every mark.
    var audioGraphSummary: String {
        guard let first = days.first, let last = days.last, let highest, let lowest else {
            return "No days recorded yet."
        }
        return "\(CafeWording.days(days.count, locale: locale)). "
            + "First day \(CafeWording.cups(first.cups, locale: locale)), last day \(CafeWording.cups(last.cups, locale: locale)). "
            + "Highest \(CafeWording.cups(highest, locale: locale)) on \(dayList(with: highest)), "
            + "lowest \(CafeWording.cups(lowest, locale: locale)) on \(dayList(with: lowest))."
    }
}
