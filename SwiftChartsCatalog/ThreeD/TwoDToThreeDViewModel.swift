import Accessibility
import Foundation
import Observation
import SwiftUI

/// The words this screen uses: the three tasting scores and the origin from `CafeWording`, and the scale's end.
nonisolated enum TwoDToThreeDWording {
    static let acidity = CafeWording.acidity
    static let body = CafeWording.body
    static let sweetness = CafeWording.sweetness
    static let origin = CafeWording.origin
    /// The end of every score's scale, said with each score so a bare number is not read alone.
    static let outOfTen = "out of 10"

    /// "1 sample", "60 samples".
    static func samples(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) sample](inflect: true)", locale: locale).characters)
    }

    /// A score as the axes draw it, to one decimal place in the reader's locale: "7.2", or "7,2" in German.
    static func score(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
    }

    /// A score rounded to a whole number, for the headline: every whole number has a grid line on the chart.
    static func wholeScore(_ value: Double, locale: Locale) -> String {
        value.rounded().formatted(.number.precision(.fractionLength(0)).locale(locale))
    }
}

/// One of the three tasting scores, each from 0 to 10.
nonisolated enum TwoDToThreeDScore: CaseIterable {
    case acidity, body, sweetness

    var name: String {
        switch self {
        case .acidity: TwoDToThreeDWording.acidity
        case .body: TwoDToThreeDWording.body
        case .sweetness: TwoDToThreeDWording.sweetness
        }
    }

    func value(of bean: BeanTasting) -> Double {
        switch self {
        case .acidity: bean.acidity
        case .body: bean.body
        case .sweetness: bean.sweetness
        }
    }

    /// Every score runs from 0 to 10, so every chart on the screen takes this one domain.
    static let domain: ClosedRange<Double> = 0 ... 10
}

/// Which chart the screen shows: one of the three 2D pairs, or the 3D chart of all three scores.
nonisolated enum TwoDToThreeDChart: CaseIterable, Hashable, Identifiable {
    case acidityBody, sweetnessBody, aciditySweetness, threeD

    var id: Self {
        self
    }

    /// The picker's short title.
    var title: String {
        switch self {
        case .acidityBody: "A × B"
        case .sweetnessBody: "S × B"
        case .aciditySweetness: "A × S"
        case .threeD: "3D"
        }
    }

    /// What the picker's segment speaks: the short title is letters, so VoiceOver gets the words.
    var spokenTitle: String {
        switch self {
        case .threeD: "3D, all three scores"
        default: "\(xScore.name) across, \(yScore.name.lowercased()) up"
        }
    }

    /// The score across the chart. In 3D, the x axis.
    var xScore: TwoDToThreeDScore {
        switch self {
        case .acidityBody, .aciditySweetness, .threeD: .acidity
        case .sweetnessBody: .sweetness
        }
    }

    /// The score up the chart. In 3D, the y axis.
    var yScore: TwoDToThreeDScore {
        switch self {
        case .acidityBody, .sweetnessBody, .threeD: .body
        case .aciditySweetness: .sweetness
        }
    }

    /// The score a 2D chart leaves out. In 3D, nothing is left out: the third score is the z axis.
    var hiddenScore: TwoDToThreeDScore? {
        switch self {
        case .acidityBody: .sweetness
        case .sweetnessBody: .acidity
        case .aciditySweetness: .body
        case .threeD: nil
        }
    }

    /// The face of the 3D cube that shows the same pair, seen straight on.
    var face: TwoDToThreeDViewpoint? {
        switch self {
        case .acidityBody: .front
        case .sweetnessBody: .side
        case .aciditySweetness: .below
        case .threeD: nil
        }
    }
}

/// Where the 3D chart is seen from. Each face matches one of the 2D charts; `angle` is the pose it opens on.
/// The third face is seen from below, not from the top: from the top, sweetness ran down the screen.
nonisolated enum TwoDToThreeDViewpoint: CaseIterable, Hashable {
    case angle, front, side, below

    var title: String {
        switch self {
        case .angle: "Angle"
        case .front: "Front"
        case .side: "Side"
        case .below: "Below"
        }
    }

    /// Where the chart is seen from, in a sentence: "the front", "below".
    var spokenPlace: String {
        switch self {
        case .angle: "the opening angle"
        case .front: "the front"
        case .side: "the side"
        case .below: "below"
        }
    }

    /// The 2D chart this face shows, or `nil` for the angled view, which shows all three scores.
    var matchingChart: TwoDToThreeDChart? {
        TwoDToThreeDChart.allCases.first { $0.face == self }
    }
}

/// One origin's samples and the span of each score among them.
nonisolated struct TwoDToThreeDCluster: Equatable {
    let origin: String
    let count: Int
    let acidity: ClosedRange<Double>
    let body: ClosedRange<Double>
    let sweetness: ClosedRange<Double>
    let meanAcidity: Double
    let meanBody: Double
    let meanSweetness: Double

    func span(of score: TwoDToThreeDScore) -> ClosedRange<Double> {
        switch score {
        case .acidity: acidity
        case .body: body
        case .sweetness: sweetness
        }
    }

    func mean(of score: TwoDToThreeDScore) -> Double {
        switch score {
        case .acidity: meanAcidity
        case .body: meanBody
        case .sweetness: meanSweetness
        }
    }
}

/// What the charts say in words: the headline, each cluster's label and value, and the Audio Graph's summary.
/// Not tied to the main actor, since the chart descriptor uses it.
nonisolated struct TwoDToThreeDSummary {
    let beans: [BeanTasting]
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The origins present in the data, in the legend's order, then any the legend does not know.
    var origins: [String] {
        let present = Set(beans.map(\.origin))
        let known = BeanOriginStyle.origins.filter(present.contains)
        var unknown: [String] = []
        for bean in beans where !known.contains(bean.origin) && !unknown.contains(bean.origin) {
            unknown.append(bean.origin)
        }
        return known + unknown
    }

    func beans(from origin: String) -> [BeanTasting] {
        beans.filter { $0.origin == origin }
    }

    var clusters: [TwoDToThreeDCluster] {
        origins.compactMap { origin in
            let samples = beans(from: origin)
            guard !samples.isEmpty else { return nil }
            func span(_ score: TwoDToThreeDScore) -> ClosedRange<Double> {
                let values = samples.map(score.value(of:))
                return (values.min() ?? 0) ... (values.max() ?? 0)
            }
            func mean(_ score: TwoDToThreeDScore) -> Double {
                samples.map(score.value(of:)).reduce(0, +) / Double(samples.count)
            }
            return TwoDToThreeDCluster(
                origin: origin, count: samples.count,
                acidity: span(.acidity), body: span(.body), sweetness: span(.sweetness),
                meanAcidity: mean(.acidity), meanBody: mean(.body), meanSweetness: mean(.sweetness)
            )
        }
    }

    // MARK: The headline

    /// The chart's message in a sentence, true of the chart that is drawn. Every figure is a whole number,
    /// and each whole number has a grid line.
    func headline(for chart: TwoDToThreeDChart) -> String {
        guard !beans.isEmpty else { return "No tastings recorded yet." }
        switch chart {
        case .acidityBody:
            return "\(leaderSentence(for: .acidity)); \(leaderSentence(for: .body, first: false))."
        case .aciditySweetness:
            return "\(leaderSentence(for: .acidity)); \(leaderSentence(for: .sweetness, first: false))."
        case .sweetnessBody:
            return trendSentence
        case .threeD:
            return "All three scores in one chart: turn it to see the origins apart and sweetness following body."
        }
    }

    /// "Ethiopia scores highest for acidity, about 7 to 9": the origin with the highest average score,
    /// and the span of that score among its samples. Ties name every origin that shares the highest average.
    private func leaderSentence(for score: TwoDToThreeDScore, first: Bool = true) -> String {
        let all = clusters
        guard let top = all.map({ $0.mean(of: score) }).max() else { return "" }
        let leaders = all.filter { $0.mean(of: score) == top }
        let names = CafeWording.list(leaders.map(\.origin))
        let low = leaders.map { $0.span(of: score).lowerBound }.min() ?? 0
        let high = leaders.map { $0.span(of: score).upperBound }.max() ?? 0
        let span = low.rounded() == high.rounded()
            ? "\(TwoDToThreeDWording.wholeScore(low, locale: locale))"
            : "\(TwoDToThreeDWording.wholeScore(low, locale: locale)) to \(TwoDToThreeDWording.wholeScore(high, locale: locale))"
        let sentence = leaders.count == all.count
            ? "every origin scores about \(span) for \(score.name.lowercased())"
            : "\(names) \(leaders.count == 1 ? "scores" : "score") highest for \(score.name.lowercased()), about \(span)"
        return first ? sentence.prefix(1).uppercased() + sentence.dropFirst() : sentence
    }

    /// Sweetness at the lightest and the fullest body, as two points a reader can find at either end of the chart.
    private var trendSentence: String {
        guard let lightest = beans.min(by: { $0.body < $1.body }),
              let fullest = beans.max(by: { $0.body < $1.body }) else { return "" }
        let score = { (value: Double) in TwoDToThreeDWording.wholeScore(value, locale: locale) }
        guard lightest.body.rounded() != fullest.body.rounded() else {
            return "Every sample has a body of about \(score(lightest.body)), so this view shows no trend."
        }
        let direction = if fullest.sweetness.rounded() > lightest.sweetness.rounded() {
            "Sweetness rises with body"
        } else if fullest.sweetness.rounded() < lightest.sweetness.rounded() {
            "Sweetness falls as body rises"
        } else {
            "Sweetness stays level as body rises"
        }
        return "\(direction): about \(score(lightest.sweetness)) for the lightest sample (body \(score(lightest.body))) "
            + "and \(score(fullest.sweetness)) for the fullest (body \(score(fullest.body)))."
    }

    // MARK: What assistive technologies get

    /// An element's label: the origin, then how many samples it covers.
    func elementLabel(for cluster: TwoDToThreeDCluster) -> String {
        "\(cluster.origin), \(TwoDToThreeDWording.samples(cluster.count, locale: locale))"
    }

    /// An element's value: the span of each score the chart draws, x first, in the order the axes are named
    /// everywhere on the screen. The 3D chart's elements carry all three.
    func elementValue(for cluster: TwoDToThreeDCluster, chart: TwoDToThreeDChart) -> String {
        let scores = chart == .threeD ? TwoDToThreeDScore.allCases : [chart.xScore, chart.yScore]
        return scores.map { score in
            let span = cluster.span(of: score)
            return "\(score.name) \(spoken(span))"
        }
        .joined(separator: ", ")
    }

    /// "4.1 to 6.9 out of 10", or "5 out of 10" when every sample shares the score.
    private func spoken(_ span: ClosedRange<Double>) -> String {
        let low = TwoDToThreeDWording.score(span.lowerBound, locale: locale)
        let high = TwoDToThreeDWording.score(span.upperBound, locale: locale)
        return low == high ? "\(low) \(TwoDToThreeDWording.outOfTen)" : "\(low) to \(high) \(TwoDToThreeDWording.outOfTen)"
    }

    /// The Audio Graph's title: what the chart is.
    func descriptorTitle(for chart: TwoDToThreeDChart) -> String {
        switch chart {
        case .threeD: "Bean tastings: acidity, body and sweetness, by origin"
        default: "Bean tastings: \(chart.xScore.name.lowercased()) against \(chart.yScore.name.lowercased()), by origin"
        }
    }

    /// The Audio Graph's summary, in actual values: the sample count, then each origin's spans.
    func audioGraphSummary(for chart: TwoDToThreeDChart) -> String {
        guard !beans.isEmpty else { return "No tastings recorded yet." }
        let origins = CafeWording.list(clusters.map(\.origin))
        let spans = clusters.map { "\($0.origin): \(elementValue(for: $0, chart: chart))." }.joined(separator: " ")
        return "\(TwoDToThreeDWording.samples(beans.count, locale: locale)) from \(origins). \(spans)"
    }

    /// What is announced when the picker changes the chart: what changed, then the headline.
    func announcement(for chart: TwoDToThreeDChart) -> String {
        let change = switch chart {
        case .threeD: "Showing the 3D chart of all three scores."
        default: "Showing \(chart.xScore.name.lowercased()) against \(chart.yScore.name.lowercased())."
        }
        return "\(change) \(headline(for: chart))"
    }

    /// What is announced when the viewpoint control turns the 3D chart: the face, then which scores it shows.
    func announcement(for viewpoint: TwoDToThreeDViewpoint) -> String {
        guard let chart = viewpoint.matchingChart else {
            return "Turned to the opening angle, which shows all three scores."
        }
        return "Seen from \(viewpoint.spokenPlace): \(chart.xScore.name.lowercased()) across, "
            + "\(chart.yScore.name.lowercased()) up, the same as the 2D chart of those two scores."
    }
}

/// The screen's state: which chart is shown and where the 3D chart is seen from, as plain values.
@Observable
final class TwoDToThreeDViewModel {
    let beans: [BeanTasting]
    var chart: TwoDToThreeDChart = .acidityBody {
        didSet {
            // The 3D view and its pose are made afresh each time the 3D chart is shown, opening on this
            // viewpoint. A pose turned by hand is not kept, so the control goes back to the opening angle with it.
            if chart == .threeD, viewpoint == nil { viewpoint = .angle }
        }
    }

    /// The viewpoint the control last chose, or `nil` once the chart has been turned by hand to a pose that is
    /// none of them. The pose itself is an iOS 26 type, so it lives in the 3D view, which opens on this
    /// viewpoint; this is what the view tells the model about it.
    var viewpoint: TwoDToThreeDViewpoint? = .angle

    /// The viewpoint the 3D view opens on: the one the control shows, or the opening angle.
    var openingViewpoint: TwoDToThreeDViewpoint {
        viewpoint ?? .angle
    }

    init(beans: [BeanTasting] = CafeData.beanTastings) {
        self.beans = beans
    }

    func summary(locale: Locale) -> TwoDToThreeDSummary {
        TwoDToThreeDSummary(beans: beans, locale: locale)
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline(for: chart)
    }

    var isEmpty: Bool {
        beans.isEmpty
    }

    /// The 3D view reports the pose it now has, as the viewpoint it matches, or `nil` for none.
    func poseChanged(toMatch matching: TwoDToThreeDViewpoint?) {
        if viewpoint != matching { viewpoint = matching }
    }

    /// The explanation under the chart, for the chart shown.
    var explanation: String {
        switch chart {
        case .threeD:
            """
            Chart becomes Chart3D, each PointMark gains a z, the z axis gets a label, and the three charts are \
            one; the legend, symbol(by:) and the labelled Plots do not come across, so the screen supplies them. \
            It is read by turning it: from the front it is the first chart, and turned, the clusters and the trend \
            show together. 3D earns that drag only where the shape matters more than the exact values.
            """
        default:
            if let hidden = chart.hiddenScore {
                """
                Each 2D scatter plot shows two of the three scores and leaves \(hidden.name.lowercased()) out. \
                Read together, the three answer every question about pairs exactly, with nothing to turn; \
                that is why the 3D chart has to earn its place.
                """
            } else {
                ""
            }
        }
    }

    /// The snippets See Code shows: the 2D chart, or the 3D chart with its availability check.
    var snippets: [SnippetReference] {
        switch chart {
        case .threeD: Self.threeDSnippets
        default: Self.twoDSnippets
        }
    }

    static let twoDSnippets = [
        SnippetReference(name: "from-2d-to-3d-scatter", title: "A 2D scatter plot"),
        SnippetReference(name: "from-2d-to-3d-elements", title: "One element per origin"),
    ]

    static let threeDSnippets = [
        SnippetReference(name: "from-2d-to-3d-chart3d", title: "The same chart in 3D"),
        SnippetReference(name: "from-2d-to-3d-gate", title: "The availability check"),
        SnippetReference(name: "from-2d-to-3d-pose", title: "Turning it from a control"),
        SnippetReference(name: "from-2d-to-3d-elements", title: "One element per origin"),
    ]
}

/// The chart for the Audio Graph: acidity on x, a score on y, and in 3D sweetness as a third axis. Every
/// score is said with its scale. Not tied to the main actor: the accessibility system calls it when it chooses.
nonisolated struct TwoDToThreeDDescriptor: AXChartDescriptorRepresentable {
    let beans: [BeanTasting]
    let chart: TwoDToThreeDChart
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = TwoDToThreeDSummary(beans: beans, locale: locale)
        let locale = locale
        func axis(_ score: TwoDToThreeDScore) -> AXNumericDataAxisDescriptor {
            AXNumericDataAxisDescriptor(
                title: score.name, range: TwoDToThreeDScore.domain, gridlinePositions: []
            ) { value in
                value.isFinite ? "\(TwoDToThreeDWording.score(value, locale: locale)) \(TwoDToThreeDWording.outOfTen)" : ""
            }
        }
        let third: TwoDToThreeDScore? = chart == .threeD ? .sweetness : nil
        let series = summary.origins.map { origin in
            AXDataSeriesDescriptor(
                name: origin,
                isContinuous: false,
                dataPoints: summary.beans(from: origin).map { bean in
                    AXDataPoint(
                        x: chart.xScore.value(of: bean),
                        y: chart.yScore.value(of: bean),
                        additionalValues: third.map { [.number($0.value(of: bean))] } ?? []
                    )
                }
            )
        }
        return AXChartDescriptor(
            title: summary.descriptorTitle(for: chart),
            summary: summary.audioGraphSummary(for: chart),
            xAxis: axis(chart.xScore),
            yAxis: axis(chart.yScore),
            additionalAxes: third.map { [axis($0)] } ?? [],
            series: series
        )
    }
}
