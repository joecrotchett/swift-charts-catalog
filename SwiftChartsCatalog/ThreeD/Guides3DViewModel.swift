import Accessibility
import Foundation
import Observation
import SwiftUI

/// The three axes of the tasting scores, x, y and z in that order.
nonisolated enum Guides3DAxis: CaseIterable, Hashable {
    case acidity, body, sweetness

    /// The axis's name, as its axis title and every sentence say it. `CafeWording` has no words for the bean
    /// scores, so they are kept here.
    var title: String {
        switch self {
        case .acidity: "Acidity"
        case .body: "Body"
        case .sweetness: "Sweetness"
        }
    }

    /// The name inside a sentence: "a rule along acidity".
    var lowercasedTitle: String {
        title.lowercased()
    }

    /// The letter of the chart's axis it is drawn on.
    var letter: String {
        switch self {
        case .acidity: "x"
        case .body: "y"
        case .sweetness: "z"
        }
    }
}

/// The 3D mark the chosen ranges make: no range a point, one a rule, two a rectangle.
nonisolated enum Guides3DMarkKind: Hashable {
    case point, rule, rectangle

    var name: String {
        switch self {
        case .point: "point"
        case .rule: "rule"
        case .rectangle: "rectangle"
        }
    }
}

/// The angles the chart can be turned to without a drag.
nonisolated enum Guides3DViewAngle: CaseIterable, Hashable {
    case angled, front, side, top

    /// The axis this angle looks straight along, if any: a rule along it is seen end-on, and a rectangle
    /// across it edge-on. The front looks along z and the top along y (`chart3d.md`: `.front` shows x across
    /// and y up, `.bottom` x across and z up); the side, `.left`, shows z across and y up, so it looks along x.
    var lineOfSight: Guides3DAxis? {
        switch self {
        case .angled: nil
        case .front: .sweetness
        case .side: .acidity
        case .top: .body
        }
    }

    /// The angle inside a sentence: "from the front".
    var phrase: String {
        switch self {
        case .angled: "from an angle"
        case .front: "from the front"
        case .side: "from the side"
        case .top: "from the top"
        }
    }

    var title: String {
        switch self {
        case .angled: "Angled"
        case .front: "Front"
        case .side: "Side"
        case .top: "Top"
        }
    }

    /// The angles of each preset, in degrees. Front, side and top are the framework's `.front`, `.left` and
    /// `.top`, as read on iOS (`chart3d.md`): top is 89.9, since inclination stops a tenth of a degree short
    /// of straight down. The chart opens angled, tilted further than the default's 15 degrees so a flat
    /// rectangle across acidity and sweetness shows as a plane rather than a sliver.
    var azimuthDegrees: Double {
        switch self {
        case .angled: -30
        case .front, .top: 0
        case .side: 90
        }
    }

    var inclinationDegrees: Double {
        switch self {
        case .angled: 25
        case .front, .side: 0
        case .top: 89.9
        }
    }
}

/// The scale every axis shares: the roaster's scores run from 0 to 10, and the guide sits at the middle.
nonisolated enum Guides3DScale {
    static let lower = 0.0
    static let upper = 10.0
    /// Where a guide's single values sit: the middle of the scale.
    static let reference = 5.0
    static let domain = lower ... upper
    /// The values each axis labels. A 3D axis does not label its domain's ends, so these lie inside it,
    /// and they include the reference, so the figure the headline names is labelled on every axis.
    static let labelledValues: [Double] = [1, 3, 5, 7, 9]
    /// Where the rectangle is drawn on each axis given 0 to 10, read from renders on the iOS 27.0 simulator:
    /// 2.5 to 7.5. A 3D rectangle is centred on its ranges, but its width is the length of the range taken
    /// through the scale as if it were a position (a range of 10 on a domain of 0 to 10 and a range of
    /// −0.5 to 0.5 maps to 0.5, half the box), so 0..<5 draws nothing and 4..<6 draws wider than 2..<8.
    /// A rule spans its range in full. The spoken text describes what is drawn.
    static let drawnRectangleSpan = 2.5 ... 7.5
}

/// State and words for "Rules and rectangles in 3D": which axes get a range, and what that draws.
@MainActor
@Observable
final class Guides3DViewModel {
    /// The axes given a range instead of a single value. A 3D mark takes at most two.
    private(set) var ranges: Set<Guides3DAxis> = [.acidity]
    /// The preset the chart is turned to, or nil once a drag has turned it somewhere else.
    private(set) var viewAngle: Guides3DViewAngle? = .angled
    /// The chart's viewing angle as plain numbers. The chart's iOS 26 view turns them into a pose and writes
    /// a drag back through `turn(azimuth:inclination:)`, so the angle survives the chart's new identity.
    private(set) var azimuthDegrees = Guides3DViewAngle.angled.azimuthDegrees
    private(set) var inclinationDegrees = Guides3DViewAngle.angled.inclinationDegrees
    let beans: [BeanTasting]

    /// The most ranges a 3D mark takes: two make a rectangle, and there is no mark with three.
    static let maximumRanges = 2

    init(beans: [BeanTasting] = CafeData.beanTastings) {
        self.beans = beans
    }

    /// The axes with a range, in x, y, z order.
    var orderedRanges: [Guides3DAxis] {
        Guides3DAxis.allCases.filter { ranges.contains($0) }
    }

    /// The axes with a single value, in x, y, z order.
    var singleAxes: [Guides3DAxis] {
        Guides3DAxis.allCases.filter { !ranges.contains($0) }
    }

    var markKind: Guides3DMarkKind {
        switch ranges.count {
        case 0: .point
        case 1: .rule
        default: .rectangle
        }
    }

    func hasRange(_ axis: Guides3DAxis) -> Bool {
        ranges.contains(axis)
    }

    /// Whether the axis's switch can be turned on: off once two others have ranges.
    func canToggle(_ axis: Guides3DAxis) -> Bool {
        ranges.contains(axis) || ranges.count < Self.maximumRanges
    }

    /// Gives the axis a range or takes it away, and returns what to announce: what changed, then the headline.
    /// Returns nil when nothing changed, including a third range, which no 3D mark takes.
    @discardableResult
    func setRange(_ axis: Guides3DAxis, _ isOn: Bool, locale: Locale) -> String? {
        guard isOn != ranges.contains(axis) else { return nil }
        if isOn {
            guard ranges.count < Self.maximumRanges else { return nil }
            ranges.insert(axis)
        } else {
            ranges.remove(axis)
        }
        let change = isOn ? "Range on \(axis.lowercasedTitle) added." : "Range on \(axis.lowercasedTitle) removed."
        return "\(change) \(headline(locale: locale))"
    }

    /// Turns the chart to a preset and returns what to announce when that changes the headline, as it does
    /// when the guide comes to be seen end-on or edge-on, or stops being.
    @discardableResult
    func setViewAngle(_ angle: Guides3DViewAngle?, locale: Locale) -> String? {
        let before = headline(locale: locale)
        viewAngle = angle
        if let angle {
            azimuthDegrees = angle.azimuthDegrees
            inclinationDegrees = angle.inclinationDegrees
        }
        let after = headline(locale: locale)
        guard before != after, let angle else { return nil }
        return "Viewed \(angle.phrase). \(after)"
    }

    /// Takes the angle a drag turned the chart to. Once it is more than a degree from the preset, the picker
    /// lets go of it, so neither it nor the headline names an angle the chart is no longer at; less than a
    /// degree is rounding in what the chart writes back.
    func turn(azimuth: Double, inclination: Double) {
        azimuthDegrees = azimuth
        inclinationDegrees = inclination
        guard let angle = viewAngle else { return }
        if abs(azimuth - angle.azimuthDegrees) >= 1 || abs(inclination - angle.inclinationDegrees) >= 1 {
            viewAngle = nil
        }
    }

    /// Whether the current preset looks along the guide, so it draws nothing: a rule seen end-on, a rectangle
    /// edge-on. A point is seen from every side.
    var isGuideHidden: Bool {
        guard let axis = viewAngle?.lineOfSight else { return false }
        switch markKind {
        case .point: return false
        case .rule: return ranges == [axis]
        case .rectangle: return ranges.contains(axis)
        }
    }

    /// The explanation under the chart: the concept, then what this setting draws.
    var explanation: String {
        let concept = """
        A 3D mark takes a value on each of x, y and z. Give one axis a range instead and the mark is a RuleMark, \
        a line along that axis; give two axes ranges and it is a RectangleMark, a flat plane across them. There is \
        no mark with three ranges. Here each range is 0 to 10, the whole scale, and each single value is 5, its \
        middle, among the 60 bean samples drawn in grey. Top looks down from 89.9 degrees, the steepest a pose \
        goes, and a guide lying along the line of sight still draws nothing there.
        """
        switch markKind {
        case .point:
            return concept
        case .rule:
            return concept + """
             A 3D rule has no line width to set: it is drawn as a red hairline, so look closely for it.
            """
        case .rectangle:
            return concept + """
             On iOS 27 the rectangle is drawn smaller than its ranges, centred on them: given 0 to 10 it covers \
            2.5 to 7.5 on each axis. A rule reaches both ends of its range.
            """
        }
    }

    /// A chart identity built from every state that changes the elements' text or the chart descriptor.
    var chartIdentity: String {
        orderedRanges.map(\.letter).joined(separator: "-") + "-ranges-" + (isGuideHidden ? "hidden" : "shown")
    }

    /// The chart's message: which mark the ranges make, and where it sits.
    func headline(locale: Locale) -> String {
        let reference = Self.number(Guides3DScale.reference, locale: locale)
        let singles = singleAxes.map { "\($0.lowercasedTitle) \(reference)" }
        let ranged = CafeWording.list(orderedRanges.map(\.lowercasedTitle))
        switch markKind {
        case .point:
            return "No range makes a point: one mark at \(CafeWording.list(singles))."
        case .rule:
            return "One range makes a rule: a line along \(ranged), at \(CafeWording.list(singles))." + hiddenSentence
        case .rectangle:
            return "Two ranges make a rectangle: a plane across \(ranged), at \(CafeWording.list(singles))."
                + hiddenSentence
        }
    }

    /// Said after the headline when the preset looks along the guide.
    private var hiddenSentence: String {
        guard isGuideHidden, let angle = viewAngle else { return "" }
        let view = markKind == .rule ? "end-on" : "edge-on"
        return " Seen \(view) \(angle.phrase), it draws nothing."
    }

    /// The guide's accessibility label: what it is, with its axes.
    var guideLabel: String {
        let ranged = CafeWording.list(orderedRanges.map(\.lowercasedTitle))
        return switch markKind {
        case .point: "Reference point"
        case .rule: "Reference rule along \(ranged)"
        case .rectangle: "Reference plane across \(ranged)"
        }
    }

    /// The guide's accessibility value: where it lies on each axis, x first.
    func guideValue(locale: Locale) -> String {
        let span = markKind == .rectangle ? Guides3DScale.drawnRectangleSpan : Guides3DScale.domain
        let lower = Self.number(span.lowerBound, locale: locale)
        let upper = Self.number(span.upperBound, locale: locale)
        let reference = Self.number(Guides3DScale.reference, locale: locale)
        let positions = Guides3DAxis.allCases.map { axis in
            ranges.contains(axis) ? "\(axis.title) \(lower) to \(upper)" : "\(axis.title) \(reference)"
        }
        .joined(separator: ", ")
        guard markKind == .rectangle else { return positions }
        let given = "\(Self.number(Guides3DScale.lower, locale: locale)) to \(Self.number(Guides3DScale.upper, locale: locale))"
        return "\(positions), as drawn from ranges of \(given)"
    }

    /// The context points' accessibility value: how many, and the span of each score, x first.
    func samplesValue(locale: Locale) -> String {
        guard !beans.isEmpty else { return "No samples." }
        let spans = Guides3DAxis.allCases.map { axis in
            let scores = beans.map { Self.score($0, on: axis) }
            let lowest = Self.number(scores.min() ?? 0, locale: locale)
            let highest = Self.number(scores.max() ?? 0, locale: locale)
            return "\(axis.title.lowercased()) \(lowest) to \(highest)"
        }
        return "\(Guides3DWording.samples(beans.count, locale: locale)): \(spans.joined(separator: ", "))."
    }

    /// The Audio Graph's summary: the headline, then the samples, in actual values.
    func audioGraphSummary(locale: Locale) -> String {
        "\(headline(locale: locale)) Context: \(samplesValue(locale: locale))"
    }

    /// The Audio Graph's title.
    var audioGraphTitle: String {
        "Bean tasting scores with a reference \(markKind.name)"
    }

    /// One bean's score on an axis.
    nonisolated static func score(_ bean: BeanTasting, on axis: Guides3DAxis) -> Double {
        switch axis {
        case .acidity: bean.acidity
        case .body: bean.body
        case .sweetness: bean.sweetness
        }
    }

    /// A score in the view's locale, with at most one decimal place: "5", "2.1".
    nonisolated static func number(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
    }
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum Guides3DWording {
    static let samplesTitle = "Bean samples"

    /// "1 sample", "60 samples".
    static func samples(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) sample](inflect: true)", locale: locale).characters)
    }
}

/// The Audio Graph for the chart, which a `Chart3D` does not give: the scores on three numeric axes, the samples
/// as one series, and the guide stated in the summary, since a rule or a reference is not a series.
nonisolated struct Guides3DChartDescriptor: AXChartDescriptorRepresentable {
    let beans: [BeanTasting]
    let title: String
    let summary: String
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let range = Guides3DScale.domain
        func axis(_ axis: Guides3DAxis) -> AXNumericDataAxisDescriptor {
            AXNumericDataAxisDescriptor(title: axis.title, range: range, gridlinePositions: []) { value in
                value.isFinite ? "\(Guides3DViewModel.number(value, locale: locale)) out of 10" : ""
            }
        }
        let series = AXDataSeriesDescriptor(
            name: Guides3DWording.samplesTitle,
            isContinuous: false,
            dataPoints: beans.map { bean in
                AXDataPoint(x: bean.acidity, y: bean.body, additionalValues: [.number(bean.sweetness)])
            }
        )
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: axis(.acidity),
            yAxis: axis(.body),
            additionalAxes: [axis(.sweetness)],
            series: [series]
        )
    }
}
