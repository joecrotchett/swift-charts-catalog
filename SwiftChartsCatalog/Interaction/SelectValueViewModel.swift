import Foundation
import Observation

/// The state of "Select a value": the raw value the chart's selection reports, and whether it is snapped
/// to the nearest day. Everything said about it is worked out by `SelectValueSummary`.
@Observable
final class SelectValueViewModel {
    let days: [DailySales]
    /// The exact position under the finger, as `chartXSelection(value:)` reports it: a date with a time of day.
    /// `nil` when nothing is selected.
    var rawSelection: Date?
    /// Whether the raw value is snapped to the nearest day before it is drawn and described.
    var isSnapping = true

    init(days: [DailySales] = CafeData.harbourSales) {
        self.days = days
    }

    func summary(locale: Locale) -> SelectValueSummary {
        SelectValueSummary(days: days, locale: locale)
    }

    /// The day the selection is drawn at: the nearest day while snapping, none otherwise.
    var snappedDay: DailySales? {
        guard isSnapping, let rawSelection else { return nil }
        return SelectValueSummary.nearestDay(to: rawSelection, in: days)
    }

    /// The raw value, drawn as it is, when snapping is off.
    var unsnappedSelection: Date? {
        isSnapping ? nil : rawSelection
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline(rawSelection: rawSelection, isSnapping: isSnapping)
    }

    /// The longest headline the screen can write with the current snapping setting, at rest or for any
    /// selection, which the headline keeps room for so the chart does not move when a selection appears
    /// or clears.
    func reservedHeadline(locale: Locale) -> String? {
        summary(locale: locale).longestHeadline(isSnapping: isSnapping)
    }

    /// The code the See Code sheet shows for the current setting.
    var snippets: [SnippetReference] {
        if isSnapping {
            [
                SnippetReference(name: "select-a-value-binding", title: "Bind the selection"),
                SnippetReference(name: "select-a-value-snap", title: "Snap the raw value to the nearest day"),
                SnippetReference(name: "select-a-value-snapped-rule", title: "A rule and a popover at the day"),
            ]
        } else {
            [
                SnippetReference(name: "select-a-value-binding", title: "Bind the selection"),
                SnippetReference(name: "select-a-value-raw-rule", title: "A rule at the raw value"),
            ]
        }
    }
}

/// What the chart says in words, for any selection: the headline, the popover's lines, the elements'
/// text and the Audio Graph summary. Dates are written in the data's time zone (UTC), so the words name
/// the day that is drawn on any device.
nonisolated struct SelectValueSummary {
    let days: [DailySales]
    /// The locale every number and date is written in. The view passes its environment's.
    let locale: Locale

    /// The words this screen needs that `CafeWording` does not have.
    static let selectedValueLabel = "Selected"
    /// The chart's caption, worded as Select a range words the same data.
    static let caption = "Cups sold each day, \(CafeWording.harbour) café"
    static let calendar = CafeData.calendar

    // snippet:select-a-value-snap
    /// The binding reports the exact position under the finger, which is rarely a data point.
    /// Snap it to the day whose point is nearest: each point sits at the middle of its day,
    /// because the line is plotted with `unit: .day`. Before the first point or after the last,
    /// that is the first or the last day.
    static func nearestDay(to raw: Date, in days: [DailySales]) -> DailySales? {
        days.min { distance(from: raw, to: $0) < distance(from: raw, to: $1) }
    }

    private static func distance(from raw: Date, to day: DailySales) -> TimeInterval {
        let middle = calendar.dateInterval(of: .day, for: day.day).map { $0.start + $0.duration / 2 } ?? day.day
        return abs(raw.timeIntervalSince(middle))
    }

    // end

    // MARK: Words for dates

    /// Every date is written in the data's calendar and its time zone, UTC.
    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: Self.calendar, timeZone: Self.calendar.timeZone)
    }

    /// "Wednesday, March 4".
    func dayText(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.wide).month(.wide).day())
    }

    /// "March 4", for the summary's span.
    func shortDayText(_ date: Date) -> String {
        date.formatted(dateStyle.month(.wide).day())
    }

    /// "March 4, 7:14 AM UTC": a raw selection, with its time of day. The time is the data's, UTC, which
    /// is not the device's time zone, so the words say so.
    func rawText(_ date: Date) -> String {
        "\(date.formatted(dateStyle.month(.wide).day().hour().minute())) UTC"
    }

    /// "7:14 AM UTC": the time of a raw selection alone.
    func rawTimeText(_ date: Date) -> String {
        "\(date.formatted(dateStyle.hour().minute())) UTC"
    }

    func cups(_ count: Int) -> String {
        CafeWording.cups(count, locale: locale)
    }

    // MARK: The headline

    /// Every day that sold the most, in data order. Empty when no day sold anything.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }
    }

    /// The headline at rest, or for the selection: always a day and a figure that are on the chart as drawn.
    func headline(rawSelection: Date?, isSnapping: Bool) -> String {
        guard !days.isEmpty else { return "No days of sales yet." }
        if let rawSelection {
            if isSnapping, let day = Self.nearestDay(to: rawSelection, in: days) {
                return "\(dayText(day.day)): \(cups(day.cups))."
            }
            return "\(rawText(rawSelection)) is between data points: no day's cups are at that exact time."
        }
        guard let most = busiestDays.first?.cups else {
            return "No cups sold in \(CafeWording.days(days.count, locale: locale))."
        }
        let names = CafeWording.list(busiestDays.map { dayText($0.day) })
        return busiestDays.count == 1
            ? "The busiest day was \(names): \(cups(most))."
            : "The busiest days were \(names): \(cups(most)) each."
    }

    /// The longest headline the screen can write: the one at rest, or a selection's, of every day while
    /// snapping or of a raw value on every day (at a time with the widest hour and minute) while not.
    /// Measured in characters, which follows the width closely enough for the headline to keep its
    /// height. `nil` with no days.
    func longestHeadline(isSnapping: Bool) -> String? {
        guard !days.isEmpty else { return nil }
        // Noon snaps to its own day; 22:58 has the widest hour and minute.
        let time = isSnapping ? DateComponents(hour: 12) : DateComponents(hour: 22, minute: 58)
        let selections = days.compactMap { day -> String? in
            guard let raw = Self.calendar.date(byAdding: time, to: day.day) else { return nil }
            return headline(rawSelection: raw, isSnapping: isSnapping)
        }
        return ([headline(rawSelection: nil, isSnapping: isSnapping)] + selections).max { $0.count < $1.count }
    }

    // MARK: The popover

    /// The popover's three lines for a snapped selection: the day, its cups, and the raw value it came from.
    func snappedPopover(day: DailySales, rawSelection: Date) -> SelectValuePopoverText {
        SelectValuePopoverText(
            title: dayText(day.day), value: cups(day.cups), footnote: "Snapped from \(rawText(rawSelection))",
            compactValue: cups(day.cups)
        )
    }

    /// The popover's lines for a raw selection: the position itself, and that no data point is there.
    func rawPopover(rawSelection: Date) -> SelectValuePopoverText {
        SelectValuePopoverText(
            title: "Raw value", value: rawText(rawSelection), footnote: "Not a data point",
            compactValue: rawTimeText(rawSelection)
        )
    }

    // MARK: The Audio Graph

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let first = days.first, let last = days.last,
              let lowest = days.map(\.cups).min(), let highest = days.map(\.cups).max()
        else { return "No days of sales yet." }
        return "\(CafeWording.days(days.count, locale: locale)), \(shortDayText(first.day)) to \(shortDayText(last.day)). "
            + "First day \(cups(first.cups)), last day \(cups(last.cups)). "
            + "Lowest \(cups(lowest)), highest \(cups(highest))."
    }
}

/// The lines of the selection popover, as plain strings so they can be tested.
nonisolated struct SelectValuePopoverText: Equatable {
    let title: String
    let value: String
    let footnote: String
    /// The one line shown at the accessibility text sizes, where three lines no longer fit the chart's width:
    /// the cups of a snapped day, or the time of a raw value. The headline above the chart gives the rest.
    let compactValue: String
}
