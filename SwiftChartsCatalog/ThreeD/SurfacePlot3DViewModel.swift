import Foundation
import Observation

/// The functions the surface can draw, each y = f(x, z) over x and z from -2 to 2, with y between -1 and 1.
nonisolated enum SurfacePlot3DFunction: String, CaseIterable, Identifiable {
    case ripple
    case saddle
    case hill

    var id: Self {
        self
    }

    /// The picker's name for it.
    var title: String {
        switch self {
        case .ripple: "Ripple"
        case .saddle: "Saddle"
        case .hill: "Hill"
        }
    }

    /// The formula as the caption shows it.
    var formula: String {
        switch self {
        case .ripple: "y = sin(2x) × cos(2z)"
        case .saddle: "y = (x² − z²) ÷ 4"
        case .hill: "y = e^−(x² + z²)"
        }
    }

    // snippet:surface-plot-functions
    /// y for a given x and z. Each is defined everywhere it is drawn, so none needs `Double.nan`.
    func value(x: Double, z: Double) -> Double {
        switch self {
        case .ripple: sin(2 * x) * cos(2 * z)
        case .saddle: (x * x - z * z) / 4
        case .hill: exp(-(x * x + z * z))
        }
    }
    // end
}

/// How the surface is coloured: the three kinds of style `chart3d.md` names for a `SurfacePlot`.
nonisolated enum SurfacePlot3DStyle: String, CaseIterable, Identifiable {
    case heightBased
    case normalBased
    case gradient

    var id: Self {
        self
    }

    /// The picker's name for it.
    var title: String {
        switch self {
        case .heightBased: "Height"
        case .normalBased: "Normal"
        case .gradient: "Gradient"
        }
    }

    /// The snippet showing this style's one line of code.
    var snippet: SnippetReference {
        switch self {
        case .heightBased: SnippetReference(name: "surface-plot-height-based", title: "Height-based style")
        case .normalBased: SnippetReference(name: "surface-plot-normal-based", title: "Normal-based style")
        case .gradient: SnippetReference(name: "surface-plot-gradient", title: "Gradient style")
        }
    }

    /// What this style does, as a sentence a reader can check against the chart.
    var explanation: String {
        switch self {
        case .heightBased:
            "The height-based style colours each part of the surface by where it sits on the y scale, not by the surface's own range: dark blue at the bottom of the scale, yellow-green at 0, red near the top. So the ripple's troughs are blue and its peaks red, and the hill's flat ground at 0 is yellow-green."
        case .normalBased:
            "The normal-based style colours each part of the surface by the direction it faces, so slopes facing one way share a colour whatever their height."
        case .gradient:
            "A gradient paints the surface in colours that do not follow y: here an elliptical gradient, warm in the middle of the surface and blue towards its edges, whatever the height."
        }
    }
}

/// Where the surface is seen from, for the control that turns it without a drag. The pose itself is an
/// iOS 26 type, so it lives in the gated chart view; this is the plain value it follows.
nonisolated enum SurfacePlot3DViewpoint: String, CaseIterable, Identifiable {
    case angle, front, side, above

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .angle: "Angle"
        case .front: "Front"
        case .side: "Side"
        case .above: "Above"
        }
    }
}

/// The surface plot screen's state: which function is drawn, how it is styled, and where it is seen from.
@Observable
final class SurfacePlot3DViewModel {
    var style: SurfacePlot3DStyle = .heightBased
    var function: SurfacePlot3DFunction = .ripple
    /// The viewpoint the control last chose, or `nil` once the chart has been turned by hand to none of them.
    var viewpoint: SurfacePlot3DViewpoint? = .angle

    /// The gated chart view reports the viewpoint its pose now matches, or `nil` for none.
    func poseChanged(toMatch matching: SurfacePlot3DViewpoint?) {
        if viewpoint != matching { viewpoint = matching }
    }

    /// The snippets for the current style: the availability check, the chart, the style's line, the functions.
    var snippets: [SnippetReference] {
        Self.snippets(for: style)
    }

    /// Two or three sentences on the concept, the last one about the current style.
    var explanation: String {
        "SurfacePlot draws y as a function of x and z, over the region the x and z scales set. "
            + style.explanation
            + " Drag across the chart to turn it, or choose a view below."
    }

    nonisolated static func snippets(for style: SurfacePlot3DStyle) -> [SnippetReference] {
        [
            SnippetReference(name: "surface-plot-chart", title: "Chart3D with a SurfacePlot"),
            SnippetReference(name: "surface-plot-gate", title: "iOS 26 check"),
            style.snippet,
            SnippetReference(name: "surface-plot-functions", title: "The functions"),
        ]
    }

    /// Every snippet the screen can show, for registering it.
    nonisolated static var allSnippets: [SnippetReference] {
        var all: [SnippetReference] = []
        for style in SurfacePlot3DStyle.allCases {
            for snippet in snippets(for: style) where !all.contains(snippet) {
                all.append(snippet)
            }
        }
        return all
    }

    /// The headline for the current function, or the reason there is no chart.
    func headline(locale: Locale, isChartAvailable: Bool) -> String {
        isChartAvailable
            ? SurfacePlot3DWording.headline(for: function, locale: locale) : SurfacePlot3DWording.unavailableHeadline
    }

    /// What VoiceOver announces when the function changes: what changed, then the headline.
    func functionChangeAnnouncement(locale: Locale) -> String {
        SurfacePlot3DWording.announcement(for: function, locale: locale)
    }
}

/// Every word the screen shows or speaks about the surface, in one place.
nonisolated enum SurfacePlot3DWording {
    /// The x and z scales run over this region: the surface is drawn over it.
    static let planeDomain: ClosedRange<Double> = -2 ... 2
    /// Every function stays between -1 and 1.
    static let valueRange: ClosedRange<Double> = -1 ... 1
    /// The y scale runs a quarter beyond the values, so -1 and 1 fall inside the box, where the automatic
    /// axis labels them: a 3D chart leaves the ends of its box unlabelled.
    static let heightDomain: ClosedRange<Double> = -1.25 ... 1.25

    static let unavailableHeadline = "Surface plots need iOS 26 or later."

    /// A number as the axes write it: whole where it is whole, otherwise up to two decimals.
    static func number(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
    }

    /// The highest and lowest figures the headline names, as the axes write them. Each is a point of the
    /// Audio Graph's rows (the hill's lowest, e^−8 at the corners, is 0 to two decimals).
    static func headlineExtremes(for function: SurfacePlot3DFunction) -> (highest: Double, lowest: Double) {
        switch function {
        case .ripple, .saddle: (1, -1)
        case .hill: (1, 0)
        }
    }

    /// The chart's message. Every figure it names (1, -1 and 0) is labelled on an axis.
    static func headline(for function: SurfacePlot3DFunction, locale: Locale) -> String {
        let one = number(1, locale: locale)
        let minusOne = number(-1, locale: locale)
        let zero = number(0, locale: locale)
        switch function {
        case .ripple:
            return "Three peaks of \(one) and three troughs of \(minusOne) alternate across the middle, "
                + "with lower ridges along both x edges."
        case .saddle:
            return "A saddle: it rises to \(one) towards both ends of x and falls to \(minusOne) towards both ends of z, "
                + "passing \(zero) in the middle."
        case .hill:
            return "One peak of \(one) in the middle, where x and z are \(zero), flattening towards \(zero) at every edge."
        }
    }

    /// The function's formula in words, for the accessibility label.
    static func spokenFormula(for function: SurfacePlot3DFunction) -> String {
        switch function {
        case .ripple: "y equals sine of 2x times cosine of 2z"
        case .saddle: "y equals x squared minus z squared, divided by 4"
        case .hill: "y equals e to the power of minus x squared minus z squared"
        }
    }

    /// The chart's one accessibility element: what it is, then the region it covers.
    static func elementLabel(for function: SurfacePlot3DFunction, locale: Locale) -> String {
        "Surface plot, \(spokenFormula(for: function)), for x and z from "
            + "\(number(planeDomain.lowerBound, locale: locale)) to \(number(planeDomain.upperBound, locale: locale))"
    }

    /// The element's value: where the highest and lowest points are, and one figure the headline leaves out.
    /// The headline is on screen beside the chart, so the value does not repeat it.
    static func elementValue(for function: SurfacePlot3DFunction, locale: Locale) -> String {
        let n = { number($0, locale: locale) }
        switch function {
        case .ripple:
            let edge = abs(function.value(x: planeDomain.upperBound, z: 0))
            return "Highest, \(n(1)), at x \(n(.pi / 4)) and z \(n(0)), and at x \(n(-.pi / 4)) and z \(n(-.pi / 2)) or \(n(.pi / 2)). "
                + "Lowest, \(n(-1)), at the same places with the sign of x changed. "
                + "The ridges along the x edges reach only \(n(edge)) and \(n(-edge))."
        case .saddle:
            return "Highest, \(n(1)), at x \(n(-2)) and \(n(2)) where z is \(n(0)). "
                + "Lowest, \(n(-1)), at z \(n(-2)) and \(n(2)) where x is \(n(0)). "
                + "At the four corners it is \(n(0))."
        case .hill:
            return "Highest, \(n(1)), at x \(n(0)) and z \(n(0)). "
                + "\(n(function.value(x: 1, z: 0))) at a distance of \(n(1)) from the middle, "
                + "and \(n(0)) to two decimals at the edges."
        }
    }

    static func announcement(for function: SurfacePlot3DFunction, locale: Locale) -> String {
        "Showing the \(function.title.lowercased()). " + headline(for: function, locale: locale)
    }

    /// The Audio Graph's title, in words: a screen reader reads "x²" and "÷" unreliably.
    static func descriptorTitle(for function: SurfacePlot3DFunction) -> String {
        "Surface plot of \(spokenFormula(for: function))"
    }

    /// The rows of the surface the Audio Graph plays, one series each, chosen so that every figure the headline
    /// names is a data point: the ripple's peaks and troughs lie on z = −π/2, 0 and π/2, the saddle's and the
    /// hill's on whole numbers. The edges are rows too, so the ripple's lower ridges are heard.
    static func rowZValues(for function: SurfacePlot3DFunction) -> [Double] {
        switch function {
        case .ripple: [-2, -.pi / 2, 0, .pi / 2, 2]
        case .saddle, .hill: [-2, -1, 0, 1, 2]
        }
    }

    /// The x values along each row: every quarter from -2 to 2, and for the ripple also ±π/4, where its
    /// peaks and troughs are.
    static func rowXValues(for function: SurfacePlot3DFunction) -> [Double] {
        let quarters = stride(from: planeDomain.lowerBound, through: planeDomain.upperBound, by: 0.25).map(\.self)
        switch function {
        case .ripple: return (quarters + [-.pi / 4, .pi / 4]).sorted()
        case .saddle, .hill: return quarters
        }
    }

    static func rowName(z: Double, locale: Locale) -> String {
        "Row at z \(number(z, locale: locale))"
    }

    /// The value description for the descriptor's axes: the number, or "" for one that is not finite.
    static func spokenValue(_ value: Double, axis: String, locale: Locale) -> String {
        value.isFinite ? "\(axis) \(number(value, locale: locale))" : ""
    }
}
