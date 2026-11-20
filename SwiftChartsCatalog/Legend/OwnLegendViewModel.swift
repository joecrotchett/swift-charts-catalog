import Charts
import Foundation
import Observation

/// The three cup sizes, a fixed set of categories plotted as an enum, not as strings typed at each use.
/// The raw values are what the chart shows in its legend and what VoiceOver reads.
nonisolated enum OwnLegendSize: String, Plottable, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
}

/// One segment of a stacked bar: one drink in one size.
nonisolated struct OwnLegendOrder: Identifiable, Hashable {
    let drink: String
    let size: OwnLegendSize
    let cups: Int

    var id: String {
        "\(drink)-\(size.rawValue)"
    }
}

/// State and words for "A legend of your own": which legend is drawn, and what the chart says.
@Observable
final class OwnLegendViewModel {
    /// True when the app draws its own legend from the chart's scale; false for the automatic legend.
    var isShowingOwnLegend = true

    let orders: [OwnLegendOrder]

    /// Every size the colour scale holds, in the order the segments stack from the bottom.
    /// Fixing the domain keeps each size's colour and its place in either legend whatever the data holds.
    let sizes = OwnLegendSize.allCases

    /// Rows whose size is not one of the three are left out: the chart has no colour for them.
    /// The rest are sorted into the colour scale's order within each drink, so the segments stack in the
    /// order both legends list the sizes, whatever order the data came in. The drinks keep their order.
    init(orders: [DrinkOrder] = CafeData.drinkOrders) {
        let known = orders.compactMap { order in
            OwnLegendSize(rawValue: order.size).map { OwnLegendOrder(drink: order.drink, size: $0, cups: order.cups) }
        }
        let drinkOrder = known.reduce(into: [String]()) { drinks, order in
            if !drinks.contains(order.drink) { drinks.append(order.drink) }
        }
        let sizeOrder = OwnLegendSize.allCases
        self.orders = known.enumerated().sorted { first, second in
            let a = (drinkOrder.firstIndex(of: first.element.drink) ?? 0, sizeOrder.firstIndex(of: first.element.size) ?? 0)
            let b = (drinkOrder.firstIndex(of: second.element.drink) ?? 0, sizeOrder.firstIndex(of: second.element.size) ?? 0)
            return a != b ? a < b : first.offset < second.offset
        }.map(\.element)
    }

    // MARK: Figures

    var totalCups: Int {
        orders.map(\.cups).reduce(0, +)
    }

    /// Nothing sold is no data: the chart shows a placeholder instead of axes with no bars.
    var hasCups: Bool {
        totalCups > 0
    }

    /// The drinks in data order, the order of the bars.
    var drinks: [String] {
        orders.reduce(into: [String]()) { drinks, order in
            if !drinks.contains(order.drink) { drinks.append(order.drink) }
        }
    }

    func total(for size: OwnLegendSize) -> Int {
        orders.filter { $0.size == size }.map(\.cups).reduce(0, +)
    }

    /// The cups axis as drawn, from zero to the tallest stack rounded up to the axis step (164 → 200): the
    /// chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [tallestBar])
    }

    /// The tallest bar's height: the top of the drawn value scale's data.
    var tallestBar: Int {
        drinks.map { drink in orders.filter { $0.drink == drink }.map(\.cups).reduce(0, +) }.max() ?? 0
    }

    /// Every size that sold the most cups, in scale order. More than one on a tie; none when nothing sold.
    var bestSizes: [OwnLegendSize] {
        guard let most = sizes.map(total(for:)).max(), most > 0 else { return [] }
        return sizes.filter { total(for: $0) == most }
    }

    // MARK: Words

    /// The chart's message. With the app's legend the figure is on screen beside the size's name, so the
    /// headline gives it; the automatic legend shows no totals, so the headline names the size alone.
    func headline(locale: Locale) -> String {
        guard let best = bestSizes.first else { return "No cups sold yet today." }
        let names = CafeWording.list(bestSizes.map(\.rawValue))
        guard isShowingOwnLegend else { return "\(names) cups sold the most." }
        let each = bestSizes.count > 1 ? " each" : ""
        return "\(names) cups sold the most: \(CafeWording.cups(total(for: best), locale: locale))\(each)."
    }

    /// What one row of the app's legend says, name first: "Large, 96 cups".
    func legendEntry(for size: OwnLegendSize, locale: Locale) -> String {
        "\(size.rawValue), \(CafeWording.cups(total(for: size), locale: locale))"
    }

    /// The legend's spoken value, its rows in the order they are drawn. The sizes come from the chart's
    /// own scale, read through the proxy by the view and handed in as plain values.
    func legendSpokenValue(sizes: [OwnLegendSize], locale: Locale) -> String {
        sizes.map { legendEntry(for: $0, locale: locale) }.joined(separator: "; ")
    }

    /// Actual values only, the same whichever legend is drawn.
    func audioGraphSummary(locale: Locale) -> String {
        guard let best = bestSizes.first else { return "No cups sold yet today." }
        let bySize = sizes.map { legendEntry(for: $0, locale: locale) }.joined(separator: "; ")
        return "\(CafeWording.drinks(drinks.count, locale: locale)), \(CafeWording.cups(totalCups, locale: locale)) in total. "
            + "By size: \(bySize). "
            + "Most: \(CafeWording.list(bestSizes.map(\.rawValue))), \(CafeWording.cups(total(for: best), locale: locale))."
    }

    /// Said when the toggle changes the legend: what changed, then the headline, which changes with it.
    func announcement(locale: Locale) -> String {
        let change = isShowingOwnLegend
            ? "Legend drawn by the app, in stacking order with each size's cups."
            : "Automatic legend."
        return "\(change) \(headline(locale: locale))"
    }

    /// What the screen demonstrates, true of the chart as it is drawn now: which legend, and where.
    /// - Parameter isBesideBars: false at the accessibility text sizes, where the app's legend goes above the bars.
    func explanation(isBesideBars: Bool) -> String {
        let concept = """
        When the automatic legend's layout will not do, hide it with chartLegend(.hidden) and draw your own. \
        Inside chartOverlay the ChartProxy lists the colour scale's values with foregroundStyleDomain and gives \
        the colour the chart assigned to each with foregroundStyle(for:), so the legend cannot drift from the marks.
        """
        // With nothing sold the placeholder stands in for the chart, and neither legend is drawn.
        guard hasCups else { return concept }
        guard isShowingOwnLegend else {
            return concept + " The switch is off, so this chart shows the automatic legend below the bars, "
                + "with each size's name and colour but no cups."
        }
        let place = isBesideBars
            ? "beside the bars, in room the x scale's end padding keeps clear"
            : "above the bars, in room the y scale's end padding keeps clear, because at this text size a column beside them would leave the bars no room"
        return concept + " This one lists the sizes in the order they stack, each with its cups, \(place)."
    }

    // MARK: Code

    static let chartSnippet = SnippetReference(
        name: "a-legend-of-your-own-chart", title: "Hide the automatic legend and keep room for your own"
    )
    static let keySnippet = SnippetReference(
        name: "a-legend-of-your-own-key", title: "A legend drawn from the chart's own scale"
    )

    /// The code for the current setting: the legend's own code only while it is drawn.
    var snippets: [SnippetReference] {
        isShowingOwnLegend ? [Self.chartSnippet, Self.keySnippet] : [Self.chartSnippet]
    }
}
