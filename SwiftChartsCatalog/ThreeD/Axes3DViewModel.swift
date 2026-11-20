import Foundation
import Observation

/// The three tasting scores, one on each axis of the chart: acidity across (x), body up (y) and
/// sweetness in depth (z), the same mapping the skill's 3D recipes use.
nonisolated enum Axes3DAxis: CaseIterable, Hashable {
    case acidity, body, sweetness

    /// The axis title and the `.value` label, from `CafeWording`.
    var title: String {
        switch self {
        case .acidity: CafeWording.acidity
        case .body: CafeWording.body
        case .sweetness: CafeWording.sweetness
        }
    }

    /// The title inside a sentence: "acidity".
    var lowercaseTitle: String {
        title.lowercased()
    }

    /// Which axis of the chart it is on.
    var chartAxisName: String {
        switch self {
        case .acidity: "x"
        case .body: "y"
        case .sweetness: "z"
        }
    }

    func score(of bean: BeanTasting) -> Double {
        switch self {
        case .acidity: bean.acidity
        case .body: bean.body
        case .sweetness: bean.sweetness
        }
    }
}

/// The angles the chart can be turned to from a button, for anyone who cannot drag it. Each
/// shows two axes face on, except the angled view, which shows all three.
nonisolated enum Axes3DViewpoint: CaseIterable, Hashable {
    case angled, front, side, below

    var title: String {
        switch self {
        case .angled: "Angled"
        case .front: "Front"
        case .side: "Side"
        case .below: "Below"
        }
    }

    /// The angles of the framework's presets, as read on iOS (`chart3d.md`, *Camera and pose*):
    /// `.default` −30/15, `.front` 0/0, `.left` 90/0, `.bottom` 0/−89.9.
    var azimuthDegrees: Double {
        switch self {
        case .angled: -30
        case .front: 0
        case .side: 90
        case .below: 0
        }
    }

    var inclinationDegrees: Double {
        switch self {
        case .angled: 15
        case .front: 0
        case .side: 0
        case .below: -89.9
        }
    }

    /// What the button's view shows, spoken as its hint.
    var spokenHint: String {
        switch self {
        case .angled: "Shows all three axes."
        case .front: "Acidity across, body up."
        case .side: "Sweetness across, body up."
        case .below: "Acidity across, sweetness up."
        }
    }
}

/// One origin's samples inside the three domains: one accessibility element.
nonisolated struct Axes3DOriginGroup: Identifiable, Hashable {
    let origin: String
    let beans: [BeanTasting]
    var id: String {
        origin
    }

    /// The lowest acidity among the samples: where the group's element starts along x.
    var leadingEdge: Double {
        beans.map(\.acidity).min() ?? 0
    }
}

/// The state of *Scales and axes in 3D*: where each axis's domain starts, the angle the chart is
/// seen from, and every sentence the screen shows or speaks.
@Observable
final class Axes3DViewModel {
    /// The top of every score, and so of every domain: the scores run from 0 to 10.
    nonisolated static let scoreTop = 10.0
    /// How far a domain's start can be moved up, in whole scores.
    nonisolated static let startRange = 0.0 ... 5.0

    let beans: [BeanTasting]

    /// Where each axis's domain starts. The domain always ends at 10.
    var acidityStart = 0.0
    var bodyStart = 0.0
    var sweetnessStart = 0.0

    /// The chart's viewing angle, as plain numbers; the chart's iOS 26 view turns them into a pose
    /// and writes a drag back into them.
    var azimuthDegrees = Axes3DViewpoint.angled.azimuthDegrees
    var inclinationDegrees = Axes3DViewpoint.angled.inclinationDegrees

    init(beans: [BeanTasting] = CafeData.beanTastings) {
        self.beans = beans
    }

    // MARK: Domains and axis marks

    func start(for axis: Axes3DAxis) -> Double {
        switch axis {
        case .acidity: acidityStart
        case .body: bodyStart
        case .sweetness: sweetnessStart
        }
    }

    func setStart(_ value: Double, for axis: Axes3DAxis) {
        let clamped = min(Self.startRange.upperBound, max(Self.startRange.lowerBound, value.rounded()))
        switch axis {
        case .acidity: acidityStart = clamped
        case .body: bodyStart = clamped
        case .sweetness: sweetnessStart = clamped
        }
    }

    /// The scale's domain for the axis, in data values: from its start to 10.
    func domain(for axis: Axes3DAxis) -> ClosedRange<Double> {
        start(for: axis) ... Self.scoreTop
    }

    func markedValues(for axis: Axes3DAxis) -> [Double] {
        Self.markedValues(in: domain(for: axis))
    }

    /// The values an axis marks: every even score strictly inside the domain. A 3D axis does not
    /// label its domain's ends (`chart3d.md`, *Scales and axes in 3D*), so neither end is listed.
    nonisolated static func markedValues(in domain: ClosedRange<Double>) -> [Double] {
        stride(from: 0.0, through: scoreTop, by: 2).filter { $0 > domain.lowerBound && $0 < domain.upperBound }
    }

    /// Whether a sample lies inside all three domains.
    func isInside(_ bean: BeanTasting) -> Bool {
        Axes3DAxis.allCases.allSatisfy { domain(for: $0).contains($0.score(of: bean)) }
    }

    /// The samples the chart draws: those inside all three domains. The rest are left out by the app,
    /// so no point is drawn outside the cube.
    var beansInside: [BeanTasting] {
        beans.filter(isInside)
    }

    /// The samples inside the domains, one group per origin that has any, in the order VoiceOver reads
    /// them, which the key and the Audio Graph follow. Read on the iOS 27 simulator, the representation's
    /// elements came out by the leading edge of their frames (Sumatra, Colombia, Ethiopia), not in the
    /// order they were declared, so the groups are sorted by their lowest acidity, the origins' own order
    /// breaking a tie.
    /// The groups in the app's one order of origins (`BeanOriginStyle.origins`), for the key and the Audio Graph's
    /// series, so they list the origins as every other bean screen does. The elements keep the order the
    /// accessibility tree gives them, which follows the chart, not the data.
    var originGroupsInOriginOrder: [Axes3DOriginGroup] {
        originGroups.enumerated().sorted { first, second in
            let one = BeanOriginStyle.origins.firstIndex(of: first.element.origin) ?? Int.max
            let two = BeanOriginStyle.origins.firstIndex(of: second.element.origin) ?? Int.max
            return (one, first.offset) < (two, second.offset)
        }
        .map(\.element)
    }

    var originGroups: [Axes3DOriginGroup] {
        let inside = beansInside
        let known = BeanOriginStyle.origins
        var origins = known.filter { origin in inside.contains { $0.origin == origin } }
        for bean in inside where !origins.contains(bean.origin) {
            origins.append(bean.origin)
        }
        let groups = origins.map { origin in Axes3DOriginGroup(origin: origin, beans: inside.filter { $0.origin == origin }) }
        return groups.enumerated()
            .sorted { ($0.element.leadingEdge, $0.offset) < ($1.element.leadingEdge, $1.offset) }
            .map(\.element)
    }

    /// Every state that changes the elements or the chart descriptor, for the chart's identity:
    /// VoiceOver and the Audio Graph keep what they read for an identity (`accessibility.md`, *Pitfalls*).
    var chartIdentity: String {
        Axes3DAxis.allCases.map { "\(start(for: $0))" }.joined(separator: "-")
    }

    // MARK: Pose

    func show(_ viewpoint: Axes3DViewpoint) {
        azimuthDegrees = viewpoint.azimuthDegrees
        inclinationDegrees = viewpoint.inclinationDegrees
    }

    // MARK: Words

    /// The chart's message: how many samples lie inside the three domains. Each one inside is drawn.
    func headline(locale: Locale) -> String {
        let inside = beansInside.count
        let total = Axes3DWording.samples(beans.count, locale: locale)
        if beans.isEmpty {
            return "No bean samples to show."
        }
        if inside == beans.count {
            return "Inside the three domains: all \(total)."
        }
        if inside == 0 {
            return "Inside the three domains: none of the \(total)."
        }
        return "Inside the three domains: \(inside.formatted(.number.locale(locale))) of \(total)."
    }

    /// The domain as the slider's row shows it: "3 to 10".
    func domainText(for axis: Axes3DAxis, locale: Locale) -> String {
        let domain = domain(for: axis)
        return "\(Self.score(domain.lowerBound, locale: locale)) to \(Self.score(domain.upperBound, locale: locale))"
    }

    /// What the slider speaks: the setting, then the headline, so a step that changes what is drawn
    /// is heard without an announcement on every step (`accessibility-beyond-voiceover.md`).
    func sliderSpokenValue(for axis: Axes3DAxis, locale: Locale) -> String {
        "\(domainText(for: axis, locale: locale)). \(headline(locale: locale))"
    }

    func sliderTitle(for axis: Axes3DAxis) -> String {
        "\(axis.title) domain"
    }

    /// The axis's marked values in words, for the descriptor's summary: "2, 4, 6, and 8".
    func markedValuesText(for axis: Axes3DAxis, locale: Locale) -> String {
        let values = markedValues(for: axis).map { Self.score($0, locale: locale) }
        return values.isEmpty ? "nothing" : CafeWording.list(values)
    }

    /// The label of an origin's element: the origin first, as context.
    func elementLabel(for group: Axes3DOriginGroup) -> String {
        group.origin
    }

    /// The value of an origin's element: how many samples, and the span of each score among them.
    func elementValue(for group: Axes3DOriginGroup, locale: Locale) -> String {
        let spans = Axes3DAxis.allCases.map { axis in
            let scores = group.beans.map(axis.score)
            let low = Self.score(scores.min() ?? 0, locale: locale)
            let high = Self.score(scores.max() ?? 0, locale: locale)
            return "\(axis.lowercaseTitle) \(low) to \(high)"
        }
        return "\(Axes3DWording.samples(group.beans.count, locale: locale)). \(CafeWording.list(spans))."
    }

    /// The Audio Graph's summary, in actual values.
    func audioGraphSummary(locale: Locale) -> String {
        let domains = Axes3DAxis.allCases.map { "\($0.lowercaseTitle) \(domainText(for: $0, locale: locale))" }
        let groups = originGroupsInOriginOrder.map { "\($0.origin) \(Axes3DWording.samples($0.beans.count, locale: locale))" }
        var sentences = [headline(locale: locale), "Domains: \(CafeWording.list(domains))."]
        if !groups.isEmpty {
            sentences.append("\(CafeWording.list(groups)).")
        }
        return sentences.joined(separator: " ")
    }

    /// A score written with at most one decimal place, in the view's locale: "3", "6.5".
    nonisolated static func score(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
    }
}

/// Words the screen needs that `CafeWording` does not have.
nonisolated enum Axes3DWording {
    /// "1 sample", "60 samples".
    static func samples(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) sample](inflect: true)", locale: locale).characters)
    }
}
