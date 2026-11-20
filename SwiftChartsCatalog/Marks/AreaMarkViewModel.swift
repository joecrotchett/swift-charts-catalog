import Foundation
import Observation

/// The two forms of `AreaMark` the screen shows.
nonisolated enum AreaMarkForm: String, CaseIterable, Identifiable {
    /// The area under a line: filled from the baseline up to each value.
    case basic
    /// A range area: filled between a low and a high value.
    case range

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .basic: "Basic"
        case .range: "Range"
        }
    }
}

/// The state behind the Area screen: which form of `AreaMark` is drawn, and the words that go with it.
@Observable
final class AreaMarkViewModel {
    var form: AreaMarkForm = .basic
    let months: [MonthlySummary]

    init(months: [MonthlySummary] = CafeData.monthlySummaries) {
        self.months = months
    }

    /// The chart's words for the form now drawn, in the locale given: the screen passes its environment's,
    /// the one the month axis is formatted with.
    func summary(locale: Locale) -> AreaMarkSummary {
        AreaMarkSummary(months: months, form: form, locale: locale)
    }

    var caption: String {
        switch form {
        case .basic: "Cups on an average day at the \(CafeWording.harbour) café, by month"
        case .range: "Cups on the quietest and busiest day at the \(CafeWording.harbour) café, by month"
        }
    }

    var explanation: String {
        switch form {
        case .basic:
            """
            AreaMark with an x and a y fills from the baseline, zero, up to each value, and joins the values \
            into one region. The top edge is the data, the same shape a line would draw, and the fill gives \
            the amount weight.
            """
        case .range:
            """
            AreaMark with a yStart and a yEnd fills only between two values at each x: here each month's \
            quietest and busiest day. Both edges of the band are data, and nothing reaches down to the baseline.
            """
        }
    }

    /// The code that draws the form now on screen.
    var snippets: [SnippetReference] {
        switch form {
        case .basic: [SnippetReference(name: "area-basic", title: "AreaMark(x:y:)")]
        case .range: [SnippetReference(name: "area-range", title: "AreaMark(x:yStart:yEnd:)")]
        }
    }

    /// What to say aloud when the form changes, for people who cannot see the chart redraw.
    func changeAnnouncement(locale: Locale) -> String {
        let headline = summary(locale: locale).headline
        return switch form {
        case .basic: "Chart changed to the area under each month's average day. \(headline)"
        case .range: "Chart changed to the range between each month's quietest and busiest day. \(headline)"
        }
    }
}

/// What the area chart says in words, for one form: its headline, its element labels,
/// and the summary the Audio Graph speaks.
nonisolated struct AreaMarkSummary {
    let months: [MonthlySummary]
    let form: AreaMarkForm
    /// The locale every word and number here is written in. It has no default: the views pass the
    /// environment's, so the words agree with the month axis.
    let locale: Locale

    static let noData = "No sales recorded yet."

    /// Whether the form now drawn has anything to draw. Only zeros is no data.
    var hasData: Bool {
        switch form {
        case .basic: months.contains { $0.averageDay > 0 }
        case .range: months.contains { $0.highestDay > 0 }
        }
    }

    /// Every month whose average day was the highest, in data order. More than one on a tie.
    var peakAverageMonths: [MonthlySummary] {
        guard let highest = months.map(\.averageDay).max(), highest > 0 else { return [] }
        return months.filter { $0.averageDay == highest }
    }

    /// The lowest value drawn on the band's lower edge.
    var lowestDay: Int? {
        months.map(\.lowestDay).min()
    }

    /// The highest value drawn on the band's upper edge.
    var highestDay: Int? {
        months.map(\.highestDay).max()
    }

    /// The largest value the form draws, which sets the top of the value axis.
    var largestValue: Int {
        switch form {
        case .basic: months.map(\.averageDay).max() ?? 0
        case .range: highestDay ?? 0
        }
    }

    /// The cups axis as drawn in this form, from zero to the largest value rounded up to the axis step (253 →
    /// 300, 347 → 400): the chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [largestValue])
    }

    /// The chart's message in a sentence. Its figures are ones the chart draws in this form.
    var headline: String {
        guard hasData else { return Self.noData }
        switch form {
        case .basic:
            guard let cups = peakAverageMonths.first?.averageDay else { return Self.noData }
            let names = peakAverageMonths.map { monthName($0.month) }.formatted(.list(type: .and).locale(locale))
            return "The average day was busiest in \(names): \(cupsText(cups))."
        case .range:
            guard let lowestDay, let highestDay else { return Self.noData }
            return "Across \(monthsText(months.count)), a day sold between \(lowestDay.formatted(.number.locale(locale))) "
                + "and \(cupsText(highestDay))."
        }
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard hasData, let first = months.first, let last = months.last else { return Self.noData }
        let period = "\(monthsText(months.count)), \(monthAndYear(first.month)) to \(monthAndYear(last.month))."
        switch form {
        case .basic:
            guard let peak = peakAverageMonths.first else { return Self.noData }
            let names = peakAverageMonths.map { monthAndYear($0.month) }.formatted(.list(type: .and).locale(locale))
            return "\(period) Average day: first month \(cupsText(first.averageDay)), "
                + "last month \(cupsText(last.averageDay)), highest \(cupsText(peak.averageDay)) in \(names)."
        case .range:
            guard let lowestDay, let highestDay else { return Self.noData }
            let lowMonths = months.filter { $0.lowestDay == lowestDay }.map { monthAndYear($0.month) }
            let highMonths = months.filter { $0.highestDay == highestDay }.map { monthAndYear($0.month) }
            return "\(period) Quietest day: \(cupsText(lowestDay)), in \(lowMonths.formatted(.list(type: .and).locale(locale))). "
                + "Busiest day: \(cupsText(highestDay)), in \(highMonths.formatted(.list(type: .and).locale(locale)))."
        }
    }

    /// What VoiceOver calls one month's element: "March 2026".
    func elementLabel(for month: MonthlySummary) -> String {
        monthAndYear(month.month)
    }

    /// What VoiceOver reads as one month's value, in the form now drawn.
    func elementValue(for month: MonthlySummary) -> String {
        switch form {
        case .basic: "\(cupsText(month.averageDay)) on an average day"
        case .range: "Quietest day \(cupsText(month.lowestDay)), busiest day \(cupsText(month.highestDay))"
        }
    }

    /// A count with its unit, agreeing in number: "1 cup", "219 cups".
    func cupsText(_ cups: Int) -> String {
        CafeWording.cups(cups, locale: locale)
    }

    /// The month's name alone, in the time zone the data was recorded in: "July".
    func monthName(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide))
    }

    /// The month written out with its year: "July 2026".
    func monthAndYear(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).year())
    }

    private func monthsText(_ count: Int) -> String {
        CafeWording.months(count, locale: locale)
    }
}
