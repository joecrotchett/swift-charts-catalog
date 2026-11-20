import Charts
import Foundation
import Observation

/// The sizes a cup comes in: every value the colour scale can ever have, in the order the data lists them.
nonisolated enum StableColoursSize: String, CaseIterable, Identifiable, Plottable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: Self {
        self
    }
}

/// One stacked segment: a drink's cups in one size.
nonisolated struct StableColoursOrder: Identifiable, Hashable {
    let drink: String
    let size: StableColoursSize
    let cups: Int

    var id: String {
        "\(drink)-\(size.rawValue)"
    }

    /// The café's orders by drink and size, with any size the scale does not know left out.
    static func orders(from rows: [DrinkOrder]) -> [StableColoursOrder] {
        rows.compactMap { row in
            StableColoursSize(rawValue: row.size).map { StableColoursOrder(drink: row.drink, size: $0, cups: row.cups) }
        }
    }
}

/// The state of the "Stable colours" screen: which sizes the filter shows, and whether the colour
/// scale's domain is fixed. Turning the domain off is the mistake the screen demonstrates.
@Observable
final class StableColoursViewModel {
    /// Every order, before the filter.
    let orders: [StableColoursOrder]
    /// The sizes the filter chips let through.
    private(set) var shownSizes: Set<StableColoursSize> = Set(StableColoursSize.allCases)
    /// Whether the chart fixes its colour domain to every size. Off is the mistake.
    var isDomainFixed = true

    init(orders: [StableColoursOrder] = StableColoursOrder.orders(from: CafeData.drinkOrders)) {
        self.orders = orders
    }

    // MARK: Filter

    func isShown(_ size: StableColoursSize) -> Bool {
        shownSizes.contains(size)
    }

    /// Shows or hides one size, and returns the sentence to announce: what changed, then the headline.
    @discardableResult
    func setShown(_ size: StableColoursSize, _ isShown: Bool, locale: Locale) -> String {
        if isShown { shownSizes.insert(size) } else { shownSizes.remove(size) }
        return "\(size.rawValue) \(isShown ? "shown" : "hidden"). \(headline(locale: locale))"
    }

    /// Fixes or removes the colour domain, and returns the sentence to announce.
    @discardableResult
    func setDomainFixed(_ isFixed: Bool, locale: Locale) -> String {
        isDomainFixed = isFixed
        return "\(isFixed ? "Colour domain fixed" : "Colour domain removed"). \(headline(locale: locale))"
    }

    /// The orders the chart draws: those in a size the filter shows.
    var visibleOrders: [StableColoursOrder] {
        orders.filter { shownSizes.contains($0.size) }
    }

    /// The sizes the chart draws, in the order they first appear in the data, which is the order
    /// the automatic colours are handed out in.
    var visibleSizes: [StableColoursSize] {
        var sizes: [StableColoursSize] = []
        for order in visibleOrders where !sizes.contains(order.size) {
            sizes.append(order.size)
        }
        return sizes
    }

    /// Whether there is anything to draw: no sizes, or only zeros, draw no bars.
    var hasBars: Bool {
        visibleOrders.contains { $0.cups > 0 }
    }

    // MARK: Colours

    /// The position in the automatic palette the chart gives a size, or `nil` when it is not drawn.
    /// With the domain fixed it is the size's place among every size; without it, its place among
    /// the sizes the filtered data contains, so it moves when a size before it is filtered out.
    func colourIndex(of size: StableColoursSize) -> Int? {
        guard visibleSizes.contains(size) else { return nil }
        return isDomainFixed ? StableColoursSize.allCases.firstIndex(of: size) : visibleSizes.firstIndex(of: size)
    }

    /// Each drawn size whose colour is another size's, paired with the size whose colour it took.
    var colourSwaps: [(size: StableColoursSize, takes: StableColoursSize)] {
        visibleSizes.compactMap { size in
            guard let index = colourIndex(of: size), index != StableColoursSize.allCases.firstIndex(of: size) else {
                return nil
            }
            return (size, StableColoursSize.allCases[index])
        }
    }

    // MARK: Words

    /// The chart's message, true for every filter and both settings of the domain.
    func headline(locale: Locale) -> String {
        let total = StableColoursSize.allCases.count
        guard hasBars else {
            return visibleSizes.isEmpty
                ? "No sizes shown: choose a size to draw its cups."
                : "No cups sold in the sizes shown."
        }
        let shown = visibleSizes.count
        let lead = shown == total
            ? "All \(CafeWording.sizes(total, locale: locale)) shown"
            : "\(CafeWording.list(visibleSizes.map(\.rawValue))) shown, \(shown.formatted(.number.locale(locale))) of \(CafeWording.sizes(total, locale: locale))"
        let swaps = colourSwaps
        guard !swaps.isEmpty else { return "\(lead): each size keeps its own colour." }
        let phrases = swaps.map { "\($0.size.rawValue) is drawn in \($0.takes.rawValue)’s colour" }
        return "\(lead): \(CafeWording.list(phrases))."
    }

    /// Each drink's cups across the sizes shown, in data order.
    var drinkTotals: [(drink: String, cups: Int)] {
        var totals: [(drink: String, cups: Int)] = []
        for order in visibleOrders {
            if let index = totals.firstIndex(where: { $0.drink == order.drink }) {
                totals[index].cups += order.cups
            } else {
                totals.append((order.drink, order.cups))
            }
        }
        return totals
    }

    /// The Audio Graph's summary: the sizes drawn and each drink's stacked total, in actual values,
    /// then the headline, so what the colours do is spoken there too.
    func audioGraphSummary(locale: Locale) -> String {
        guard hasBars else { return headline(locale: locale) }
        let sizes = "Sizes shown: \(CafeWording.list(visibleSizes.map(\.rawValue)))."
        let totals = drinkTotals.map { "\($0.drink) \(CafeWording.cups($0.cups, locale: locale))" }
        return "\(sizes) \(CafeWording.list(totals)) in total. \(headline(locale: locale))"
    }

    // MARK: Code

    /// The code for the current setting of the domain.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "stable-colours-bars", title: "Bars coloured by size"),
            isDomainFixed
                ? SnippetReference(name: "stable-colours-fixed-domain", title: "A fixed colour domain")
                : SnippetReference(name: "stable-colours-no-domain", title: "No domain (the mistake)"),
        ]
    }
}
