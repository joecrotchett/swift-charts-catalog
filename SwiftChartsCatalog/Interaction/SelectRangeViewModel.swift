import Accessibility
import Foundation
import Observation
import SwiftUI

/// How the screen selects a range: the framework's own modifier, or a drag gesture written by hand.
nonisolated enum SelectRangeTechnique: String, CaseIterable, Identifiable {
    case builtIn = "Built in"
    case byHand = "By hand"

    var id: Self {
        self
    }
}

/// A range of whole days, snapped from a raw selection, with the days of data inside it.
nonisolated struct SelectRangeSelection: Equatable {
    /// The first and last selected days, at midnight in the data's calendar.
    let firstDay: Date
    let lastDay: Date
    /// The days of data that fall inside the range. Empty when the range holds no data.
    let days: [DailySales]

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }
}

/// The state and the words of "Select a range": which technique is in use, the raw range the
/// gesture reported, the whole days it snaps to, and every sentence the screen says about them.
@Observable
final class SelectRangeViewModel {
    let days: [DailySales]
    /// The calendar the days were counted in (UTC). Snapping, drawing and writing dates all use it.
    let calendar: Calendar

    /// The technique in use. Changing it clears the selection, which belonged to the other technique.
    var technique: SelectRangeTechnique = .builtIn {
        didSet {
            guard oldValue != technique else { return }
            techniqueChangeClearedSelection = rawRange != nil
            rawRange = nil
        }
    }

    /// Whether the last change of technique cleared a selection, which changed the headline.
    private(set) var techniqueChangeClearedSelection = false

    /// The range exactly as the gesture reported it: positions on the axis, not days of data.
    private(set) var rawRange: ClosedRange<Date>?

    init(days: [DailySales] = CafeData.harbourSales, calendar: Calendar = CafeData.calendar) {
        self.days = days
        self.calendar = calendar
    }

    var hasData: Bool {
        !days.isEmpty
    }

    // MARK: Input from the two techniques

    /// What `chartXSelection(range:)` reports. Ignored while the screen selects by hand.
    func builtInRangeChanged(_ range: ClosedRange<Date>?) {
        guard technique == .builtIn else { return }
        rawRange = range
    }

    /// The two dates a drag covers, already converted through the chart proxy: where it started and
    /// where the finger is now, in either order. Ignored while the screen uses the built-in selection.
    func dragChanged(from start: Date, to current: Date) {
        guard technique == .byHand else { return }
        rawRange = min(start, current) ... max(start, current)
    }

    /// Whether the Clear range button can act: a range drawn by hand stays after the finger lifts,
    /// unlike the built-in one, so it needs a way to be cleared.
    var canClearRange: Bool {
        technique == .byHand && rawRange != nil
    }

    /// Clears a range drawn by hand.
    func clearSelection() {
        rawRange = nil
    }

    // MARK: Snapping

    // snippet:select-a-range-snapping
    /// The raw range is a pair of axis positions with a time of day. Snap each end to the nearest day
    /// (the line's points sit at midnight) and keep it inside the data, then collect the days it holds.
    var selection: SelectRangeSelection? {
        guard let rawRange else { return nil }
        var first = nearestDay(to: rawRange.lowerBound)
        var last = nearestDay(to: rawRange.upperBound)
        if let dataStart = days.first?.day, let dataEnd = days.last?.day,
           first <= dataEnd, last >= dataStart
        {
            first = max(first, dataStart)
            last = min(last, dataEnd)
        }
        let inside = days.filter { (first ... last).contains($0.day) }
        return SelectRangeSelection(firstDay: first, lastDay: last, days: inside)
    }

    private func nearestDay(to date: Date) -> Date {
        calendar.startOfDay(for: date.addingTimeInterval(12 * 60 * 60))
    }

    // end

    /// Where the by-hand band starts and ends: half a day either side of the selected points, so a
    /// single day is a visible band, kept inside the data so the band never widens the axis.
    var band: ClosedRange<Date>? {
        guard let selection else { return nil }
        let halfDay: TimeInterval = 12 * 60 * 60
        var start = selection.firstDay.addingTimeInterval(-halfDay)
        var end = selection.lastDay.addingTimeInterval(halfDay)
        if let dataStart = days.first?.day, let dataEnd = days.last?.day {
            start = min(max(start, dataStart), dataEnd)
            end = max(min(end, dataEnd), dataStart)
        }
        return start ... end
    }

    // MARK: Words

    private func shortDate(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day())
    }

    private func longDate(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// The selected days as the label above the chart writes them: "Mar 3 – Mar 9", or "Mar 3" for one day.
    /// `compact` writes the interval the locale's shortest way ("Mar 3 – 9"), for the accessibility text
    /// sizes, where the full form is wider than a phone's chart.
    func rangeText(locale: Locale, compact: Bool = false) -> String? {
        guard let selection else { return nil }
        let first = shortDate(selection.firstDay, locale: locale)
        guard selection.firstDay != selection.lastDay else { return first }
        if compact {
            let style = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                .month(.abbreviated).day()
            return (selection.firstDay ..< selection.lastDay).formatted(style)
        }
        return "\(first) – \(shortDate(selection.lastDay, locale: locale))"
    }

    /// The second line of the label: the selection's total, or that it holds no sales.
    func totalText(locale: Locale) -> String? {
        guard let selection else { return nil }
        return selection.days.isEmpty ? "No sales" : CafeWording.cups(selection.total, locale: locale)
    }

    /// The chart's message for its current state, with no abbreviations, since VoiceOver reads it.
    func headline(locale: Locale) -> String {
        headline(for: selection, locale: locale)
    }

    private func headline(for selection: SelectRangeSelection?, locale: Locale) -> String {
        guard let first = days.first, let last = days.last else { return "No sales to show." }
        if let selection {
            let from = longDate(selection.firstDay, locale: locale)
            let to = longDate(selection.lastDay, locale: locale)
            let single = selection.firstDay == selection.lastDay
            guard !selection.days.isEmpty else {
                return single ? "No sales recorded on \(from)." : "No sales recorded from \(from) to \(to)."
            }
            let cups = CafeWording.cups(selection.total, locale: locale)
            guard !single else { return "\(from): \(cups)." }
            return "\(from) to \(to): \(cups) in \(CafeWording.days(selection.days.count, locale: locale))."
        }
        let lowest = days.map(\.cups).min() ?? 0
        let highest = days.map(\.cups).max() ?? 0
        let amount = lowest == highest
            ? CafeWording.cups(highest, locale: locale)
            : "\(lowest.formatted(.number.locale(locale))) to \(CafeWording.cups(highest, locale: locale))"
        let period = first.day == last.day
            ? "on \(longDate(first.day, locale: locale))"
            : "a day, \(longDate(first.day, locale: locale)) to \(longDate(last.day, locale: locale))"
        return "\(CafeWording.harbour) sold \(amount) \(period)."
    }

    /// What is said when the picker changes the technique and so clears a selection: that the range was
    /// cleared, then the headline. `nil` when nothing was cleared: the picker speaks its own value, and
    /// nothing drawn changed.
    func techniqueAnnouncement(locale: Locale) -> String? {
        guard techniqueChangeClearedSelection else { return nil }
        return "Range cleared. \(headline(locale: locale))"
    }

    /// The longest headline the screen can write: the one at rest, or a selection's, of every range of
    /// whole days inside the data, which is every range either technique can select. The headline keeps
    /// room for it, so the chart does not move when a selection appears or clears. Measured in characters,
    /// which follows the width closely enough for the headline to keep its height. Worked out once per
    /// locale. `nil` with no days.
    func reservedHeadline(locale: Locale) -> String? {
        guard hasData else { return nil }
        if let cached = reservedHeadlines[locale] { return cached }
        var longest = headline(for: nil, locale: locale)
        for start in days.indices {
            var inside: [DailySales] = []
            for end in days.indices[start...] {
                inside.append(days[end])
                let candidate = headline(
                    for: SelectRangeSelection(firstDay: days[start].day, lastDay: days[end].day, days: inside),
                    locale: locale
                )
                if candidate.count > longest.count { longest = candidate }
            }
        }
        reservedHeadlines[locale] = longest
        return longest
    }

    @ObservationIgnored private var reservedHeadlines: [Locale: String] = [:]

    /// A day's element label, with the date written out in the data's time zone: "Tuesday, March 3".
    func elementLabel(for day: DailySales, locale: Locale) -> String {
        day.day.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                .weekday(.wide).month(.wide).day()
        )
    }

    /// The snippets See Code shows for the technique in use.
    var snippets: [SnippetReference] {
        switch technique {
        case .builtIn:
            [
                SnippetReference(name: "select-a-range-built-in-modifier", title: "chartXSelection(range:)"),
                SnippetReference(name: "select-a-range-built-in-marks", title: "Two rules, one annotation"),
                SnippetReference(name: "select-a-range-snapping", title: "Snapping to whole days"),
            ]
        case .byHand:
            [
                SnippetReference(name: "select-a-range-by-hand-gesture", title: "A drag in chartOverlay"),
                SnippetReference(name: "select-a-range-hold-then-drag", title: "Hold, then drag"),
                SnippetReference(name: "select-a-range-by-hand-mark", title: "A RectangleMark"),
                SnippetReference(name: "select-a-range-snapping", title: "Snapping to whole days"),
            ]
        }
    }

    /// Every snippet the screen can show, for its registration.
    static let allSnippets: [SnippetReference] = [
        SnippetReference(name: "select-a-range-built-in-modifier", title: "chartXSelection(range:)"),
        SnippetReference(name: "select-a-range-built-in-marks", title: "Two rules, one annotation"),
        SnippetReference(name: "select-a-range-by-hand-gesture", title: "A drag in chartOverlay"),
        SnippetReference(name: "select-a-range-hold-then-drag", title: "Hold, then drag"),
        SnippetReference(name: "select-a-range-by-hand-mark", title: "A RectangleMark"),
        SnippetReference(name: "select-a-range-snapping", title: "Snapping to whole days"),
    ]
}

/// The chart for the Audio Graph: one continuous series of daily cups, dates written out, and a summary
/// that gives each week's total, so a listener gets range totals without making a gesture.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct SelectRangeChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let calendar: Calendar
    let locale: Locale

    private func longDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    var summary: String {
        guard let first = days.first, let last = days.last else { return "No sales to show." }
        let cups = days.map(\.cups)
        let weeks = stride(from: 0, to: days.count, by: 7).map { start in
            let week = days[start ..< min(start + 7, days.count)]
            let span = week.count == 1
                ? longDate(week[week.startIndex].day)
                : "\(longDate(week[week.startIndex].day)) to \(longDate(week[week.endIndex - 1].day))"
            return "\(span), \(CafeWording.cups(week.map(\.cups).reduce(0, +), locale: locale))"
        }
        return "\(CafeWording.days(days.count, locale: locale)), \(longDate(first.day)) to \(longDate(last.day)). "
            + "Lowest \(CafeWording.cups(cups.min() ?? 0, locale: locale)), "
            + "highest \(CafeWording.cups(cups.max() ?? 0, locale: locale)), "
            + "\(CafeWording.cups(cups.reduce(0, +), locale: locale)) in total. "
            + "By week: \(weeks.joined(separator: "; "))."
    }

    /// The value axis as drawn and as given here: 0 to the most cups, rounded up to a tidy step.
    static func valueDomain(for days: [DailySales]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { longDate($0.day) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: Self.valueDomain(for: days),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: days.map { AXDataPoint(x: longDate($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold a day at the \(CafeWording.harbour) café",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
