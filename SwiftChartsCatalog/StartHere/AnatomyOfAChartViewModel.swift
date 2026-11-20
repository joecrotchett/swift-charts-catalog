import Foundation
import Observation

/// One of the parts a chart is made of.
nonisolated enum ChartPart: String, CaseIterable, Identifiable {
    case marks, scales, axes, legend, plotArea

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .marks: "Marks"
        case .scales: "Scales"
        case .axes: "Axes"
        case .legend: "Legend"
        case .plotArea: "Plot area"
        }
    }

    /// Marks, scales, axes and the legend are what a chart is built from.
    var isBuildingBlock: Bool {
        self != .plotArea
    }

    /// The axes, the legend and the plot area are the parts with modifiers of their own.
    var isCustomisable: Bool {
        self == .axes || self == .legend || self == .plotArea
    }

    /// What the part is and where its code is, in a sentence or two.
    var summary: String {
        switch self {
        case .marks:
            "Marks are the shapes that represent the data: here one BarMark for each drink and size. "
                + "They are the only part you write; everything else is generated from them."
        case .scales:
            "Scales turn data values into positions and colours. Plotting a value creates its scale: the drink on x, "
                + "the cups on y, the size as colour. The note on the chart reads the three scales back from the chart."
        case .axes:
            "Axes explain the position scales with grid lines, ticks and labels. "
                + "chartXAxis and chartYAxis restyle or replace them, as they do here to draw them heavier."
        case .legend:
            "The legend explains the colour scale. It is there because the marks use foregroundStyle(by:), and chartLegend "
                + "places or hides it. The automatic legend has no styling of its own, so the other parts step back."
        case .plotArea:
            "The plot area is the rectangle the marks are drawn in, inside the axes and the legend. "
                + "chartPlotStyle styles it, here with a tint and a border, and leaves the labels around it alone."
        }
    }
}

/// Numbers that belong to this chart's drawing.
nonisolated enum AnatomyMetrics {
    /// How far the parts that are not highlighted step back.
    static let fadedOpacity = 0.3
    static let mutedGridLineOpacity = 0.2
    static let mutedLabelOpacity = 0.6
    static let plotTintOpacity = 0.15
    static let plotBorderWidth: CGFloat = 2
    static let emphasisedAxisLineWidth: CGFloat = 1
    /// The height of the three-line note on the scales at the default text size.
    static let scaleNoteHeight: CGFloat = 68
    /// The strip of space between neighbouring segments of a stack.
    static let segmentGap: CGFloat = 1
}

/// How the chart is drawn for one highlight: which parts are at full strength and which step back.
nonisolated struct AnatomyLook: Equatable {
    enum AxisEmphasis: Equatable {
        /// The axes as the framework draws them.
        case standard
        /// Fainter grid lines and labels, while another part is highlighted.
        case muted
        /// Heavier grid lines and ticks, and labels at full strength.
        case emphasised
    }

    var marksOpacity = 1.0
    var axes = AxisEmphasis.standard
    var showsScaleNote = false
    var styledPlotArea = false

    init(highlight: ChartPart?) {
        switch highlight {
        case nil:
            break
        case .marks:
            axes = .muted
        case .scales:
            marksOpacity = AnatomyMetrics.fadedOpacity
            showsScaleNote = true
        case .axes:
            marksOpacity = AnatomyMetrics.fadedOpacity
            axes = .emphasised
        case .legend:
            marksOpacity = AnatomyMetrics.fadedOpacity
            axes = .muted
        case .plotArea:
            marksOpacity = AnatomyMetrics.fadedOpacity
            axes = .muted
            styledPlotArea = true
        }
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct AnatomySummary {
    struct DrinkTotal: Equatable {
        let drink: String
        let cups: Int
    }

    let orders: [DrinkOrder]

    /// Every drink in data order, which is the order of the bars.
    var drinks: [String] {
        Self.unique(orders.map(\.drink))
    }

    /// Every size in data order, which is the order of the stack and of the legend.
    var sizes: [String] {
        Self.unique(orders.map(\.size))
    }

    /// The height of each bar: a drink's cups over all sizes.
    var totals: [DrinkTotal] {
        drinks.map { drink in
            DrinkTotal(drink: drink, cups: orders.filter { $0.drink == drink }.map(\.cups).reduce(0, +))
        }
    }

    var total: Int {
        orders.map(\.cups).reduce(0, +)
    }

    /// The cups axis as drawn, for the descriptor. This chart's subject is the scales the framework makes, so its y
    /// scale stays automatic (the scale note reads it back from the proxy); `ChartAxis` gives the same rounded top
    /// the automatic axis draws (0 to 200 for a tallest stack of 164), so the Audio Graph reads the drawn ends.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: totals.map(\.cups))
    }

    /// Nothing to draw: no rows, or rows that are all zero.
    var isEmpty: Bool {
        total == 0
    }

    /// Every drink with the tallest bar. More than one on a tie.
    var bestSellers: [DrinkTotal] {
        guard !isEmpty, let most = totals.map(\.cups).max() else { return [] }
        return totals.filter { $0.cups == most }
    }

    /// Every drink with the shortest bar.
    var slowestSellers: [DrinkTotal] {
        guard !isEmpty, let fewest = totals.map(\.cups).min() else { return [] }
        return totals.filter { $0.cups == fewest }
    }

    /// The chart's message, with a figure that is the height of a bar. True on a tie and when nothing sold.
    var headline: String {
        guard let most = bestSellers.first?.cups else { return Self.nothingSold }
        return "\(Self.names(bestSellers)) sold the most: \(Self.spokenCups(most))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else { return Self.nothingSold }
        return "\(Self.counted(drinks.count, "drink")) in \(Self.counted(sizes.count, "size")): "
            + "\(sizes.formatted(.list(type: .and))). "
            + "\(Self.spokenCups(total)) in total. "
            + "Most: \(Self.names(bestSellers)), \(Self.spokenCups(most)). "
            + "Fewest: \(Self.names(slowestSellers)), \(Self.spokenCups(fewest))."
    }

    static let nothingSold = "No cups sold yet today."

    static func names(_ totals: [DrinkTotal]) -> String {
        totals.map(\.drink).formatted(.list(type: .and))
    }

    /// A count with its unit as a plain string that agrees in number: "1 cup", "164 cups".
    static func spokenCups(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) cup](inflect: true)").characters)
    }

    /// A count with a noun that agrees in number: "1 size", "3 sizes".
    static func counted(_ count: Int, _ noun: String) -> String {
        count == 1 ? "\(count.formatted()) \(noun)" : "\(count.formatted()) \(noun)s"
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

/// The state of "Anatomy of a chart": which part is highlighted, and what follows from it.
@Observable
final class AnatomyOfAChartViewModel {
    /// The part that stands out, or `nil` for the chart as it is.
    var highlight: ChartPart?
    let orders: [DrinkOrder]

    init(orders: [DrinkOrder] = CafeData.drinkOrders, highlight: ChartPart? = nil) {
        self.orders = orders
        self.highlight = highlight
    }

    var summary: AnatomySummary {
        AnatomySummary(orders: orders)
    }

    /// The same for every highlight: highlighting changes how the parts are drawn, never the data.
    var headline: String {
        summary.headline
    }

    var look: AnatomyLook {
        AnatomyLook(highlight: highlight)
    }

    /// The sentence under the picker.
    var highlightSummary: String {
        highlight?.summary ?? "Choose a part to make it stand out on the chart and to see its code in See Code."
    }

    /// What is said aloud when the highlight changes, for people who cannot see the chart change.
    var announcement: String {
        switch highlight {
        case nil:
            "No part highlighted. The chart shows the same cups as before."
        case .scales:
            "Scales highlighted. The bars are drawn shorter to make room for a note on the three scales. "
                + "The chart shows the same cups as before."
        case let part?:
            "\(part.title) highlighted. The chart shows the same cups as before."
        }
    }

    /// The code that produces or customises the highlighted part. With no highlight, the whole chart in order.
    var snippets: [SnippetReference] {
        switch highlight {
        case nil:
            [
                SnippetReference(name: Self.marksSnippet, title: "Marks"),
                SnippetReference(name: Self.scalesSnippet, title: "Scales"),
                SnippetReference(name: Self.axesSnippet, title: "Axes"),
                SnippetReference(name: Self.axisMarksSnippet, title: "What each axis draws"),
                SnippetReference(name: Self.legendSnippet, title: "Legend"),
                SnippetReference(name: Self.plotAreaSnippet, title: "Plot area"),
            ]
        case .marks:
            [SnippetReference(name: Self.marksSnippet, title: "One BarMark per drink and size")]
        case .scales:
            [
                SnippetReference(name: Self.marksSnippet, title: "Each plotted value creates a scale"),
                SnippetReference(name: Self.scalesSnippet, title: "Customising a colour scale and a position scale"),
                SnippetReference(name: Self.scaleNoteSnippet, title: "Reading the scales back"),
            ]
        case .axes:
            [
                SnippetReference(name: Self.axesSnippet, title: "Replacing both axes"),
                SnippetReference(name: Self.axisMarksSnippet, title: "What each axis draws"),
            ]
        case .legend:
            [
                SnippetReference(name: Self.marksSnippet, title: "foregroundStyle(by:) adds the legend"),
                SnippetReference(name: Self.legendSnippet, title: "Placing the legend"),
            ]
        case .plotArea:
            [SnippetReference(name: Self.plotAreaSnippet, title: "Styling the plot area")]
        }
    }

    static let marksSnippet = "anatomy-of-a-chart-marks"
    static let scalesSnippet = "anatomy-of-a-chart-scales"
    static let scaleNoteSnippet = "anatomy-of-a-chart-scale-note"
    static let axesSnippet = "anatomy-of-a-chart-axes"
    static let axisMarksSnippet = "anatomy-of-a-chart-axis-marks"
    static let legendSnippet = "anatomy-of-a-chart-legend"
    static let plotAreaSnippet = "anatomy-of-a-chart-plot-area"
}
