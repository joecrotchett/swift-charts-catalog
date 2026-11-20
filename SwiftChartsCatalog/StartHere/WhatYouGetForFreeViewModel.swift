import Foundation
import Observation

/// The mark the uncustomised chart is drawn with.
enum FreeDefaultsMark: String, CaseIterable, Identifiable {
    case bars = "Bars"
    case lines = "Lines"
    case points = "Points"

    var id: String {
        rawValue
    }

    /// The code region that draws the chart with this mark.
    var snippet: SnippetReference {
        switch self {
        case .bars: SnippetReference(name: "what-you-get-for-free-bars", title: "Bars, nothing configured")
        case .lines: SnippetReference(name: "what-you-get-for-free-lines", title: "Lines, nothing configured")
        case .points: SnippetReference(name: "what-you-get-for-free-points", title: "Points, nothing configured")
        }
    }

    /// Whether the mark also encodes the size as a symbol shape, so sizes differ by more than colour.
    var usesSymbols: Bool {
        self != .bars
    }

    /// Whether marks that share a drink stack, so a drink's height is its total across sizes.
    /// Lines and points do not stack: each drink and size sits at its own value.
    var stacksValues: Bool {
        self == .bars
    }
}

/// One default of an uncustomised chart: what it is here, and what changes it.
nonisolated struct FreeDefault: Identifiable, Hashable {
    let name: String
    /// What the default looks like on this chart.
    let detail: String
    /// The code someone would write to have it otherwise.
    let change: String

    var id: String {
        name
    }
}

/// The state of "What you get for free": the mark in use, and the words for each default on show.
@Observable
final class WhatYouGetForFreeViewModel {
    /// The colours a category colour encoding assigns, in order, before starting again.
    static let colourOrder = ["blue", "green", "orange", "purple", "red", "cyan", "yellow"]
    /// The shapes a symbol encoding assigns to points, in order, before starting again.
    static let symbolOrder = ["circle", "cross", "triangle", "plus", "square", "asterisk", "diamond"]
    /// The outlined shapes a symbol encoding assigns to lines. Only the first three were seen on a rendered chart.
    static let lineSymbolOrder = ["circle", "square", "triangle"]

    var mark = FreeDefaultsMark.bars
    let orders: [DrinkOrder]

    init(orders: [DrinkOrder] = CafeData.drinkOrders) {
        self.orders = orders
    }

    /// The chart's words for the mark in use: stacked bars show totals per drink, lines and points
    /// show each drink and size on its own.
    var summary: FreeDefaultsSummary {
        FreeDefaultsSummary(orders: orders, isStacked: mark.stacksValues)
    }

    /// What the screen says about the chart. A line across categories is not a form to recommend,
    /// so the line form says why it is here.
    var explanation: String {
        let base = """
        Nothing about this chart was configured: the code is the marks and the data they plot. \
        Swift Charts made the scales, both axes, the grid lines, the colours and the legend from that data. \
        Each default named below is something you would write code to change, and switching the mark changes none of them.
        """
        guard mark == .lines else { return base }
        return base + " " + """
        Drinks are separate categories, with nothing between one and the next, so a line over them is shown here \
        only to show the defaults a line gets.
        """
    }

    /// The code the Code view shows for the mark in use.
    var snippets: [SnippetReference] {
        [mark.snippet]
    }

    /// Each size with the colour the chart gives it: the first size is blue, the second green, and so on.
    var colourAssignments: [String] {
        Self.assignments(of: Self.colourOrder, to: summary.sizes)
    }

    /// Each size with the symbol the chart gives its points: the first size is a circle, the second a cross, and so on.
    var symbolAssignments: [String] {
        Self.assignments(of: Self.symbolOrder, to: summary.sizes)
    }

    /// Each size with the outlined symbol the chart gives its line, or nothing when there are more
    /// sizes than the shapes this screen has seen assigned.
    var lineSymbolAssignments: [String] {
        guard summary.sizes.count <= Self.lineSymbolOrder.count else { return [] }
        return Self.assignments(of: Self.lineSymbolOrder, to: summary.sizes)
    }

    /// What VoiceOver is told when the mark changes, since the marks and the value scale both change.
    /// The headline is the one for the new mark.
    var changeAnnouncement: String {
        "Chart now drawn with \(mark.rawValue.lowercased()). \(summary.headline)"
    }

    /// The defaults the chart is showing, named, each with what would change it.
    var defaults: [FreeDefault] {
        // With nothing to plot there are no scales, axes or legend to describe.
        guard summary.total > 0 else {
            return [FreeDefault(
                name: "No data",
                detail: "An uncustomised chart given nothing to plot draws nothing at all, not even its axes.",
                change: "Show a placeholder in place of the chart, as this screen does."
            )]
        }
        return [valueAxis, categoryAxis, categoryOrder, colours, legend, markDefault]
    }

    private var valueAxis: FreeDefault {
        let top = mark == .bars ? "the tallest stack" : "the largest value"
        return FreeDefault(
            name: "Value axis",
            detail: "On the trailing edge, with a solid grid line at each label. "
                + "The scale starts at zero and rounds up past \(top).",
            change: "chartYAxis moves or rebuilds the axis; chartYScale sets its range."
        )
    }

    private var categoryAxis: FreeDefault {
        FreeDefault(
            name: "Category axis",
            detail: "Along the bottom, with dashed vertical grid lines between the drinks.",
            change: "chartXAxis hides or rebuilds it."
        )
    }

    private var categoryOrder: FreeDefault {
        FreeDefault(
            name: "Category order",
            detail: "\(Self.list(summary.drinks)): the order the drinks first appear in the data, not alphabetical.",
            change: "Sort the data."
        )
    }

    private var colours: FreeDefault {
        FreeDefault(
            name: "Colours",
            detail: "\(Self.list(colourAssignments)). "
                + "Colours are handed out in a fixed order to the sizes as they first appear in the data.",
            change: "chartForegroundStyleScale chooses the colours."
        )
    }

    private var legend: FreeDefault {
        let swatch = mark.usesSymbols ? "its own symbol for each size" : "a circle for each size"
        return FreeDefault(
            name: "Legend",
            detail: "Below the chart at the leading edge, with \(swatch), in data order. "
                + "It is there because the size is encoded as colour.",
            change: "chartLegend hides or moves it."
        )
    }

    private var markDefault: FreeDefault {
        switch mark {
        case .bars:
            FreeDefault(
                name: "Stacking",
                detail: "Bars that share a drink stack from the bottom in data order, "
                    + "\(summary.sizes.first ?? "the first size") first, and fill most of their band.",
                change: "position(by:) puts them side by side; the stacking parameter changes how they stack."
            )
        case .lines:
            FreeDefault(
                name: "Lines and symbols",
                detail: "Straight segments between the points, one line per size. "
                    + "The symbol encoding marks every point with an outlined shape for its size"
                    + (lineSymbolAssignments.isEmpty ? "." : ": \(Self.list(lineSymbolAssignments))."),
                change: "interpolationMethod curves a line; chartSymbolScale chooses the shapes."
            )
        case .points:
            FreeDefault(
                name: "Symbols",
                detail: "Points that share a drink do not stack: each sits at its own value. "
                    + "The symbol encoding hands out shapes in a fixed order: \(Self.list(symbolAssignments)).",
                change: "chartSymbolScale chooses the shapes; symbolSize sets their size."
            )
        }
    }

    /// Pairs each size with the name the chart assigns it, starting the names again when they run out.
    private static func assignments(of names: [String], to sizes: [String]) -> [String] {
        sizes.enumerated().map { index, size in "\(size) is \(names[index % names.count])" }
    }

    private static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and))
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct FreeDefaultsSummary {
    let orders: [DrinkOrder]
    /// True when the sizes of a drink are stacked (bars), so the chart shows a total per drink.
    /// False when each drink and size is drawn at its own value (lines, points).
    var isStacked = true

    /// The drinks, in the order they first appear in the data: the order the chart draws them in.
    var drinks: [String] {
        Self.inFirstAppearanceOrder(orders.map(\.drink))
    }

    /// The sizes, in the order they first appear in the data: the order of the colours and the legend.
    var sizes: [String] {
        Self.inFirstAppearanceOrder(orders.map(\.size))
    }

    var total: Int {
        orders.map(\.cups).reduce(0, +)
    }

    /// Cups per drink across every size, in chart order.
    var drinkTotals: [(drink: String, cups: Int)] {
        drinks.map { drink in
            (drink, orders.filter { $0.drink == drink }.map(\.cups).reduce(0, +))
        }
    }

    /// The values the chart draws, each named: a total per drink when stacked ("Tea"),
    /// or one per drink and size when not ("Small Tea").
    var plotted: [(name: String, cups: Int)] {
        isStacked
            ? drinkTotals.map { (name: $0.drink, cups: $0.cups) }
            : orders.map { (name: "\($0.size) \($0.drink)", cups: $0.cups) }
    }

    /// The largest value the chart draws: the tallest stack, or the largest single value.
    var highestPlotted: Int {
        plotted.map(\.cups).max() ?? 0
    }

    /// The cups axis as drawn, for the descriptor. Defaults are this screen's subject, so the chart's scale stays
    /// automatic; `ChartAxis` gives the same rounded top the automatic axis draws (0 to 200 for a tallest stack of
    /// 164, 0 to 80 for a largest point of 71), so the Audio Graph reads the drawn ends.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [highestPlotted])
    }

    /// Everything drawn at the largest value, in chart order. More than one when there is a tie.
    var bestSellers: [String] {
        guard total > 0 else { return [] }
        return plotted.filter { $0.cups == highestPlotted }.map(\.name)
    }

    /// Everything drawn at the smallest value, in chart order.
    var slowestSellers: [String] {
        guard let fewest = plotted.map(\.cups).min(), total > 0 else { return [] }
        return plotted.filter { $0.cups == fewest }.map(\.name)
    }

    /// The chart's message in a sentence, carrying a value the chart draws. True on a tie, and when nothing sold.
    var headline: String {
        guard total > 0 else { return "No cups sold yet today." }
        return "\(Self.list(bestSellers)) sold the most: \(Self.cupsText(highestPlotted))."
    }

    /// Actual values only, with no judgement of them: the most and the fewest are values the chart draws.
    var audioGraphSummary: String {
        guard let fewest = plotted.map(\.cups).min(), total > 0 else {
            return "No cups sold yet today."
        }
        return "\(Self.drinksText(drinks.count)) in \(Self.sizesText(sizes.count)), "
            + "\(Self.cupsText(total)) in total. "
            + "Most: \(Self.list(bestSellers)), \(Self.cupsText(highestPlotted)). "
            + "Fewest: \(Self.list(slowestSellers)), \(Self.cupsText(fewest))."
    }

    /// A count of cups with its unit, agreeing in number: "1 cup", "164 cups".
    static func cupsText(_ cups: Int) -> String {
        resolved("^[\(cups) cup](inflect: true)")
    }

    /// "1 drink", "3 drinks".
    static func drinksText(_ count: Int) -> String {
        resolved("^[\(count) drink](inflect: true)")
    }

    /// "1 size", "3 sizes".
    static func sizesText(_ count: Int) -> String {
        resolved("^[\(count) size](inflect: true)")
    }

    /// The Audio Graph takes plain strings, not Text, so the agreement in number is resolved here.
    private static func resolved(_ value: String.LocalizationValue) -> String {
        String(AttributedString(localized: value).characters)
    }

    private static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and))
    }

    private static func inFirstAppearanceOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
