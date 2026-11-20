import CoreGraphics
import Foundation
import Observation

/// The state of "Plot aspect ratio": the ratio the fixed plot is held to, and the shape the free plot
/// was actually given, measured from the chart.
@Observable
final class PlotAspectRatioViewModel {
    /// The slider's range and step for the fixed plot's width-to-height ratio.
    static let ratioRange: ClosedRange<Double> = 0.5 ... 2
    static let ratioStep = 0.25

    /// The fixed plot's width divided by its height.
    var ratio: Double = 1
    /// The free plot's width-to-height ratio as drawn, or `nil` before it has been laid out.
    /// The view measures the plot frame and passes the size in as plain numbers.
    private(set) var freeRatio: Double?

    /// Records the free plot's size as the chart laid it out.
    func freePlotDidLayOut(width: Double, height: Double) {
        freeRatio = PlotAspectRatioSummary.ratio(width: width, height: height)
    }

    /// The screen's words for the current state, in the view's locale.
    func summary(locale: Locale) -> PlotAspectRatioSummary {
        PlotAspectRatioSummary(fixedRatio: ratio, freeRatio: freeRatio, locale: locale)
    }
}

/// Everything the screen says about the two circles: the headline, the captions over each plot,
/// the slider's value, and what the accessibility elements and Audio Graphs say.
nonisolated struct PlotAspectRatioSummary: Equatable {
    /// The fixed plot's width-to-height ratio.
    let fixedRatio: Double
    /// The free plot's measured width-to-height ratio, `nil` until it has been laid out.
    let freeRatio: Double?
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The circle's radius, in the units of both axes.
    static let radius = 3.0
    /// Both scales run over this domain, so one unit on x and one unit on y differ only by the plot's shape.
    static let domain: ClosedRange<Double> = -4 ... 4

    /// A plot's width over its height, to two decimal places as the screen writes it.
    /// `nil` for a size with no area, which a plot has before layout.
    static func ratio(width: Double, height: Double) -> Double? {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        return rounded(width / height)
    }

    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    // MARK: Ratios and shapes

    /// "1.5:1", "0.58:1".
    func ratioText(_ ratio: Double) -> String {
        "\(number(ratio)):1"
    }

    /// "1.5 to 1", the same setting as `ratioText`, as it is said.
    func spokenRatio(_ ratio: Double) -> String {
        "\(number(ratio)) to 1"
    }

    /// What a circle looks like in a plot of this ratio, when both axes cover the same values:
    /// "round", "1.5 times as wide as it is tall", "2 times as tall as it is wide".
    func shape(atRatio ratio: Double) -> String {
        let stretch = Self.rounded(ratio >= 1 ? ratio : 1 / ratio)
        guard stretch != 1 else { return "round" }
        let times = String(AttributedString(
            localized: "^[\(stretch, format: .number.precision(.fractionLength(0 ... 2))) time](inflect: true)",
            locale: locale
        ).characters)
        return ratio > 1 ? "\(times) as wide as it is tall" : "\(times) as tall as it is wide"
    }

    var fixedShape: String {
        shape(atRatio: fixedRatio)
    }

    /// The free circle's shape, or `nil` before the free plot has been laid out.
    var freeShape: String? {
        freeRatio.map { shape(atRatio: $0) }
    }

    // MARK: Words on screen

    /// The chart's message. Every ratio in it is written over the plot it describes.
    var headline: String {
        let fixed = "At \(ratioText(fixedRatio)) the circle is \(fixedShape)"
        guard let freeRatio, let freeShape else { return "\(fixed)." }
        return "\(fixed); in the free plot, \(ratioText(freeRatio)) here, it is \(freeShape)."
    }

    /// The caption over the free plot.
    var freeCaption: String {
        guard let freeRatio else { return PlotAspectRatioWording.freePlot }
        return "\(PlotAspectRatioWording.freePlot), \(ratioText(freeRatio))"
    }

    /// The caption over the fixed plot.
    var fixedCaption: String {
        "\(PlotAspectRatioWording.fixedPlot), \(ratioText(fixedRatio))"
    }

    /// The slider's value as shown.
    var sliderValueText: String {
        ratioText(fixedRatio)
    }

    /// The slider's value as spoken: the setting, then the headline it leads to, since the headline changes with it.
    var sliderSpokenValue: String {
        "\(spokenRatio(fixedRatio)). \(headline)"
    }

    // MARK: Accessibility

    /// The circle, as both element labels describe it after the plot's name.
    private var circleDescription: String {
        "circle of radius \(number(Self.radius)), centred on 0, 0"
    }

    /// The free circle's element label: the plot's name first, since the captions are hidden and
    /// the two circles are otherwise the same.
    var freeCircleLabel: String {
        "\(PlotAspectRatioWording.freePlot): \(circleDescription)"
    }

    /// The fixed circle's element label.
    var fixedCircleLabel: String {
        "\(PlotAspectRatioWording.fixedPlot): \(circleDescription)"
    }

    /// The free circle's element value: what is drawn, as far as it is known.
    var freeCircleValue: String {
        guard let freeRatio, let freeShape else { return "In a plot that takes the chart's shape" }
        return "Drawn \(freeShape), in a plot \(spokenRatio(freeRatio))"
    }

    /// The fixed circle's element value.
    var fixedCircleValue: String {
        "Drawn \(fixedShape), in a plot \(spokenRatio(fixedRatio))"
    }

    var freeDescriptorTitle: String {
        "A circle of radius \(number(Self.radius)) in the free plot"
    }

    var fixedDescriptorTitle: String {
        "A circle of radius \(number(Self.radius)) in a plot fixed at \(spokenRatio(fixedRatio))"
    }

    /// What both Audio Graphs say first: the circle and the axes, in actual values.
    private var circleFacts: String {
        "Centre 0, 0, radius \(number(Self.radius)). "
            + "Both axes run from \(number(Self.domain.lowerBound)) to \(number(Self.domain.upperBound))."
    }

    var freeDescriptorSummary: String {
        guard let freeRatio, let freeShape else {
            return "\(circleFacts) The plot takes the chart's shape."
        }
        return "\(circleFacts) The plot is \(spokenRatio(freeRatio)), width to height, so the circle is drawn \(freeShape)."
    }

    var fixedDescriptorSummary: String {
        "\(circleFacts) The plot is held at \(spokenRatio(fixedRatio)), width to height, so the circle is drawn \(fixedShape)."
    }

    /// A coordinate as written on the axes and spoken by the Audio Graph.
    func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
    }
}
