import Foundation
import Observation

/// The ways a chart can say which series a mark belongs to.
enum SeriesDeclaration: String, CaseIterable, Identifiable {
    case seriesParameter
    case foregroundStyle
    case symbol
    case lineStyle

    var id: String {
        rawValue
    }

    /// The API, as it is written in code.
    var title: String {
        switch self {
        case .seriesParameter: "series:"
        case .foregroundStyle: "foregroundStyle(by:)"
        case .symbol: "symbol(by:)"
        case .lineStyle: "lineStyle(by:)"
        }
    }

    /// The code region that draws the chart this way.
    var snippet: SnippetReference {
        switch self {
        case .seriesParameter: SnippetReference(name: "series-parameter", title: "The series: parameter")
        case .foregroundStyle: SnippetReference(name: "series-foreground-style", title: "foregroundStyle(by:)")
        case .symbol: SnippetReference(name: "series-symbol", title: "symbol(by:)")
        case .lineStyle: SnippetReference(name: "series-line-style", title: "lineStyle(by:)")
        }
    }

    /// What this way of declaring the series does, and what it leaves alone.
    var explanation: String {
        switch self {
        case .seriesParameter:
            """
            A series is a set of marks that belong together, such as one line. The series: parameter on LineMark \
            says which line each point belongs to and nothing more. The colours here are fixed by hand, one per \
            café, so there is no scale to explain and no legend.
            """
        case .foregroundStyle:
            """
            A series is a set of marks that belong together, such as one line. foregroundStyle(by:) encodes the \
            café as colour: marks that share a value form one line, each value takes a colour from the scale, \
            and a legend appears to explain that scale.
            """
        case .symbol:
            """
            A series is a set of marks that belong together, such as one line. symbol(by:) encodes the café as a \
            point shape: it separates the lines, puts a marker at every point, and the legend shows each café's \
            shape. The colour is left alone, so both lines are the same blue.
            """
        case .lineStyle:
            """
            A series is a set of marks that belong together, such as one line. lineStyle(by:) encodes the café as \
            a dash pattern: the lines are separate, the first solid and the second dashed, and the legend shows \
            a sample of each. The colour is left alone.
            """
        }
    }

    /// What changed on the chart, for people who cannot see it change.
    var announcement: String {
        switch self {
        case .seriesParameter: "One line per café, coloured by hand, with no legend."
        case .foregroundStyle: "One line per café, a colour each, with a legend."
        case .symbol: "One line per café, a point shape each, with a legend."
        case .lineStyle: "One line per café, a dash pattern each, with a legend."
        }
    }
}

/// The state behind the Series screen: how the series is declared, and whether it is left out.
@Observable
final class SeriesViewModel {
    static let mistakeSnippet = SnippetReference(name: "series-mistake", title: "The mistake: no series")

    static let mistakeExplanation = """
    This is the mistake. With no series: parameter and no by: encoding, every LineMark in the chart joins into \
    one line. It runs through the first café's days, then a stray diagonal doubles back from that café's last \
    day to the next café's first.
    """

    static let mistakeAnnouncement = "The series is removed: both cafés are joined into one line."

    let stores: [StoreSales]
    var declaration: SeriesDeclaration = .seriesParameter
    var isShowingMistake = false

    init(stores: [StoreSales] = CafeData.storeSales) {
        self.stores = stores
    }

    /// The chart's words. The headline is about the data and is the same in every state.
    var summary: SeriesSummary {
        SeriesSummary(stores: stores)
    }

    /// The code behind the chart as it is drawn now.
    var snippets: [SnippetReference] {
        [isShowingMistake ? Self.mistakeSnippet : declaration.snippet]
    }

    var explanation: String {
        isShowingMistake ? Self.mistakeExplanation : declaration.explanation
    }

    var announcement: String {
        isShowingMistake ? Self.mistakeAnnouncement : declaration.announcement
    }
}

/// A week of one café's line: what one accessibility element of the chart covers.
nonisolated struct SeriesPortion: Identifiable, Hashable {
    let store: String
    let days: [DailySales]
    /// The café and the dates covered, written out.
    let label: String
    /// Where the stretch starts and ends and its extremes, in cups.
    let value: String

    var id: String {
        "\(store)-\(days.first?.day.timeIntervalSinceReferenceDate ?? 0)"
    }
}

/// What the chart says in words: its headline, the Audio Graph's summary, and each element's label.
nonisolated struct SeriesSummary {
    static let daysPerPortion = 7

    let stores: [StoreSales]
    /// True in the mistake state: no series is declared, so every café's days are drawn as one line.
    var isJoined = false
    var calendar = CafeData.calendar
    var locale = Locale.current

    /// The cafés that have at least one day.
    var storesWithDays: [StoreSales] {
        stores.filter { !$0.days.isEmpty }
    }

    /// False when there are no days, or nothing was sold on any of them.
    var hasData: Bool {
        stores.contains { store in store.days.contains { $0.cups != 0 } }
    }

    /// The chart's message in a sentence, in actual values. True when nothing was sold.
    var headline: String {
        guard hasData else { return "No cups sold in this period." }
        let parts = storesWithDays.enumerated().map { index, store in
            let first = store.days.first?.cups ?? 0
            let last = store.days.last?.cups ?? 0
            return index == 0
                ? "\(store.store) went from \(first.formatted(numberFormat)) to \(Self.cupsText(last, locale: locale)) a day"
                : "\(store.store) from \(first.formatted(numberFormat)) to \(last.formatted(numberFormat))"
        }
        return parts.formatted(.list(type: .and).locale(locale)) + "."
    }

    /// Actual values only, with no judgement of them. When the cafés are joined into one line,
    /// it says so and describes that line, not the series the chart does not have.
    var audioGraphSummary: String {
        guard hasData else { return "No cups sold in this period." }
        if isJoined {
            let cups = joinedDays.map(\.cups)
            let order = storesWithDays.map { "\($0.store)'s days" }.joined(separator: ", then ")
            return "\(period). The cafés are not separate series: every day is joined into one line, \(order). "
                + "First point \(Self.cupsText(cups.first ?? 0, locale: locale)), "
                + "last point \(Self.cupsText(cups.last ?? 0, locale: locale)), "
                + "lowest \(Self.cupsText(cups.min() ?? 0, locale: locale)), "
                + "highest \(Self.cupsText(cups.max() ?? 0, locale: locale))."
        }
        let perStore = storesWithDays.map { store in
            let cups = store.days.map(\.cups)
            return "\(store.store): first day \(Self.cupsText(cups.first ?? 0, locale: locale)), "
                + "last day \(Self.cupsText(cups.last ?? 0, locale: locale)), "
                + "lowest \(Self.cupsText(cups.min() ?? 0, locale: locale)), "
                + "highest \(Self.cupsText(cups.max() ?? 0, locale: locale))."
        }
        return (["\(period)."] + perStore).joined(separator: " ")
    }

    /// The title of the chart, for the Audio Graph.
    var title: String {
        isJoined ? "Cups sold per day, every café joined into one line" : "Cups sold per day at each café"
    }

    /// The name of the one series the chart draws when no series is declared.
    static let joinedSeriesName = "All cafés, joined"

    /// Every café's days end to end, in the order the joined line runs through them.
    var joinedDays: [DailySales] {
        storesWithDays.flatMap(\.days)
    }

    /// Every day any café has, in order, written out.
    var dayNames: [String] {
        allDays.map(dayName)
    }

    var allDays: [Date] {
        Set(stores.flatMap { $0.days.map(\.day) }).sorted()
    }

    /// The cups axis as drawn, off zero: the lowest and highest daily count across the cafés, rounded out to the
    /// axis step (152 to 282 → 150 to 300). The chart's scale and the descriptor's range.
    var cupsRange: ClosedRange<Double> {
        ChartAxis.valueDomain(for: stores.flatMap { $0.days.map(\.cups) }, includesZero: false)
    }

    /// A café's days in stretches of a week, each with its label and value. When the cafés are joined,
    /// each stretch is named as part of the one line, not as part of a café's own.
    func portions(of store: StoreSales) -> [SeriesPortion] {
        stride(from: 0, to: store.days.count, by: Self.daysPerPortion).map { start in
            let days = Array(store.days[start ..< min(start + Self.daysPerPortion, store.days.count)])
            let cups = days.map(\.cups)
            let dates = [days.first?.day, days.last?.day].compactMap(\.self).map(dayName)
            let span = dates.first == dates.last ? (dates.first ?? "") : dates.joined(separator: " to ")
            return SeriesPortion(
                store: store.store,
                days: days,
                label: isJoined ? "Joined line, \(store.store)'s days, \(span)" : "\(store.store), \(span)",
                value: "Starts at \(Self.cupsText(cups.first ?? 0, locale: locale)), "
                    + "ends at \(Self.cupsText(cups.last ?? 0, locale: locale)), "
                    + "lowest \(Self.cupsText(cups.min() ?? 0, locale: locale)), "
                    + "highest \(Self.cupsText(cups.max() ?? 0, locale: locale))"
            )
        }
    }

    /// A day written out with no ambiguity: "March 1".
    func dayName(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// A count with its unit, agreeing in number: "1 cup", "164 cups".
    static func cupsText(_ cups: Int, locale: Locale = .current) -> String {
        resolved("^[\(cups) cup](inflect: true)", locale: locale)
    }

    /// The Audio Graph takes plain strings, not Text, so the agreement in number is resolved here.
    private static func resolved(_ value: String.LocalizationValue, locale: Locale) -> String {
        String(AttributedString(localized: value, locale: locale).characters)
    }

    private var numberFormat: IntegerFormatStyle<Int> {
        .number.locale(locale)
    }

    /// How many cafés and days, and the dates covered.
    private var period: String {
        let days = allDays
        let cafes = Self.resolved("^[\(storesWithDays.count) café](inflect: true)", locale: locale)
        let count = Self.resolved("^[\(days.count) day](inflect: true)", locale: locale)
        guard let first = days.first, let last = days.last, first != last else {
            return "\(cafes), \(count)\(days.first.map { ", \(dayName($0))" } ?? "")"
        }
        return "\(cafes), \(count), \(dayName(first)) to \(dayName(last))"
    }
}
