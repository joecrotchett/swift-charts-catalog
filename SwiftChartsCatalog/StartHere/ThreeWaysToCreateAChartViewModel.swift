import Foundation
import Observation

// snippet:three-ways-to-create-a-chart-row
/// One café's cups on one day. Two cafés make two rows per day, so the collection stays flat
/// and `Chart(data)` can still make one mark per element.
nonisolated struct ThreeWaysStoreDay: Identifiable, Hashable {
    let store: String
    let day: Date
    let cups: Int

    var id: String {
        "\(store)-\(day.timeIntervalSinceReferenceDate)"
    }
}

// end

// snippet:three-ways-to-create-a-chart-reading
/// The same row with no `id`: not Identifiable, so `Chart` has to be told what identifies it.
nonisolated struct ThreeWaysReading: Hashable {
    let store: String
    let day: Date
    let cups: Int
}

// end

/// The dates and counts the screen writes in words, in the sample data's own time zone.
nonisolated enum ThreeWaysFormat {
    private static var base: Date.FormatStyle {
        Date.FormatStyle(calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
    }

    /// "Sun": the label under each day on the axis.
    static var weekday: Date.FormatStyle {
        base.weekday(.abbreviated)
    }

    /// "Sunday, March 1": a date as VoiceOver and the Audio Graph say it.
    static func spokenDay(_ day: Date) -> String {
        day.formatted(base.weekday(.wide).month(.wide).day())
    }

    /// "March 1": a date in the caption.
    static func shortDay(_ day: Date) -> String {
        day.formatted(base.month(.wide).day())
    }

    /// A count with its unit as a plain string that agrees in number: "1 cup", "36 cups".
    static func cupsText(_ cups: Int) -> String {
        String(AttributedString(localized: "^[\(cups) cup](inflect: true)").characters)
    }

    /// "1 café", "2 cafés".
    static func cafesText(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) café](inflect: true)").characters)
    }

    /// "1 average line", "6 average lines".
    static func averageLinesText(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) average line](inflect: true)").characters)
    }
}

/// What the chart says in words: its caption, its headline and the summary the Audio Graph speaks.
nonisolated struct ThreeWaysSummary {
    /// The cafés the chart shows, each with its days.
    let stores: [StoreSales]
    /// Whether the chart draws the average rule, so the summary can state it.
    var showsAverage = false

    private var allCups: [Int] {
        stores.flatMap(\.days).map(\.cups)
    }

    var total: Int {
        allCups.reduce(0, +)
    }

    /// Nothing sold is no data: the chart shows a placeholder.
    var hasData: Bool {
        total > 0
    }

    /// The cups axis as drawn, kept off zero so the week's ups and downs fill the plot: the lowest and highest
    /// day rounded out to the axis step (152 to 219 → 140 to 220). The chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: allCups, includesZero: false)
    }

    /// The mean of every point shown, to the nearest cup.
    var average: Int {
        allCups.isEmpty ? 0 : Int((Double(total) / Double(allCups.count)).rounded())
    }

    var storeNames: String {
        stores.map(\.store).formatted(.list(type: .and))
    }

    var caption: String {
        let days = stores.flatMap(\.days).map(\.day)
        guard let first = days.min(), let last = days.max() else { return "Cups sold per day" }
        return "Cups sold per day, \(ThreeWaysFormat.shortDay(first)) to \(ThreeWaysFormat.shortDay(last))"
    }

    /// The chart's message in a sentence. True for one café, several, and when nothing sold.
    var headline: String {
        guard hasData else { return "No cups sold in the week." }
        let sold = "\(storeNames) sold \(ThreeWaysFormat.cupsText(total)) in the week"
        return stores.count == 1
            ? "\(sold): \(average.formatted()) a day on average."
            : "\(sold): \(average.formatted()) per café a day on average."
    }

    /// Actual values only, with no judgement of them. The rule is not a series, so it is stated here.
    var audioGraphSummary: String {
        guard hasData else { return "No cups sold in the week." }
        let perStore = stores.map { store in
            let cups = store.days.map(\.cups)
            return "\(store.store): \(ThreeWaysFormat.cupsText(cups.reduce(0, +))), "
                + "lowest day \(ThreeWaysFormat.cupsText(cups.min() ?? 0)), "
                + "highest day \(ThreeWaysFormat.cupsText(cups.max() ?? 0))."
        }
        let averageText = showsAverage ? ["Average: \(ThreeWaysFormat.cupsText(average)) a day."] : []
        return (perStore + averageText).joined(separator: " ")
    }
}

/// The state behind "Three ways to create a chart": which initializer, how many series,
/// and whether the average rule is written where it does not belong.
@Observable
final class ThreeWaysToCreateAChartViewModel {
    enum Way: String, CaseIterable, Identifiable {
        case data
        case dataWithID
        case content

        var id: Self {
            self
        }

        /// The initializer as it is written.
        var title: String {
            switch self {
            case .data: "Chart(data)"
            case .dataWithID: "Chart(data, id:)"
            case .content: "Chart { }"
            }
        }
    }

    enum SeriesCount: String, CaseIterable, Identifiable {
        case one
        case several

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .one: "One series"
            case .several: "Several series"
            }
        }
    }

    static let snippetPrefix = "three-ways-to-create-a-chart"

    /// The first week of the sample data: seven days stay one VoiceOver element each.
    static let firstWeek: [StoreSales] = CafeData.storeSales.map { store in
        StoreSales(store: store.store, days: Array(store.days.prefix(7)))
    }

    private let allStores: [StoreSales]

    var way = Way.data {
        didSet {
            // Chart { } has a place for the rule, so the mistake cannot be shown there.
            if way == .content { isShowingMistake = false }
        }
    }

    var seriesCount = SeriesCount.one
    var isShowingMistake = false

    init(stores: [StoreSales] = ThreeWaysToCreateAChartViewModel.firstWeek) {
        allStores = stores
    }

    /// Every café the screen can show, in data order: the domain of the colour and symbol scales,
    /// so a café looks the same with one series on screen or several.
    var cafes: [String] {
        allStores.map(\.store)
    }

    /// The cafés the chart shows: the first, or all of them.
    var stores: [StoreSales] {
        seriesCount == .one ? Array(allStores.prefix(1)) : allStores
    }

    /// The first café's days, for `Chart(data)` with one series.
    var days: [DailySales] {
        stores.first?.days ?? []
    }

    /// One Identifiable row per café and day.
    var rows: [ThreeWaysStoreDay] {
        stores.flatMap { store in
            store.days.map { ThreeWaysStoreDay(store: store.store, day: $0.day, cups: $0.cups) }
        }
    }

    /// The same rows, not Identifiable.
    var readings: [ThreeWaysReading] {
        rows.map { ThreeWaysReading(store: $0.store, day: $0.day, cups: $0.cups) }
    }

    /// The mistake needs a closure that runs once per element, which `Chart { }` does not have.
    var canShowMistake: Bool {
        way != .content
    }

    /// How many average rules the chart holds: one written beside the data, or one per element.
    var ruleCount: Int {
        if isShowingMistake { return rows.count }
        return way == .content ? 1 : 0
    }

    var summary: ThreeWaysSummary {
        ThreeWaysSummary(stores: stores, showsAverage: ruleCount > 0)
    }

    var explanation: String {
        if isShowingMistake {
            return """
            The rule is written inside the closure that \(way.title) runs once per element, so this chart holds \
            \(ruleCount.formatted()) average rules, one on top of the other. They look like one line, drawn darker \
            and heavier than a single rule, and VoiceOver stops on “Average” \(ruleCount.formatted()) times. A mark \
            that is not one per element belongs in Chart { }.
            """
        }
        switch (way, seriesCount) {
        case (.data, .one):
            return """
            Chart(data) takes one collection of Identifiable elements and runs its closure once for each: one mark \
            per element, and nothing else. It is the shortest way to write a chart of one series.
            """
        case (.data, .several):
            return """
            Chart(data) still fits two cafés when the data is one flat collection, a row per café and day, with the \
            café encoded as colour and symbol. Its closure still runs once per element, so it has no place for \
            anything else.
            """
        case (.dataWithID, .one):
            return """
            Chart(data, id:) is the same initializer for elements that are not Identifiable. The key path names a \
            Hashable value that is unique per element: here the day.
            """
        case (.dataWithID, .several):
            return """
            Chart(data, id:) is the same initializer for elements that are not Identifiable. Two cafés share each \
            day, so the day no longer identifies a row: here the whole element does.
            """
        case (.content, .one):
            return """
            Chart { } takes any mix of ForEach and individual marks. The ForEach moves from the initializer into \
            the body, which leaves room for a mark that is not one per element: the average rule, written once \
            beside the data.
            """
        case (.content, .several):
            return """
            Chart { } takes any mix of ForEach and individual marks, so nested data needs no flattening: one \
            ForEach per café around one per day, styled once on the inner loop, and the average rule written once \
            beside them.
            """
        }
    }

    /// The snippets for the current setting: the chart, then the parts it is made of.
    var snippets: [SnippetReference] {
        var result = [SnippetReference(name: chartSnippetName, title: chartSnippetTitle)]
        if ruleCount > 0 {
            result.append(SnippetReference(name: "\(Self.snippetPrefix)-rule", title: "The average rule"))
        }
        switch (way, seriesCount) {
        case (.dataWithID, _):
            result.append(SnippetReference(name: "\(Self.snippetPrefix)-reading", title: "Elements that are not Identifiable"))
        case (.data, .several):
            result.append(SnippetReference(name: "\(Self.snippetPrefix)-row", title: "One row per café and day"))
        default:
            break
        }
        result.append(SnippetReference(name: "\(Self.snippetPrefix)-mark", title: "The mark for one day"))
        return result
    }

    /// The region that draws the chart on screen, such as "three-ways-to-create-a-chart-data-one-mistake".
    var chartSnippetName: String {
        let wayName = switch way {
        case .data: "data"
        case .dataWithID: "id"
        case .content: "content"
        }
        return "\(Self.snippetPrefix)-\(wayName)-\(seriesCount.rawValue)" + (isShowingMistake ? "-mistake" : "")
    }

    private var chartSnippetTitle: String {
        isShowingMistake ? "\(way.title) with the rule inside: the mistake" : "\(way.title), \(seriesCount.title.lowercased())"
    }

    /// What changed in the chart, for people who cannot see it change. The same for two settings
    /// that draw the same chart.
    var changeAnnouncement: String {
        guard summary.hasData else { return "Chart shows no data." }
        let rules = ruleCount == 0 ? "no average line" : ThreeWaysFormat.averageLinesText(ruleCount)
        return "Chart shows \(ThreeWaysFormat.cafesText(stores.count)) and \(rules)."
    }
}
