import Foundation
import Observation

/// The functions the screen can graph. Each runs past the y scale's domain where it is drawn, so leaving
/// the plot area unclipped is a mistake whichever is chosen. Only the fit needs `.nan` to be drawn right:
/// the others break, or stop, by themselves.
nonisolated enum UndefinedValuesFunction: String, CaseIterable, Identifiable {
    case fit
    case reciprocal
    case logarithm
    case tangent

    var id: String {
        rawValue
    }

    /// The name on the picker.
    var title: String {
        switch self {
        case .fit: "Fit"
        case .reciprocal: "1/x"
        case .logarithm: "ln x"
        case .tangent: "tan x"
        }
    }

    /// The name in the caption and the Audio Graph's title: "Graph of a fit, y = x²/2 − 1".
    var name: String {
        self == .fit ? "a fit, y = x²/2 − 1" : title
    }

    /// The name VoiceOver says: "1/x" would be read as "1 slash x".
    var spokenTitle: String {
        switch self {
        case .fit: "A fit, y equals x squared over 2, minus 1"
        case .reciprocal: "1 over x"
        case .logarithm: "Natural log of x"
        case .tangent: "Tangent of x"
        }
    }

    // snippet:undefined-values-functions
    /// The x values the fit was made from. Outside them it says nothing, though its formula still gives numbers.
    static let fitRange: ClosedRange<Double> = 0 ... 3

    /// The fit's formula, which returns a finite number for every x.
    static func fitFormula(_ x: Double) -> Double {
        x * x / 2 - 1
    }

    /// y for a given x, as the plot asks for it.
    func y(at x: Double) -> Double {
        switch self {
        case .fit:
            // The formula would draw on across the window: .nan is what removes it outside the fit's range.
            Self.fitRange.contains(x) ? Self.fitFormula(x) : .nan
        case .reciprocal:
            // No guard: the plot never asks for y at x = 0, and breaks the line at the pole by itself.
            1 / x
        case .logarithm:
            // No guard: the log of a negative is already NaN, and log(0) is -infinity. Both leave a gap.
            log(x)
        case .tangent:
            // Poles at ±π/2, where the plot breaks the line by itself.
            tan(x)
        }
    }

    // end

    /// The poles, in order: the x values where the curve breaks by itself.
    var breaks: [Double] {
        switch self {
        case .reciprocal: [0]
        case .tangent: [-Double.pi / 2, Double.pi / 2]
        case .fit, .logarithm: []
        }
    }

    /// The x below which nothing is defined, for a function undefined over a whole stretch.
    var undefinedAtAndBelow: Double? {
        self == .logarithm ? 0 : nil
    }

    /// The only x values the curve is drawn for, when `.nan` removes the rest.
    var drawnRange: ClosedRange<Double>? {
        self == .fit ? Self.fitRange : nil
    }

    /// Whether the curve runs past the top and the bottom of the y scale's domain, where it is drawn.
    var leavesTop: Bool {
        self != .logarithm
    }

    var leavesBottom: Bool {
        self != .fit
    }

    /// A few points on the curve, for the spoken value: x values where it is drawn.
    var spokenSamples: [Double] {
        switch self {
        case .fit: [0, 1, 2]
        case .reciprocal: [-2, -1, 1, 2]
        case .logarithm: [1, 2, 4]
        case .tangent: [-1, 0, 1]
        }
    }
}

/// The window onto every function: the same for all three, so switching changes only the curve.
nonisolated enum UndefinedValuesWindow {
    static let xDomain: ClosedRange<Double> = -4 ... 4
    static let yDomain: ClosedRange<Double> = -3 ... 3
    /// Every whole number on y, ends included: inside the domain, so they do not widen it.
    static let yAxisValues: [Double] = [-3, -2, -1, 0, 1, 2, 3]
    /// How many points per unit of x the Audio Graph is given: one every 0.1.
    static let describedPointsPerUnit = 10
}

/// One unbroken piece of the curve, between breaks: the Audio Graph plays each as its own series.
nonisolated struct UndefinedValuesBranch: Equatable {
    let name: String
    let points: [(x: Double, y: Double)]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && lhs.points.map(\.x) == rhs.points.map(\.x) && lhs.points.map(\.y) == rhs.points.map(\.y)
    }
}

/// What the chart says in words for one function and one clipping setting.
nonisolated struct UndefinedValuesSummary {
    let function: UndefinedValuesFunction
    let isClipped: Bool
    let locale: Locale

    func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
    }

    /// "x = 0", "x = -1.57 and x = 1.57".
    private var breaksText: String {
        CafeWording.list(function.breaks.map { "x = \(number($0))" })
    }

    /// Where the curve is not drawn, and why, as a sentence.
    var undefinedSentence: String {
        if let range = function.drawnRange {
            return "The fit holds only from x = \(number(range.lowerBound)) to \(number(range.upperBound)). "
                + "Its formula gives numbers outside that range too, so it returns .nan there and nothing is drawn."
        }
        if let bound = function.undefinedAtAndBelow {
            return "\(function.title) is undefined at x = \(number(bound)) and below: "
                + "the log of a negative is already NaN, so no curve is drawn there."
        }
        let poles = function.breaks.count == 1 ? "a pole" : "poles"
        return "\(function.title) has \(poles) at \(breaksText), where the plot breaks the line by itself."
    }

    /// "y = 3 and y = -3", or the one edge the curve reaches.
    private var edgesText: String {
        var edges: [String] = []
        if function.leavesTop { edges.append("y = \(number(UndefinedValuesWindow.yDomain.upperBound))") }
        if function.leavesBottom { edges.append("y = \(number(UndefinedValuesWindow.yDomain.lowerBound))") }
        return CafeWording.list(edges)
    }

    /// What clipping does to this curve, as drawn.
    var clippingSentence: String {
        isClipped
            ? "Clipped, it stops at the edge of the plot, \(edgesText)."
            : "Unclipped, it runs on past \(edgesText), out of the plot area."
    }

    /// Where the curve is not drawn, as the chart's message; how (.nan, a pole, the log of a negative) is the
    /// explanation's to say, so the headline stays short at the largest text sizes.
    var messageSentence: String {
        if let range = function.drawnRange {
            return "The fit holds only from x = \(number(range.lowerBound)) to \(number(range.upperBound)): outside it, nothing is drawn."
        }
        if let bound = function.undefinedAtAndBelow {
            return "\(function.title) is undefined at x = \(number(bound)) and below, so no curve is drawn there."
        }
        let poles = function.breaks.count == 1 ? "a pole" : "poles"
        return "\(function.title) has \(poles) at \(breaksText), where the line breaks."
    }

    /// The chart's message: true for every function and both clipping settings.
    var headline: String {
        "\(messageSentence) \(clippingSentence)"
    }

    /// The value of the curve's one accessibility element: where it is not drawn, then actual values.
    var elementValue: String {
        let samples = function.spokenSamples.map { "x = \(number($0)), y = \(number(function.y(at: $0)))" }
        let undefined = if let range = function.drawnRange {
            "Drawn only from x = \(number(range.lowerBound)) to \(number(range.upperBound))"
        } else if let bound = function.undefinedAtAndBelow {
            "Undefined at x = \(number(bound)) and below"
        } else {
            "Breaks at \(breaksText)"
        }
        return "\(undefined). \(samples.joined(separator: "; ")). \(clippingSentence)"
    }

    /// The pieces of the curve the Audio Graph plays, sampled every 0.1 across the x domain.
    /// Clipped, a point beyond the y domain is not drawn, so it is left out; unclipped, it is drawn and kept.
    var branches: [UndefinedValuesBranch] {
        let x = UndefinedValuesWindow.xDomain
        let perUnit = UndefinedValuesWindow.describedPointsPerUnit
        // Whole tenths divided once, so 0.3 is 0.3 and not 0.30000000000000004.
        let samples = (Int(x.lowerBound) * perUnit ... Int(x.upperBound) * perUnit).map { Double($0) / Double(perUnit) }
        let edges = [x.lowerBound] + function.breaks + [x.upperBound]
        return zip(edges, edges.dropFirst()).compactMap { start, end in
            // A sample on a pole, or where the function returns .nan, is not finite, so it drops out.
            let points = samples
                .filter { $0 >= start && $0 <= end }
                .map { (x: $0, y: function.y(at: $0)) }
                .filter { $0.y.isFinite && (!isClipped || UndefinedValuesWindow.yDomain.contains($0.y)) }
            guard !points.isEmpty else { return nil }
            let from = max(start, function.drawnRange?.lowerBound ?? function.undefinedAtAndBelow ?? start)
            let to = min(end, function.drawnRange?.upperBound ?? end)
            return UndefinedValuesBranch(name: "\(function.title), x from \(number(from)) to \(number(to))", points: points)
        }
    }

    /// The y values the Audio Graph spans: the y domain, widened to every point it is given, so that
    /// unclipped, where the curve is drawn past the plot's edges, the range holds what is drawn.
    var describedYRange: ClosedRange<Double> {
        let window = UndefinedValuesWindow.yDomain
        let ys = branches.flatMap(\.points).map(\.y)
        guard let low = ys.min(), let high = ys.max() else { return window }
        return min(low, window.lowerBound) ... max(high, window.upperBound)
    }

    /// The Audio Graph's summary, in actual values.
    var audioGraphSummary: String {
        "\(function.title), window x from \(number(UndefinedValuesWindow.xDomain.lowerBound)) to "
            + "\(number(UndefinedValuesWindow.xDomain.upperBound)), y from "
            + "\(number(UndefinedValuesWindow.yDomain.lowerBound)) to \(number(UndefinedValuesWindow.yDomain.upperBound)). "
            + "\(undefinedSentence) \(clippingSentence)"
    }
}

/// The screen's state: which function is graphed and whether the plot area is left unclipped.
@Observable
final class UndefinedValuesViewModel {
    var function: UndefinedValuesFunction = .fit
    /// The mistake: the plot area left unclipped, so the curve is drawn outside it.
    var isShowingUnclipped = false

    var isClipped: Bool {
        !isShowingUnclipped
    }

    func summary(locale: Locale) -> UndefinedValuesSummary {
        UndefinedValuesSummary(function: function, isClipped: isClipped, locale: locale)
    }

    /// An identity for the chart that changes with everything its element text depends on.
    var chartIdentity: String {
        "\(function.rawValue)-\(isClipped)"
    }

    /// Said aloud when the function changes: what changed, then the headline.
    func functionAnnouncement(locale: Locale) -> String {
        "Showing \(function.spokenTitle). \(summary(locale: locale).headline)"
    }

    /// Said aloud when clipping changes: the chart's drawing changes with it, and so does the headline.
    func clippingAnnouncement(locale: Locale) -> String {
        "\(isClipped ? "Plot area clipped" : "Plot area unclipped"). \(summary(locale: locale).headline)"
    }

    static let functionsSnippet = SnippetReference(name: "undefined-values-functions", title: "Returning .nan")
    static let chartSnippet = SnippetReference(name: "undefined-values-chart", title: "Clipping the plot area")

    /// The same two snippets in every state: the chart's code branches on clipping inside `chartPlotStyle`.
    var snippets: [SnippetReference] {
        [Self.functionsSnippet, Self.chartSnippet]
    }
}
