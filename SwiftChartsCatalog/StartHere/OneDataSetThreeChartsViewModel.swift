import Foundation
import Observation

/// The three forms the screen draws its data in.
enum ThreeChartsForm: String, CaseIterable, Identifiable {
    case bars
    case line
    case linePerCafe

    var id: String {
        rawValue
    }

    /// The form's name in the picker.
    var title: String {
        switch self {
        case .bars: "Bars"
        case .line: "Line"
        case .linePerCafe: "Line per café"
        }
    }

    /// The code region that draws this form, and its title in the Code view.
    var snippet: SnippetReference {
        switch self {
        case .bars: SnippetReference(name: "one-data-set-three-charts-bars", title: "Bars")
        case .line: SnippetReference(name: "one-data-set-three-charts-line", title: "A line")
        case .linePerCafe: SnippetReference(name: "one-data-set-three-charts-line-per-cafe", title: "A line per café")
        }
    }
}

/// A week of one café's line: what one accessibility element of the line-per-café form covers.
nonisolated struct ThreeChartsWeek: Identifiable, Hashable {
    let cafe: String
    let days: [DailySales]
    /// The café and the dates covered, written out.
    let label: String
    /// Where the week starts and ends and its extremes, in cups.
    let value: String

    var id: String {
        "\(cafe)-\(days.first?.day.timeIntervalSinceReferenceDate ?? 0)"
    }
}

/// The words the chart is described in, shared by the headline, the marks' labels and the Audio Graph.
nonisolated enum ThreeChartsText {
    static let daysPerWeek = 7

    /// A count with its unit as a plain string that agrees in number: "1 cup", "164 cups".
    static func cups(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) cup](inflect: true)").characters)
    }

    /// A number of days, agreeing in number: "1 day", "28 days".
    static func days(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) day](inflect: true)").characters)
    }

    /// A day written out in the sample data's own time zone: "Sunday, March 1".
    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day())
    }

    /// A day as one end of a range of dates, in the sample data's own time zone: "March 1".
    static func shortDay(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(timeZone: CafeData.calendar.timeZone).month(.wide).day())
    }

    /// A café's days in stretches of a week, each with the label and value of its accessibility element.
    static func weeks(of store: StoreSales) -> [ThreeChartsWeek] {
        stride(from: 0, to: store.days.count, by: daysPerWeek).map { start in
            let days = Array(store.days[start ..< min(start + daysPerWeek, store.days.count)])
            let counts = days.map(\.cups)
            let dates = [days.first?.day, days.last?.day].compactMap(\.self).map(shortDay)
            let span = dates.first == dates.last ? (dates.first ?? "") : dates.joined(separator: " to ")
            return ThreeChartsWeek(
                cafe: store.store,
                days: days,
                label: "\(store.store), \(span)",
                value: "Starts at \(cups(counts.first ?? 0)), ends at \(cups(counts.last ?? 0)), "
                    + "lowest \(cups(counts.min() ?? 0)), highest \(cups(counts.max() ?? 0))"
            )
        }
    }
}

/// The state behind "One data set, three charts": which form is shown, and everything said about it.
@Observable
final class OneDataSetThreeChartsViewModel {
    var form: ThreeChartsForm
    /// Every café's daily sales. The first is the one the single-series forms draw.
    let stores: [StoreSales]

    init(stores: [StoreSales] = CafeData.storeSales, form: ThreeChartsForm = .bars) {
        self.stores = stores
        self.form = form
    }

    /// The series the current form draws: the first café alone, or every café.
    var shownStores: [StoreSales] {
        form == .linePerCafe ? stores : Array(stores.prefix(1))
    }

    /// Whether there is anything to draw. Days that are all zero are no data.
    var hasData: Bool {
        shownStores.contains { store in store.days.contains { $0.cups > 0 } }
    }

    /// The cups axis as drawn in every form, from every café's days: 0 to 300 for a busiest day of 282. The same
    /// in all three forms, so only the mark changes, and passed to the descriptor so the Audio Graph reads it.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: stores.flatMap(\.days).map(\.cups))
    }

    /// Whether the current form joins its values into a line.
    var isContinuous: Bool {
        form != .bars
    }

    /// What the chart shows, with its unit. Also the Audio Graph's title.
    var caption: String {
        if form == .linePerCafe {
            return "Cups sold per day at each café"
        }
        guard let store = stores.first else { return "Cups sold per day" }
        return "Cups sold per day at the \(store.store) café"
    }

    /// Every café the screen can draw, in data order: the colour scale's domain, so a café keeps
    /// its colour whichever form is shown.
    var cafes: [String] {
        stores.map(\.store)
    }

    /// The chart's message in a sentence, in figures the chart shows: daily cups, never a total.
    /// The bars and the line show the same data, so they share it.
    var headline: String {
        guard hasData else { return Self.noDataText }
        if form == .linePerCafe {
            let peaks = shownStores.map { (store: $0.store, cups: $0.days.map(\.cups).max() ?? 0) }
            let most = peaks.map(\.cups).max() ?? 0
            let leaders = peaks.filter { $0.cups == most }.map(\.store)
            return leaders.count == 1
                ? "\(leaders[0]) had the busiest day: \(ThreeChartsText.cups(most))."
                : "\(leaders.formatted(.list(type: .and))) tied for the busiest day: \(ThreeChartsText.cups(most))."
        }
        guard let store = shownStores.first else { return Self.noDataText }
        let lowest = store.days.map(\.cups).min() ?? 0
        let highest = store.days.map(\.cups).max() ?? 0
        return lowest == highest
            ? "\(store.store) sold \(ThreeChartsText.cups(highest)) every day."
            : "\(store.store) sold between \(lowest.formatted()) and \(ThreeChartsText.cups(highest)) a day."
    }

    /// The Audio Graph's summary: actual values only, a sentence or two per café drawn.
    var audioGraphSummary: String {
        guard hasData else { return Self.noDataText }
        return shownStores.filter { !$0.days.isEmpty }.map { store in
            let cups = store.days.map(\.cups)
            return "\(store.store): \(ThreeChartsText.days(cups.count)), \(ThreeChartsText.cups(Self.total(store))) in total. "
                + "First day \(ThreeChartsText.cups(cups.first ?? 0)), last day \(ThreeChartsText.cups(cups.last ?? 0)), "
                + "lowest \(ThreeChartsText.cups(cups.min() ?? 0)), highest \(ThreeChartsText.cups(cups.max() ?? 0))."
        }
        .joined(separator: " ")
    }

    /// What assistive technologies are told when the form changes, since the animation is not enough.
    var announcement: String {
        switch form {
        case .bars: "Chart changed to bars, one per day."
        case .line: "Chart changed to a line."
        case .linePerCafe: "Chart changed to a line for each café."
        }
    }

    /// The code the Code view shows: the chart for the current form.
    var snippets: [SnippetReference] {
        [form.snippet]
    }

    static let noDataText = "No cups sold yet."

    private static func total(_ store: StoreSales) -> Int {
        store.days.map(\.cups).reduce(0, +)
    }
}
