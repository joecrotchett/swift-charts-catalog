import Foundation
import Observation

/// Which chart the screen draws.
nonisolated enum GatedChartBranch: Equatable {
    /// The `Chart3D`, on a system that passed `#available(iOS 26, *)`.
    case chart3D
    /// The 2D scatter plot people on iOS 18 to 25 see.
    case fallback
}

/// The angles the 3D chart can be turned to without a drag, as plain values any system can hold.
nonisolated enum GatedChartAngle: String, CaseIterable, Identifiable {
    /// Turned a little, the opening pose: the three clusters apart, and depth to see.
    case angled
    /// Acidity across, body up: the same pair the 2D fallback draws.
    case front
    /// Sweetness across, body up: sweetness rising with body, seen edge-on.
    case side

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .angled: "Angled"
        case .front: "Front"
        case .side: "Side"
        }
    }

    /// The angles in degrees, as plain numbers any system can hold; the 3D view makes the pose. Angled opens
    /// a little to the right of front and above it, so the clusters separate along acidity and body and the
    /// depth still shows. Front and side are the framework's `.front` (0, 0) and `.left` (90, 0).
    var azimuthDegrees: Double {
        switch self {
        case .angled: 20
        case .front: 0
        case .side: 90
        }
    }

    var inclinationDegrees: Double {
        switch self {
        case .angled: 15
        case .front, .side: 0
        }
    }
}

/// The state of "Gating with a fallback": the "Simulate older OS" toggle, the angle of the 3D chart, and
/// whether this system passes the iOS 26 check at all.
@Observable
final class GatedChartViewModel {
    /// The screen's toggle: draw the fallback even though this system passed the check.
    var simulatesOlderOS = false
    /// The 3D chart's viewing angle as plain numbers: a button sets them, a drag writes back into them, so
    /// any button can be pressed again after a drag, and the angle survives the chart being rebuilt.
    var azimuthDegrees = GatedChartAngle.angled.azimuthDegrees
    var inclinationDegrees = GatedChartAngle.angled.inclinationDegrees

    let beans: [BeanTasting]
    /// Whether this system passed `#available(iOS 26, *)`. Passed in so tests can be an older system.
    let systemHas3D: Bool
    /// This system's version, such as "27.0", for the status line.
    let systemVersion: String

    init(
        beans: [BeanTasting] = CafeData.beanTastings,
        systemHas3D: Bool = GatedChartViewModel.currentSystemHas3D,
        systemVersion: String = GatedChartViewModel.currentSystemVersion
    ) {
        self.beans = beans
        self.systemHas3D = systemHas3D
        self.systemVersion = systemVersion
    }

    /// The real check, made once here so the status line and the chart agree.
    static var currentSystemHas3D: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    static var currentSystemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion)"
    }

    var hasData: Bool {
        !beans.isEmpty
    }

    /// The 3D chart only when the system passed the check and the toggle is off.
    var branch: GatedChartBranch {
        systemHas3D && !simulatesOlderOS ? .chart3D : .fallback
    }

    /// The toggle can only simulate an older system on a newer one, and only while there is a chart.
    var canSimulateOlderOS: Bool {
        systemHas3D && hasData
    }

    /// The angle buttons turn the 3D chart, so they work only while that chart is drawn.
    var canChooseAngle: Bool {
        branch == .chart3D && hasData
    }

    /// Turns the 3D chart to a preset angle, even the one it was last turned to before a drag.
    func show(_ angle: GatedChartAngle) {
        azimuthDegrees = angle.azimuthDegrees
        inclinationDegrees = angle.inclinationDegrees
    }

    func summary(locale: Locale) -> GatedChartSummary {
        GatedChartSummary(beans: beans, locale: locale)
    }

    /// Which branch ran, and why, in a sentence.
    var status: String {
        switch (branch, systemHas3D) {
        case (.chart3D, _):
            "This system runs iOS \(systemVersion) and passed the iOS 26 check: the 3D chart is drawn."
        case (.fallback, true):
            "This system runs iOS \(systemVersion) and passed the iOS 26 check; the toggle overrides it, so the 2D fallback is drawn."
        case (.fallback, false):
            "This system runs iOS \(systemVersion) and failed the iOS 26 check: the 2D fallback is drawn."
        }
    }

    /// Spoken when the toggle swaps the chart: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        let change = switch branch {
        case .chart3D: "Showing the 3D chart iOS 26 draws."
        case .fallback: "Showing the 2D chart iOS 18 gets instead. Sweetness is not drawn."
        }
        return "\(change) \(summary(locale: locale).headline)"
    }
}

/// Every word the screen writes about the data: headline, element text and the Audio Graph's summary.
nonisolated struct GatedChartSummary {
    let beans: [BeanTasting]
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The origins present, in the order every chart and legend lists them.
    var origins: [String] {
        BeanOriginStyle.origins.filter { origin in beans.contains { $0.origin == origin } }
            + Set(beans.map(\.origin)).subtracting(BeanOriginStyle.origins).sorted()
    }

    func beans(from origin: String) -> [BeanTasting] {
        beans.filter { $0.origin == origin }
    }

    /// The origin with the highest mean of a score; the first in chart order on a tie.
    func leader(by score: (BeanTasting) -> Double) -> String? {
        origins.max { first, second in
            mean(of: beans(from: first), score) < mean(of: beans(from: second), score)
        }
    }

    /// "60 samples from 3 origins: Ethiopia's beans are the most acidic, Sumatra's the fullest-bodied."
    var headline: String {
        guard let mostAcidic = leader(by: \.acidity), let fullest = leader(by: \.body) else {
            return "No bean samples to show."
        }
        let counts = "\(GatedChartWording.samples(beans.count, locale: locale)) from \(GatedChartWording.origins(origins.count, locale: locale))"
        if origins.count == 1 {
            return "\(counts)."
        }
        if mostAcidic == fullest {
            return "\(counts): \(mostAcidic)'s beans are the most acidic and the fullest-bodied."
        }
        return "\(counts): \(mostAcidic)'s beans are the most acidic, \(fullest)'s the fullest-bodied."
    }

    /// What VoiceOver reads for one origin's points: its name.
    func elementLabel(origin: String) -> String {
        origin
    }

    /// The count and the range of each score drawn: "20 samples. Acidity 6.9 to 8.7, body 2.5 to 4.3."
    /// Sweetness is named only where it is drawn, in 3D.
    func elementValue(origin: String, includesSweetness: Bool) -> String {
        let group = beans(from: origin)
        var ranges = [
            "\(GatedChartWording.acidity) \(range(of: group, \.acidity))",
            "\(GatedChartWording.body.lowercased()) \(range(of: group, \.body))",
        ]
        if includesSweetness {
            ranges.append("\(GatedChartWording.sweetness.lowercased()) \(range(of: group, \.sweetness))")
        }
        return "\(GatedChartWording.samples(group.count, locale: locale)). \(ranges.joined(separator: ", "))."
    }

    /// The Audio Graph's summary: the counts, then each origin's ranges, in actual values.
    func audioGraphSummary(includesSweetness: Bool) -> String {
        guard !beans.isEmpty else { return headline }
        let counts = "\(GatedChartWording.samples(beans.count, locale: locale)) from \(GatedChartWording.origins(origins.count, locale: locale))."
        let groups = origins.map { origin in
            "\(origin): \(elementValue(origin: origin, includesSweetness: includesSweetness))"
        }
        return ([counts] + groups).joined(separator: " ")
    }

    /// "6.9 to 8.7", in the view's locale.
    func range(of group: [BeanTasting], _ score: (BeanTasting) -> Double) -> String {
        let scores = group.map(score)
        guard let lowest = scores.min(), let highest = scores.max() else { return "" }
        return "\(GatedChartWording.score(lowest, locale: locale)) to \(GatedChartWording.score(highest, locale: locale))"
    }

    private func mean(of group: [BeanTasting], _ score: (BeanTasting) -> Double) -> Double {
        group.isEmpty ? 0 : group.map(score).reduce(0, +) / Double(group.count)
    }
}

/// The words for the bean tastings that `CafeWording` does not have yet, kept with this screen.
nonisolated enum GatedChartWording {
    static let acidity = "Acidity"
    static let body = "Body"
    static let sweetness = "Sweetness"
    static let origin = "Origin"
    /// Every score runs from 0 to 10: the domain of every axis, 2D and 3D.
    static let scoreRange: ClosedRange<Double> = 0 ... 10

    /// "1 sample", "60 samples".
    static func samples(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) sample](inflect: true)", locale: locale).characters)
    }

    /// "1 origin", "3 origins".
    static func origins(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) origin](inflect: true)", locale: locale).characters)
    }

    /// A tasting score with one decimal place: "7.8".
    static func score(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// A score as the Audio Graph says it, with no decimal on a whole number: "7.8 out of 10", "10 out of 10",
    /// or "" for a value that is not finite.
    static func spokenScore(_ value: Double, locale: Locale) -> String {
        guard value.isFinite else { return "" }
        return "\(value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))) out of 10"
    }
}
