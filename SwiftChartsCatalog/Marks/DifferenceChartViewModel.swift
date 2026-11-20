import Foundation
import Observation

/// The state of the "Difference chart" screen: whether the gap between the two lines is filled.
@Observable
final class DifferenceChartViewModel {
    /// Lines with the filled difference when on; the two lines alone when off.
    var showsFills = true

    let comparison: DifferenceChartComparison

    init(comparison: DifferenceChartComparison = DifferenceChartComparison(stores: CafeData.storeSales)) {
        self.comparison = comparison
    }

    let caption = "Cups sold a day at two cafés"

    /// True of the chart as it is drawn under the current setting.
    var explanation: String {
        if showsFills {
            """
            A difference chart shows two series as the gap between them. Each café has its own AreaMark that runs \
            from the lower of the two values up to its own value, so it has height only where that café leads and \
            the gap takes the leader's colour. A point is added to the data wherever the lines cross, so each fill \
            ends exactly on the crossing.
            """
        } else {
            """
            These are the two lines alone. Who leads, and by how much, has to be read by following which line is \
            on top between each pair of crossings. Switch the fills on to draw the gap itself: one area layer per \
            café, each with height only where that café leads.
            """
        }
    }

    /// The code behind the chart as it is currently drawn.
    var snippets: [SnippetReference] {
        if showsFills {
            [
                SnippetReference(name: "difference-chart-fills", title: "One area layer per café"),
                SnippetReference(name: "difference-chart-crossings", title: "A point where the lines cross"),
                SnippetReference(name: "difference-chart-lines", title: "The two lines"),
            ]
        } else {
            [SnippetReference(name: "difference-chart-lines", title: "The two lines")]
        }
    }

    func headline(locale: Locale) -> String {
        comparison.headline(locale: locale)
    }

    /// What is said aloud when the toggle redraws the chart: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        let change = showsFills
            ? "Now showing the two lines with the difference between them filled."
            : "Now showing the two lines alone."
        return "\(change) \(headline(locale: locale))"
    }
}

/// One day both cafés have a figure for.
nonisolated struct DifferenceChartDay: Identifiable, Hashable {
    let day: Date
    let first: Int
    let second: Int

    var id: Date {
        day
    }

    /// Positive when the first café sold more, negative when the second did.
    var gap: Int {
        first - second
    }
}

/// A position along the x axis with both cafés' values: a day, or the instant between two days where the lines cross.
nonisolated struct DifferenceChartPoint: Identifiable, Hashable {
    let day: Date
    let first: Double
    let second: Double

    var id: Date {
        day
    }

    /// The base of both fills: the lower of the two values.
    var lower: Double {
        min(first, second)
    }
}

/// One stretch of the chart, a week at most, read out as one accessibility element.
nonisolated struct DifferenceChartPortion: Identifiable, Hashable {
    let days: [DifferenceChartDay]
    /// The same days as one series per café, for the lines.
    let series: [StoreSales]

    var id: Date? {
        days.first?.day
    }
}

/// Two cafés' daily cups compared: who led, by how much, and where the lead changed.
nonisolated struct DifferenceChartComparison {
    let firstName: String
    let secondName: String
    /// The days both cafés have, in the first café's order.
    let days: [DifferenceChartDay]
    /// The calendar the days were recorded in. The axis and every written date use its time zone.
    let calendar: Calendar

    /// Compares the first two cafés in `stores` on the days they share.
    init(stores: [StoreSales], calendar: Calendar = CafeData.calendar) {
        self.calendar = calendar
        guard stores.count >= 2 else {
            firstName = stores.first?.store ?? CafeWording.harbour
            secondName = CafeWording.station
            days = []
            return
        }
        firstName = stores[0].store
        secondName = stores[1].store
        // Both layers of a difference chart need both values at every x, so only shared days are kept.
        let secondCups = Dictionary(stores[1].days.map { ($0.day, $0.cups) }) { first, _ in first }
        days = stores[0].days.compactMap { sale in
            secondCups[sale.day].map { DifferenceChartDay(day: sale.day, first: sale.cups, second: $0) }
        }
    }

    // MARK: What the chart draws

    /// The two cafés in data order: the domain of the colour scale and of the dash scale.
    var storeNames: [String] {
        [firstName, secondName]
    }

    /// The days as one series per café.
    var series: [StoreSales] {
        Self.series(of: days, firstName: firstName, secondName: secondName)
    }

    // snippet:difference-chart-crossings
    /// The days, plus a point at each place the two lines cross between one day and the next.
    /// Without it each fill would run on to the following day and spill past the crossing.
    var fillPoints: [DifferenceChartPoint] {
        var points: [DifferenceChartPoint] = []
        for (index, day) in days.enumerated() {
            if index > 0 {
                let previous = days[index - 1]
                // The lead changed hands between these two days: the gap has opposite signs.
                if previous.gap * day.gap < 0 {
                    // How far along the way from `previous` to `day` the gap reaches zero.
                    let fraction = Double(previous.gap) / Double(previous.gap - day.gap)
                    let cups = Double(previous.first) + fraction * Double(day.first - previous.first)
                    let instant = previous.day.addingTimeInterval(fraction * day.day.timeIntervalSince(previous.day))
                    points.append(DifferenceChartPoint(day: instant, first: cups, second: cups))
                }
            }
            points.append(DifferenceChartPoint(day: day.day, first: Double(day.first), second: Double(day.second)))
        }
        return points
    }

    // end

    /// The chart in stretches of a week, each one accessibility element.
    var portions: [DifferenceChartPortion] {
        stride(from: 0, to: days.count, by: Self.daysPerPortion).map { start in
            let slice = Array(days[start ..< min(start + Self.daysPerPortion, days.count)])
            return DifferenceChartPortion(
                days: slice, series: Self.series(of: slice, firstName: firstName, secondName: secondName)
            )
        }
    }

    static let daysPerPortion = 7

    private static func series(of days: [DifferenceChartDay], firstName: String, secondName: String) -> [StoreSales] {
        [
            StoreSales(store: firstName, days: days.map { DailySales(day: $0.day, cups: $0.first) }),
            StoreSales(store: secondName, days: days.map { DailySales(day: $0.day, cups: $0.second) }),
        ]
    }

    // MARK: What the chart says

    /// Nothing to draw: no shared days, or no cups at either café.
    var hasNoSales: Bool {
        days.allSatisfy { $0.first == 0 && $0.second == 0 }
    }

    /// How many times the lead passed from one café to the other. A level day in between is not a change.
    var leadChanges: Int {
        let leaders = days.map(\.gap).filter { $0 != 0 }.map { $0 > 0 }
        return zip(leaders, leaders.dropFirst()).count { $0 != $1 }
    }

    /// The first day with the widest gap, or nil when the cafés were level on every day.
    var widestGapDay: DifferenceChartDay? {
        Self.widestGapDay(in: days)
    }

    /// The cups axis as drawn, off zero: the lowest and highest values rounded out to the axis step (152 to 282 →
    /// 150 to 300). The chart's scale and the Audio Graph's value axis.
    var valueRange: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.flatMap { [$0.first, $0.second] }, includesZero: false)
    }

    /// The chart's message, with figures a reader can find in it whether or not the gap is filled:
    /// the crossings, and the widest gap.
    func headline(locale: Locale) -> String {
        guard !hasNoSales else { return "No cups sold yet at either café." }
        guard let widest = widestGapDay else {
            return "\(firstName) and \(secondName) sold the same number of cups every day."
        }
        let changes = leadChanges == 0
            ? "The lead never changed."
            : "The lead changed \(Self.times(leadChanges, locale: locale))."
        return "\(changes) \(widestGapSentence(widest, opening: "The widest gap was", locale: locale))"
    }

    /// Actual values only, for the Audio Graph.
    func audioGraphSummary(locale: Locale) -> String {
        guard !hasNoSales else { return "No cups sold yet at either café." }
        var sentences = ["\(CafeWording.days(days.count, locale: locale))."]
        sentences.append(Self.leadSentence(for: days, firstName: firstName, secondName: secondName, locale: locale))
        if let widest = widestGapDay {
            sentences.append("The lead changed \(Self.times(leadChanges, locale: locale)).")
            sentences.append(widestGapSentence(widest, opening: "Widest gap", locale: locale))
        }
        return sentences.joined(separator: " ")
    }

    /// A portion's label: the dates it covers, written out.
    func label(for portion: DifferenceChartPortion, locale: Locale) -> String {
        guard let first = portion.days.first, let last = portion.days.last else { return "" }
        if first.day == last.day { return dayText(first.day, locale: locale) }
        return "\(dayText(first.day, locale: locale)) to \(dayText(last.day, locale: locale))"
    }

    /// A portion's value: who was ahead on how many days, and the widest gap in it.
    func value(for portion: DifferenceChartPortion, locale: Locale) -> String {
        let lead = Self.leadSentence(for: portion.days, firstName: firstName, secondName: secondName, locale: locale)
        guard let widest = Self.widestGapDay(in: portion.days) else { return lead }
        return "\(lead) \(widestGapSentence(widest, opening: "Widest gap", locale: locale))"
    }

    /// "The widest gap was 89 cups, on March 28, with Harbour ahead."
    private func widestGapSentence(_ day: DifferenceChartDay, opening: String, locale: Locale) -> String {
        let leader = day.gap > 0 ? firstName : secondName
        return "\(opening) \(CafeWording.cups(abs(day.gap), locale: locale)), "
            + "on \(dayText(day.day, locale: locale)), with \(leader) ahead."
    }

    private static func widestGapDay(in days: [DifferenceChartDay]) -> DifferenceChartDay? {
        var widest: DifferenceChartDay?
        for day in days where day.gap != 0 && abs(day.gap) > abs(widest?.gap ?? 0) {
            widest = day
        }
        return widest
    }

    /// "Harbour ahead on 2 days, Station ahead on 5 days." Level days are counted too when there are any.
    private static func leadSentence(
        for days: [DifferenceChartDay], firstName: String, secondName: String, locale: Locale
    ) -> String {
        var parts = [
            "\(firstName) ahead on \(CafeWording.days(days.count { $0.gap > 0 }, locale: locale))",
            "\(secondName) ahead on \(CafeWording.days(days.count { $0.gap < 0 }, locale: locale))",
        ]
        let level = days.count { $0.gap == 0 }
        if level > 0 {
            parts.append("level on \(CafeWording.days(level, locale: locale))")
        }
        return parts.joined(separator: ", ") + "."
    }

    // MARK: Words

    /// A day written out, in the calendar the data was recorded in: "March 28".
    func dayText(_ day: Date, locale: Locale) -> String {
        day.formatted(Date.FormatStyle(locale: locale, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// "1 time", "6 times".
    static func times(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) time](inflect: true)", locale: locale).characters)
    }
}
