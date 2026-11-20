import Charts
import CoreGraphics
import Foundation

/// The edge the value axis sits on. It moves the plot area inside the chart, and so inside the overlay.
enum ProxyPositionsAxisEdge: String, CaseIterable, Identifiable {
    case trailing = "Trailing"
    case leading = "Leading"

    var id: Self {
        self
    }

    /// The axis position the chart is given.
    var markPosition: AxisMarkPosition {
        switch self {
        case .trailing: .trailing
        case .leading: .leading
        }
    }
}

/// What the proxy found under the pointer: the drink whose band it is in, and the cups at its height.
nonisolated struct ProxyPositionsReading: Equatable {
    let drink: String
    let cups: Double
}

/// Moves positions between the overlay's coordinates, where a gesture's location and a placed view live,
/// and the plot area's, where every `ChartProxy` position lives. Plain values only: the plot frame is
/// read from the proxy in the view and handed in as a rectangle.
///
/// Seen on the iOS simulator in a right-to-left layout: the resolved plot frame, the proxy's positions
/// and a drag's location all measure x from the left edge, as in left to right, but `position(x:)`
/// measures it from the right edge. So a position is mirrored across the overlay's width on its way to
/// `position`, and a touch is not mirrored on its way to the proxy.
nonisolated struct ProxyPositionsMapping: Equatable {
    /// The plot area, in the overlay's coordinates (`geometry[proxy.plotFrame]`).
    let plotFrame: CGRect
    /// The overlay's width (`geometry.size.width`), across which `position` is mirrored in right to left.
    var overlayWidth: CGFloat = 0
    /// The layout direction the chart is drawn in.
    var isRightToLeft = false
    /// The mistake: proxy positions used as overlay positions, and the other way round.
    var ignoresOrigin = false

    /// A location in the overlay, such as a drag's, as a position the proxy can convert.
    func plotPoint(forOverlay location: CGPoint) -> CGPoint {
        ignoresOrigin ? Self.mistakenPlotPoint(forOverlay: location) : Self.plotPoint(forOverlay: location, in: plotFrame)
    }

    /// A position the proxy gave, as a point to hand to `position(_:)` in the overlay.
    func overlayPoint(forPlot point: CGPoint) -> CGPoint {
        ignoresOrigin
            ? Self.mistakenOverlayPoint(forPlot: point, overlayWidth: overlayWidth, isRightToLeft: isRightToLeft)
            : Self.overlayPoint(forPlot: point, in: plotFrame, overlayWidth: overlayWidth, isRightToLeft: isRightToLeft)
    }

    /// Whether a plot position lies on the plot. Outside it a number scale still answers, with a value
    /// beyond the axis, so the position is checked before it is converted.
    func contains(plotPoint point: CGPoint) -> Bool {
        (0 ... plotFrame.width).contains(point.x) && (0 ... plotFrame.height).contains(point.y)
    }

    /// The centre of a category's band, a range of plot positions.
    static func centre(of band: ClosedRange<CGFloat>) -> CGFloat {
        (band.lowerBound + band.upperBound) / 2
    }

    // snippet:chart-proxy-origin
    /// The proxy measures from the plot area's corner, not the overlay's:
    /// subtract the plot's origin from a touch, add it to a position.
    static func plotPoint(forOverlay location: CGPoint, in plotFrame: CGRect) -> CGPoint {
        CGPoint(x: location.x - plotFrame.minX, y: location.y - plotFrame.minY)
    }

    /// In right to left, `position(x:)` counts from the right edge,
    /// while the plot frame and the proxy count from the left: mirror x.
    static func overlayPoint(
        forPlot point: CGPoint, in plotFrame: CGRect, overlayWidth: CGFloat, isRightToLeft: Bool
    ) -> CGPoint {
        let x = point.x + plotFrame.minX
        return CGPoint(x: isRightToLeft ? overlayWidth - x : x, y: point.y + plotFrame.minY)
    }

    // end

    // snippet:chart-proxy-origin-mistake
    /// The mistake: the plot's origin left out. Right only while the plot
    /// starts at the overlay's left edge; an axis on the left moves it.
    static func mistakenPlotPoint(forOverlay location: CGPoint) -> CGPoint {
        location
    }

    static func mistakenOverlayPoint(
        forPlot point: CGPoint, overlayWidth: CGFloat, isRightToLeft: Bool
    ) -> CGPoint {
        CGPoint(x: isRightToLeft ? overlayWidth - point.x : point.x, y: point.y)
    }
    // end
}

/// The state of the Chart proxy screen: the sales, the controls, the plot frame the proxy reported, and
/// what is under the pointer.
@Observable
final class ProxyPositionsViewModel {
    /// The sales, most cups first: the headline is about the best seller, so the bars are ranked.
    let sales: [DrinkSales]
    var axisEdge: ProxyPositionsAxisEdge = .trailing
    var isShowingMistake = false
    /// What the proxy found under the pointer, while a drag is on the plot.
    var reading: ProxyPositionsReading?
    /// The plot area in the overlay's coordinates, as the proxy last reported it.
    private(set) var plotFrame: CGRect?
    /// The overlay's width, as last reported: `position(x:)` is mirrored across it in right to left.
    private(set) var overlayWidth: CGFloat = 0
    /// The layout direction the chart was last laid out in.
    private(set) var isRightToLeft = false
    /// A change made by a control whose effect on the headline arrives only after layout.
    private var pendingChange: String?

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = Self.ranked(sales)
    }

    /// Most cups first; a tie keeps the data's order.
    static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    /// The conversions in force, once the plot frame is known.
    var mapping: ProxyPositionsMapping? {
        plotFrame.map {
            ProxyPositionsMapping(
                plotFrame: $0, overlayWidth: overlayWidth, isRightToLeft: isRightToLeft, ignoresOrigin: isShowingMistake
            )
        }
    }

    /// The drinks the star marks: every one that sold the most.
    var bestSellers: [DrinkSales] {
        summary(locale: .current).bestSellers
    }

    /// How far, in whole points, the star is drawn from the band it marks. Zero unless the mistake is shown
    /// and the plot area does not start at the overlay's left edge (an axis on the left).
    var badgeOffset: Int {
        guard isShowingMistake, let plotFrame else { return 0 }
        return Int(plotFrame.minX.rounded())
    }

    func summary(locale: Locale) -> ProxyPositionsSummary {
        ProxyPositionsSummary(sales: sales, badgeOffset: badgeOffset, isRightToLeft: isRightToLeft, locale: locale)
    }

    /// The pointer's reading in words, shown and spoken alike: the band it is in and the height it is at,
    /// such as "Tea's band, 120 cups high". It is a height on the scale, not the drink's sales.
    func readout(locale: Locale) -> String? {
        reading.map { "\($0.drink)'s band, \(CafeWording.count($0.cups.rounded(), locale: locale)) high" }
    }

    /// The snippets for the current setting: the mistaken conversion replaces the right one.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "chart-proxy-overlay", title: "Values to positions and back"),
            isShowingMistake
                ? SnippetReference(name: "chart-proxy-origin-mistake", title: "The mistake: no plot origin")
                : SnippetReference(name: "chart-proxy-origin", title: "Overlay and plot coordinates"),
            SnippetReference(name: "chart-proxy-axis", title: "The axis that moves the plot"),
        ]
    }

    /// What the screen demonstrates, true in the layout direction the chart is drawn in.
    func explanation(isRightToLeft: Bool) -> String {
        let concept = """
        A chart's overlay is handed a ChartProxy, which converts between data values and positions: \
        positionRange(forX:) gives the best seller's band so a star can sit over it, and value(atX:) and \
        value(atY:) name the band and the height under your finger. Every proxy position is measured from the \
        plot area's corner, so subtract plotFrame's origin from a touch and add it to a position.
        """
        guard isRightToLeft else {
            return concept + " With the value axis on the trailing edge the two corners meet and leaving the origin "
                + "out goes unseen; on the leading edge it does not."
        }
        return concept + " In this right-to-left layout the plot frame, the proxy and a touch still count x from "
            + "the left, but position(x:) counts it from the right, so a position is also mirrored across the "
            + "overlay's width. Here the corners meet with the value axis on the leading edge, and leaving the "
            + "origin out goes unseen; on the trailing edge it does not."
    }

    // MARK: Changes

    /// Records the plot frame and overlay width the proxy reported, and the layout direction. Returns the
    /// announcement owed when that changed the headline after a control was used, so the change is said,
    /// not only drawn.
    func updatePlotFrame(
        _ frame: CGRect, overlayWidth: CGFloat = 0, isRightToLeft: Bool = false, locale: Locale
    ) -> String? {
        let before = summary(locale: locale).headline
        // Only the plot's origin and the direction can change the headline; a new height or width cannot,
        // so a control's pending change waits for the layout that does.
        let movesStar = plotFrame?.minX.rounded() != frame.minX.rounded() || self.isRightToLeft != isRightToLeft
        plotFrame = frame
        self.overlayWidth = overlayWidth
        self.isRightToLeft = isRightToLeft
        guard movesStar else { return nil }
        return takeAnnouncement(headlineBefore: before, locale: locale)
    }

    /// The axis moved. That restyles the chart and the picker speaks its own value, so it is announced only
    /// when it moves the misplaced star, which the headline reports. That happens after layout.
    func axisEdgeChanged() {
        pendingChange = isShowingMistake ? "Value axis moved to the \(axisEdge.rawValue.lowercased()) edge" : nil
    }

    /// The mistake was switched. Returns the announcement when the star moved, which changes the headline now.
    func mistakeChanged(locale: Locale) -> String? {
        let before = ProxyPositionsSummary(
            sales: sales,
            badgeOffset: isShowingMistake ? 0 : Int((plotFrame?.minX ?? 0).rounded()),
            isRightToLeft: isRightToLeft,
            locale: locale
        ).headline
        pendingChange = isShowingMistake ? "Plot origin left out" : "Plot origin added back"
        return takeAnnouncement(headlineBefore: before, locale: locale)
    }

    /// The pending change and the new headline when the headline changed. Either way the pending change
    /// is used up, so it is never said later about a change it did not cause.
    private func takeAnnouncement(headlineBefore: String, locale: Locale) -> String? {
        let after = summary(locale: locale).headline
        let change = pendingChange
        pendingChange = nil
        guard after != headlineBefore, let change else { return nil }
        return "\(change). \(after)"
    }
}

/// What the chart says in words: the headline and the Audio Graph's summary.
nonisolated struct ProxyPositionsSummary {
    /// The sales in the order the bars are drawn, most cups first.
    let sales: [DrinkSales]
    /// How far, in points, the star is drawn from its band; zero when it is placed right.
    let badgeOffset: Int
    /// The misplaced star is always drawn to the left of its band: before it in left to right, after it
    /// in right to left.
    var isRightToLeft = false
    let locale: Locale

    /// The value axis as drawn and as given to the descriptor: 0 to the most cups, rounded up to a tidy step.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// Nothing sold, or only zeros: there are no bars to draw.
    var isEmpty: Bool {
        total == 0
    }

    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// What is wrong with the star, when it is drawn in the wrong place.
    var badgeSentence: String? {
        guard badgeOffset > 0, !isEmpty else { return nil }
        let side = isRightToLeft ? "after" : "before"
        return "Each star is drawn \(CafeWording.points(Double(badgeOffset), locale: locale)) \(side) the bar it marks."
    }

    /// The best seller with its figure, and the star's misplacement when the mistake shows one.
    var headline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        let sentence = "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
        return [sentence, badgeSentence].compactMap(\.self).joined(separator: " ")
    }

    /// Actual values, then where the star is.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        let names = CafeWording.list(bestSellers.map(\.drink))
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(names), \(CafeWording.cups(most, locale: locale)), marked with a star. "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
            + (badgeSentence.map { " \($0)" } ?? "")
    }
}
