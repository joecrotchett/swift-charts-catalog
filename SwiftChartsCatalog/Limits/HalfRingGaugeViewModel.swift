import Foundation
import Observation

/// The gauge screen's state: how far along the goal is, and whether the clear sector is drawn tinted.
@Observable
final class HalfRingGaugeViewModel {
    /// The slider's value, from 0 to 1. The gauge clamps and rounds it (`HalfRingGaugeAngles`).
    var progress: Double = 0.72
    /// Tints the sector that holds the other half of the circle, so the reader can see it.
    var showsClearSector = false

    var angles: HalfRingGaugeAngles {
        HalfRingGaugeAngles(progress: progress)
    }

    func wording(locale: Locale) -> HalfRingGaugeWording {
        HalfRingGaugeWording(percent: angles.percent, locale: locale)
    }

    /// A new identity for the chart whenever its element text or descriptor changes, so VoiceOver and the
    /// Audio Graph do not keep the first ones.
    var chartIdentity: String {
        "\(angles.percent)-\(showsClearSector)"
    }

    /// The snippets the screen shows, the same in every state.
    static let snippets = [
        SnippetReference(name: "gauge-half-ring", title: "Half ring"),
        SnippetReference(name: "gauge-angles", title: "Angle ranges"),
        SnippetReference(name: "gauge-descriptor", title: "Chart descriptor"),
    ]
}

// snippet:gauge-angles
/// The three angle ranges of the half ring, on one angle scale that runs from 0 to 2: the gauge takes
/// 0 to 1, half the circle, and a clear sector takes 1 to 2, the other half.
nonisolated struct HalfRingGaugeAngles: Equatable {
    /// Where the gauge ends and the clear sector begins on the angle scale.
    static let gaugeEnd = 1.0
    /// Where the clear sector ends: the largest value in the chart, so the whole scale is a full circle.
    static let circleEnd = 2.0
    /// Sectors start at 12 o'clock; a quarter turn back starts the half ring at 9 o'clock.
    static let rotationDegrees = -90.0

    /// The value, clamped to 0...1 and rounded to a whole percent, so the drawing, the headline and the
    /// spoken value always agree. Not a number counts as zero.
    let progress: Double

    init(progress: Double) {
        let clamped = progress.isNaN ? 0 : min(max(progress, 0), Self.gaugeEnd)
        self.progress = (clamped * 100).rounded() / 100
    }

    /// The whole percent the gauge shows.
    var percent: Int {
        Int((progress * 100).rounded())
    }

    /// The filled part, or `nil` at 0%: a sector needs a range that is not empty.
    var filled: Range<Double>? {
        progress > 0 ? 0 ..< progress : nil
    }

    /// The pale track after the filled part, or `nil` at 100%.
    var track: Range<Double>? {
        progress < Self.gaugeEnd ? progress ..< Self.gaugeEnd : nil
    }

    /// The other half of the circle, drawn clear.
    let clear: Range<Double> = gaugeEnd ..< circleEnd

    /// How far the filled part sweeps on screen: 0° to 180°.
    var filledSweepDegrees: Double {
        progress / Self.circleEnd * 360
    }

    /// Where the filled part ends on screen, in degrees clockwise from 12 o'clock once the chart is
    /// rotated: -90° (9 o'clock) at 0%, 0° at 50%, 90° (3 o'clock) at 100%.
    var filledEndDegrees: Double {
        Self.rotationDegrees + filledSweepDegrees
    }
}

// end

/// Every word the screen writes or speaks about the gauge, in one place.
nonisolated struct HalfRingGaugeWording {
    let percent: Int
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    static let caption = "Progress toward today's cup goal"
    /// The `.value` labels of the three sectors, spoken as axis names.
    static let progressLabel = "Progress"
    static let remainingLabel = "Remaining"
    static let unusedLabel = "Unused"
    static let elementLabel = "Today's cup goal"
    static let clearSectorLabel = "Clear sector, tinted"
    static let clearSectorValue = "The lower half of the circle, 1 to 2 on the angle scale. It is drawn clear when the toggle is off."
    static let descriptorTitle = "Progress toward today's cup goal"

    /// "72%", written in the locale.
    var percentText: String {
        (Double(percent) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// The chart's message, with the figure written under the arch.
    var headline: String {
        switch percent {
        case 0: "None of today's cup goal is reached yet: \(percentText)."
        case 100: "Today's cup goal is reached: \(percentText)."
        default: "\(percentText) of today's cup goal is reached."
        }
    }

    /// The longest headline, so the chart, and the slider under the finger, do not move as the slider changes it:
    /// a slider is dragged like a selection, so it keeps the reserve a picker or toggle would not.
    static func reservedHeadline(locale: Locale) -> String {
        HalfRingGaugeWording(percent: 0, locale: locale).headline
    }

    /// The gauge element's value.
    var elementValue: String {
        percentText
    }

    /// The slider's spoken value: the headline alone, which already says the setting.
    var sliderSpokenValue: String {
        headline
    }

    /// "72 percent", for the Audio Graph's value description and summary.
    nonisolated static func spokenPercent(_ value: Double, locale: Locale) -> String {
        guard value.isFinite else { return "" }
        return "\(Int(value.rounded()).formatted(.number.locale(locale))) percent"
    }

    var audioGraphSummary: String {
        "\(Self.spokenPercent(Double(percent), locale: locale)) of the goal."
    }
}
