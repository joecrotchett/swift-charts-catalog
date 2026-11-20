import Accessibility
import Foundation
import Observation
import SwiftUI

/// One drink's bar in the simpler chart: its total, and its sizes in words.
nonisolated struct SimplerChartTotal: Identifiable, Hashable {
    let drink: String
    let cups: Int
    /// "Small 34, Medium 58, and Large 36": the stack the drawn bar shows, in the data's order.
    let detail: String

    var id: String {
        drink
    }
}

/// One accessibility element as the screen predicts it: what VoiceOver reads first, then its value.
nonisolated struct SimplerChartElement: Identifiable, Hashable {
    let label: String
    let value: String

    var id: String {
        label
    }

    /// The two read together, as VoiceOver speaks them.
    var spoken: String {
        value.isEmpty ? label : "\(label), \(value)"
    }
}

/// What the Audio Graph is given, written out for the screen.
nonisolated struct SimplerChartAudioGraph: Hashable {
    let title: String
    let summary: String
    let xAxisTitle: String
    let yAxisTitle: String
    let categories: [String]
    /// The value axis's range in words, such as "0 to 200 cups".
    let yAxisRange: String
    /// Each series' name with its values in words, such as "Small: Latte 34, Tea 71, Mocha 22".
    let series: [String]
}

/// Every word the chart speaks, in one table, so a prediction that differs from what iOS reads is
/// replaced in one place. Each entry names the skill passage it is predicted from.
nonisolated struct SimplerChartSpeech {
    let orders: [DrinkOrder]
    /// Every count and number is written in this locale. It has no default: the view passes its environment's.
    let locale: Locale

    // MARK: The data, reshaped

    /// The drinks in the order they first appear, which is the drawn chart's order along x.
    var drinks: [String] {
        orders.map(\.drink).uniqued()
    }

    /// The sizes in the order they first appear, which is the order they stack in, bottom up.
    var sizes: [String] {
        orders.map(\.size).uniqued()
    }

    // snippet:simpler-chart-totals
    /// One total per drink, in the drawn chart's order, each with its sizes in words.
    var totals: [SimplerChartTotal] {
        drinks.map { drink in
            let rows = orders.filter { $0.drink == drink }
            let detail = CafeWording.list(rows.map { "\($0.size) \($0.cups.formatted(.number.locale(locale)))" })
            return SimplerChartTotal(drink: drink, cups: rows.map(\.cups).reduce(0, +), detail: detail)
        }
    }

    /// The value an element of the representation speaks: "128 cups: Small 34, Medium 58, and Large 36".
    func representationValue(_ total: SimplerChartTotal) -> String {
        "\(CafeWording.cups(total.cups, locale: locale)): \(total.detail)"
    }

    // end

    var grandTotal: Int {
        orders.map(\.cups).reduce(0, +)
    }

    /// Nothing to draw: no orders, or only zeros, whose bars would have no height.
    var isEmpty: Bool {
        grandTotal == 0
    }

    /// The top of the value axis, given to the drawn chart, the representation and the descriptor alike:
    /// the largest total rounded up to the next 50, so all three share one scale.
    var valueAxisTop: Int {
        let largest = totals.map(\.cups).max() ?? 0
        let step = 50
        return max(step, (largest + step - 1) / step * step)
    }

    // MARK: Headline

    /// Every drink with the largest total, in data order. Empty when nothing sold.
    var bestSellers: [SimplerChartTotal] {
        guard let most = totals.map(\.cups).max(), most > 0 else { return [] }
        return totals.filter { $0.cups == most }
    }

    var fewestSellers: [SimplerChartTotal] {
        guard let fewest = totals.map(\.cups).min(), grandTotal > 0 else { return [] }
        return totals.filter { $0.cups == fewest }
    }

    /// The chart's message, true of the bars as drawn: the tallest stack and its height.
    var headline: String {
        guard let most = bestSellers.first else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(most.cups, locale: locale)) across every size."
    }

    // MARK: Elements

    /// With the representation: one element per drink, its total then its sizes.
    /// `accessibility.md`, "When the elements should not follow the marks", and "Labels and values":
    /// a labelled `Plot` is one element with that label and value.
    var representationElements: [SimplerChartElement] {
        totals.map { total in
            SimplerChartElement(label: total.drink, value: representationValue(total))
        }
    }

    /// Without it: the framework's own element for each stack, its total and how many sizes.
    /// `accessibility-defaults.md`, the table under "Elements", row "Stacked marks":
    /// "Latte, total 128, 3 Sizes". The plural is the `.value` label, `CafeWording.size`, made plural.
    var defaultElements: [SimplerChartElement] {
        drinks.map { drink in
            let rows = orders.filter { $0.drink == drink }
            let total = rows.map(\.cups).reduce(0, +)
            let sizeCount = String(AttributedString(
                localized: "^[\(rows.count) \(CafeWording.size)](inflect: true)", locale: locale
            ).characters)
            return SimplerChartElement(
                label: drink,
                value: "total \(total.formatted(.number.locale(locale))), \(sizeCount)"
            )
        }
    }

    // MARK: Audio Graph

    static let xAxisTitle = CafeWording.drink
    static let yAxisTitle = CafeWording.cupsAxisTitle
    static let totalSeriesName = "All sizes"
    static let representationTitle = "Cups sold today by drink, every size together"
    static let stackedTitle = "Cups sold today by drink and size"

    /// The summary both descriptors speak: actual values, no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first, let fewest = fewestSellers.first else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(drinks.count, locale: locale)) in \(CafeWording.sizes(sizes.count, locale: locale)), "
            + "\(CafeWording.cups(grandTotal, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most.cups, locale: locale)). "
            + "Fewest: \(CafeWording.list(fewestSellers.map(\.drink))), \(CafeWording.cups(fewest.cups, locale: locale))."
    }

    /// With the representation: the descriptor on the simpler chart, one series of totals.
    var representationAudioGraph: SimplerChartAudioGraph {
        SimplerChartAudioGraph(
            title: Self.representationTitle,
            summary: audioGraphSummary,
            xAxisTitle: Self.xAxisTitle,
            yAxisTitle: Self.yAxisTitle,
            categories: drinks,
            yAxisRange: yAxisRange,
            series: [seriesLine(Self.totalSeriesName, totals.map { ($0.drink, $0.cups) })]
        )
    }

    /// Without it: the descriptor on the stacked chart, one series per size, each point its own piece.
    /// `audio-graph.md`: "In a stacked chart each point carries its piece's own value."
    var stackedAudioGraph: SimplerChartAudioGraph {
        SimplerChartAudioGraph(
            title: Self.stackedTitle,
            summary: audioGraphSummary,
            xAxisTitle: Self.xAxisTitle,
            yAxisTitle: Self.yAxisTitle,
            categories: drinks,
            yAxisRange: yAxisRange,
            series: sizes.map { size in
                seriesLine(size, orders.filter { $0.size == size }.map { ($0.drink, $0.cups) })
            }
        )
    }

    var yAxisRange: String {
        "\(0.formatted(.number.locale(locale))) to \(CafeWording.cups(valueAxisTop, locale: locale))"
    }

    private func seriesLine(_ name: String, _ points: [(String, Int)]) -> String {
        let values = points.map { "\($0.0) \(CafeWording.cups($0.1, locale: locale))" }
        return "\(name): \(values.joined(separator: ", "))"
    }

    // MARK: Announcement

    /// Said when the toggle changes what assistive technologies get: what changed, then the headline.
    func announcement(usesRepresentation: Bool) -> String {
        let change = usesRepresentation
            ? "VoiceOver now gets one bar per drink, with its sizes in words."
            : "VoiceOver now gets the stacked chart as drawn."
        return "\(change) \(headline)"
    }
}

/// The screen's state: whether the stacked chart carries a simpler representation.
@Observable
final class SimplerChartViewModel {
    let orders: [DrinkOrder]
    var usesRepresentation = true

    init(orders: [DrinkOrder] = CafeData.drinkOrders) {
        self.orders = orders
    }

    func speech(locale: Locale) -> SimplerChartSpeech {
        SimplerChartSpeech(orders: orders, locale: locale)
    }

    /// The elements predicted for the current state.
    func elements(locale: Locale) -> [SimplerChartElement] {
        let speech = speech(locale: locale)
        return usesRepresentation ? speech.representationElements : speech.defaultElements
    }

    /// The Audio Graph predicted for the current state.
    func audioGraph(locale: Locale) -> SimplerChartAudioGraph {
        let speech = speech(locale: locale)
        return usesRepresentation ? speech.representationAudioGraph : speech.stackedAudioGraph
    }

    /// The snippets the Code view shows for the current state.
    var snippets: [SnippetReference] {
        if usesRepresentation {
            [
                SnippetReference(name: "simpler-chart-representation", title: "The stacked chart with a representation"),
                SnippetReference(name: "simpler-chart-totals", title: "Totals and the sizes in words"),
                SnippetReference(name: "simpler-chart-totals-descriptor", title: "The descriptor on the representation"),
            ]
        } else {
            [
                SnippetReference(name: "simpler-chart-stacked", title: "The stacked chart, no representation"),
                SnippetReference(name: "simpler-chart-stacked-descriptor", title: "The descriptor on the stacked chart"),
            ]
        }
    }

    /// Every snippet the screen can show, for the registry.
    static let allSnippets: [SnippetReference] = [
        SnippetReference(name: "simpler-chart-representation", title: "The stacked chart with a representation"),
        SnippetReference(name: "simpler-chart-totals", title: "Totals and the sizes in words"),
        SnippetReference(name: "simpler-chart-totals-descriptor", title: "The descriptor on the representation"),
        SnippetReference(name: "simpler-chart-stacked", title: "The stacked chart, no representation"),
        SnippetReference(name: "simpler-chart-stacked-descriptor", title: "The descriptor on the stacked chart"),
    ]
}

/// The Audio Graph for the simpler chart: one series of totals over the drinks.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct SimplerChartTotalsDescriptor: AXChartDescriptorRepresentable {
    let speech: SimplerChartSpeech

    // snippet:simpler-chart-totals-descriptor
    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = speech.locale
        return AXChartDescriptor(
            title: SimplerChartSpeech.representationTitle,
            summary: speech.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: SimplerChartSpeech.xAxisTitle, categoryOrder: speech.drinks),
            // The same range as the drawn scale: one domain, given to both charts and to this.
            yAxis: AXNumericDataAxisDescriptor(
                title: SimplerChartSpeech.yAxisTitle,
                range: 0 ... Double(speech.valueAxisTop),
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: SimplerChartSpeech.totalSeriesName,
                isContinuous: false,
                dataPoints: speech.totals.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )]
        )
    }
    // end
}

/// The Audio Graph for the stacked chart as drawn: one series per size, each point that size's own cups.
nonisolated struct SimplerChartStackedDescriptor: AXChartDescriptorRepresentable {
    let speech: SimplerChartSpeech

    // snippet:simpler-chart-stacked-descriptor
    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = speech.locale
        let orders = speech.orders
        return AXChartDescriptor(
            title: SimplerChartSpeech.stackedTitle,
            summary: speech.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: SimplerChartSpeech.xAxisTitle, categoryOrder: speech.drinks),
            yAxis: AXNumericDataAxisDescriptor(
                title: SimplerChartSpeech.yAxisTitle,
                range: 0 ... Double(speech.valueAxisTop),
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            // A series per size, each point the piece's own value, not its height in the stack.
            series: speech.sizes.map { size in
                AXDataSeriesDescriptor(
                    name: size,
                    isContinuous: false,
                    dataPoints: orders.filter { $0.size == size }.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
                )
            }
        )
    }
    // end
}

private extension Array where Element: Hashable {
    /// The elements in order, each only the first time it appears.
    nonisolated func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
