import Accessibility
import Charts
import Observation
import SwiftUI

/// The words this screen needs that `CafeWording` does not have yet: the three tasting scores and the origin.
nonisolated enum PoseProjectionWording {
    static let acidity = "Acidity"
    static let body = "Body"
    static let sweetness = "Sweetness"
    static let origin = "Origin"

    /// "1 sample", "60 samples".
    static func samples(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) sample](inflect: true)", locale: locale).characters)
    }

    /// "1 origin", "3 origins".
    static func origins(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) origin](inflect: true)", locale: locale).characters)
    }

    /// An angle as spoken, whole degrees agreeing in number: "1 degree", "-30 degrees".
    static func degrees(_ value: Double, locale: Locale) -> String {
        let whole = Int(exactly: value.rounded()) ?? 0
        return String(AttributedString(localized: "^[\(whole) degree](inflect: true)", locale: locale).characters)
    }

    /// An angle as shown: "-30°".
    static func degreesShort(_ value: Double, locale: Locale) -> String {
        "\(value.rounded().formatted(.number.precision(.fractionLength(0)).locale(locale)))°"
    }

    /// A score from 0 to 10, with one decimal place: "7.8".
    static func score(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }
}

/// The poses the preset buttons choose. Each is one of the framework's own presets, and each has the angles
/// the framework reports for it, so the sliders can show them.
nonisolated enum PoseProjectionPreset: String, CaseIterable, Identifiable {
    case clusters
    case trend
    case standard

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .clusters: "Clusters"
        case .trend: "Trend"
        case .standard: "Default"
        }
    }

    /// The angles of the framework's preset, in degrees, as `Chart3DPose` reports them (read on iOS 27).
    var angles: PoseProjectionAngles {
        switch self {
        case .clusters: PoseProjectionAngles(azimuth: 0, inclination: 0)
        case .trend: PoseProjectionAngles(azimuth: 90, inclination: 0)
        case .standard: PoseProjectionAngles(azimuth: -30, inclination: 15)
        }
    }

    /// What the button says to VoiceOver about where it looks from.
    var spokenDescription: String {
        switch self {
        case .clusters: "From the front"
        case .trend: "From the left"
        case .standard: "The framework's default pose"
        }
    }

    // snippet:pose-and-projection-presets
    /// Each preset button chooses one of the framework's poses.
    @available(iOS 26, *)
    var pose: Chart3DPose {
        switch self {
        case .clusters: .front // looks along sweetness: acidity across, body up
        case .trend: .left // looks along acidity: sweetness rising to the right, body up
        case .standard: .default // what a chart with no pose opens on
        }
    }
    // end
}

/// The camera's projection, as the picker offers it.
nonisolated enum PoseProjectionProjection: String, CaseIterable, Identifiable {
    case orthographic
    case perspective

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .orthographic: "Orthographic"
        case .perspective: "Perspective"
        }
    }

    /// What the projection does to the chart, as a sentence the reader can check against it.
    var note: String {
        switch self {
        case .orthographic:
            "Orthographic: every point is the same size whatever its depth, and the box's parallel edges stay parallel, so a view straight on reads as a flat scatter."
        case .perspective:
            "Perspective: nearer points are drawn larger and farther ones smaller, and the box's parallel edges converge, which gives depth but moves points off the grid they sit on."
        }
    }
}

/// An azimuth and an inclination, in degrees.
nonisolated struct PoseProjectionAngles: Equatable {
    var azimuth: Double
    var inclination: Double

    /// The same direction with the azimuth in -180 up to 180.
    var normalized: PoseProjectionAngles {
        var turned = azimuth.truncatingRemainder(dividingBy: 360)
        if turned > 180 { turned -= 360 }
        if turned <= -180 { turned += 360 }
        return PoseProjectionAngles(azimuth: turned, inclination: min(90, max(-90, inclination)))
    }

    /// Within a tenth of a degree on both angles, after normalizing. The framework keeps inclination
    /// within 89.9 degrees, so a slider at 90 and the pose it gives count as the same.
    func isClose(to other: PoseProjectionAngles) -> Bool {
        let one = normalized, two = other.normalized
        var turn = abs(one.azimuth - two.azimuth)
        turn = min(turn, 360 - turn)
        return turn <= 0.11 && abs(one.inclination - two.inclination) <= 0.11
    }
}

/// Which pair of scores a pose lines up with the screen, if any.
nonisolated enum PoseProjectionView: Equatable {
    /// Looking along sweetness: acidity against body. `fromBehind` when turned round to the back.
    case front(fromBehind: Bool)
    /// Looking along acidity: sweetness against body. Seen on iOS, from the left (azimuth 90, `.left`)
    /// sweetness rises to the right as in a 2D chart; from the right (azimuth -90, `.right`) it runs right
    /// to left, the mirror image.
    case side(fromRight: Bool)
    /// Looking along body: acidity against sweetness. `fromBelow` when tilted under.
    case top(fromBelow: Bool)
    /// None of the three: depth mixes every score into the view.
    case angled

    /// How far a pose may be from straight on and still count as it: 10 degrees.
    static let tolerance = 10.0

    init(_ angles: PoseProjectionAngles) {
        let angles = angles.normalized
        let turn = abs(angles.azimuth), tilt = abs(angles.inclination)
        if tilt >= 90 - Self.tolerance {
            self = .top(fromBelow: angles.inclination < 0)
        } else if tilt > Self.tolerance {
            self = .angled
        } else if turn <= Self.tolerance || turn >= 180 - Self.tolerance {
            self = .front(fromBehind: turn >= 180 - Self.tolerance)
        } else if abs(turn - 90) <= Self.tolerance {
            self = .side(fromRight: angles.azimuth < 0)
        } else {
            self = .angled
        }
    }
}

/// The scores of one origin's samples: the extent of each, for the elements and the summary.
nonisolated struct PoseProjectionCluster: Identifiable, Equatable {
    let origin: String
    let count: Int
    let acidity: ClosedRange<Double>
    let body: ClosedRange<Double>
    let sweetness: ClosedRange<Double>
    let meanAcidity: Double
    let meanBody: Double
    let meanSweetness: Double

    var id: String {
        origin
    }
}

/// What the bean tastings show, worked out from the data, so the headline says only what is true of it.
nonisolated struct PoseProjectionFacts {
    let tastings: [BeanTasting]

    /// One cluster per origin that has samples, in `CafeData.beanOrigins` order, then any others.
    var clusters: [PoseProjectionCluster] {
        var origins = CafeData.beanOrigins.filter { origin in tastings.contains { $0.origin == origin } }
        for tasting in tastings where !origins.contains(tasting.origin) {
            origins.append(tasting.origin)
        }
        return origins.compactMap { origin in
            let rows = tastings.filter { $0.origin == origin }
            guard let first = rows.first else { return nil }
            func extent(_ value: KeyPath<BeanTasting, Double>) -> ClosedRange<Double> {
                let values = rows.map { $0[keyPath: value] }
                return (values.min() ?? first[keyPath: value]) ... (values.max() ?? first[keyPath: value])
            }
            func mean(_ value: KeyPath<BeanTasting, Double>) -> Double {
                rows.map { $0[keyPath: value] }.reduce(0, +) / Double(rows.count)
            }
            return PoseProjectionCluster(
                origin: origin, count: rows.count,
                acidity: extent(\.acidity), body: extent(\.body), sweetness: extent(\.sweetness),
                meanAcidity: mean(\.acidity), meanBody: mean(\.body), meanSweetness: mean(\.sweetness)
            )
        }
    }

    /// True when no two origins' boxes of acidity and body overlap: seen from the front, each origin
    /// sits apart from the others.
    var clustersSeparateFromFront: Bool {
        separate { ($0.acidity, $0.body) }
    }

    /// True when no two origins' boxes of acidity and sweetness overlap: seen from above.
    var clustersSeparateFromAbove: Bool {
        separate { ($0.acidity, $0.sweetness) }
    }

    private func separate(_ box: (PoseProjectionCluster) -> (ClosedRange<Double>, ClosedRange<Double>)) -> Bool {
        let clusters = clusters
        guard clusters.count > 1 else { return false }
        for (index, one) in clusters.enumerated() {
            for two in clusters[(index + 1)...] {
                let (oneAcross, oneUp) = box(one), (twoAcross, twoUp) = box(two)
                if oneAcross.overlaps(twoAcross), oneUp.overlaps(twoUp) { return false }
            }
        }
        return true
    }

    /// The correlation of sweetness with body across every sample, or `nil` with fewer than three
    /// samples or no spread.
    var bodySweetnessCorrelation: Double? {
        guard tastings.count >= 3 else { return nil }
        let count = Double(tastings.count)
        let meanBody = tastings.map(\.body).reduce(0, +) / count
        let meanSweetness = tastings.map(\.sweetness).reduce(0, +) / count
        var product = 0.0, bodySquares = 0.0, sweetnessSquares = 0.0
        for tasting in tastings {
            let body = tasting.body - meanBody, sweetness = tasting.sweetness - meanSweetness
            product += body * sweetness
            bodySquares += body * body
            sweetnessSquares += sweetness * sweetness
        }
        guard bodySquares > 0, sweetnessSquares > 0 else { return nil }
        return product / (bodySquares * sweetnessSquares).squareRoot()
    }

    /// Sweetness rises with body closely enough that, edge-on, the samples make one narrow band.
    var risesInOneBand: Bool {
        (bodySweetnessCorrelation ?? 0) >= 0.9
    }

    /// The sample with the least body and the one with the most.
    var lightest: BeanTasting? {
        tastings.min { $0.body < $1.body }
    }

    var heaviest: BeanTasting? {
        tastings.max { $0.body < $1.body }
    }
}

/// The state of "Pose and projection": the angle the chart is seen from, and its projection.
///
/// The angles here are what the sliders and presets set and what the chart's bound pose reports when
/// someone rotates it, so the sliders, the headline and the chart always agree.
@Observable
final class PoseProjectionViewModel {
    let tastings: [BeanTasting]
    /// Degrees, -180 up to 180. Set by the slider, a preset, or the chart when it is rotated.
    var azimuth: Double
    /// Degrees, -90 to 90.
    var inclination: Double
    var projection: PoseProjectionProjection

    init(
        tastings: [BeanTasting] = CafeData.beanTastings,
        preset: PoseProjectionPreset = .clusters,
        projection: PoseProjectionProjection = .orthographic
    ) {
        self.tastings = tastings
        azimuth = preset.angles.azimuth
        inclination = preset.angles.inclination
        self.projection = projection
    }

    var angles: PoseProjectionAngles {
        PoseProjectionAngles(azimuth: azimuth, inclination: inclination)
    }

    var facts: PoseProjectionFacts {
        PoseProjectionFacts(tastings: tastings)
    }

    var view: PoseProjectionView {
        PoseProjectionView(angles)
    }

    /// The preset the chart is at now, if any, so its button shows as chosen.
    var activePreset: PoseProjectionPreset? {
        PoseProjectionPreset.allCases.first { $0.angles.isClose(to: angles) }
    }

    // MARK: Changes

    /// A preset button. Returns what VoiceOver announces: where the chart is seen from, then the headline.
    @discardableResult
    func choose(_ preset: PoseProjectionPreset, locale: Locale) -> String {
        azimuth = preset.angles.azimuth
        inclination = preset.angles.inclination
        return "\(preset.spokenDescription). \(headline(locale: locale))"
    }

    /// The chart reported a new pose, because someone rotated it or because a control set it. The angles
    /// are taken only when they differ, so a pose the controls set does not write itself back.
    func chartReported(_ reported: PoseProjectionAngles) {
        guard !reported.isClose(to: angles) else { return }
        let normalized = reported.normalized
        azimuth = normalized.azimuth
        inclination = normalized.inclination
    }

    /// Whether the chart's pose must be set again to match the controls: false when it already shows
    /// these angles, which is what stops the chart and the controls setting each other in a loop.
    func chartNeedsPose(currently shown: PoseProjectionAngles) -> Bool {
        !shown.isClose(to: angles)
    }

    // MARK: Words

    /// The chart's message, worked out from the pose and the data.
    func headline(locale: Locale) -> String {
        headline(for: angles, locale: locale)
    }

    /// The headline the chart would have at these angles.
    func headline(for angles: PoseProjectionAngles, locale: Locale) -> String {
        let facts = facts
        guard !tastings.isEmpty else { return "No tastings to show." }
        switch PoseProjectionView(angles) {
        case let .front(fromBehind):
            let from = fromBehind ? "From behind" : "From the front"
            let clusters = facts.clusters.count
            return facts.clustersSeparateFromFront
                ? "\(from), acidity against body: the \(PoseProjectionWording.origins(clusters, locale: locale)) sit in separate clusters."
                : "\(from), acidity against body: the origins overlap."
        case let .side(fromRight):
            let view = fromRight
                ? "From the right, mirrored, sweetness running right to left against body"
                : "From the left, sweetness against body"
            return facts.risesInOneBand
                ? "\(view): all \(PoseProjectionWording.samples(tastings.count, locale: locale)) rise in one narrow band."
                : "\(view): the samples make no single band."
        case let .top(fromBelow):
            let from = fromBelow ? "From below" : "From above"
            return facts.clustersSeparateFromAbove
                ? "\(from), acidity against sweetness: the clusters separate, and body is hidden."
                : "\(from), acidity against sweetness: the origins overlap, and body is hidden."
        case .angled:
            return "At azimuth \(PoseProjectionWording.degreesShort(angles.azimuth, locale: locale)), inclination \(PoseProjectionWording.degreesShort(angles.inclination, locale: locale)): depth mixes all three scores, so no two can be read off the axes."
        }
    }

    /// The longest headline the screen can show for this data, written in the locale, so the chart does
    /// not move as the pose changes. One pose of each kind, and the angled pose with the widest angles
    /// (an inclination of -80 is already "from below", but its digits are as wide as any angled one's).
    func reservedHeadline(locale: Locale) -> String {
        let poses = [
            (0.0, 0.0), (180.0, 0.0), (90.0, 0.0), (-90.0, 0.0), (0.0, 90.0), (0.0, -90.0),
        ].map { PoseProjectionAngles(azimuth: $0.0, inclination: $0.1) }
        let angled = "At azimuth \(PoseProjectionWording.degreesShort(-180, locale: locale)), inclination \(PoseProjectionWording.degreesShort(-80, locale: locale)): depth mixes all three scores, so no two can be read off the axes."
        let all = poses.map { headline(for: $0, locale: locale) } + [angled]
        return all.max { $0.count < $1.count } ?? angled
    }

    func azimuthText(locale: Locale) -> String {
        PoseProjectionWording.degreesShort(azimuth, locale: locale)
    }

    func inclinationText(locale: Locale) -> String {
        PoseProjectionWording.degreesShort(inclination, locale: locale)
    }

    /// A slider speaks its setting, then the headline, instead of posting an announcement on every step.
    func azimuthSpokenValue(locale: Locale) -> String {
        "\(PoseProjectionWording.degrees(azimuth, locale: locale)). \(headline(locale: locale))"
    }

    func inclinationSpokenValue(locale: Locale) -> String {
        "\(PoseProjectionWording.degrees(inclination, locale: locale)). \(headline(locale: locale))"
    }

    /// The snippets for the current projection.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "pose-and-projection-chart", title: "Bind the pose"),
            SnippetReference(name: "pose-and-projection-gate", title: "Gate the 3D chart"),
            SnippetReference(name: "pose-and-projection-sync", title: "Keep sliders and pose together"),
            SnippetReference(name: "pose-and-projection-presets", title: "Presets"),
            projection == .orthographic
                ? SnippetReference(name: "pose-and-projection-orthographic", title: "Orthographic projection")
                : SnippetReference(name: "pose-and-projection-perspective", title: "Perspective projection"),
        ]
    }

    // MARK: Accessibility

    /// What each origin's element says: its name and count, then the extent of each score.
    func elementLabel(for cluster: PoseProjectionCluster, locale: Locale) -> String {
        "\(cluster.origin), \(PoseProjectionWording.samples(cluster.count, locale: locale))"
    }

    func elementValue(for cluster: PoseProjectionCluster, locale: Locale) -> String {
        func extent(_ name: String, _ range: ClosedRange<Double>) -> String {
            "\(name) \(PoseProjectionWording.score(range.lowerBound, locale: locale)) to \(PoseProjectionWording.score(range.upperBound, locale: locale))"
        }
        return [
            extent(PoseProjectionWording.acidity, cluster.acidity),
            extent(PoseProjectionWording.body.lowercased(), cluster.body),
            extent(PoseProjectionWording.sweetness.lowercased(), cluster.sweetness),
        ].joined(separator: ", ")
    }
}

/// The chart for the Audio Graph. A `Chart3D` gives assistive technologies nothing of its own, so this
/// describes the tastings as the chart opens on them, from the front: acidity across and body up, with
/// sweetness as a third axis that every point carries, one series per origin. The summary states the
/// clusters, and the trend the side view shows. Not tied
/// to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct PoseProjectionDescriptor: AXChartDescriptorRepresentable {
    let tastings: [BeanTasting]
    let locale: Locale

    /// Scores run from 0 to 10, the drawn domain on every axis.
    static let scoreRange: ClosedRange<Double> = 0 ... 10

    var summary: String {
        let facts = PoseProjectionFacts(tastings: tastings)
        guard let lightest = facts.lightest, let heaviest = facts.heaviest else { return "No tastings." }
        let score = { PoseProjectionWording.score($0, locale: locale) }
        let clusters = facts.clusters.map { cluster in
            "\(cluster.origin) averages acidity \(score(cluster.meanAcidity)), body \(score(cluster.meanBody)), sweetness \(score(cluster.meanSweetness))"
        }
        return "\(PoseProjectionWording.samples(tastings.count, locale: locale)) from \(PoseProjectionWording.origins(facts.clusters.count, locale: locale)), scored 0 to 10. "
            + clusters.joined(separator: "; ") + ". "
            + "Least body \(score(lightest.body)), with sweetness \(score(lightest.sweetness)); "
            + "most body \(score(heaviest.body)), with sweetness \(score(heaviest.sweetness))."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let facts = PoseProjectionFacts(tastings: tastings)
        let score: @Sendable (Double) -> String = { value in
            value.isFinite ? "\(PoseProjectionWording.score(value, locale: locale)) out of 10" : ""
        }
        func axis(_ title: String) -> AXNumericDataAxisDescriptor {
            AXNumericDataAxisDescriptor(title: title, range: Self.scoreRange, gridlinePositions: [], valueDescriptionProvider: score)
        }
        return AXChartDescriptor(
            title: "Bean tastings: body against acidity, with sweetness, by origin",
            summary: summary,
            xAxis: axis(PoseProjectionWording.acidity),
            yAxis: axis(PoseProjectionWording.body),
            additionalAxes: [axis(PoseProjectionWording.sweetness)],
            series: facts.clusters.map { cluster in
                AXDataSeriesDescriptor(
                    name: cluster.origin,
                    isContinuous: false,
                    dataPoints: tastings.filter { $0.origin == cluster.origin }.map {
                        AXDataPoint(x: $0.acidity, y: $0.body, additionalValues: [.number($0.sweetness)])
                    }
                )
            }
        )
    }
}
