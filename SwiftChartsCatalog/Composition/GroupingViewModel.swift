import Foundation
import Observation

/// How bars that share a drink are arranged.
enum BarArrangement: String, CaseIterable, Identifiable {
    case stacked
    case grouped

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .stacked: "Stacked"
        case .grouped: "Grouped"
        }
    }
}

/// How much of a drink's band its group of bars may use.
enum GroupSpan: String, CaseIterable, Identifiable {
    case automatic
    case half
    case whole

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic: "Default"
        case .half: "Half"
        case .whole: "Whole"
        }
    }

    /// The fraction of the band the group uses, or `nil` to leave `span:` out.
    var ratio: Double? {
        switch self {
        case .automatic: nil
        case .half: 0.5
        case .whole: 1
        }
    }
}

/// What the chart draws: bars stacked, or side by side with the framework's span or one that is set.
nonisolated enum GroupingLayout: Hashable {
    case stacked
    case grouped
    case groupedWithSpan(ratio: Double)
}

/// The state behind the Grouping screen: stacked or grouped, and the span of a group in its band.
@Observable
final class GroupingViewModel {
    static let stackedSnippet = SnippetReference(name: "grouping-stacked", title: "Stacked: no position(by:)")
    static let groupedSnippet = SnippetReference(name: "grouping-grouped", title: "position(by:)")
    static let spanSnippet = SnippetReference(name: "grouping-span", title: "position(by:) with span:")

    let orders: [DrinkOrder]
    var arrangement: BarArrangement
    var span: GroupSpan

    init(orders: [DrinkOrder] = CafeData.drinkOrders, arrangement: BarArrangement = .grouped, span: GroupSpan = .automatic) {
        self.orders = orders
        self.arrangement = arrangement
        self.span = span
    }

    /// The span only means something when the bars are side by side.
    var isSpanEnabled: Bool {
        arrangement == .grouped
    }

    var layout: GroupingLayout {
        guard arrangement == .grouped else { return .stacked }
        guard let ratio = span.ratio else { return .grouped }
        return .groupedWithSpan(ratio: ratio)
    }

    var summary: DrinkOrdersSummary {
        DrinkOrdersSummary(orders: orders, isStacked: arrangement == .stacked)
    }

    var headline: String {
        summary.headline
    }

    /// The code that draws the chart as it is now.
    var snippets: [SnippetReference] {
        switch layout {
        case .stacked: [Self.stackedSnippet]
        case .grouped: [Self.groupedSnippet]
        case .groupedWithSpan: [Self.spanSnippet]
        }
    }

    var explanation: String {
        switch layout {
        case .stacked:
            """
            Bars that share a position stack. Each drink has three rows, one per size, so its three bars pile \
            into one whose height is the drink's total. foregroundStyle(by:) only colours the pieces; it is not \
            what stacks them.
            """
        case .grouped:
            """
            position(by:) on the same property as the colour places the bars side by side inside the drink's \
            band instead of stacking them. Every bar now rises from zero, so sizes can be compared with each \
            other, and the value axis shrinks to fit the tallest single bar.
            """
        case .groupedWithSpan:
            """
            span: limits how much of the drink's band the group may use. It takes a MarkDimension: a ratio of \
            the band, an inset or a fixed width. A smaller span makes narrower bars and wider gaps between \
            drinks; a ratio of 1 gives the group the whole band, and the bars keep the gaps between them.
            """
        }
    }

    /// What changed on the chart, and what it now shows, for people who cannot see it change.
    var announcement: String {
        let change = switch layout {
        case .stacked: "Bars stacked, one bar per drink."
        case .grouped: "Bars side by side, one bar per size in each drink."
        case let .groupedWithSpan(ratio):
            "Bars side by side, each group using \(ratio.formatted(.percent)) of its drink's band."
        }
        return "\(change) \(headline)"
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct DrinkOrdersSummary {
    let orders: [DrinkOrder]
    /// Stacked, a bar is a drink's total; side by side, a bar is one size of one drink.
    let isStacked: Bool

    var total: Int {
        orders.map(\.cups).reduce(0, +)
    }

    /// Drinks and sizes in the order they first appear in the data, which is the order the chart draws them.
    var drinks: [String] {
        Self.unique(orders.map(\.drink))
    }

    var sizes: [String] {
        Self.unique(orders.map(\.size))
    }

    /// Each drink's cups across all sizes: the height of its stacked bar.
    var drinkTotals: [(drink: String, cups: Int)] {
        drinks.map { drink in
            (drink, orders.filter { $0.drink == drink }.map(\.cups).reduce(0, +))
        }
    }

    /// The bars as drawn, named and valued: a drink's total when stacked, one size of one drink when grouped.
    var bars: [(name: String, cups: Int)] {
        isStacked
            ? drinkTotals.map { ($0.drink, $0.cups) }
            : orders.map { ("\($0.size) \($0.drink)", $0.cups) }
    }

    /// The top of the value axis's data: the tallest bar as drawn.
    var tallestBar: Int {
        bars.map(\.cups).max() ?? 0
    }

    /// The cups axis as drawn: from zero to the tallest bar rounded up to the axis step (a stack of 164 → 200, a
    /// single bar of 71 → 80). The chart's scale and the descriptor's range, for each layout.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [tallestBar])
    }

    /// Every bar that is tallest, in data order. More than one on a tie; none when nothing sold.
    var tallestBars: [(name: String, cups: Int)] {
        guard total > 0 else { return [] }
        return bars.filter { $0.cups == tallestBar }
    }

    var shortestBars: [(name: String, cups: Int)] {
        guard total > 0, let fewest = bars.map(\.cups).min() else { return [] }
        return bars.filter { $0.cups == fewest }
    }

    /// The chart's message, with a figure that is the height of a bar as currently drawn.
    var headline: String {
        guard let cups = tallestBars.first?.cups else { return Self.nothingSold }
        let names = Self.names(tallestBars)
        return isStacked
            ? "\(names) sold the most across all sizes: \(Self.cupsText(cups))."
            : "\(names) sold the most of any drink and size: \(Self.cupsText(cups))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = tallestBars.first?.cups, let fewest = shortestBars.first?.cups else { return Self.nothingSold }
        let shape = isStacked
            ? "Sizes are stacked, so each bar is a drink's total."
            : "Sizes are side by side, so each bar is one size of one drink."
        return "\(drinks.count.formatted()) drinks in \(sizes.count.formatted()) sizes, \(Self.cupsText(total)) in total. "
            + "\(shape) Most: \(Self.names(tallestBars)), \(Self.cupsText(most)). "
            + "Fewest: \(Self.names(shortestBars)), \(Self.cupsText(fewest))."
    }

    static let nothingSold = "No cups sold yet today."

    static func names(_ bars: [(name: String, cups: Int)]) -> String {
        bars.map(\.name).formatted(.list(type: .and))
    }

    /// A count with its unit, agreeing in number: "1 cup", "71 cups".
    static func cupsText(_ cups: Int) -> String {
        cups == 1 ? "\(cups.formatted()) cup" : "\(cups.formatted()) cups"
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
