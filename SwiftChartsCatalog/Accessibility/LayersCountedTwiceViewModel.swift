import Accessibility
import Foundation
import SwiftUI

/// The two ways a chart can draw the same data twice.
enum LayersCountedTwiceCase: String, CaseIterable, Identifiable {
    /// A line with an area under it.
    case lineOverArea
    /// A line with a separate layer of points on it.
    case lineWithPoints

    var id: Self {
        self
    }

    /// The picker's name for the case.
    var title: String {
        switch self {
        case .lineOverArea: "Line over area"
        case .lineWithPoints: "Line with points"
        }
    }
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum LayersCountedTwiceWording {
    /// The y value's `.value` label and axis title: the spoken axis name.
    static let averageCupsAxisTitle = "Average cups a day"
    /// The café the monthly summaries are from, as a series name and in sentences.
    static let cafe = "\(CafeWording.harbour) café"

    /// "205 cups a day", agreeing in number through `CafeWording.cups`.
    static func cupsADay(_ count: Int, locale: Locale) -> String {
        "\(CafeWording.cups(count, locale: locale)) a day"
    }
}

/// One month of the chart: its name as the x category, and its average cups a day.
nonisolated struct LayersCountedTwiceMonth: Identifiable, Hashable {
    /// The month's name in the view's locale, written in the data's UTC calendar: "March".
    let name: String
    /// The abbreviated name, for the axis at the accessibility text sizes only: "Mar".
    let shortName: String
    let cups: Int

    var id: String {
        name
    }

    /// The months of `summaries`, named in `locale` and the data's calendar so the device's time zone
    /// cannot move a month stored as midnight UTC on its first day into the month before.
    static func make(_ summaries: [MonthlySummary], locale: Locale) -> [LayersCountedTwiceMonth] {
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return summaries.map {
            LayersCountedTwiceMonth(
                name: $0.month.formatted(style.month(.wide)),
                shortName: $0.month.formatted(style.month(.abbreviated)),
                cups: $0.averageDay
            )
        }
    }
}

/// The one value scale for every state: from zero to the highest month rounded up to the next hundred,
/// 0 to 300 for the sample months, the scale the framework drew by itself. The chart draws it with
/// `chartYScale(domain:)` and the descriptor's y axis gives the same range.
nonisolated enum LayersCountedTwiceScale {
    static let step = 100

    static func yDomain(for months: [LayersCountedTwiceMonth]) -> ClosedRange<Double> {
        let step = Double(step)
        let highest = Double(months.map(\.cups).max() ?? 0)
        return 0 ... max(step, (highest / step).rounded(.up) * step)
    }
}

/// What the screen shows as "what assistive technologies get": every spoken text in one table,
/// read on iOS 27 in the simulator (`Docs/field-notes/epic-10/wave-1-dumps/layers-*.txt`).
nonisolated struct LayersCountedTwiceSpokenText: Equatable {
    /// The VoiceOver elements, one line each, in the order read on iOS.
    let elements: [String]
    /// What the Audio Graph is given, one line each.
    let audioGraph: [String]
    /// What is wrong with this state, or why it is right.
    let verdict: String
}

/// The state and words of the "Layers counted twice" screen: which case is drawn, whether its second
/// layer is left visible to assistive technologies, and what the chart then says.
@Observable
final class LayersCountedTwiceViewModel {
    var layerCase: LayersCountedTwiceCase = .lineOverArea
    /// `true` while the chart shows the mistake: both layers visible to assistive technologies.
    var isShowingMistake = true
    let summaries: [MonthlySummary]

    init(summaries: [MonthlySummary] = CafeData.monthlySummaries) {
        self.summaries = summaries
    }

    func months(locale: Locale) -> [LayersCountedTwiceMonth] {
        LayersCountedTwiceMonth.make(summaries, locale: locale)
    }

    /// No months at all: nothing to draw in either case, so the controls have nothing to change.
    var hasNoMonths: Bool {
        summaries.isEmpty
    }

    /// Nothing to see: no months, or, for the area case only, only zeros, whose area is empty and whose
    /// line lies on the axis. Points at zero are still drawn, so the points case keeps its chart.
    var hasNoData: Bool {
        switch layerCase {
        case .lineOverArea: summaries.allSatisfy { $0.averageDay == 0 }
        case .lineWithPoints: hasNoMonths
        }
    }

    /// The one value scale, shared by the chart and the descriptor.
    func yDomain(locale: Locale) -> ClosedRange<Double> {
        LayersCountedTwiceScale.yDomain(for: months(locale: locale))
    }

    /// Where, in the line-over-area mistake, each month's bare area element came before its labelled line
    /// element, by index: March only, read on iOS 27 for the sample months. The order inside a pair follows
    /// the marks' frames, not a rule.
    static let areaReadFirstMonths: Set<Int> = [0]

    /// The order the separate point layer's bare elements were read in, after the six labelled line
    /// elements: June, July, May, August, April, March, read on iOS 27 for the sample months. It follows
    /// the marks' frames, not x order and not a rule; with other months the data order is shown instead.
    static let pointLayerReadOrder = [3, 4, 2, 5, 1, 0]

    /// The months with the highest average, in data order: more than one on a tie.
    func busiestMonths(locale: Locale) -> [LayersCountedTwiceMonth] {
        let months = months(locale: locale)
        guard let most = months.map(\.cups).max(), most > 0 else { return [] }
        return months.filter { $0.cups == most }
    }

    /// The chart's message, with a figure that can be read off the chart in every state.
    func headline(locale: Locale) -> String {
        let busiest = busiestMonths(locale: locale)
        guard let cups = busiest.first?.cups else { return "No cups sold in these months." }
        return "Busiest on average: \(CafeWording.list(busiest.map(\.name))), "
            + "\(LayersCountedTwiceWording.cupsADay(cups, locale: locale))."
    }

    /// The label of a month's element: context first.
    func elementLabel(for month: LayersCountedTwiceMonth) -> String {
        month.name
    }

    /// The value of a month's element, with its unit.
    func elementValue(for month: LayersCountedTwiceMonth, locale: Locale) -> String {
        LayersCountedTwiceWording.cupsADay(month.cups, locale: locale)
    }

    /// Whether the chart carries its own descriptor: in the fixed state only. In the mistake state the
    /// automatic Audio Graph, built from both layers, is the mistake being shown; a descriptor would replace it.
    var hasDescriptor: Bool {
        !isShowingMistake
    }

    /// The snippets for the current setting: the chart as drawn, and the descriptor when it has one.
    var snippets: [SnippetReference] {
        let chart = switch (layerCase, isShowingMistake) {
        case (.lineOverArea, true):
            SnippetReference(name: "layers-counted-twice-area-both", title: "Area and line, both heard")
        case (.lineOverArea, false):
            SnippetReference(name: "layers-counted-twice-area-hidden", title: "The area hidden")
        case (.lineWithPoints, true):
            SnippetReference(name: "layers-counted-twice-points-layer", title: "A separate PointMark layer")
        case (.lineWithPoints, false):
            SnippetReference(name: "layers-counted-twice-points-symbol", title: "Points drawn with symbol")
        }
        guard hasDescriptor else { return [chart] }
        return [chart, SnippetReference(name: "layers-counted-twice-descriptor", title: "The chart descriptor")]
    }

    /// Spoken when the case or the mistake toggle redraws the chart: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        let change = switch (layerCase, isShowingMistake) {
        case (.lineOverArea, true): "Showing a line over an area, both heard by VoiceOver."
        case (.lineOverArea, false): "Showing a line over an area, the area hidden from VoiceOver."
        case (.lineWithPoints, true): "Showing a line with a separate layer of points, both heard by VoiceOver."
        case (.lineWithPoints, false): "Showing a line with its points drawn as symbols on the line."
        }
        return "\(change) \(headline(locale: locale))"
    }

    // MARK: What assistive technologies get (read on iOS 27)

    /// The elements and Audio Graph for the current state, as read on iOS 27 in the simulator. The one
    /// line marked "Predicted" was not read: the descriptor replaces what it describes.
    func spokenText(locale: Locale) -> LayersCountedTwiceSpokenText {
        let months = months(locale: locale)
        let labelled = months.map { "\(elementLabel(for: $0)), \(elementValue(for: $0, locale: locale))" }
        let bare = months.map { "\($0.name), \($0.cups.formatted(.number.locale(locale)))" }
        let domain = yDomain(locale: locale)
        let low = Int(domain.lowerBound).formatted(.number.locale(locale))
        let high = Int(domain.upperBound).formatted(.number.locale(locale))
        let axes = "x axis \"\(CafeWording.month)\", y axis \"\(LayersCountedTwiceWording.averageCupsAxisTitle)\""

        guard isShowingMistake else {
            let descriptor = LayersCountedTwiceDescriptor(months: months, yDomain: domain, locale: locale)
            let fallback = switch layerCase {
            case .lineOverArea: "Predicted, not read: without the descriptor, the framework's own would now hold one series of \(months.count) points, the hidden area adding none."
            case .lineWithPoints: "Predicted, not read: without the descriptor, the framework's own would now hold one series of \(months.count) points, symbols adding no marks."
            }
            return LayersCountedTwiceSpokenText(
                elements: labelled,
                audioGraph: [
                    "Title: \(descriptor.title)",
                    "Summary: \(descriptor.summary)",
                    "Axes: \(axes), from \(low) to \(high), the drawn scale",
                    "Series: \"\(LayersCountedTwiceWording.cafe)\", continuous, \(months.count) points",
                    "Each point: \(labelled.first ?? "the month and its cups a day")",
                    fallback,
                ],
                verdict: "Fixed: each month is one stop, and the Audio Graph plays one line with a title, a summary and units."
            )
        }

        // Both layers visible: each month is an element twice, once from the labelled Plot around the
        // line and once from the second layer's own default text, the x value and the bare number.
        let defaultAxes = "\(axes), from \(low) to \(high), the drawn scale, ends read as bare numbers"
        switch layerCase {
        case .lineOverArea:
            // Each month's pair, in the order read: the bare area element first for March only.
            let pairs = months.indices.flatMap { index in
                Self.areaReadFirstMonths.contains(index) ? [bare[index], labelled[index]] : [labelled[index], bare[index]]
            }
            return LayersCountedTwiceSpokenText(
                elements: pairs,
                audioGraph: [
                    "Title: \"Chart\"",
                    "Summary: none",
                    "Axes: \(defaultAxes)",
                    "Series: one, with no name, continuous, \(months.count * 2) points: every month twice",
                    "Each point: \(bare.first ?? "the month and a bare number"), no unit",
                ],
                verdict: "Wrong: the area repeats the line's data, so every month is heard twice and plays twice in the Audio Graph."
            )
        case .lineWithPoints:
            // The six labelled line elements first, then the six bare points in the order read.
            let order = Set(Self.pointLayerReadOrder) == Set(months.indices) ? Self.pointLayerReadOrder : Array(months.indices)
            return LayersCountedTwiceSpokenText(
                elements: labelled + order.map { bare[$0] },
                audioGraph: [
                    "Title: \"Chart\"",
                    "Summary: none",
                    "Axes: \(defaultAxes)",
                    "Series: two, neither named: the line (continuous) and the points (separate), \(months.count) points each",
                    "Each point: \(bare.first ?? "the month and a bare number"), no unit",
                ],
                verdict: "Wrong: the points are a second layer of the same data, so every month is heard twice and the Audio Graph has two series that are one."
            )
        }
    }
}

// snippet:layers-counted-twice-descriptor
/// The Audio Graph of the fixed chart: a title, a summary in actual values, the months as categories,
/// and each value said with its unit. One series: the area or points are not data of their own.
nonisolated struct LayersCountedTwiceDescriptor: AXChartDescriptorRepresentable {
    let months: [LayersCountedTwiceMonth]
    /// The chart's own value scale, so the Audio Graph's axis is the axis that is drawn.
    let yDomain: ClosedRange<Double>
    let locale: Locale

    var title: String {
        let range = [months.first?.name, months.last?.name].compactMap(\.self)
        return "\(LayersCountedTwiceWording.averageCupsAxisTitle) at the \(LayersCountedTwiceWording.cafe), "
            + range.joined(separator: " to ")
    }

    var summary: String {
        guard let first = months.first, let last = months.last,
              let highest = months.map(\.cups).max(), let lowest = months.map(\.cups).min()
        else { return "No months." }
        let busiest = months.filter { $0.cups == highest }.map(\.name)
        let quietest = months.filter { $0.cups == lowest }.map(\.name)
        let cups = { LayersCountedTwiceWording.cupsADay($0, locale: locale) }
        return "\(CafeWording.months(months.count, locale: locale)). "
            + "First \(first.name), \(cups(first.cups)); last \(last.name), \(cups(last.cups)). "
            + "Highest \(CafeWording.list(busiest)), \(cups(highest)); lowest \(CafeWording.list(quietest)), \(cups(lowest))."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.month, categoryOrder: months.map(\.name))
        // The same range the chart is drawn with.
        let yAxis = AXNumericDataAxisDescriptor(
            title: LayersCountedTwiceWording.averageCupsAxisTitle,
            range: yDomain,
            gridlinePositions: []
        ) { value in
            let cups = CafeWording.count(value, locale: locale)
            return cups.isEmpty ? "" : "\(cups) a day"
        }
        let series = AXDataSeriesDescriptor(
            name: LayersCountedTwiceWording.cafe,
            isContinuous: true,
            dataPoints: months.map { AXDataPoint(x: $0.name, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series]
        )
    }
}

// end
