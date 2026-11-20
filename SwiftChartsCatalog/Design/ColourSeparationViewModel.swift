import Accessibility
import CoreGraphics
import Foundation
import Observation
import SwiftUI

/// The state of "Colour: separation": the drinks, largest first, and whether neighbouring segments
/// are separated by a gap or left touching (the mistake the screen shows on purpose).
@Observable
final class ColourSeparationViewModel {
    /// The drinks with sales, largest first, so the donut's biggest sector starts at 12 o'clock and the
    /// bar stacks in the same order. A drink with no cups has no segment and no sector, so it is left out.
    let shares: [DrinkSales]
    /// The mistake: neighbouring segments drawn with no gap between them.
    var isTouching = false

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        shares = ColourSeparationSummary.drawn(sales)
    }

    // snippet:colour-separation-gap
    /// Points taken off each side of a segment or sector: two neighbours together leave twice this.
    var gapEachSide: CGFloat {
        isTouching ? 0 : ColourSeparationMetrics.gapEachSide
    }

    // end

    /// The width of the strip of background between two neighbouring segments, in points.
    var gapBetweenSegments: CGFloat {
        gapEachSide * 2
    }

    /// Whether there is anything to draw. With no sales, or only zeros, a placeholder replaces both charts.
    var hasChart: Bool {
        !shares.isEmpty
    }

    /// The colour scale's domain, in the order the segments stack, so the legend reads in the same order
    /// as the bar and the ring, and both charts give each drink the same colour.
    var drinkNames: [String] {
        shares.map(\.drink)
    }

    /// A new identity for both charts whenever the descriptor's words change, so the Audio Graph does not
    /// keep the summary it read for the other state.
    var chartIdentity: String {
        isTouching ? "touching" : "separated"
    }

    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "colour-separation-gap", title: "The gap"),
            SnippetReference(name: "colour-separation-bar", title: "A gap between stacked segments"),
            SnippetReference(name: "colour-separation-donut", title: "Angular inset between sectors"),
        ]
    }

    func summary(locale: Locale) -> ColourSeparationSummary {
        ColourSeparationSummary(shares: shares, gapBetweenSegments: Double(gapBetweenSegments), locale: locale)
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline
    }

    /// The explanation under the chart. True in both states: it says what the gap is, and what the reader
    /// sees when it is switched off.
    func explanation(locale: Locale) -> String {
        let each = CafeWording.points(Double(ColourSeparationMetrics.gapEachSide), locale: locale)
        let gap = CafeWording.points(Double(ColourSeparationMetrics.gapEachSide * 2), locale: locale)
        return "Where coloured segments meet, a thin strip of empty space lets each one be seen as its own shape. "
            + "Each segment of the bar is clipped to a rectangle inset by \(each), and each sector of the donut has an "
            + "angular inset of \(each): both leave a gap of \(gap) between neighbours. "
            + "Let the segments touch and every border, in the bar and in the ring, is only a change of colour. "
            + "A segment of the bar wide enough for its drink's name carries it; a narrower one is left unnamed, and "
            + "only its colour, matched in the legend under the donut, says which drink it is."
    }
}

/// Constants that belong to this screen's marks.
nonisolated enum ColourSeparationMetrics {
    /// Points off each side: 1.5 is the size `marks.md` recommends for `angularInset`, used for the bar too,
    /// so both charts show the same 3-point gap.
    static let gapEachSide: CGFloat = 1.5
    /// The single stacked bar's height.
    static let barHeight: CGFloat = 36
    /// The donut's hole, as a fraction of its outer radius (`gallery/donut.md`).
    static let innerRadiusRatio: CGFloat = 0.618
    /// How much of the hole's width the centre label may use, leaving a margin inside the ring.
    static let labelWidthRatio: CGFloat = 0.85
    /// The space between the ring and its legend (`gallery/donut.md`).
    static let legendSpacing: CGFloat = 18
}

/// What the charts say in words: the headline, each element's value and the Audio Graph's summary.
nonisolated struct ColourSeparationSummary {
    let shares: [DrinkSales]
    /// The strip of background between two neighbours, in points; zero when they touch.
    let gapBetweenSegments: Double
    let locale: Locale

    /// The drinks with sales, largest first; a tie keeps the data's order.
    static func drawn(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .filter { $0.element.cups > 0 }
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    var total: Int {
        shares.map(\.cups).reduce(0, +)
    }

    /// Every drink that sold the most, in the order drawn.
    var bestSellers: [DrinkSales] {
        guard let most = shares.first?.cups else { return [] }
        return shares.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in the order drawn.
    var slowestSellers: [DrinkSales] {
        guard let fewest = shares.last?.cups else { return [] }
        return shares.filter { $0.cups == fewest }
    }

    /// The names of the best sellers, as the donut's hole shows them.
    var bestSellerNames: String {
        CafeWording.list(bestSellers.map(\.drink))
    }

    /// The best sellers' cups, as the donut's hole shows them: "164 cups", or "90 cups each" on a tie.
    var bestSellerCups: String {
        guard let cups = bestSellers.first?.cups else { return "" }
        let count = CafeWording.cups(cups, locale: locale)
        return bestSellers.count > 1 ? "\(count) each" : count
    }

    /// The headline. Its figure is the one written in the donut's hole.
    var headline: String {
        guard !bestSellers.isEmpty else { return "No cups sold yet today." }
        return "\(bestSellerNames) sold the most today: \(bestSellerCups)."
    }

    /// An element's value: its cups, then its share of the total. "164 cups, 30% of all cups".
    func elementValue(for share: DrinkSales) -> String {
        let fraction = total > 0 ? Double(share.cups) / Double(total) : 0
        let percent = fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
        return "\(CafeWording.cups(share.cups, locale: locale)), \(percent) of all cups"
    }

    /// What the gap is in this state, said in words, so the Audio Graph describes what is drawn.
    var separationSentence: String {
        guard gapBetweenSegments > 0 else { return "Neighbouring segments touch, with no gap between them." }
        return "Neighbouring segments are separated by a gap of \(CafeWording.points(gapBetweenSegments, locale: locale))."
    }

    /// Actual values only, then how the segments are drawn.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(shares.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale)). "
            + separationSentence
    }
}

/// The Audio Graph for either chart: the drinks as categories, one series of cups. A single stacked bar
/// and a donut have no automatic Audio Graph, so without this they would have none.
nonisolated struct ColourSeparationDescriptor: AXChartDescriptorRepresentable {
    /// "as one bar" or "as a donut".
    enum Form {
        case bar, donut

        var title: String {
            switch self {
            case .bar: "Cups sold today by drink, as one stacked bar"
            case .donut: "Cups sold today by drink, as a donut"
            }
        }
    }

    let form: Form
    let summary: ColourSeparationSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let shares = summary.shares
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: shares.map(\.drink))
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            // Both forms draw each drink as a share of the total: the bar's scale runs to it, and so does the ring.
            range: 0 ... Double(summary.total),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.cups,
            isContinuous: false,
            dataPoints: shares.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: form.title,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
