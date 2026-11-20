import Foundation
import Observation
import SwiftUI

/// The edge a picker puts an axis on. Leading and trailing are edges of a y axis, top and bottom of an x axis.
nonisolated enum AxisPositionEdge: String, CaseIterable, Identifiable {
    case leading
    case trailing
    case top
    case bottom

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .leading: "Leading"
        case .trailing: "Trailing"
        case .top: "Top"
        case .bottom: "Bottom"
        }
    }

    /// Whether the edge is a side of the chart, where a y axis goes, rather than its top or bottom.
    var isSide: Bool {
        self == .leading || self == .trailing
    }
}

/// Where an axis's labels sit against the plot area and their grid lines.
nonisolated enum AxisPositionPreset: String, CaseIterable, Identifiable {
    case automatic
    case aligned
    case extended
    case inset

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .aligned: "Aligned"
        case .extended: "Extended"
        case .inset: "Inset"
        }
    }
}

/// The two pickers of "Position and presets", and what each chart says about the axis they move.
@Observable
final class AxisPositionViewModel {
    /// The edge chosen. It moves the bar chart's value axis or its category axis, whichever runs along that edge,
    /// and the same for the horizontal bar chart. Starts at the bottom, where both charts are drawn exactly
    /// as the framework draws them with no axis code.
    var edge: AxisPositionEdge = .bottom
    /// The preset given to the axis that the edge moves. The other axis keeps the default.
    var preset: AxisPositionPreset = .automatic

    /// On vertical bars the y axis holds the numbers, so a side edge moves the value axis.
    var barsMovedAxis: String {
        edge.isSide ? "Value axis" : "Category axis"
    }

    /// On horizontal bars the y axis holds the names, so a side edge moves the category axis.
    var horizontalMovedAxis: String {
        edge.isSide ? "Category axis" : "Value axis"
    }

    /// The caption over the bar chart: which of its axes is set, where, and how.
    var barsCaption: String {
        caption(chart: "Bars", axis: barsMovedAxis)
    }

    /// The caption over the horizontal bar chart.
    var horizontalCaption: String {
        caption(chart: "Horizontal bars", axis: horizontalMovedAxis)
    }

    /// What the current setting draws that a reader might take for a fault, or `nil` when nothing does.
    /// Seen on the iOS simulator: names on the trailing edge in the inset style get no room in the chart.
    var note: String? {
        switch (edge, preset) {
        case (.trailing, .automatic):
            "The horizontal bars' names keep their default inset style, which on the trailing edge draws them "
                + "past the end of the plot, outside the chart's frame."
        case (.trailing, .inset):
            "Inset draws the bars' numbers inside the plot, and the horizontal bars' names past the end of the plot, "
                + "outside the chart's frame."
        case (.top, .inset), (.bottom, .inset):
            // Seen in renders: the vertical bars' names move inside the plot, and the bars, narrowed, are drawn over them.
            "Inset draws the moved axis's labels inside the plot, in the space the bars use: the vertical bars "
                + "narrow and cover their names."
        case (_, .inset):
            "Inset draws the moved axis's labels inside the plot, in the space the bars use."
        default:
            nil
        }
    }

    /// The snippets the Code view shows for the current edge: the axis each chart sets, and the presets.
    var snippets: [SnippetReference] {
        [
            SnippetReference(
                name: "axis-position-bars-\(edge.rawValue)",
                title: "Bars: \(barsMovedAxis.lowercased()) on the \(edge.rawValue) edge"
            ),
            SnippetReference(
                name: "axis-position-horizontal-\(edge.rawValue)",
                title: "Horizontal bars: \(horizontalMovedAxis.lowercased()) on the \(edge.rawValue) edge"
            ),
            SnippetReference(name: "axis-position-presets", title: "The four presets"),
        ]
    }

    /// The caption over the bar chart at a text size: from `AxisPositionTextSize.large` it names only the chart,
    /// so a caption of three lines does not take the height the bars need. The pickers below say the rest.
    func barsCaption(at size: DynamicTypeSize) -> String {
        AxisPositionTextSize.isLarge(size) ? "Bars" : barsCaption
    }

    /// The caption over the horizontal bar chart at a text size.
    func horizontalCaption(at size: DynamicTypeSize) -> String {
        AxisPositionTextSize.isLarge(size) ? "Horizontal bars" : horizontalCaption
    }

    private func caption(chart: String, axis: String) -> String {
        "\(chart): \(axis.lowercased()), \(edge.rawValue), \(preset.rawValue)"
    }
}

/// What the bar chart changes as the text grows. Seen in window renders on an iPhone 17: at Accessibility 5
/// the five value labels on the half-height chart's y axis piled on each other, and "Latte" and "Mocha" were
/// cut to "Lat…" and "Mo…" in bands a third of the plot wide.
nonisolated enum AxisPositionTextSize {
    /// From this size the bar chart's value axis is labelled every hundred cups, and the captions are short.
    static let large = DynamicTypeSize.accessibility3
    /// From this size the bar chart's drink names are turned to read top to bottom.
    static let largest = DynamicTypeSize.accessibility4
    /// Every hundred cups: 0, 100 and 200 on this data, instead of every fifty.
    static let largeValueStride = 100.0

    static func isLarge(_ size: DynamicTypeSize) -> Bool {
        size >= large
    }

    /// Whether the bar chart's names must be vertical to be read whole at this size.
    static func namesAreVertical(at size: DynamicTypeSize) -> Bool {
        size >= largest
    }
}

/// The screen's data: the first three drinks of `CafeData.drinkSales`. Two charts share one panel, so each
/// has half its height; with all five drinks the horizontal chart's rows are too short to draw a bar under
/// the names the default inset preset puts in them.
nonisolated enum AxisPositionData {
    static let sales = Array(CafeData.drinkSales.prefix(3))
    /// How many drinks the café sells, so the screen can say its three are not the whole day.
    static let menuCount = CafeData.drinkSales.count
}

/// What the charts say in words: the headline, and the summary the Audio Graph speaks. The pickers move
/// labels and never the data, so neither depends on them.
nonisolated struct AxisPositionSummary {
    let sales: [DrinkSales]
    /// The locale every count is written in. It has no default: the view passes its environment's.
    let locale: Locale
    /// How many drinks the café sells: the chart draws `sales.count` of them.
    var menuCount = AxisPositionData.menuCount

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// "3 of the 5 drinks", or "5 drinks" when every drink is drawn.
    var drinksDrawn: String {
        guard sales.count < menuCount else { return CafeWording.drinks(sales.count, locale: locale) }
        return "\(sales.count.formatted(.number.locale(locale))) of the \(CafeWording.drinks(menuCount, locale: locale))"
    }

    /// The chart's caption: today's cups, and which of the drinks they are.
    var caption: String {
        "Cups sold today, \(drinksDrawn)"
    }

    /// Every drink that sold the most, in data order; more than one on a tie, none when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order; none when nothing sold.
    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The message in a sentence, with its figure. True on a tie and when nothing sold.
    var headline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(drinksDrawn), \(CafeWording.cups(total, locale: locale)) between them. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
    }
}
