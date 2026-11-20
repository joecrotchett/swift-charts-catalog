import Foundation
import Observation
import SwiftUI

/// One stacked segment as drawn: a drink's cups in one size, and whether it is the top of its bar.
nonisolated struct DataOrderSegment: Identifiable, Hashable {
    let drink: String
    let size: String
    let cups: Int
    /// The last of its drink's rows in the drawn data: the segment the stack ends with.
    let isTopOfStack: Bool

    var id: String {
        "\(drink)-\(size)"
    }
}

/// The state of the "Order comes from the data" screen: how the rows are ordered and how the
/// colour scale's domain is ordered, and everything the chart and its words derive from them.
@Observable
final class DataOrderViewModel {
    /// The rows exactly as `CafeData` holds them.
    let orders: [DrinkOrder]
    /// Whether the rows are sorted by each drink's total before they reach the chart.
    var sortsByTotal = false
    /// Whether the colour scale's domain lists the sizes in reverse of their order in the data.
    var reversesScaleDomain = false

    init(orders: [DrinkOrder] = CafeData.drinkOrders) {
        self.orders = orders
    }

    // MARK: Orders

    /// The rows the chart is given, in the order it is given them.
    var drawnOrders: [DrinkOrder] {
        sortsByTotal ? Self.sortedByTotal(orders) : orders
    }

    // snippet:data-order-sort
    /// Sorting the rows is how the bars are ranked: the chart places categories in the order
    /// they first appear. Each drink's rows keep their own order, so the stacks do not change.
    static func sortedByTotal(_ orders: [DrinkOrder]) -> [DrinkOrder] {
        let drinks = firstAppearances(of: orders.map(\.drink))
        let totals = Dictionary(grouping: orders, by: \.drink).mapValues { $0.map(\.cups).reduce(0, +) }
        // Largest total first; a tie keeps the order of the data.
        let ranked = drinks.enumerated().sorted { first, second in
            let firstTotal = totals[first.element] ?? 0
            let secondTotal = totals[second.element] ?? 0
            return firstTotal == secondTotal ? first.offset < second.offset : firstTotal > secondTotal
        }
        return ranked.flatMap { drink in orders.filter { $0.drink == drink.element } }
    }

    // end

    /// Each value once, in the order it first occurs.
    static func firstAppearances(of values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    /// The bars in reading order (left to right, or right to left in a right-to-left layout): each drink
    /// in the order it first appears in the drawn rows.
    var drinkOrder: [String] {
        Self.firstAppearances(of: drawnOrders.map(\.drink))
    }

    /// The segments from the bottom of a stack up: each size in the order it first appears in the rows.
    var stackOrder: [String] {
        Self.firstAppearances(of: drawnOrders.map(\.size))
    }

    /// The sizes in the order the data gives them, whatever the controls say.
    var sizesInDataOrder: [String] {
        Self.firstAppearances(of: orders.map(\.size))
    }

    // snippet:data-order-domain
    /// The colour scale's domain. Its order is the legend's order; the colours stay with their
    /// sizes because the scale maps each size to its colour by name, not by position.
    var scaleDomain: [String] {
        reversesScaleDomain ? sizesInDataOrder.reversed() : sizesInDataOrder
    }

    // end

    /// The legend reads the scale's domain, in its order.
    var legendOrder: [String] {
        scaleDomain
    }

    /// The segments to draw, in the drawn order, each knowing whether it ends its stack.
    var segments: [DataOrderSegment] {
        let rows = drawnOrders
        return rows.enumerated().map { index, order in
            let isLast = !rows[(index + 1)...].contains { $0.drink == order.drink }
            return DataOrderSegment(drink: order.drink, size: order.size, cups: order.cups, isTopOfStack: isLast)
        }
    }

    /// Each drink's total cups, in bar order.
    var totals: [(drink: String, cups: Int)] {
        drinkOrder.map { drink in
            (drink, drawnOrders.filter { $0.drink == drink }.map(\.cups).reduce(0, +))
        }
    }

    var grandTotal: Int {
        orders.map(\.cups).reduce(0, +)
    }

    /// Nothing to draw: no rows, or only zeros, which would draw axes with no bars.
    var isEmpty: Bool {
        grandTotal == 0
    }

    var highestTotal: Int {
        totals.map(\.cups).max() ?? 0
    }

    // MARK: Words

    /// The direction the bars run in, in words: the chart mirrors in a right-to-left layout.
    static func direction(_ layoutDirection: LayoutDirection) -> String {
        layoutDirection == .rightToLeft ? "from right to left" : "from left to right"
    }

    /// The chart's message, true for every setting and layout direction: the bars' order and the drink
    /// with the most cups.
    func headline(locale: Locale, layoutDirection: LayoutDirection) -> String {
        guard !isEmpty else { return "No cups ordered yet today." }
        let most = highestTotal
        let leaders = totals.filter { $0.cups == most }.map(\.drink)
        let each = leaders.count > 1 ? " each" : ""
        return "\(CafeWording.list(drinkOrder)), \(Self.direction(layoutDirection)). "
            + "\(CafeWording.list(leaders)) sold the most: \(CafeWording.cups(most, locale: locale))\(each)."
    }

    /// The Audio Graph's summary: what is drawn, in actual values, including both orders. It names no
    /// direction: the Audio Graph plays the bars in order, whichever way the layout runs.
    func audioGraphSummary(locale: Locale) -> String {
        guard !isEmpty else { return "No cups ordered yet today." }
        let bars = totals.map { "\($0.drink) \(CafeWording.cups($0.cups, locale: locale))" }
        return "\(CafeWording.drinks(drinkOrder.count, locale: locale)), \(CafeWording.cups(grandTotal, locale: locale)) in total. "
            + "In order: \(CafeWording.list(bars)). "
            + "Each bar stacks \(CafeWording.list(stackOrder)) from the bottom up. "
            + "The legend lists \(CafeWording.list(legendOrder))."
    }

    /// What a change to the row order says, then the headline.
    func sortAnnouncement(locale: Locale, layoutDirection: LayoutDirection) -> String {
        let change = sortsByTotal ? "Rows sorted by total; the bars moved." : "Rows back in data order; the bars moved."
        return "\(change) \(headline(locale: locale, layoutDirection: layoutDirection))"
    }

    /// What a change to the scale's domain says, then the headline.
    func domainAnnouncement(locale: Locale, layoutDirection: LayoutDirection) -> String {
        "Legend now lists \(CafeWording.list(legendOrder)); the bars and stacks did not move. "
            + headline(locale: locale, layoutDirection: layoutDirection)
    }

    // MARK: Code

    /// The snippets for the current setting: the chart always, the sort and the domain when they are in effect.
    var snippets: [SnippetReference] {
        var references = [SnippetReference(name: "data-order-chart", title: "Stacked bars, ordered by the data")]
        if sortsByTotal {
            references.append(SnippetReference(name: "data-order-sort", title: "Sorting the rows ranks the bars"))
        }
        if reversesScaleDomain {
            references.append(SnippetReference(name: "data-order-domain", title: "The domain orders the legend"))
        }
        return references
    }
}
