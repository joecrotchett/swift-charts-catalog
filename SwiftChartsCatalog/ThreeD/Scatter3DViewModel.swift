import Accessibility
import Observation
import SwiftUI

/// The state of the 3D scatter screen: the shape the points take and the three sliders that style them.
/// None of them changes the data or the scales, so the headline, the elements and the descriptor stay put.
@Observable
final class Scatter3DViewModel {
    let beans: [BeanTasting]
    var shapeChoice: Scatter3DShapeChoice = .byOrigin
    var symbolSize = Scatter3DDefaults.symbolSize
    var metalness = Scatter3DDefaults.metalness
    var roughness = Scatter3DDefaults.roughness

    init(beans: [BeanTasting] = CafeData.beanTastings) {
        self.beans = beans
    }

    /// The origins in the order the data gives them (for the sample data, `CafeData.beanOrigins`).
    var origins: [String] {
        Scatter3DSummary.origins(of: beans)
    }

    var hasData: Bool {
        !beans.isEmpty
    }

    func summary(locale: Locale) -> Scatter3DSummary {
        Scatter3DSummary(beans: beans, locale: locale)
    }

    /// The solid each origin is drawn with under the current choice, in origin order.
    var shapes: [BeanOriginSolid] {
        origins.map { shapeChoice.solid(for: $0) }
    }

    /// The SF Symbol the legend draws for each origin, in origin order: the origin's own symbol from
    /// `BeanOriginStyle` under "By origin", otherwise the picture of the one solid every point takes.
    var legendSymbolNames: [String] {
        origins.map { shapeChoice.fixedSolid?.symbolName ?? BeanOriginStyle.symbolName(for: $0) }
    }

    /// Said aloud when the shape picker changes which shape each origin gets: what changed, then the headline.
    func shapeChangeAnnouncement(locale: Locale) -> String {
        let change = if let solid = shapeChoice.fixedSolid {
            "Every point is now a \(solid.name)."
        } else {
            "Each origin now has its own shape."
        }
        return "\(change) \(summary(locale: locale).headline)"
    }

    func symbolSizeText(locale: Locale) -> String {
        symbolSize.formatted(.number.precision(.fractionLength(2)).locale(locale))
    }

    func metalnessText(locale: Locale) -> String {
        metalness.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    func roughnessText(locale: Locale) -> String {
        roughness.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// The same four snippets in every state: the controls change values, not the code.
    let snippets = Scatter3DViewModel.snippetReferences

    static let snippetReferences = [
        SnippetReference(name: "3d-scatter-chart", title: "Chart3D with PointMark(x:y:z:)"),
        SnippetReference(name: "3d-scatter-gate", title: "The iOS 26 check"),
        SnippetReference(name: "3d-scatter-legend", title: "A legend of your own"),
        SnippetReference(name: "3d-scatter-accessibility", title: "Elements and Audio Graph"),
    ]
}

/// Where the controls start.
nonisolated enum Scatter3DDefaults {
    static let symbolSize = 0.05
    static let symbolSizeRange = 0.02 ... 0.1
    static let symbolSizeStep = 0.01
    static let metalness = 0.0
    static let roughness = 0.5
    static let materialStep = 0.1
}

/// What the shape picker offers: a shape per origin (a second cue beside colour), or one shape for every point.
nonisolated enum Scatter3DShapeChoice: String, CaseIterable, Identifiable {
    case byOrigin, sphere, cube, cylinder, cone

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .byOrigin: "By origin"
        case .sphere: "Sphere"
        case .cube: "Cube"
        case .cylinder: "Cylinder"
        case .cone: "Cone"
        }
    }

    /// The one solid every point takes, or `nil` under "By origin".
    var fixedSolid: BeanOriginSolid? {
        switch self {
        case .byOrigin: nil
        case .sphere: .sphere
        case .cube: .cube
        case .cylinder: .cylinder
        case .cone: .cone
        }
    }

    /// The solid an origin's points take: under "By origin", the origin's own from `BeanOriginStyle`.
    func solid(for origin: String) -> BeanOriginSolid {
        fixedSolid ?? BeanOriginStyle.solid(for: origin)
    }
}

/// The words for this data: the scores and the origin from `CafeWording`, and the scores' shared range.
nonisolated enum Scatter3DWording {
    static let acidity = CafeWording.acidity
    static let body = CafeWording.body
    static let sweetness = CafeWording.sweetness
    static let origin = CafeWording.origin
    /// Every score runs from 0 to 10: the scales and the descriptor share this range.
    static let scoreRange: ClosedRange<Double> = 0 ... 10

    /// "1 sample", "60 samples".
    static func samples(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) sample](inflect: true)", locale: locale).characters)
    }

    /// "1 origin", "3 origins".
    static func origins(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) origin](inflect: true)", locale: locale).characters)
    }

    /// A score with one decimal place: "7.8".
    static func score(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// A score as the Audio Graph says it: "7.8 out of 10", or "" for a value that is not finite.
    static func spokenScore(_ value: Double, locale: Locale) -> String {
        guard value.isFinite else { return "" }
        return "\(score(value, locale: locale)) out of 10"
    }
}

/// One origin's samples and what is said about them.
nonisolated struct Scatter3DOriginGroup: Equatable {
    let origin: String
    let beans: [BeanTasting]

    func mean(_ score: KeyPath<BeanTasting, Double>) -> Double {
        beans.isEmpty ? 0 : beans.map { $0[keyPath: score] }.reduce(0, +) / Double(beans.count)
    }

    func span(_ score: KeyPath<BeanTasting, Double>) -> ClosedRange<Double> {
        let values = beans.map { $0[keyPath: score] }
        return (values.min() ?? 0) ... (values.max() ?? 0)
    }
}

/// Every text the chart's accessibility gives, in one place: the element for each origin and the Audio Graph.
/// A `Chart3D` gives assistive technologies nothing, so all of it is the screen's.
nonisolated struct Scatter3DSpokenText: Equatable {
    struct Element: Equatable {
        let label: String
        let value: String
    }

    let elements: [Element]
    let descriptorTitle: String
    let descriptorSummary: String
}

/// What the chart says in words: the headline, the elements, and the Audio Graph. Its locale has no default.
nonisolated struct Scatter3DSummary {
    let beans: [BeanTasting]
    let locale: Locale

    static func origins(of beans: [BeanTasting]) -> [String] {
        var origins: [String] = []
        for bean in beans where !origins.contains(bean.origin) {
            origins.append(bean.origin)
        }
        return origins
    }

    var groups: [Scatter3DOriginGroup] {
        Self.origins(of: beans).map { origin in
            Scatter3DOriginGroup(origin: origin, beans: beans.filter { $0.origin == origin })
        }
    }

    /// Every origin whose mean for a score is the highest, in origin order (more than one on a tie).
    func leaders(by score: KeyPath<BeanTasting, Double>) -> [String] {
        let means = groups.map { ($0.origin, $0.mean(score)) }
        guard let best = means.map(\.1).max() else { return [] }
        return means.filter { $0.1 == best }.map(\.0)
    }

    /// True for every setting of the controls, since none of them changes the data.
    var headline: String {
        guard !beans.isEmpty else { return "No bean tastings yet." }
        let counts = "\(Scatter3DWording.samples(beans.count, locale: locale)) from "
            + "\(Scatter3DWording.origins(groups.count, locale: locale))."
        guard groups.count > 1 else { return counts }
        return "\(counts) Most acidic: \(CafeWording.list(leaders(by: \.acidity))). "
            + "Fullest body: \(CafeWording.list(leaders(by: \.body)))."
    }

    var spokenText: Scatter3DSpokenText {
        Scatter3DSpokenText(
            elements: groups.map { group in
                Scatter3DSpokenText.Element(
                    label: group.origin,
                    value: "\(Scatter3DWording.samples(group.beans.count, locale: locale)). "
                        + "\(Scatter3DWording.acidity) \(spanText(group.span(\.acidity))), "
                        + "\(Scatter3DWording.body.lowercased()) \(spanText(group.span(\.body))), "
                        + "\(Scatter3DWording.sweetness.lowercased()) \(spanText(group.span(\.sweetness)))."
                )
            },
            descriptorTitle: "Bean tastings: acidity, body and sweetness, by origin",
            descriptorSummary: audioGraphSummary
        )
    }

    /// Actual values only: each origin's mean scores.
    var audioGraphSummary: String {
        guard !beans.isEmpty else { return "No bean tastings yet." }
        let perOrigin = groups.map { group in
            "\(group.origin): mean acidity \(Scatter3DWording.score(group.mean(\.acidity), locale: locale)), "
                + "body \(Scatter3DWording.score(group.mean(\.body), locale: locale)), "
                + "sweetness \(Scatter3DWording.score(group.mean(\.sweetness), locale: locale))."
        }
        return (["\(Scatter3DWording.samples(beans.count, locale: locale)) from "
                + "\(Scatter3DWording.origins(groups.count, locale: locale)), each scored 0 to 10."] + perOrigin)
            .joined(separator: " ")
    }

    /// "6.9 to 8.7", or the one score when every sample has it.
    private func spanText(_ span: ClosedRange<Double>) -> String {
        let low = Scatter3DWording.score(span.lowerBound, locale: locale)
        let high = Scatter3DWording.score(span.upperBound, locale: locale)
        return low == high ? low : "\(low) to \(high)"
    }
}

/// The Audio Graph: acidity on x, body on y, sweetness as an additional axis, one series per origin.
/// `chart3d.md` and `audio-graph.md` give no 3D descriptor; this uses the Accessibility framework's
/// `additionalAxes` and `AXDataPoint(additionalValues:)`, read from the SDK's interface.
nonisolated struct Scatter3DChartDescriptor: AXChartDescriptorRepresentable {
    let summary: Scatter3DSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let text = summary.spokenText
        func axis(_ title: String) -> AXNumericDataAxisDescriptor {
            AXNumericDataAxisDescriptor(title: title, range: Scatter3DWording.scoreRange, gridlinePositions: []) { value in
                Scatter3DWording.spokenScore(value, locale: locale)
            }
        }
        return AXChartDescriptor(
            title: text.descriptorTitle,
            summary: text.descriptorSummary,
            xAxis: axis(Scatter3DWording.acidity),
            yAxis: axis(Scatter3DWording.body),
            additionalAxes: [axis(Scatter3DWording.sweetness)],
            series: summary.groups.map { group in
                AXDataSeriesDescriptor(
                    name: group.origin,
                    isContinuous: false,
                    dataPoints: group.beans.map { bean in
                        AXDataPoint(x: bean.acidity, y: bean.body, additionalValues: [.number(bean.sweetness)])
                    }
                )
            }
        )
    }
}
