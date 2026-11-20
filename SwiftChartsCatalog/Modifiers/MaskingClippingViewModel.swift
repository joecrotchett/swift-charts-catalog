import Foundation
import Observation

/// What the bars are cut to: nothing, a shape (`clipShape`) or other chart content (`mask`).
enum MaskingClippingShape: String, CaseIterable, Identifiable {
    case none
    case pill
    case blocks

    var id: Self {
        self
    }

    /// The picker's word for it.
    var title: String {
        switch self {
        case .none: "None"
        case .pill: "Pill"
        case .blocks: "Blocks"
        }
    }

    /// The code region that draws the bars this way.
    var snippets: [SnippetReference] {
        switch self {
        case .none:
            [SnippetReference(name: "masking-clipping-none", title: "Bars with no clip")]
        case .pill:
            [SnippetReference(name: "masking-clipping-pill", title: "clipShape(Capsule())")]
        case .blocks:
            [
                SnippetReference(name: "masking-clipping-blocks", title: "mask with chart content"),
                SnippetReference(name: "masking-clipping-block-ranges", title: "The blocks the mask is made of"),
            ]
        }
    }
}

/// One block of a bar in the masked form: a stretch of the value axis, in cups.
nonisolated struct MaskingClippingBlock: Identifiable, Hashable {
    let start: Int
    let end: Int

    var id: Int {
        start
    }
}

/// The state of the "Masking and clipping" screen: the data, in ranked order, and how the bars are cut.
@Observable
final class MaskingClippingViewModel {
    /// The drinks, most cups first, since the headline is about which sold the most.
    let sales: [DrinkSales]
    var shape: MaskingClippingShape = .pill

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = Self.ranked(sales)
    }

    /// Most cups first; drinks with the same cups keep their data order, so a tie always draws the same way.
    nonisolated static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    var snippets: [SnippetReference] {
        shape.snippets
    }

    func summary(locale: Locale) -> MaskingClippingSummary {
        MaskingClippingSummary(sales: sales, locale: locale)
    }
}

// snippet:masking-clipping-block-ranges
/// The pieces a bar of `cups` is cut into: one per `size` cups, with a strip of `gap` cups left
/// empty under each block that has another above it. The last block ends exactly at `cups`, so
/// the masked bar still reaches its value.
nonisolated func maskingClippingBlocks(cups: Int, size: Int = 20, gap: Int = 2) -> [MaskingClippingBlock] {
    guard cups > 0, size > gap, gap >= 0 else { return [] }
    return stride(from: 0, to: cups, by: size).map { start in
        let hasBlockAbove = start + size < cups
        return MaskingClippingBlock(start: start, end: hasBlockAbove ? start + size - gap : cups)
    }
}

// end

/// What the chart says in words: the headline and the Audio Graph's summary. The cut does not
/// change a value, so both are the same for every shape.
nonisolated struct MaskingClippingSummary {
    let sales: [DrinkSales]
    let locale: Locale

    /// The cups axis as drawn, from zero to the most rounded up to the axis step (164 → 200): the chart's scale
    /// and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    var headline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
    }
}
