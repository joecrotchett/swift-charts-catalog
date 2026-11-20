import Foundation
import Observation

/// The state behind "Range bar": the months drawn and the code regions the screen shows.
/// The screen has no controls, so nothing here changes after it is made.
@Observable
final class RangeBarViewModel {
    let months: [MonthlySummary]

    /// The code regions the screen shows, in order.
    let snippets = [
        SnippetReference(name: "range-bar-marks", title: "A floating bar and a tick per month"),
        SnippetReference(name: "range-bar-axis", title: "A label under each month"),
    ]

    init(months: [MonthlySummary] = CafeData.monthlySummaries) {
        self.months = months
    }

    /// The chart's words, written for the locale the chart is drawn in.
    func summary(locale: Locale) -> RangeBarSummary {
        RangeBarSummary(months: months, locale: locale)
    }
}

/// The words this screen needs that `CafeWording` does not have: the names of a month's three values.
nonisolated enum RangeBarWording {
    static let lowestDay = "Lowest day"
    static let highestDay = "Highest day"
    static let averageDay = "Average day"
}

/// What the range bar chart says in words: its headline, what each month's element says, and the
/// summary the Audio Graph speaks. Not tied to the main actor, so the chart descriptor can use it.
nonisolated struct RangeBarSummary {
    let months: [MonthlySummary]
    let locale: Locale

    /// False with no months, and when no month sold a cup: there is nothing to draw a range of.
    var hasData: Bool {
        months.contains { $0.highestDay > 0 }
    }

    /// The cups axis as drawn, from zero to the busiest day rounded up to the axis step (347 → 400): the chart's
    /// scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: months.map(\.highestDay))
    }

    /// The largest gap between a month's lowest and highest day.
    var widestGap: Int {
        months.map(Self.gap).max() ?? 0
    }

    /// Every month with the widest gap, in data order. More than one when there is a tie.
    var widestMonths: [MonthlySummary] {
        let widest = widestGap
        guard hasData, widest > 0 else { return [] }
        return months.filter { Self.gap($0) == widest }
    }

    /// The chart's message in a sentence. Its figures are the ends, or the length, of the longest bar.
    var headline: String {
        guard hasData else { return Self.noData }
        let widest = widestMonths
        guard let first = widest.first else {
            return "No month had a gap between its quietest and busiest day."
        }
        if widest.count == 1 {
            return "\(monthName(first.month)) had the widest gap between its quietest and busiest day: "
                + "\(number(first.lowestDay)) to \(cupsText(first.highestDay))."
        }
        let names = widest.map { monthName($0.month) }.formatted(.list(type: .and).locale(locale))
        return "\(names) had the widest gap between quietest and busiest day: \(cupsText(widestGap))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard hasData, let first = months.first, let last = months.last,
              let lowest = months.map(\.lowestDay).min(), let highest = months.map(\.highestDay).max(),
              let lowestAverage = months.map(\.averageDay).min(), let highestAverage = months.map(\.averageDay).max()
        else { return Self.noData }
        let lowestIn = months.filter { $0.lowestDay == lowest }.map { monthName($0.month, withYear: true) }
        let highestIn = months.filter { $0.highestDay == highest }.map { monthName($0.month, withYear: true) }
        return "\(monthsText(months.count)), \(monthName(first.month, withYear: true)) to \(monthName(last.month, withYear: true)). "
            + "\(RangeBarWording.lowestDay): \(cupsText(lowest)), in \(lowestIn.formatted(.list(type: .and).locale(locale))). "
            + "\(RangeBarWording.highestDay): \(cupsText(highest)), in \(highestIn.formatted(.list(type: .and).locale(locale))). "
            + "\(RangeBarWording.averageDay): between \(number(lowestAverage)) and \(cupsText(highestAverage))."
    }

    /// What one month's accessibility element is called: the month written out, with its year.
    func elementLabel(_ month: MonthlySummary) -> String {
        monthName(month.month, withYear: true)
    }

    /// What one month's accessibility element says: its three values, each named, in cups.
    func elementValue(_ month: MonthlySummary) -> String {
        "\(RangeBarWording.lowestDay) \(cupsText(month.lowestDay)), "
            + "\(RangeBarWording.highestDay.lowercased()) \(cupsText(month.highestDay)), "
            + "\(RangeBarWording.averageDay.lowercased()) \(cupsText(month.averageDay))"
    }

    /// A month's name in the data's own time zone: "July", or "July 2026".
    func monthName(_ date: Date, withYear: Bool = false) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return date.formatted(withYear ? style.month(.wide).year() : style.month(.wide))
    }

    /// A count with its unit, agreeing in number: "1 cup", "301 cups".
    func cupsText(_ count: Int) -> String {
        CafeWording.cups(count, locale: locale)
    }

    /// A count of months, agreeing in number: "1 month", "6 months".
    func monthsText(_ count: Int) -> String {
        CafeWording.months(count, locale: locale)
    }

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    private static let noData = "No cups sold yet."

    private static func gap(_ month: MonthlySummary) -> Int {
        month.highestDay - month.lowestDay
    }
}
