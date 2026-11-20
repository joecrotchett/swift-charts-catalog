import Foundation
import Observation

/// The state of "Styling the plot area": whether the plot area has its background and border.
@Observable
final class PlotStyleViewModel {
    /// The drinks drawn, ranked from most cups to fewest, so the headline's drink is the top bar.
    let sales: [DrinkSales]
    /// On: the plot area has a tinted background and a border. Off: the default plot area.
    var isStyled = true

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = PlotStyleSummary.ranked(sales)
    }

    /// The snippets See Code shows. The plot style's code is the same in both settings: its closure
    /// returns the plot area restyled, or as it is.
    static let snippetNames = ["styling-the-plot-area-chart"]
}

/// What the chart says in words: its headline and the summary the Audio Graph speaks. The toggle only
/// restyles the plot area, so neither changes with it.
nonisolated struct PlotStyleSummary {
    let sales: [DrinkSales]
    /// The locale every count is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The value axis as drawn and as given to the descriptor: 0 to the most cups, rounded up to a tidy step.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    /// Most cups first; a tie keeps the data's order.
    static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// True when there is nothing to draw: no drinks, or no cups sold.
    var isEmpty: Bool {
        total == 0
    }

    /// Every drink that sold the most, in data order. Empty when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order. Empty when nothing sold.
    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The chart's message in a sentence, with the figure on its top bar.
    var headline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
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
