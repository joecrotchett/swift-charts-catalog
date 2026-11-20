import Foundation
import Observation

/// The words for the tasting scores. `CafeWording` has none for `beanTastings`, so this screen keeps its own.
nonisolated enum FittedSurfaceWording {
    static let acidity = "Acidity"
    static let body = "Body"
    static let sweetness = "Sweetness"
    static let origin = "Origin"
    static let fittedPlane = "Fitted plane"

    /// "1 bean sample", "60 bean samples".
    static func samples(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) bean sample](inflect: true)", locale: locale).characters)
    }

    /// "1 origin", "3 origins".
    static func origins(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) origin](inflect: true)", locale: locale).characters)
    }

    /// A tasting score as the chart's axes write it, with at most one decimal place: "6.5". Empty for a value
    /// that is not finite, since the accessibility system chooses the numbers it asks about.
    static func score(_ value: Double, locale: Locale) -> String {
        guard value.isFinite else { return "" }
        return value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))
    }

    /// A fitted weight to two decimal places, without its sign: "0.75". Rounded first, so a weight of
    /// -0.0005 is written "0.00" and not "-0.00".
    static func weight(_ value: Double, locale: Locale) -> String {
        let rounded = (abs(value) * 100).rounded() / 100
        return rounded.formatted(.number.precision(.fractionLength(2)).locale(locale))
    }

    /// Whether a weight is written with a minus: only when it is still negative after rounding.
    static func isNegative(_ value: Double) -> Bool {
        (value * 100).rounded() < 0
    }
}

// snippet:a-surface-through-the-points-fit
/// sweetness = intercept + acidityWeight × acidity + bodyWeight × body, fitted by least squares.
/// The chart draws whatever plane it is given: the app computes the fit.
nonisolated struct FittedSurfacePlane: Equatable {
    let intercept: Double
    let acidityWeight: Double
    let bodyWeight: Double

    func sweetness(acidity: Double, body: Double) -> Double {
        intercept + acidityWeight * acidity + bodyWeight * body
    }

    /// Ordinary least squares through the normal equations, solved by Cramer's rule. `nil` with fewer
    /// than three samples, or when they lie in a line, since then no single plane fits them.
    static func fit(_ tastings: [BeanTasting]) -> FittedSurfacePlane? {
        guard tastings.count >= 3 else { return nil }
        let n = Double(tastings.count)
        let sa = tastings.map(\.acidity).reduce(0, +)
        let sb = tastings.map(\.body).reduce(0, +)
        let saa = tastings.map { $0.acidity * $0.acidity }.reduce(0, +)
        let sbb = tastings.map { $0.body * $0.body }.reduce(0, +)
        let sab = tastings.map { $0.acidity * $0.body }.reduce(0, +)
        let sy = tastings.map(\.sweetness).reduce(0, +)
        let say = tastings.map { $0.acidity * $0.sweetness }.reduce(0, +)
        let sby = tastings.map { $0.body * $0.sweetness }.reduce(0, +)

        /// [n sa sb; sa saa sab; sb sab sbb] · [intercept, acidity, body] = [sy, say, sby]
        func det(_ m: [[Double]]) -> Double {
            m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
                - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
        }
        let matrix = [[n, sa, sb], [sa, saa, sab], [sb, sab, sbb]]
        let right = [sy, say, sby]
        let determinant = det(matrix)
        guard determinant.isFinite, abs(determinant) > 1e-9 * max(1, n * saa * sbb) else { return nil }
        func replacing(column: Int) -> [[Double]] {
            matrix.enumerated().map { row, values in
                values.enumerated().map { $0.offset == column ? right[row] : $0.element }
            }
        }
        return FittedSurfacePlane(
            intercept: det(replacing(column: 0)) / determinant,
            acidityWeight: det(replacing(column: 1)) / determinant,
            bodyWeight: det(replacing(column: 2)) / determinant
        )
    }
}

// end

/// Ready-made angles to view the chart from, for anyone who cannot drag to rotate it.
nonisolated enum FittedSurfacePosePreset: CaseIterable, Identifiable {
    /// The opening angle: turned so the plane is seen as a tilted sheet with the points around it.
    case turned
    /// Almost along the acidity axis: body across, sweetness up. The plane is seen nearly edge-on, a thin
    /// line through the points. Exactly edge-on (azimuth 90, inclination 0) it is not drawn at all.
    case nearlyEdgeOn
    /// Looking along the body axis: acidity across, sweetness up.
    case alongBody

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .turned: "Turned"
        case .nearlyEdgeOn: "Edge-on"
        case .alongBody: "Along body"
        }
    }

    /// Degrees; the chart turns them into a `Chart3DPose` behind its iOS 26 check.
    var azimuth: Double {
        switch self {
        case .turned: 55
        case .nearlyEdgeOn: 84
        case .alongBody: 0
        }
    }

    var inclination: Double {
        switch self {
        case .turned: 12
        case .nearlyEdgeOn: 4
        case .alongBody: 0
        }
    }
}

/// Everything spoken about the chart, in one place: its elements, the Audio Graph's summary and the
/// announcement when the plane is shown or hidden.
nonisolated struct FittedSurfaceSpokenText {
    let tastings: [BeanTasting]
    let plane: FittedSurfacePlane?
    let showsSurface: Bool
    let locale: Locale

    var drawsPlane: Bool {
        showsSurface && plane != nil
    }

    /// The origins in the order VoiceOver reads their elements, which the key and the Audio Graph follow.
    var originsInReadOrder: [String] {
        FittedSurfaceViewModel.readOrder(of: tastings)
    }

    /// The origins in the app's one order (`BeanOriginStyle.origins`), for the key and the Audio Graph's series,
    /// so they list the origins as every other bean screen does.
    var originsInOriginOrder: [String] {
        FittedSurfaceViewModel.originOrder(of: originsInReadOrder)
    }

    /// The plane in words: "sweetness is 1.21, plus 0.00 for each point of acidity, plus 0.75 for each point of body".
    var planeInWords: String {
        guard let plane else { return "" }
        func term(_ weight: Double, _ name: String) -> String {
            "\(FittedSurfaceWording.isNegative(weight) ? "minus" : "plus") \(FittedSurfaceWording.weight(weight, locale: locale)) for each point of \(name)"
        }
        let intercept = (plane.intercept * 100).rounded() / 100 + 0
        return "sweetness is \(intercept.formatted(.number.precision(.fractionLength(2)).locale(locale))), "
            + "\(term(plane.acidityWeight, "acidity")), \(term(plane.bodyWeight, "body"))"
    }

    /// One element per origin: its name.
    func originLabel(_ origin: String) -> String {
        origin
    }

    /// The origin's count and the span of each score: "20 bean samples. Acidity 6.9 to 8.7, body 2.5 to 4.3, sweetness 2.9 to 4.7".
    func originValue(_ origin: String) -> String {
        let rows = tastings.filter { $0.origin == origin }
        func span(_ values: [Double]) -> String {
            guard let low = values.min(), let high = values.max() else { return "" }
            return "\(FittedSurfaceWording.score(low, locale: locale)) to \(FittedSurfaceWording.score(high, locale: locale))"
        }
        return "\(FittedSurfaceWording.samples(rows.count, locale: locale)). "
            + "Acidity \(span(rows.map(\.acidity))), body \(span(rows.map(\.body))), sweetness \(span(rows.map(\.sweetness)))"
    }

    var planeLabel: String {
        FittedSurfaceWording.fittedPlane
    }

    var planeValue: String {
        "Fitted to \(FittedSurfaceWording.samples(tastings.count, locale: locale)): \(planeInWords)"
    }

    /// The Audio Graph's summary, in actual values.
    var summary: String {
        let origins = BeanOriginStyle.origins.filter { origin in tastings.contains { $0.origin == origin } }
        var text = "\(FittedSurfaceWording.samples(tastings.count, locale: locale)) from "
            + "\(FittedSurfaceWording.origins(origins.count, locale: locale)), each scored from 0 to 10."
        if let low = tastings.map(\.sweetness).min(), let high = tastings.map(\.sweetness).max() {
            text += " Sweetness from \(FittedSurfaceWording.score(low, locale: locale)) to \(FittedSurfaceWording.score(high, locale: locale))."
        }
        if drawsPlane {
            text += " Fitted plane: \(planeInWords)."
        }
        return text
    }
}

/// What the opening pose shows, as seen in a render of the chart at that pose.
nonisolated enum FittedSurfaceExplanation {
    static let openingPose = """
    At the opening angle body runs along the front, from left to right, and acidity back into the chart.
    """
}

/// The plane's height at one body score.
nonisolated struct FittedSurfaceHeight: Equatable {
    let body: Double
    let sweetness: Double
}

/// The heights the headline names, all at one acidity.
nonisolated struct FittedSurfaceLabelledHeights: Equatable {
    let acidity: Double
    let heights: [FittedSurfaceHeight]
}

/// The state and logic of "A surface through the points": the samples, the plane fitted to them, whether
/// the plane is drawn, and the angle the chart is seen from.
@Observable
final class FittedSurfaceViewModel {
    let tastings: [BeanTasting]
    /// Fitted once: the samples do not change.
    let plane: FittedSurfacePlane?
    var showsSurface = true
    /// The chart's viewing angle as plain numbers. The chart's iOS 26 view turns them into a pose and writes
    /// a drag back into them, so the angle survives the chart being rebuilt when the plane is toggled.
    var azimuthDegrees = FittedSurfacePosePreset.turned.azimuth
    var inclinationDegrees = FittedSurfacePosePreset.turned.inclination

    init(tastings: [BeanTasting] = CafeData.beanTastings) {
        self.tastings = tastings
        plane = FittedSurfacePlane.fit(tastings)
    }

    /// Turns the chart to a preset, even the same one again after a drag.
    func choose(_ preset: FittedSurfacePosePreset) {
        azimuthDegrees = preset.azimuth
        inclinationDegrees = preset.inclination
    }

    var hasData: Bool {
        !tastings.isEmpty
    }

    var drawsPlane: Bool {
        showsSurface && plane != nil
    }

    /// The acidity axis: the data's span rounded out to whole points, so the plane covers the samples and
    /// no more; the full 0 to 10 when there is no data.
    var acidityDomain: ClosedRange<Double> {
        Self.domain(tastings.map(\.acidity))
    }

    var bodyDomain: ClosedRange<Double> {
        Self.domain(tastings.map(\.body))
    }

    /// Sweetness keeps the score's whole range, 0 to 10.
    let sweetnessDomain: ClosedRange<Double> = 0 ... 10
    /// The sweetness axis's labels: a 3D axis does not label its domain's ends, so they lie inside it.
    let sweetnessMarks: [Double] = [2, 4, 6, 8]

    /// The values the acidity axis labels, and so the only acidity the headline may name.
    var acidityMarks: [Double] {
        Self.labelledValues(in: acidityDomain)
    }

    /// The values the body axis labels, and so the only body scores the headline may name.
    var bodyMarks: [Double] {
        Self.labelledValues(in: bodyDomain)
    }

    private static func domain(_ values: [Double]) -> ClosedRange<Double> {
        guard let low = values.min(), let high = values.max() else { return 0 ... 10 }
        let lower = max(0, low.rounded(.down))
        let upper = min(10, high.rounded(.up))
        return lower < upper ? lower ... upper : max(0, lower - 1) ... min(10, upper + 1)
    }

    /// Whole scores strictly inside the domain, since a 3D axis leaves its ends unlabelled; only the odd
    /// ones when there are more than four, so the labels stay apart. On 2 to 9: 3, 5 and 7.
    nonisolated static func labelledValues(in domain: ClosedRange<Double>) -> [Double] {
        let inside = stride(from: domain.lowerBound.rounded(.down) + 1, to: domain.upperBound, by: 1)
            .filter { $0 > domain.lowerBound }
        guard inside.count > 4 else { return inside }
        return inside.filter { Int($0).isMultiple(of: 2) == false }
    }

    /// The origins in the order VoiceOver reads them. Read on the iOS 27 simulator, the representation's
    /// elements came out by the leading edge of their frames (Sumatra, Colombia, Ethiopia, the plane, which
    /// spans the whole acidity axis, first), not in the order they are declared; the key and the Audio Graph
    /// follow it.
    nonisolated static func readOrder(of tastings: [BeanTasting]) -> [String] {
        var origins = BeanOriginStyle.origins.filter { origin in tastings.contains { $0.origin == origin } }
        for tasting in tastings where !origins.contains(tasting.origin) {
            origins.append(tasting.origin)
        }
        func leadingEdge(_ origin: String) -> Double {
            tastings.filter { $0.origin == origin }.map(\.acidity).min() ?? 0
        }
        return origins.enumerated()
            .sorted { (leadingEdge($0.element), $0.offset) < (leadingEdge($1.element), $1.offset) }
            .map(\.element)
    }

    var originsInReadOrder: [String] {
        Self.readOrder(of: tastings)
    }

    var originsInOriginOrder: [String] {
        Self.originOrder(of: originsInReadOrder)
    }

    /// Known origins in `BeanOriginStyle.origins` order, any others after them in the order given.
    nonisolated static func originOrder(of origins: [String]) -> [String] {
        origins.enumerated().sorted { first, second in
            let one = BeanOriginStyle.origins.firstIndex(of: first.element) ?? Int.max
            let two = BeanOriginStyle.origins.firstIndex(of: second.element) ?? Int.max
            return (one, first.offset) < (two, second.offset)
        }
        .map(\.element)
    }

    func spokenText(locale: Locale) -> FittedSurfaceSpokenText {
        FittedSurfaceSpokenText(tastings: tastings, plane: plane, showsSurface: showsSurface, locale: locale)
    }

    /// The plane's drawn height at labelled acidity and body scores, so every figure the headline names can
    /// be read off the chart: at the middle acidity label, at the lowest and highest body labels where the
    /// plane is drawn.
    var labelledHeights: FittedSurfaceLabelledHeights? {
        guard let plane, let acidity = acidityMarks.dropFirst(acidityMarks.count / 2).first else { return nil }
        let drawn = bodyMarks.compactMap { body -> FittedSurfaceHeight? in
            let height = Self.drawnSweetness(plane, acidity: acidity, body: body)
            return height.isNaN ? nil : FittedSurfaceHeight(body: body, sweetness: height)
        }
        guard let first = drawn.first, let last = drawn.last else { return nil }
        return FittedSurfaceLabelledHeights(acidity: acidity, heights: first == last ? [first] : [first, last])
    }

    /// The chart's message. With the plane drawn it gives the plane's height at labelled scores, which the
    /// reader can find against the axes; without it, what the points are.
    func headline(locale: Locale) -> String {
        guard hasData else { return "No bean samples to fit a plane to." }
        let samples = FittedSurfaceWording.samples(tastings.count, locale: locale)
        guard plane != nil else { return "\(samples): too few, or in a line, to fit a plane." }
        guard showsSurface else { return "\(samples), each scored for acidity, body and sweetness." }
        guard let labelled = labelledHeights else {
            return "Fitted plane: it leaves the 0 to 10 sweetness range at every labelled score."
        }
        func score(_ value: Double) -> String {
            FittedSurfaceWording.score(value, locale: locale)
        }
        let heights = labelled.heights.map { "sweetness \(score($0.sweetness)) at body \(score($0.body))" }
        return "Fitted plane, at acidity \(score(labelled.acidity)): \(heights.joined(separator: ", "))."
    }

    /// The fitted plane as an equation: "sweetness = 1.21 + 0.00 × acidity + 0.75 × body". Its intercept is
    /// the height at acidity 0 and body 0, outside the chart, so it lives in the explanation, not the headline.
    func equation(locale: Locale) -> String? {
        guard let plane else { return nil }
        func term(_ weight: Double, _ name: String) -> String {
            "\(FittedSurfaceWording.isNegative(weight) ? "−" : "+") \(FittedSurfaceWording.weight(weight, locale: locale)) × \(name)"
        }
        let intercept = (plane.intercept * 100).rounded() / 100 + 0
        return "sweetness = \(intercept.formatted(.number.precision(.fractionLength(2)).locale(locale))) "
            + "\(term(plane.acidityWeight, "acidity")) \(term(plane.bodyWeight, "body"))"
    }

    /// The explanation under the chart: the concept, then the fit itself.
    func explanation(locale: Locale) -> String {
        let concept = """
        The app fits a plane to the samples by least squares, sweetness from acidity and body, and a SurfacePlot \
        draws it in the same Chart3D as the points, sweetness up. \(FittedSurfaceExplanation.openingPose) \
        Turn it edge-on and the plane is a thin line through the points.
        """
        guard let equation = equation(locale: locale) else { return concept }
        return concept + " The fit is \(equation)."
    }

    /// What is announced when the plane is shown or hidden: what changed, then the headline.
    func changeAnnouncement(locale: Locale) -> String {
        "\(showsSurface ? "Fitted plane shown" : "Fitted plane hidden"). \(headline(locale: locale))"
    }

    /// The plane's height as the chart draws it: `nan` where the fit leaves the 0 to 10 score range, so
    /// the surface is not drawn there.
    nonisolated static func drawnSweetness(_ plane: FittedSurfacePlane, acidity: Double, body: Double) -> Double {
        let value = plane.sweetness(acidity: acidity, body: body)
        return (0 ... 10).contains(value) ? value : .nan
    }
}
