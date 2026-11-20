import CoreGraphics
import Foundation
import Observation

/// The state of "Plot height from content": how many drinks are charted, and the words and height that follow.
@Observable
final class PlotHeightViewModel {
    /// Every drink, ranked from most cups to fewest. The chart shows the first `rowCount` of them.
    let rankedSales: [DrinkSales]
    /// How many rows the chart shows. The stepper keeps it within `rowRange`.
    var rowCount: Int

    init(sales: [DrinkSales] = PlotHeightMenu.drinks, rowCount: Int = 5) {
        rankedSales = PlotHeightSummary.ranked(sales)
        self.rowCount = min(max(rowCount, 1), max(sales.count, 1))
    }

    /// From one row to every drink on the menu.
    var rowRange: ClosedRange<Int> {
        1 ... max(rankedSales.count, 1)
    }

    /// The drinks the chart draws: the best sellers, one row each.
    var shownSales: [DrinkSales] {
        Array(rankedSales.prefix(rowCount))
    }

    /// The code the screen shows. The controls change the data, not the code, so it is the same for every setting.
    let snippets = [
        SnippetReference(name: "plot-height-from-content-chart", title: "A plot as tall as its rows"),
        SnippetReference(name: "plot-height-from-content-row-height", title: "A row height that grows with the text"),
        SnippetReference(name: "plot-height-from-content-height", title: "The plot's height"),
    ]

    func summary(locale: Locale) -> PlotHeightSummary {
        PlotHeightSummary(sales: shownSales, locale: locale)
    }

    // snippet:plot-height-from-content-height
    /// The plot area's height: a fixed height for every row. The axes are added around it.
    static func plotHeight(rows: Int, rowHeight: CGFloat) -> CGFloat {
        CGFloat(max(rows, 0)) * rowHeight
    }

    // end

    /// The height of the plot as it is drawn now, given the row height the view read for its text size.
    func plotHeight(rowHeight: CGFloat) -> CGFloat {
        Self.plotHeight(rows: shownSales.count, rowHeight: rowHeight)
    }

    /// The plot's height written out for the controls, such as "220 points".
    func plotHeightText(rowHeight: CGFloat, locale: Locale) -> String {
        CafeWording.points(Double(plotHeight(rowHeight: rowHeight).rounded()), locale: locale)
    }

    /// The row count as the stepper shows it, such as "5".
    func rowCountText(locale: Locale) -> String {
        rowCount.formatted(.number.locale(locale))
    }

    /// What the stepper speaks as its value: the headline alone. Its label says "Rows", and the
    /// headline starts with the same count, so the count is not said twice. The stepper changes the data, so its
    /// value carries the headline instead of an announcement on every step.
    func spokenRowCount(locale: Locale) -> String {
        summary(locale: locale).headline
    }
}

/// What the chart says in words: its headline and the summary the Audio Graph speaks.
nonisolated struct PlotHeightSummary {
    /// The drinks as drawn, in the order they are drawn.
    let sales: [DrinkSales]
    let locale: Locale

    /// Most cups first; drinks with the same cups in name order, so the order never shifts.
    static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.sorted { $0.cups == $1.cups ? $0.drink < $1.drink : $0.cups > $1.cups }
    }

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// The value axis as drawn and as given to the descriptor: 0 to the most cups, rounded up to a tidy step.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    /// Whether there is anything to draw. Nothing sold is no data: bars of zero draw nothing.
    var hasCups: Bool {
        total > 0
    }

    /// Every drink that sold the most, in drawn order.
    var bestSellers: [DrinkSales] {
        guard hasCups, let most = sales.map(\.cups).max() else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in drawn order.
    var slowestSellers: [DrinkSales] {
        guard hasCups, let fewest = sales.map(\.cups).min() else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The chart's message: how many rows there are and which is longest. True for every row count, on a tie,
    /// and when nothing sold.
    var headline: String {
        guard let most = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "Of \(CafeWording.drinks(sales.count, locale: locale)) shown, "
            + "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(most, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
    }
}

/// The Harbour café's whole menu, today. `CafeData.drinkSales` has five drinks, too few for a chart that grows
/// with its rows, so this keeps those five with their counts and adds seven more.
nonisolated enum PlotHeightMenu {
    static let drinks: [DrinkSales] = CafeData.drinkSales + [
        DrinkSales(drink: "Flat white", cups: 141),
        DrinkSales(drink: "Cappuccino", cups: 119),
        DrinkSales(drink: "Iced coffee", cups: 83),
        DrinkSales(drink: "Espresso", cups: 76),
        DrinkSales(drink: "Chai latte", cups: 64),
        DrinkSales(drink: "Matcha", cups: 45),
        DrinkSales(drink: "Macchiato", cups: 38),
    ]
}
