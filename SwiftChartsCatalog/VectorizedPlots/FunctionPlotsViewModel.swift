import Accessibility
import Foundation
import SwiftUI

/// The examples the screen's picker offers, in the manner of a function catalog: two functions drawn as
/// lines, the area between two functions, and two parametric curves drawn in true proportions.
/// Not tied to the main actor: a function plot's closure is `@Sendable` and calls these from anywhere.
nonisolated enum FunctionPlotsExample: String, CaseIterable, Identifiable {
    case sine
    case cubic
    case betweenTwo
    case rose
    case circle

    var id: String {
        rawValue
    }

    /// How the example is drawn.
    enum Kind {
        /// One function y = f(x), as a line.
        case line
        /// The area between two functions of x, with both drawn as lines.
        case area
        /// A parametric curve, x and y both functions of t.
        case parametric
    }

    var kind: Kind {
        switch self {
        case .sine, .cubic: .line
        case .betweenTwo: .area
        case .rose, .circle: .parametric
        }
    }

    /// The name in the picker and the caption above the chart.
    var title: String {
        switch self {
        case .sine: "Sine wave"
        case .cubic: "Cubic"
        case .betweenTwo: "Between two functions"
        case .rose: "Rose"
        case .circle: "Circle"
        }
    }

    /// The curve's equation as written, for the legend and the headline.
    var equation: String {
        switch self {
        case .sine: "y = sin x"
        case .cubic: "y = x³ − 3x"
        case .betweenTwo: "y = x and y = x² − 1"
        case .rose: "x = 4 cos 5t cos t, y = 4 cos 5t sin t"
        case .circle: "x = 3 cos t, y = 3 sin t"
        }
    }

    /// The equation as VoiceOver should say it, with no symbols left to guess at.
    var spokenEquation: String {
        switch self {
        case .sine: "y equals sine x"
        case .cubic: "y equals x cubed minus 3 x"
        case .betweenTwo: "y equals x, and y equals x squared minus 1"
        case .rose: "x equals 4 cosine 5 t times cosine t, y equals 4 cosine 5 t times sine t"
        case .circle: "x equals 3 cosine t, y equals 3 sine t"
        }
    }

    // snippet:function-plots-formulas
    /// y = f(x) for the examples drawn as one line.
    func y(at x: Double) -> Double {
        switch self {
        case .cubic: x * x * x - 3 * x
        default: sin(x) // The sine wave.
        }
    }

    /// The two functions the area between two functions lies between.
    static func lowerBound(at x: Double) -> Double {
        x
    }

    static func upperBound(at x: Double) -> Double {
        x * x - 1
    }

    /// (x, y) at t for the parametric examples.
    func point(at t: Double) -> (x: Double, y: Double) {
        switch self {
        case .rose: (x: 4 * cos(5 * t) * cos(t), y: 4 * cos(5 * t) * sin(t))
        default: (x: 3 * cos(t), y: 3 * sin(t)) // The circle.
        }
    }

    /// The values of t a parametric curve is drawn over: once round, and no more.
    var tDomain: ClosedRange<Double> {
        // A rose with an odd number of petals is complete after half a turn.
        self == .rose ? 0 ... .pi : 0 ... 2 * .pi
    }

    // end

    /// Each legend entry and series, for the examples with more than one line.
    static let lowerBoundName = "y = x"
    static let upperBoundName = "y = x² − 1"
    static let lowerBoundSpoken = "y equals x"
    static let upperBoundSpoken = "y equals x squared minus 1"

    /// Where the window starts: half its width, and half its height, about the origin.
    var defaultHalfWidth: Double {
        switch self {
        case .sine: 6
        case .cubic: 2.25
        case .betweenTwo: 2.5
        case .rose: 5
        case .circle: 4
        }
    }

    var defaultHalfHeight: Double {
        switch self {
        case .sine: 1.5
        case .cubic: 5
        case .betweenTwo: 4
        case .rose: 5
        case .circle: 4
        }
    }

    /// The ranges the two domain sliders cover.
    var halfWidthRange: ClosedRange<Double> {
        switch self {
        case .sine: 1 ... 20
        case .cubic, .betweenTwo: 1 ... 6
        case .rose, .circle: 2 ... 10
        }
    }

    var halfHeightRange: ClosedRange<Double> {
        switch self {
        case .sine: 0.5 ... 5
        case .cubic: 1 ... 20
        case .betweenTwo: 1 ... 10
        case .rose, .circle: 2 ... 10
        }
    }

    /// The parametric curves keep one unit as long on x as on y, so a circle is round.
    var keepsTrueProportions: Bool {
        kind == .parametric
    }
}

/// What the chart says in words for one example and window: the headline, each curve's element text,
/// and the Audio Graph's summary. Plain values only, so it can be tested and read from any thread.
nonisolated struct FunctionPlotsSummary {
    let example: FunctionPlotsExample
    /// The window is `-halfWidth ... halfWidth` on x and `-halfHeight ... halfHeight` on y.
    let halfWidth: Double
    let halfHeight: Double
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// How many points a curve is sampled at to find what it does inside the window.
    static let sampleCount = 801
    /// How many points of each curve the Audio Graph is given.
    static let describedPointCount = 61

    var xDomain: ClosedRange<Double> {
        -halfWidth ... halfWidth
    }

    var yDomain: ClosedRange<Double> {
        -halfHeight ... halfHeight
    }

    // snippet:function-plots-margin
    /// How far the scales reach past the window on each side, as a share of its half-width or half-height,
    /// so the labels centred on the window's end grid lines stay inside the chart.
    static let marginFraction = 0.08

    /// The margin past the window on x and on y, in the functions' own units. With true proportions both
    /// margins are the same number of units, so a unit stays as long on both axes, margins included.
    var margin: (x: Double, y: Double) {
        guard example.keepsTrueProportions else {
            return (halfWidth * Self.marginFraction, halfHeight * Self.marginFraction)
        }
        let shared = max(halfWidth, halfHeight) * Self.marginFraction
        return (shared, shared)
    }

    /// The scales' domains: the window and its margins.
    var xScaleDomain: ClosedRange<Double> {
        -(halfWidth + margin.x) ... halfWidth + margin.x
    }

    var yScaleDomain: ClosedRange<Double> {
        -(halfHeight + margin.y) ... halfHeight + margin.y
    }

    /// The plot's width over its height when the example keeps true proportions; nil when its shape is free.
    /// Worked out on the scales' domains, margins included, so one unit is as long on x as on y.
    var plotAspectRatio: Double? {
        guard example.keepsTrueProportions else { return nil }
        return (xScaleDomain.upperBound - xScaleDomain.lowerBound) / (yScaleDomain.upperBound - yScaleDomain.lowerBound)
    }

    // end

    /// A number as the chart's axis writes it, to at most two decimal places; never "-0".
    func number(_ value: Double) -> String {
        let shown = abs(value) < 0.005 ? 0 : value
        return shown.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
    }

    /// "-6 to 6"
    var xWindow: String {
        "\(number(-halfWidth)) to \(number(halfWidth))"
    }

    var yWindow: String {
        "\(number(-halfHeight)) to \(number(halfHeight))"
    }

    // MARK: Sampling

    /// Evenly spaced values across a range, both ends included.
    static func samples(across range: ClosedRange<Double>, count: Int) -> [Double] {
        guard count > 1 else { return [range.lowerBound] }
        let step = (range.upperBound - range.lowerBound) / Double(count - 1)
        return (0 ..< count).map { range.lowerBound + Double($0) * step }
    }

    /// The lowest and highest value a function of x takes across the window's x domain.
    func extremes(of function: (Double) -> Double) -> (low: Double, high: Double) {
        let values = Self.samples(across: xDomain, count: Self.sampleCount).map(function).filter(\.isFinite)
        return (values.min() ?? 0, values.max() ?? 0)
    }

    /// How a function's values sit in the window: "from -1 to 1", or where they leave it.
    func rangePhrase(low: Double, high: Double) -> String {
        let tolerance = 0.000_001
        let leavesBottom = low < -halfHeight - tolerance
        let leavesTop = high > halfHeight + tolerance
        switch (leavesBottom, leavesTop) {
        case (false, false):
            return "from \(number(low)) to \(number(high))"
        case (false, true):
            return "from \(number(low)) up past the top of the window, y = \(number(halfHeight))"
        case (true, false):
            return "from below the bottom of the window, y = \(number(-halfHeight)), up to \(number(high))"
        case (true, true):
            return "past both edges of the window, y = \(number(-halfHeight)) and \(number(halfHeight))"
        }
    }

    // MARK: The area between two functions

    /// Where y = x meets y = x² − 1: x² − x − 1 = 0.
    static let crossings = [(1 - 5.0.squareRoot()) / 2, (1 + 5.0.squareRoot()) / 2]

    /// The crossings drawn inside the window, where the shaded region narrows to nothing.
    var visibleCrossings: [Double] {
        Self.crossings.filter { abs($0) <= halfWidth && abs(FunctionPlotsExample.lowerBound(at: $0)) <= halfHeight }
    }

    // MARK: Parametric curves

    /// The farthest the whole curve reaches from the origin along each axis.
    var parametricReach: (x: Double, y: Double) {
        let points = Self.samples(across: example.tDomain, count: Self.sampleCount).map(example.point(at:))
        return (points.map { abs($0.x) }.max() ?? 0, points.map { abs($0.y) }.max() ?? 0)
    }

    /// The edges of the window the curve runs past: "x = ±3", "x = ±3 and y = ±2", or nil when it fits.
    var parametricCutEdges: String? {
        let reach = parametricReach
        let tolerance = 0.000_001
        var edges: [String] = []
        if reach.x > halfWidth + tolerance { edges.append("x = ±\(number(halfWidth))") }
        if reach.y > halfHeight + tolerance { edges.append("y = ±\(number(halfHeight))") }
        return edges.isEmpty ? nil : CafeWording.list(edges)
    }

    private var parametricShape: String {
        example == .rose ? "A rose of five petals" : "A circle centred on the origin"
    }

    // MARK: Words

    /// The chart's message in a sentence, worked out from the window as it is drawn.
    var headline: String {
        switch example.kind {
        case .line:
            let range = extremes(of: example.y(at:))
            return "From x = \(xWindow), \(example.equation) runs \(rangePhrase(low: range.low, high: range.high))."
        case .area:
            let crossings = visibleCrossings.map { "x = \(number($0))" }
            guard !crossings.isEmpty else {
                return "Inside this window \(example.equation) do not cross, so the shaded region between them never closes."
            }
            return "The shaded region between \(example.equation) closes where they cross: \(CafeWording.list(crossings))."
        case .parametric:
            if let edges = parametricCutEdges {
                return "\(parametricShape), cut off where it reaches past \(edges)."
            }
            return example == .rose
                ? "A rose of five petals, each reaching \(number(4)) from the origin."
                : "A circle of radius \(number(3)), round because one unit is as long on both axes."
        }
    }

    /// One curve as VoiceOver hears it: what it is, then what it does in the window.
    struct SpokenCurve: Equatable {
        let label: String
        let value: String
    }

    /// The element text for each labelled curve, in the order the chart draws them.
    var spokenCurves: [SpokenCurve] {
        switch example.kind {
        case .line:
            let range = extremes(of: example.y(at:))
            return [SpokenCurve(
                label: example.spokenEquation,
                value: "x from \(xWindow), y runs \(rangePhrase(low: range.low, high: range.high))"
            )]
        case .area:
            let lower = extremes(of: FunctionPlotsExample.lowerBound(at:))
            let upper = extremes(of: FunctionPlotsExample.upperBound(at:))
            let crossings = visibleCrossings.map { "x = \(number($0))" }
            let meeting = crossings.isEmpty ? "; the two do not cross in the window" : "; meets the other at \(CafeWording.list(crossings))"
            return [
                SpokenCurve(
                    label: FunctionPlotsExample.lowerBoundSpoken,
                    value: "x from \(xWindow), y runs \(rangePhrase(low: lower.low, high: lower.high))\(meeting)"
                ),
                SpokenCurve(
                    label: FunctionPlotsExample.upperBoundSpoken,
                    value: "x from \(xWindow), y runs \(rangePhrase(low: upper.low, high: upper.high))\(meeting)"
                ),
            ]
        case .parametric:
            let reach = parametricReach
            var value = "\(example.spokenEquation); x from \(number(-reach.x)) to \(number(reach.x)), "
                + "y from \(number(-reach.y)) to \(number(reach.y))"
            if let edges = parametricCutEdges { value += "; cut off past \(edges)" }
            return [SpokenCurve(label: parametricShape, value: value)]
        }
    }

    /// Actual values, no judgement; the same facts as the headline, with the window stated.
    var audioGraphSummary: String {
        "Window x from \(xWindow), y from \(yWindow). \(headline)"
    }
}

/// The screen's state: the chosen example and the window onto it.
@Observable
final class FunctionPlotsViewModel {
    private(set) var example: FunctionPlotsExample
    /// Half the window's width and height, each set by a slider. The window is centred on the origin.
    var halfWidth: Double
    var halfHeight: Double

    init(example: FunctionPlotsExample = .sine) {
        self.example = example
        halfWidth = example.defaultHalfWidth
        halfHeight = example.defaultHalfHeight
    }

    /// Switches to another example and puts its window back where the example starts. Returns the
    /// announcement for the change: a different curve is a change to what the chart draws.
    @discardableResult
    func select(_ newExample: FunctionPlotsExample, locale: Locale) -> String {
        example = newExample
        halfWidth = newExample.defaultHalfWidth
        halfHeight = newExample.defaultHalfHeight
        return "Showing \(newExample.title), \(newExample.equation). \(summary(locale: locale).headline)"
    }

    func summary(locale: Locale) -> FunctionPlotsSummary {
        FunctionPlotsSummary(example: example, halfWidth: halfWidth, halfHeight: halfHeight, locale: locale)
    }

    /// A new identity for the chart whenever what VoiceOver reads changes, so it never keeps old words.
    var chartIdentity: String {
        "\(example.rawValue) \(halfWidth) \(halfHeight)"
    }

    /// What each slider shows beside its title, and what it says: the setting, then the headline.
    func xSliderText(locale: Locale) -> String {
        summary(locale: locale).xWindow
    }

    func xSliderSpokenValue(locale: Locale) -> String {
        let summary = summary(locale: locale)
        return "x from \(summary.xWindow). \(summary.headline)"
    }

    func ySliderText(locale: Locale) -> String {
        summary(locale: locale).yWindow
    }

    func ySliderSpokenValue(locale: Locale) -> String {
        let summary = summary(locale: locale)
        return "y from \(summary.yWindow). \(summary.headline)"
    }

    /// The code that draws the current example.
    var snippets: [SnippetReference] {
        let drawing = switch example.kind {
        case .line: SnippetReference(name: "function-plots-line", title: "A function as a line")
        case .area: SnippetReference(name: "function-plots-area", title: "The area between two functions")
        case .parametric: SnippetReference(name: "function-plots-parametric", title: "A parametric curve")
        }
        var snippets = [
            drawing,
            SnippetReference(name: "function-plots-formulas", title: "The functions"),
            SnippetReference(name: "function-plots-domain", title: "The window onto the function"),
            SnippetReference(name: "function-plots-origin-axes", title: "Axes through the origin"),
        ]
        snippets.append(SnippetReference(name: "function-plots-margin", title: "Room for the end labels"))
        if example.keepsTrueProportions {
            snippets.append(SnippetReference(name: "function-plots-proportions", title: "True proportions"))
        }
        return snippets
    }
}

/// The Audio Graph's account of the chart: numeric x and y, one series per curve, sampled inside the window.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct FunctionPlotsChartDescriptor: AXChartDescriptorRepresentable {
    let summary: FunctionPlotsSummary

    /// The axis titles: the same words as the plots' `x:` and `y:` labels.
    static let xTitle = "x"
    static let yTitle = "y"

    /// Points of a function of x inside the window, so the Audio Graph plays only what is drawn.
    private func points(of function: (Double) -> Double) -> [AXDataPoint] {
        FunctionPlotsSummary.samples(across: summary.xDomain, count: FunctionPlotsSummary.describedPointCount)
            .map { (x: $0, y: function($0)) }
            .filter { $0.y.isFinite && summary.yDomain.contains($0.y) }
            .map { AXDataPoint(x: $0.x, y: $0.y) }
    }

    func series() -> [AXDataSeriesDescriptor] {
        let example = summary.example
        switch example.kind {
        case .line:
            return [AXDataSeriesDescriptor(name: example.equation, isContinuous: true, dataPoints: points(of: example.y(at:)))]
        case .area:
            return [
                AXDataSeriesDescriptor(
                    name: FunctionPlotsExample.lowerBoundName, isContinuous: true,
                    dataPoints: points(of: FunctionPlotsExample.lowerBound(at:))
                ),
                AXDataSeriesDescriptor(
                    name: FunctionPlotsExample.upperBoundName, isContinuous: true,
                    dataPoints: points(of: FunctionPlotsExample.upperBound(at:))
                ),
            ]
        case .parametric:
            // The points follow t, not x, so x is not in order: described like a line over unordered values.
            let points = FunctionPlotsSummary.samples(across: example.tDomain, count: FunctionPlotsSummary.describedPointCount)
                .map(example.point(at:))
                .filter { summary.xDomain.contains($0.x) && summary.yDomain.contains($0.y) }
                .map { AXDataPoint(x: $0.x, y: $0.y) }
            return [AXDataSeriesDescriptor(name: example.equation, isContinuous: false, dataPoints: points)]
        }
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = summary
        return AXChartDescriptor(
            title: "Function plot: \(summary.example.title), \(summary.example.equation)",
            summary: summary.audioGraphSummary,
            xAxis: AXNumericDataAxisDescriptor(
                title: Self.xTitle, range: summary.xDomain, gridlinePositions: []
            ) { $0.isFinite ? "x = \(summary.number($0))" : "" },
            yAxis: AXNumericDataAxisDescriptor(
                title: Self.yTitle, range: summary.yDomain, gridlinePositions: []
            ) { $0.isFinite ? "y = \(summary.number($0))" : "" },
            additionalAxes: [],
            series: series()
        )
    }
}
