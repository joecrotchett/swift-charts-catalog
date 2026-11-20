import CoreGraphics
import Foundation
import Observation

/// Where the label in the donut's hole is placed: behind the marks or in front of them.
enum PlotAreaViewPlacement: String, CaseIterable, Identifiable {
    case background
    case overlay

    var id: String {
        rawValue
    }

    /// The modifier's name, as the picker shows it.
    var modifierName: String {
        switch self {
        case .background: "chartBackground"
        case .overlay: "chartOverlay"
        }
    }
}

/// Where the label and its disc go, worked out from the plot's frame as plain values.
nonisolated struct PlotAreaViewHoleLayout: Equatable {
    /// The centre of the plot area, which is the centre of the ring.
    let center: CGPoint
    /// The side of the largest square that fits in the hole: the room the label has.
    let labelSide: CGFloat
    /// The diameter of the disc behind the label. Wider than the hole, so it shows which layer it is on.
    let discDiameter: CGFloat
}

/// The marks' own proportions, which belong to this chart rather than to the app's layout.
nonisolated enum PlotAreaViewMetrics {
    /// The hole's radius as a fraction of the ring's outer radius.
    static let innerRadiusRatio = 0.618
    static let angularInset: CGFloat = 1.5
    static let cornerRadius: CGFloat = 4
    /// The opacity of every sector but the best seller.
    static let fadedOpacity = 0.35
    /// The disc behind the label reaches this fraction of the way to the ring's outer edge,
    /// past the hole and over the inside of the ring.
    static let discRatio: CGFloat = 0.8
    static let legendSpacing: CGFloat = 12
}

/// What the screen says in words: its headline, the label in the hole, each sector's text and the
/// Audio Graph's summary. Not tied to the main actor, so the chart descriptor can use it.
nonisolated struct PlotAreaViewSummary {
    /// The sectors, largest first, drinks that sold nothing left out (a sector of zero draws nothing).
    let shares: [DrinkSales]
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    init(sales: [DrinkSales], locale: Locale) {
        shares = Self.ranked(sales)
        self.locale = locale
    }

    /// Largest first, so the biggest sector starts at 12 o'clock; a tie keeps the data's order.
    static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .filter { $0.element.cups > 0 }
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    var total: Int {
        shares.map(\.cups).reduce(0, +)
    }

    /// The Audio Graph's value range: 0 to the day's total, of which each sector is a share (never empty).
    var valueRange: ClosedRange<Double> {
        0 ... Double(max(total, 1))
    }

    /// Every drink that sold the most, in data order. More than one on a tie; none when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = shares.first?.cups else { return [] }
        return shares.filter { $0.cups == most }
    }

    /// The names of the best sellers, joined the English way: "Tea", "Latte and Tea".
    var bestSellerNames: String {
        CafeWording.list(bestSellers.map(\.drink))
    }

    /// The best sellers' cups, "164 cups"; empty when nothing sold.
    var bestSellerCups: String {
        guard let most = bestSellers.first?.cups else { return "" }
        return CafeWording.cups(most, locale: locale)
    }

    /// Whether a sector is drawn at full strength: the best sellers are, the rest are faded.
    func isHighlighted(_ share: DrinkSales) -> Bool {
        bestSellers.contains { $0.id == share.id }
    }

    /// The caption above the names in the hole.
    var labelCaption: String {
        "Most sold"
    }

    /// The chart's message in a sentence, carrying a figure the hole and the sectors show.
    var headline: String {
        guard !bestSellers.isEmpty else { return "No cups sold yet today." }
        return "\(bestSellerNames) sold the most: \(bestSellerCups)."
    }

    /// A sector's share of the day, "30%", in the view's locale.
    func percent(of share: DrinkSales) -> String {
        guard total > 0 else { return "" }
        let fraction = Double(share.cups) / Double(total)
        return fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// What a sector's accessibility element says after the drink's name: "164 cups, 30% of the day".
    func sectorValue(_ share: DrinkSales) -> String {
        "\(CafeWording.cups(share.cups, locale: locale)), \(percent(of: share)) of the day"
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let fewest = shares.last else { return "No cups sold yet today." }
        let slowest = shares.filter { $0.cups == fewest.cups }.map(\.drink)
        return "\(CafeWording.drinks(shares.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(bestSellerNames), \(bestSellerCups). "
            + "Fewest: \(CafeWording.list(slowest)), \(CafeWording.cups(fewest.cups, locale: locale))."
    }

    /// Where the label goes in a plot of this frame. A sector chart draws its ring in the largest
    /// circle that fits the plot, centred in it.
    static func holeLayout(in plotFrame: CGRect) -> PlotAreaViewHoleLayout {
        let outerRadius = min(plotFrame.width, plotFrame.height) / 2
        let holeRadius = outerRadius * PlotAreaViewMetrics.innerRadiusRatio
        return PlotAreaViewHoleLayout(
            center: CGPoint(x: plotFrame.midX, y: plotFrame.midY),
            labelSide: max(0, holeRadius * 2.squareRoot()),
            discDiameter: max(0, outerRadius * 2 * PlotAreaViewMetrics.discRatio)
        )
    }
}

/// The screen's state: where the label in the hole is placed, and the sales it describes.
@Observable
final class PlotAreaViewViewModel {
    var placement: PlotAreaViewPlacement = .background
    let sales: [DrinkSales]

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = sales
    }

    /// Whether any drink sold a cup: without one there are no sectors and the placeholder is shown.
    var hasData: Bool {
        sales.contains { $0.cups > 0 }
    }

    func summary(locale: Locale) -> PlotAreaViewSummary {
        PlotAreaViewSummary(sales: sales, locale: locale)
    }

    /// The code for the current placement, then the label that both placements share.
    var snippets: [SnippetReference] {
        let placementSnippet = switch placement {
        case .background:
            SnippetReference(name: "a-view-in-the-plot-area-background", title: "chartBackground")
        case .overlay:
            SnippetReference(name: "a-view-in-the-plot-area-overlay", title: "chartOverlay")
        }
        return [
            placementSnippet,
            SnippetReference(name: "a-view-in-the-plot-area-hole-label", title: "Centring on plotFrame"),
        ]
    }

    /// What the screen demonstrates, true of the chart as it is drawn now.
    /// - Parameter isLabelShown: false at the accessibility text sizes, where the label is left out.
    func explanation(isLabelShown: Bool) -> String {
        // True with or without a chart: what plotFrame is.
        let concept = """
        chartBackground and chartOverlay hand their view a ChartProxy. Its plotFrame, read in a GeometryReader, \
        is the rectangle the marks are drawn in, not the whole chart, which also holds the legend.
        """
        // With nothing sold the placeholder stands in for the chart: there is no ring and no hole.
        guard hasData else { return concept }
        let centring = isLabelShown
            ? " Centred on that rectangle, the label sits in the middle of the hole and not in the middle of the whole chart."
            : " Centred on that rectangle, the disc sits in the middle of the ring and not in the middle of the whole chart."
        let layer = switch (placement, isLabelShown) {
        case (.background, true):
            " As a background the label and its disc are drawn behind the sectors. VoiceOver would still read the "
                + "label, so it is hidden from VoiceOver here: the headline says the same."
        case (.overlay, true):
            " As an overlay they are drawn in front of the sectors, so the disc now covers the inside of the ring, "
                + "and VoiceOver reads the label as an element of its own."
        case (.background, false):
            " As a background the disc is drawn behind the sectors."
        case (.overlay, false):
            " As an overlay the disc is drawn in front of the sectors, so it covers the inside of the ring."
        }
        let textSize = isLabelShown
            ? ""
            : " At this text size the hole is too small for the label, so it is left out; the headline says the same."
        return concept + centring + layer + textSize
    }
}
