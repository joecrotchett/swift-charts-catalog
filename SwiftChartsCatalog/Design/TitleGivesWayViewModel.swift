import Foundation
import Observation

/// One day of the chart: its date and each café's cups that day, in the data's café order.
nonisolated struct TitleGivesWayDay: Identifiable, Hashable {
    let date: Date
    let cups: [TitleGivesWayCups]

    var id: Date {
        date
    }
}

/// One café's cups on one day.
nonisolated struct TitleGivesWayCups: Hashable {
    let store: String
    let cups: Int
}

/// What the selection label says for one day: the day written out, then each café's cups.
nonisolated struct TitleGivesWaySelectionText: Identifiable, Hashable {
    let date: Date
    /// "Wednesday, March 4".
    let dayText: String
    /// "Wed, Mar 4", for the accessibility text sizes.
    let shortDayText: String
    /// "Harbour 179 cups, Station 98 cups".
    let valuesText: String

    var id: Date {
        date
    }
}

/// What sits above the plot: the chart's title (with the legend beside it), or the selection label in its place.
nonisolated enum TitleGivesWayHeaderText: Equatable {
    case title(String)
    case selection(TitleGivesWaySelectionText)
}

/// Every sentence the screen writes or speaks about the data, worked out from the data and a locale alone,
/// so the chart descriptor (which is not tied to the main actor) and the view model say the same thing.
nonisolated struct TitleGivesWaySummary {
    let stores: [StoreSales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale
    /// The calendar the sample dates were made in (UTC), so a day is written as the day that is drawn.
    let calendar = CafeData.calendar

    /// Every date any café has a record for, in order, with the cafés' cups that day.
    var days: [TitleGivesWayDay] {
        Self.days(of: stores)
    }

    /// The cafés' names, in data order: the domain of the colour and symbol scales.
    var storeNames: [String] {
        stores.map(\.store)
    }

    /// The days that carry an x label: the first day, then every `count` days after it, so the labels fall on
    /// the same days whatever the plot's padding.
    func labelledDays(every count: Int) -> [Date] {
        let dates = days.map(\.date)
        return stride(from: 0, to: dates.count, by: max(count, 1)).map { dates[$0] }
    }

    /// The days of `stores`, worked out without a locale: the selection snaps to them.
    static func days(of stores: [StoreSales]) -> [TitleGivesWayDay] {
        let dates = Set(stores.flatMap { $0.days.map(\.day) }).sorted()
        return dates.map { date in
            TitleGivesWayDay(date: date, cups: stores.compactMap { store in
                store.days.first { $0.day == date }.map { TitleGivesWayCups(store: store.store, cups: $0.cups) }
            })
        }
    }

    /// "Wednesday, March 4": the selection label's first line and each day's accessibility label.
    func dayText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).month(.wide).day())
    }

    /// "March 4": a day as the Audio Graph's category.
    func shortDayText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.wide).day())
    }

    /// "Harbour 179 cups, Station 98 cups": context first, then the value with its unit, agreeing in number.
    func valuesText(_ day: TitleGivesWayDay) -> String {
        day.cups.map { "\($0.store) \(CafeWording.cups($0.cups, locale: locale))" }.joined(separator: ", ")
    }

    /// "Wed, Mar 4".
    func abbreviatedDayText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).month(.abbreviated).day())
    }

    func selectionText(_ day: TitleGivesWayDay) -> TitleGivesWaySelectionText {
        TitleGivesWaySelectionText(
            date: day.date, dayText: dayText(day.date), shortDayText: abbreviatedDayText(day.date),
            valuesText: valuesText(day)
        )
    }

    /// The chart's own title, above the plot: "Cups a day, Mar 1 – 28, 2026".
    var title: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "Cups a day" }
        let range = (first ..< last).formatted(
            Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month().day().year()
        )
        return "Cups a day, \(range)"
    }

    /// The days on which the first café sold more than the second, of the days both have a record for.
    private var comparedDays: (ahead: Int, compared: Int)? {
        guard stores.count == 2 else { return nil }
        let pairs = days.filter { $0.cups.count == 2 }
        return (pairs.count(where: { $0.cups[0].cups > $0.cups[1].cups }), pairs.count)
    }

    /// The screen's headline: a count a reader can make by looking at where one line is above the other.
    var headline: String {
        guard let compared = comparedDays, compared.compared > 0 else {
            return days.isEmpty ? "No sales recorded yet." : "\(CafeWording.days(days.count, locale: locale)) of sales."
        }
        let (ahead, count) = compared
        let first = stores[0].store, second = stores[1].store
        let total = CafeWording.days(count, locale: locale)
        if ahead == 0 {
            return "\(first) never sold more cups than \(second) in these \(total)."
        }
        if ahead == count {
            return "\(first) sold more cups than \(second) on every one of these \(total)."
        }
        return "\(first) sold more cups than \(second) on \(ahead.formatted(.number.locale(locale))) of \(total)."
    }

    /// The Audio Graph's summary: actual values only, no judgement of them.
    var audioGraphSummary: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "No sales recorded yet." }
        let ranges = stores.compactMap { store -> String? in
            let cups = store.days.map(\.cups)
            guard let low = cups.min(), let high = cups.max() else { return nil }
            return "\(store.store) from \(CafeWording.cups(low, locale: locale)) to \(CafeWording.cups(high, locale: locale))"
        }
        return "\(CafeWording.days(days.count, locale: locale)), \(shortDayText(first)) to \(shortDayText(last)). "
            + ranges.joined(separator: "; ") + ". " + headline
    }

    /// The value axis, drawn and described alike: from the lowest value rounded down to a step of 50 to the
    /// highest rounded up. Lines far from zero do not start at zero (`design.md`, *Axes*).
    var cupsAxis: ClosedRange<Double> {
        let cups = stores.flatMap { $0.days.map { Double($0.cups) } }
        let step = TitleGivesWaySummary.axisStep
        let low = ((cups.min() ?? 0) / step).rounded(.down) * step
        let high = max(((cups.max() ?? 0) / step).rounded(.up) * step, low + step)
        return low ... high
    }

    /// Every step of the value axis, bottom to top: where the grid lines are drawn.
    var cupsAxisSteps: [Double] {
        Array(stride(from: cupsAxis.lowerBound, through: cupsAxis.upperBound, by: Self.axisStep))
    }

    /// The two ends of the value axis: its only labels at the accessibility text sizes.
    var cupsAxisEnds: [Double] {
        [cupsAxis.lowerBound, cupsAxis.upperBound]
    }

    static let axisStep = 50.0
}

/// The state of "Title gives way to selection": the data and the position the finger is on, as plain values.
@Observable
final class TitleGivesWayViewModel {
    let stores: [StoreSales]
    /// The exact position on the date axis under the finger, as `chartXSelection` reports it. `nil` when nothing is
    /// selected. Tests set it directly.
    var rawSelection: Date?

    init(stores: [StoreSales] = CafeData.storeSales, rawSelection: Date? = nil) {
        self.stores = stores
        self.rawSelection = rawSelection
    }

    func summary(locale: Locale) -> TitleGivesWaySummary {
        TitleGivesWaySummary(stores: stores, locale: locale)
    }

    var hasData: Bool {
        stores.contains { !$0.days.isEmpty }
    }

    /// Half a day either side of a point: the stretch of axis that selects that day, and the width of each day's
    /// clear accessibility band.
    static let halfDay: TimeInterval = 12 * 60 * 60

    // snippet:title-gives-way-to-selection-snap
    /// The raw position snapped to the nearest day that has data, or `nil` when the finger is off the data.
    var selectedDay: TitleGivesWayDay? {
        guard let rawSelection else { return nil }
        let days = TitleGivesWaySummary.days(of: stores)
        guard let first = days.first?.date, let last = days.last?.date,
              rawSelection >= first.addingTimeInterval(-Self.halfDay),
              rawSelection <= last.addingTimeInterval(Self.halfDay)
        else { return nil }
        return days.min {
            abs($0.date.timeIntervalSince(rawSelection)) < abs($1.date.timeIntervalSince(rawSelection))
        }
    }

    /// The title, or while a day is selected, the selection label that takes its place.
    func header(locale: Locale) -> TitleGivesWayHeaderText {
        let summary = summary(locale: locale)
        guard let selectedDay else { return .title(summary.title) }
        return .selection(summary.selectionText(selectedDay))
    }

    // end

    /// The label for every day the chart can select, laid out unseen so the space above the plot is as tall as
    /// the tallest of them whichever day is selected.
    func allSelectionTexts(locale: Locale) -> [TitleGivesWaySelectionText] {
        let summary = summary(locale: locale)
        return summary.days.map(summary.selectionText)
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline
    }
}
