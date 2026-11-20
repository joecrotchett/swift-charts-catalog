import Foundation
import Observation

/// The three lines above a chart: a caption, the figure with its unit, and the period or day it covers.
/// The compact card and the detail screen both show one, so their numbers can be compared.
nonisolated struct OverviewDetailHeadline: Equatable {
    let caption: String
    let figure: String
    let period: String
}

/// Every text the screen speaks, in one table, so a prediction that differs from what is read on a
/// device can be replaced in one place.
nonisolated struct OverviewDetailSpokenText: Equatable {
    /// Where the overview's label, value and trait come from: read from the running app, not predicted.
    static let source = "Read on the iPhone 17 simulator, iOS 27"

    /// The compact card is one element: this label and value, with the button trait.
    let compactLabel: String
    let compactValue: String
    /// The detail chart's Audio Graph.
    let descriptorTitle: String
    let descriptorSummary: String
    /// The detail chart's value axis title in the Audio Graph.
    let descriptorAxisTitle: String
}

/// What the data says, written in a locale: totals, the shared value axis, and every sentence.
/// Not tied to the main actor, so the chart descriptor can use it.
nonisolated struct OverviewDetailSummary {
    let days: [DailySales]
    /// The calendar the days were made in; dates are written in its time zone.
    let calendar: Calendar
    let locale: Locale

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// No days, or only zeros: bars grow from zero, so either draws nothing and gets a placeholder.
    var hasChart: Bool {
        total > 0
    }

    /// The step between the value axis's grid lines: the smallest of 1, 2 and 5 times a power of ten
    /// that covers the busiest day in at most four steps.
    var axisStep: Int {
        let highest = days.map(\.cups).max() ?? 0
        var power = 1
        while power <= 10_000_000 {
            for multiple in [1, 2, 5] where (highest + multiple * power - 1) / (multiple * power) <= 4 {
                return multiple * power
            }
            power *= 10
        }
        return power
    }

    /// The top of the value axis, shared by both charts and the descriptor: the busiest day rounded up
    /// to the next step, at least one step, so empty data still has an axis.
    var axisTop: Int {
        let highest = days.map(\.cups).max() ?? 0
        let step = axisStep
        return max(step, (highest + step - 1) / step * step)
    }

    /// The value axis's grid lines: every step from zero to the top, or every other step and the top
    /// at the largest text sizes, keeping the baseline.
    func axisValues(thinned: Bool) -> [Int] {
        let step = thinned ? axisStep * 2 : axisStep
        var values = Array(stride(from: 0, through: axisTop, by: step))
        if values.last != axisTop { values.append(axisTop) }
        return values
    }

    /// The days the detail's date axis labels: the first, then every seventh day, or every fourteenth at the
    /// largest text sizes. Only days the data has, so no label falls past the last one.
    func labelledDays(thinned: Bool) -> [Date] {
        let every = thinned ? 14 : 7
        return days.enumerated().filter { $0.offset % every == 0 }.map(\.element.day)
    }

    /// Whether a bar is drawn at full strength: every bar with nothing selected, only the selected one otherwise.
    static func isEmphasised(_ day: Date, selectedDay: Date?) -> Bool {
        guard let selectedDay else { return true }
        return selectedDay == day
    }

    /// Each week's busiest day, a week being seven days counted from the first. Only whole weeks.
    var weeklyPeaks: [DailySales] {
        stride(from: 0, to: days.count - days.count % 7, by: 7).compactMap { start in
            days[start ..< start + 7].max { $0.cups < $1.cups }
        }
    }

    /// The weekday every week peaked on, when each week's peak beat the one before: "Saturday".
    /// Nil with fewer than two whole weeks, or when the peaks fall on different weekdays or do not rise.
    var risingPeakWeekday: String? {
        let peaks = weeklyPeaks
        guard peaks.count >= 2 else { return nil }
        let weekdays = Set(peaks.map { calendar.component(.weekday, from: $0.day) })
        guard weekdays.count == 1, zip(peaks, peaks.dropFirst()).allSatisfy({ $0.cups < $1.cups }),
              let first = peaks.first
        else { return nil }
        return first.day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide))
    }

    // MARK: Words

    var caption: String {
        "Total at \(CafeWording.harbour)"
    }

    var figure: String {
        CafeWording.cups(total, locale: locale)
    }

    /// "Mar 1 – 28, 2026", written in the data's time zone.
    var period: String {
        guard let first = days.first?.day, let last = days.last?.day else { return "No days" }
        guard first < last else { return day(first, wide: false) }
        return (first ..< last).formatted(
            Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month().day().year()
        )
    }

    /// "March 1 to March 28, 2026": the period with nothing abbreviated, for what is spoken.
    var spokenPeriod: String {
        guard let first = days.first?.day, let last = days.last?.day else { return "No days" }
        let monthDay = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day()
        guard first < last else { return day(first, wide: true) }
        return "\(first.formatted(monthDay)) to \(last.formatted(monthDay.year()))"
    }

    /// "Saturday, Mar 28, 2026", or with the month written out for what is spoken.
    func day(_ date: Date, wide: Bool) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).day().year()
        return date.formatted(wide ? style.month(.wide) : style.month(.abbreviated))
    }

    /// "Sunday, March 1": a bar's element label in the detail chart.
    func elementLabel(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// "March 1": a day as the descriptor's category.
    func category(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// The headline both the compact card and the detail screen show at rest.
    var headline: OverviewDetailHeadline {
        OverviewDetailHeadline(caption: caption, figure: figure, period: period)
    }

    /// The detail's headline while one day is selected: that day, in the same three lines.
    func selectedHeadline(_ day: DailySales) -> OverviewDetailHeadline {
        OverviewDetailHeadline(
            caption: "Selected day", figure: CafeWording.cups(day.cups, locale: locale), period: self.day(day.day, wide: false)
        )
    }

    /// The longest selected headline the detail can show, kept behind the headline so the chart does not move.
    var longestSelectedHeadline: OverviewDetailHeadline? {
        days.map { selectedHeadline($0) }.max { "\($0.figure)\($0.period)".count < "\($1.figure)\($1.period)".count }
    }

    var spoken: OverviewDetailSpokenText {
        let summary = if hasChart, let first = days.first, let last = days.last, let best = days.max(by: { $0.cups < $1.cups }) {
            "\(CafeWording.days(days.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
                + "First day \(CafeWording.cups(first.cups, locale: locale)), "
                + "last day \(CafeWording.cups(last.cups, locale: locale)), "
                + "highest \(CafeWording.cups(best.cups, locale: locale)) on \(elementLabel(best.day))."
        } else {
            "No cups sold in these days."
        }
        return OverviewDetailSpokenText(
            compactLabel: "\(caption), \(spokenPeriod)",
            compactValue: figure,
            descriptorTitle: "Daily cups at the \(CafeWording.harbour) café, \(spokenPeriod)",
            descriptorSummary: summary,
            descriptorAxisTitle: CafeWording.cupsAxisTitle
        )
    }

    /// The screen's message: true for empty and all-zero data too.
    var message: String {
        guard hasChart else { return "No cups sold in these days, so there is no chart to open." }
        let total = "\(figure) in \(CafeWording.days(days.count, locale: locale))"
        guard let weekday = risingPeakWeekday else { return "\(total)." }
        return "Each \(weekday) was its week's busiest day and beat the \(weekday) before: \(total)."
    }
}

/// The state of "Overview and detail": whether the detail is open, and which day it has selected.
@Observable
final class OverviewDetailViewModel {
    let days: [DailySales]
    let calendar: Calendar

    /// Whether the detail screen is showing. Tapping the compact card sets it.
    var isShowingDetail = false

    /// The raw position under the finger on the detail chart's day axis, as the chart reports it.
    var rawSelectedDate: Date?

    init(days: [DailySales] = CafeData.harbourSales, calendar: Calendar = CafeData.calendar) {
        self.days = days
        self.calendar = calendar
    }

    func summary(locale: Locale) -> OverviewDetailSummary {
        OverviewDetailSummary(days: days, calendar: calendar, locale: locale)
    }

    var hasChart: Bool {
        days.map(\.cups).reduce(0, +) > 0
    }

    /// Opens the detail, only when there is a chart to open.
    func openDetail() {
        guard hasChart else { return }
        isShowingDetail = true
    }

    /// The selection snapped to the day that holds it, in the data's calendar; `nil` off the data.
    var selectedDay: DailySales? {
        guard let rawSelectedDate else { return nil }
        return days.first { calendar.isDate($0.day, inSameDayAs: rawSelectedDate) }
    }

    /// The compact card's headline.
    func compactHeadline(locale: Locale) -> OverviewDetailHeadline {
        summary(locale: locale).headline
    }

    /// The detail's headline: the same as the compact card's at rest, the selected day while there is one.
    func detailHeadline(locale: Locale) -> OverviewDetailHeadline {
        let summary = summary(locale: locale)
        if let selectedDay { return summary.selectedHeadline(selectedDay) }
        return summary.headline
    }

    /// How strongly a bar is drawn: every bar at rest, only the selected one while a day is selected.
    func isEmphasised(_ day: DailySales) -> Bool {
        OverviewDetailSummary.isEmphasised(day.day, selectedDay: selectedDay?.day)
    }
}
