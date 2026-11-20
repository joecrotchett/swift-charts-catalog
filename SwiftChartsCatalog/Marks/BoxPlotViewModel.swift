import Foundation
import Observation

/// Which of a box plot's three layers are drawn.
nonisolated struct BoxPlotLayers: Hashable {
    /// The thin line from the shortest wait to the longest.
    var range = true
    /// The box over the middle half of the waits.
    var middleHalf = true
    /// The line across the box at the median.
    var median = true

    var isEmpty: Bool {
        !range && !middleHalf && !median
    }
}

/// The words this screen needs that `CafeWording` does not have.
nonisolated enum BoxPlotWording {
    static let minimum = "Shortest wait"
    static let lowerQuartile = "Lower quartile"
    static let median = "Median wait"
    static let upperQuartile = "Upper quartile"
    static let maximum = "Longest wait"
    static let range = "Range"
    static let middleHalf = "Middle half"
    static let medianLayer = "Median"
}

/// The state of the box plot screen: the waits, and the layers switched on.
@Observable
final class BoxPlotViewModel {
    var layers = BoxPlotLayers()
    let waits: [WaitQuartiles]

    init(waits: [WaitQuartiles] = CafeData.waitQuartiles) {
        self.waits = waits
    }

    /// What the chart says in words for the layers now drawn.
    func summary(locale: Locale) -> BoxPlotSummary {
        BoxPlotSummary(waits: waits, layers: layers, locale: locale)
    }

    /// The code behind what is drawn: the chart, then one snippet for each layer that is on.
    var snippets: [SnippetReference] {
        var snippets = [SnippetReference(name: "box-plot-chart", title: "One element per café")]
        if layers.range {
            snippets.append(SnippetReference(name: "box-plot-range", title: "Range: a rule"))
        }
        if layers.middleHalf {
            snippets.append(SnippetReference(name: "box-plot-middle-half", title: "Middle half: a bar"))
        }
        if layers.median {
            snippets.append(SnippetReference(name: "box-plot-median", title: "Median: a rectangle"))
        }
        return snippets
    }

    /// What to say aloud when the layers change: what changed, then the headline.
    func announcement(after previous: BoxPlotLayers, locale: Locale) -> String {
        var changes: [String] = []
        if previous.range != layers.range {
            changes.append("\(BoxPlotWording.range) \(layers.range ? "shown" : "hidden").")
        }
        if previous.middleHalf != layers.middleHalf {
            changes.append("\(BoxPlotWording.middleHalf) \(layers.middleHalf ? "shown" : "hidden").")
        }
        if previous.median != layers.median {
            changes.append("\(BoxPlotWording.medianLayer) \(layers.median ? "shown" : "hidden").")
        }
        return (changes + [summary(locale: locale).headline]).joined(separator: " ")
    }
}

/// The chart's words: its headline, the explanation beside it, what each element says, and the
/// summary the Audio Graph speaks. Every one follows the layers that are drawn.
nonisolated struct BoxPlotSummary {
    let waits: [WaitQuartiles]
    let layers: BoxPlotLayers
    let locale: Locale

    /// No rows, or only zeros: there are no waits to draw.
    var hasNoWaits: Bool {
        waits.allSatisfy { $0.maximum == 0 }
    }

    /// The largest value in the data, which the value axis always reaches whichever layers are on.
    var longestWait: Double {
        waits.map(\.maximum).max() ?? 0
    }

    /// The smallest value in the data.
    var shortestWait: Double {
        waits.map(\.minimum).min() ?? 0
    }

    /// The value axis, from zero to the longest wait rounded up (0 to 400 for the café's waits): the chart's
    /// scale and the descriptor's range, so a layer stays where it is when another is switched off and the
    /// Audio Graph reads the ends the chart draws.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [shortestWait, longestWait])
    }

    /// The chart's message in a sentence. Its figure is one the layers now drawn show.
    var headline: String {
        if hasNoWaits { return "No waits recorded yet." }
        if layers.median {
            let (stores, value) = highest(\.median)
            return "The highest median wait was at \(stores): \(seconds(value))."
        }
        if layers.middleHalf {
            let (stores, value) = highest(\.upperQuartile)
            return "The middle half of waits ran highest at \(stores): up to \(seconds(value))."
        }
        if layers.range {
            let (stores, value) = highest(\.maximum)
            return "The longest wait was at \(stores): \(seconds(value))."
        }
        return "No layer is switched on."
    }

    /// What the screen says about the form, one sentence per layer that is drawn.
    var explanation: String {
        var sentences = [
            "Swift Charts has no box plot mark: the form is up to three marks that share one position on the x axis, "
                + "in one Plot so each café is read as one element.",
        ]
        if layers.range {
            sentences.append("The thin line is a RuleMark from the shortest wait to the longest.")
        }
        if layers.middleHalf {
            sentences.append("The box is a BarMark over the middle half of the waits, from the lower quartile to the upper.")
        }
        if layers.median {
            sentences.append("The line across is a RectangleMark two points high at the median, the wait half the orders beat.")
        }
        if layers.isEmpty {
            sentences.append("Switch a layer on to draw it.")
        }
        return sentences.joined(separator: " ")
    }

    /// What one café's element says: only the layers that are drawn, in actual values.
    func elementValue(for wait: WaitQuartiles) -> String {
        var parts: [String] = []
        if layers.median {
            parts.append("\(BoxPlotWording.medianLayer) \(seconds(wait.median)).")
        }
        if layers.middleHalf {
            parts.append("\(BoxPlotWording.middleHalf) \(number(wait.lowerQuartile)) to \(seconds(wait.upperQuartile)).")
        }
        if layers.range {
            parts.append("\(BoxPlotWording.range) \(number(wait.minimum)) to \(seconds(wait.maximum)).")
        }
        return parts.joined(separator: " ")
    }

    /// Actual values only, for the Audio Graph.
    var audioGraphSummary: String {
        if hasNoWaits { return "No waits recorded yet." }
        if layers.isEmpty { return "No layer is switched on." }
        return waits.map { "\($0.store): \(elementValue(for: $0))" }.joined(separator: " ")
    }

    /// Seconds that agree in number, with at most one decimal place, written for the locale: "1 second",
    /// "143.5 seconds".
    func seconds(_ amount: Double) -> String {
        CafeWording.seconds(amount, locale: locale)
    }

    func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
    }

    /// Every café that shares the highest value of one of the five numbers, and that value.
    private func highest(_ value: KeyPath<WaitQuartiles, Double>) -> (stores: String, value: Double) {
        let most = waits.map { $0[keyPath: value] }.max() ?? 0
        let stores = waits.filter { $0[keyPath: value] == most }.map(\.store)
        return (stores.formatted(.list(type: .and).locale(locale)), most)
    }
}
