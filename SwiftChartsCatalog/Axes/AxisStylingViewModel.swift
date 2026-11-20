import Accessibility
import Foundation
import Observation
import SwiftUI

/// The five styling choices the screen's toggles make, one axis-mark property each.
/// None of them changes the data, the scale or the kind of mark.
nonisolated struct AxisStylingStyle: Equatable {
    /// The y axis's grid lines drawn dashed instead of solid: the grid line's stroke.
    var dashedGridLines = false
    /// The y axis's grid lines drawn orange instead of the default grey: the grid line's colour.
    var orangeGridLines = false
    /// The y axis's ticks drawn longer than the default: the tick's length.
    var longTicks = false
    /// The x axis's drink names in a bold caption: the label's font.
    var boldLabels = false
    /// The x axis's drink names turned to read top to bottom: the label's orientation.
    var verticalLabels = false

    /// Whether the drink names must be turned at this text size whatever the toggle says. From extra
    /// large up, horizontal names overlap on the narrowest supported iPhone (seen in renders at 311 points).
    static func namesMustBeVertical(at dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize >= .xLarge
    }

    /// The style as drawn at a text size: the choices made, with the names turned where they must be.
    func drawn(at dynamicTypeSize: DynamicTypeSize) -> AxisStylingStyle {
        var drawn = self
        drawn.verticalLabels = verticalLabels || Self.namesMustBeVertical(at: dynamicTypeSize)
        return drawn
    }
}

/// The state of "Styling axis marks": which axis-mark styles are on, and the snippets that show them.
@Observable
final class AxisStylingViewModel {
    var style = AxisStylingStyle()

    /// One snippet per styled part, each the code that draws that part as it is drawn at this text size.
    func snippets(at dynamicTypeSize: DynamicTypeSize) -> [SnippetReference] {
        Self.snippets(for: style.drawn(at: dynamicTypeSize))
    }

    nonisolated static func snippets(for style: AxisStylingStyle) -> [SnippetReference] {
        let grid = switch (style.dashedGridLines, style.orangeGridLines) {
        case (false, false): SnippetReference(name: "axis-styling-grid-default", title: "Y axis: default grid line")
        case (true, false): SnippetReference(name: "axis-styling-grid-dashed", title: "Y axis: dashed grid line")
        case (false, true): SnippetReference(name: "axis-styling-grid-orange", title: "Y axis: orange grid line")
        case (true, true): SnippetReference(name: "axis-styling-grid-dashed-orange", title: "Y axis: dashed, orange grid line")
        }
        let tick = style.longTicks
            ? SnippetReference(name: "axis-styling-tick-long", title: "Y axis: longer tick")
            : SnippetReference(name: "axis-styling-tick-default", title: "Y axis: default tick")
        let label = switch (style.boldLabels, style.verticalLabels) {
        case (false, false): SnippetReference(name: "axis-styling-label-default", title: "X axis: default label")
        case (true, false): SnippetReference(name: "axis-styling-label-bold", title: "X axis: bold label")
        case (false, true): SnippetReference(name: "axis-styling-label-vertical", title: "X axis: vertical label")
        case (true, true): SnippetReference(name: "axis-styling-label-bold-vertical", title: "X axis: bold, vertical label")
        }
        return [grid, tick, label]
    }
}

/// What the chart says in words: its headline and the summary the Audio Graph speaks.
/// Styling the axis marks changes neither, so neither takes the style.
nonisolated struct AxisStylingSummary {
    let sales: [DrinkSales]
    /// The locale every count is written in. It has no default: the view passes its environment's.
    let locale: Locale

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// Whether there is anything to draw: no drinks, or only zeros, draw no bars.
    var hasSales: Bool {
        total > 0
    }

    /// Every drink that sold the most, in data order; more than one on a tie, none when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order; none when nothing sold.
    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), hasSales else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The tallest bar, by name and value: a figure the reader finds on the chart.
    var headline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
    }
}

/// The chart for the Audio Graph. Styling the axis marks changes nothing a listener hears, so the
/// descriptor is the same in every state. Not tied to the main actor: the accessibility system calls
/// its value description when it chooses.
nonisolated struct AxisStylingChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = AxisStylingSummary(sales: sales, locale: locale)
        let locale = locale
        return AXChartDescriptor(
            title: "Cups sold today at the \(CafeWording.harbour) café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: sales.map(\.drink)),
            // The bars grow from zero, so the drawn scale starts at zero.
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle,
                range: ChartAxis.valueDomain(for: sales.map(\.cups)),
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: false,
                dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )]
        )
    }
}
