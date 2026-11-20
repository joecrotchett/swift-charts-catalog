import Accessibility
import Charts
import Foundation
import Observation
import SwiftUI

// snippet:plottable-types-size-enum
/// A cup size. A `String` enum needs only the conformance: it plots as categories, and each raw
/// value is what the axis or the legend shows.
nonisolated enum PlottableTypesCupSize: String, Plottable, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
}

// end

// snippet:plottable-types-drink-struct
/// A drink on the menu. Any other type says which primitive value (a number, a `Date` or a
/// `String`) stands for it, and how to get back from one.
nonisolated struct PlottableTypesDrink: Plottable, Hashable {
    let name: String

    /// What the chart plots: the drink's name, so it is drawn as a category.
    var primitivePlottable: String {
        name
    }

    /// Failable: a name that is not on the menu has no drink.
    init?(primitivePlottable: String) {
        guard Self.menu.contains(primitivePlottable) else { return nil }
        name = primitivePlottable
    }

    static let menu = ["Latte", "Tea", "Mocha"]
}

// end

/// Cups of one drink sold in one size, held as the app's own types instead of strings.
nonisolated struct PlottableTypesOrder: Identifiable, Hashable {
    let drink: PlottableTypesDrink
    let size: PlottableTypesCupSize
    let cups: Int

    var id: String {
        "\(drink.name)-\(size.rawValue)"
    }

    /// The typed row for a row of sample data, or nil when its drink or size is not one the app knows.
    init?(_ order: DrinkOrder) {
        guard let drink = PlottableTypesDrink(primitivePlottable: order.drink),
              let size = PlottableTypesCupSize(rawValue: order.size) else { return nil }
        self.drink = drink
        self.size = size
        cups = order.cups
    }

    init(drink: PlottableTypesDrink, size: PlottableTypesCupSize, cups: Int) {
        self.drink = drink
        self.size = size
        self.cups = cups
    }
}

/// The drink orders as typed rows, and what the chart says about them in words.
@Observable
final class PlottableTypesViewModel {
    /// The rows the chart draws: every sample row whose drink and size convert, in data order.
    let orders: [PlottableTypesOrder]

    /// The snippets the screen shows; it has one state, so always the same three.
    static let snippetNames = ["plottable-types-size-enum", "plottable-types-drink-struct", "plottable-types-chart"]

    init(drinkOrders: [DrinkOrder] = CafeData.drinkOrders) {
        orders = drinkOrders.compactMap(PlottableTypesOrder.init)
    }

    var summary: PlottableTypesSummary {
        PlottableTypesSummary(orders: orders)
    }
}

/// One drink's total across its sizes: the height of its stack.
nonisolated struct PlottableTypesDrinkTotal: Hashable {
    let drink: PlottableTypesDrink
    let cups: Int
}

/// What the chart says in words: its headline and the Audio Graph's summary. Not tied to the main
/// actor, because the chart descriptor uses it.
nonisolated struct PlottableTypesSummary: Hashable {
    let orders: [PlottableTypesOrder]

    /// The drinks, in the order they first appear: the order of the bars.
    var drinks: [PlottableTypesDrink] {
        orders.reduce(into: []) { drinks, order in
            if !drinks.contains(order.drink) { drinks.append(order.drink) }
        }
    }

    /// The sizes, in the order they first appear: the order they stack in.
    /// The cups axis as drawn, from zero to the tallest stack rounded up to the axis step (164 → 200): the
    /// chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [highestTotal])
    }

    var sizes: [PlottableTypesCupSize] {
        orders.reduce(into: []) { sizes, order in
            if !sizes.contains(order.size) { sizes.append(order.size) }
        }
    }

    var totals: [PlottableTypesDrinkTotal] {
        drinks.map { drink in
            PlottableTypesDrinkTotal(drink: drink, cups: orders.filter { $0.drink == drink }.map(\.cups).reduce(0, +))
        }
    }

    var total: Int {
        orders.map(\.cups).reduce(0, +)
    }

    /// Nothing to draw: no rows, or every value zero, which would leave axes with no bars.
    var isEmpty: Bool {
        total == 0
    }

    /// The tallest stack's height, which the value axis reaches.
    var highestTotal: Int {
        totals.map(\.cups).max() ?? 0
    }

    /// Every drink with the tallest stack, in data order. More than one on a tie.
    var bestSellers: [PlottableTypesDrinkTotal] {
        guard !isEmpty else { return [] }
        return totals.filter { $0.cups == highestTotal }
    }

    /// Every drink with the shortest stack, in data order.
    var slowestSellers: [PlottableTypesDrinkTotal] {
        guard !isEmpty, let fewest = totals.map(\.cups).min() else { return [] }
        return totals.filter { $0.cups == fewest }
    }

    /// The chart's message in a sentence. Its figure is the top of the tallest stack.
    func headline(locale: Locale) -> String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        // On a tie the figure is each drink's own total, not their sum.
        let each = bestSellers.count > 1 ? " each" : ""
        return "\(Self.names(bestSellers)) sold the most: \(CafeWording.cups(cups, locale: locale))\(each)."
    }

    /// Actual values only, with no judgement of them.
    func audioGraphSummary(locale: Locale) -> String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(drinks.count, locale: locale)) in "
            + "\(CafeWording.sizes(sizes.count, locale: locale)), "
            + "\(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(Self.names(bestSellers)), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(Self.names(slowestSellers)), \(CafeWording.cups(fewest, locale: locale))."
    }

    /// What VoiceOver reads for one segment: context first, then the value with its unit.
    static func elementLabel(for order: PlottableTypesOrder) -> String {
        "\(order.drink.name), \(order.size.rawValue)"
    }

    static func elementValue(for order: PlottableTypesOrder, locale: Locale) -> String {
        CafeWording.cups(order.cups, locale: locale)
    }

    static func names(_ totals: [PlottableTypesDrinkTotal]) -> String {
        CafeWording.list(totals.map(\.drink.name))
    }
}

/// The chart for the Audio Graph: the drinks as categories, one series per size, each point the
/// segment's own cups rather than its height in the stack. Not tied to the main actor: the
/// accessibility system calls its value description when it chooses.
nonisolated struct PlottableTypesChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [PlottableTypesOrder]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = PlottableTypesSummary(orders: orders)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: summary.drinks.map(\.name)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = summary.sizes.map { size in
            AXDataSeriesDescriptor(
                name: size.rawValue,
                isContinuous: false,
                dataPoints: orders.filter { $0.size == size }.map {
                    AXDataPoint(x: $0.drink.name, y: Double($0.cups))
                }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold today, by drink and size",
            summary: summary.audioGraphSummary(locale: locale),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}
