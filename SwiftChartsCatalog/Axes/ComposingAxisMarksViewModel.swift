import Accessibility
import Foundation
import SwiftUI

/// How the value axis is written: one `AxisMarks` holding every part, or two, each at its own values.
nonisolated enum ComposingAxisMarksComposition: String, CaseIterable, Identifiable {
    /// Grid line, tick and label at the same values.
    case oneSet
    /// Labels and ticks at some values, grid lines at twice as many.
    case twoSets

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .oneSet: "One AxisMarks"
        case .twoSets: "Two AxisMarks"
        }
    }
}

/// The parts of an axis mark the screen can draw, each switched on and off on its own.
nonisolated struct ComposingAxisMarksParts: Equatable {
    var gridLines = true
    var ticks = true
    var labels = true
}

/// The value scale and the values each `AxisMarks` marks, worked out from the data so the scale,
/// the axis and the Audio Graph all use the same numbers.
nonisolated struct ComposingAxisMarksScale: Equatable {
    /// The distance between two labels: 50 cups, or 100 at the accessibility text sizes so the labels do not collide.
    let labelStep: Int
    /// The top of the scale: the most cups rounded up to the next label, so the top grid line is labelled.
    let top: Int

    init(sales: [DrinkSales], isLargeText: Bool) {
        let step = isLargeText ? 100 : 50
        labelStep = step
        let most = max(sales.map(\.cups).max() ?? 0, 1)
        top = (most + step - 1) / step * step
    }

    /// The values that get a label (and, with one `AxisMarks`, a grid line and a tick too).
    var labelValues: [Int] {
        Array(stride(from: 0, through: top, by: labelStep))
    }

    /// The values that get a grid line when the axis is two `AxisMarks`: every half step.
    var minorGridValues: [Int] {
        Array(stride(from: 0, through: top, by: labelStep / 2))
    }
}

/// The state of "Composing axis marks": which parts are drawn, and in how many `AxisMarks`.
@Observable
final class ComposingAxisMarksViewModel {
    let sales: [DrinkSales]
    var composition: ComposingAxisMarksComposition = .oneSet
    var parts = ComposingAxisMarksParts()

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = sales
    }

    func scale(isLargeText: Bool) -> ComposingAxisMarksScale {
        ComposingAxisMarksScale(sales: sales, isLargeText: isLargeText)
    }

    func summary(locale: Locale, isLargeText: Bool) -> ComposingAxisMarksSummary {
        ComposingAxisMarksSummary(
            sales: sales, scale: scale(isLargeText: isLargeText), composition: composition, parts: parts, locale: locale
        )
    }

    /// The snippet for the current setting. Its title says which parts the closure lists.
    var snippets: [SnippetReference] {
        switch composition {
        case .oneSet:
            [SnippetReference(name: "composing-axis-marks-one-set", title: oneSetTitle)]
        case .twoSets:
            [SnippetReference(name: "composing-axis-marks-two-sets", title: twoSetsTitle)]
        }
    }

    private var oneSetTitle: String {
        var drawn: [String] = []
        if parts.gridLines { drawn.append("grid line") }
        if parts.ticks { drawn.append("tick") }
        if parts.labels { drawn.append("label") }
        guard !drawn.isEmpty else { return "An empty closure draws nothing on the axis" }
        let listed = CafeWording.list(drawn)
        let sentence = listed.prefix(1).uppercased() + listed.dropFirst()
        return parts.gridLines ? "\(sentence) in one AxisMarks" : "\(sentence): the closure drops the grid lines"
    }

    private var twoSetsTitle: String {
        parts.gridLines
            ? "Labels at some values, grid lines at more"
            : "The second closure drops the grid lines"
    }
}

/// What the chart says in words, for the current setting: the headline, the announcement when it
/// changes, and the Audio Graph's summary.
nonisolated struct ComposingAxisMarksSummary {
    let sales: [DrinkSales]
    let scale: ComposingAxisMarksScale
    let composition: ComposingAxisMarksComposition
    let parts: ComposingAxisMarksParts
    /// The locale every count is written in. It has no default: the view passes its environment's.
    let locale: Locale

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// Every drink that sold the most, in data order. More than one on a tie, none when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// The figure a reader can find on the axis as drawn: the labelled value at or below the tallest
    /// bar, or "under" the first label above zero. Nil when the labels are not drawn.
    var labelledFigure: String? {
        guard parts.labels, let most = bestSellers.first?.cups else { return nil }
        let below = most / scale.labelStep * scale.labelStep
        if below == most { return CafeWording.cups(most, locale: locale) }
        if below == 0 { return "under \(CafeWording.cups(scale.labelStep, locale: locale))" }
        return "over \(CafeWording.cups(below, locale: locale))"
    }

    /// The chart's message. Its figure comes from the axis labels, so with the labels off it gives none.
    var headline: String {
        guard !bestSellers.isEmpty else { return "No cups sold yet today." }
        let names = CafeWording.list(bestSellers.map(\.drink))
        if let labelledFigure {
            return "\(names) sold the most: \(labelledFigure)."
        }
        return "\(names) sold the most of \(CafeWording.drinks(sales.count, locale: locale))."
    }

    /// What the screen demonstrates, with the steps the axis is drawn with at this text size. It says
    /// "here" only when the chart shows it: two `AxisMarks` with the grid lines on.
    var explanation: String {
        let labels = CafeWording.cups(scale.labelStep, locale: locale)
        let lines = CafeWording.cups(scale.labelStep / 2, locale: locale)
        let twoSets = composition == .twoSets && parts.gridLines
            ? "Two AxisMarks in one axis put different parts at different values: here labels every \(labels) "
            + "and grid lines every \(lines)."
            : "Two AxisMarks in one axis can put different parts at different values, such as labels every "
            + "\(labels) and grid lines every \(lines)."
        return "An AxisMarks with a closure draws only the parts the closure lists: AxisGridLine across the plot, "
            + "AxisTick at its edge, AxisValueLabel for the text. Leave one out and that part is gone at every value. "
            + twoSets
    }

    /// Spoken when the labels are switched, since that changes the headline: what changed, then the headline.
    var labelsAnnouncement: String {
        "\(parts.labels ? "Axis labels shown" : "Axis labels hidden"). \(headline)"
    }

    /// The grid lines drawn, for the Audio Graph.
    var gridlineValues: [Int] {
        guard parts.gridLines else { return [] }
        return composition == .oneSet ? scale.labelValues : scale.minorGridValues
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups else { return "No cups sold yet today." }
        let fewest = sales.map(\.cups).min() ?? 0
        let slowest = CafeWording.list(sales.filter { $0.cups == fewest }.map(\.drink))
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(slowest), \(CafeWording.cups(fewest, locale: locale))."
    }
}

/// The chart for the Audio Graph: the drinks as categories, cups on a range that matches the drawn scale.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ComposingAxisMarksChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ComposingAxisMarksSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: summary.sales.map(\.drink)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: 0 ... Double(summary.scale.top),
            gridlinePositions: summary.gridlineValues.map(Double.init)
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: summary.sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today at the \(CafeWording.harbour) café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
