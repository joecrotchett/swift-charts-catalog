import Accessibility
import Foundation
import Observation
import SwiftUI

/// The state of "Marks and plots": how the chart is drawn, and how many orders it draws.
@Observable
final class MarksAndPlotsViewModel {
    /// The two ways the same chart is drawn.
    enum Drawing: String, CaseIterable, Identifiable {
        case marks
        case plot

        var id: Self {
            self
        }

        /// The picker's words for it.
        var title: String {
            switch self {
            case .marks: "Marks"
            case .plot: "Plot"
            }
        }
    }

    /// The order counts the slider offers, and its step.
    static let countRange = 500 ... CafeData.manyOrdersMaximum
    static let countStep = 500
    static let defaultCount = 2000

    /// What a plot is not: faster. Measured by the orchestrating session, not by the screen's builder.
    static let timingNote = "Measured on the simulator with ImageRenderer, median of 6 renders: bare marks and a plot draw "
        + "in the same time, within 2%. This chart's marks, each with its own size and opacity, took 12 to 16% longer than "
        + "the plot: about 13 against 11 ms at 1,000 points, 52 against 45 at 5,000 and 192 against 168 at 20,000."

    /// The snippet that shows each way of drawing the chart.
    static let marksSnippet = SnippetReference(name: "marks-and-plots-marks", title: "A ForEach of marks")
    static let plotSnippet = SnippetReference(name: "marks-and-plots-plot", title: "One plot")
    static let spokenSnippet = SnippetReference(name: "marks-and-plots-spoken", title: "What VoiceOver reads, for both")

    var drawing: Drawing = .plot
    /// The orders drawn: `CafeData.manyOrders(count:)`, made again only when the count changes.
    private(set) var orders: [CafeOrder]

    init(count: Int = MarksAndPlotsViewModel.defaultCount) {
        orders = CafeData.manyOrders(count: count)
    }

    /// The slider's value: the number of orders.
    var orderCount: Double {
        get { Double(orders.count) }
        set {
            let count = Int(newValue.rounded())
            guard count != orders.count else { return }
            orders = CafeData.manyOrders(count: count)
        }
    }

    /// Whether there is nothing to draw, so a placeholder takes the chart's place.
    var isEmpty: Bool {
        orders.isEmpty
    }

    /// The current drawing's snippet first, then the other one to compare.
    var snippets: [SnippetReference] {
        switch drawing {
        case .marks: [Self.marksSnippet, Self.plotSnippet, Self.spokenSnippet]
        case .plot: [Self.plotSnippet, Self.marksSnippet, Self.spokenSnippet]
        }
    }

    func summary(locale: Locale) -> MarksAndPlotsSummary {
        MarksAndPlotsSummary(orders: orders, locale: locale)
    }

    /// One line under the picker on what is building the chart now.
    func drawingCaption(locale: Locale) -> String {
        let count = orders.count.formatted(.number.locale(locale))
        return switch drawing {
        case .marks: "ForEach makes one PointMark per order: \(count) marks."
        case .plot: "One PointPlot takes the whole collection of \(count) orders."
        }
    }

    /// What VoiceOver hears when the picker changes how the chart is drawn: what changed, then the headline.
    func drawingAnnouncement(locale: Locale) -> String {
        let change = switch drawing {
        case .marks: "Now drawn from a ForEach of PointMarks."
        case .plot: "Now drawn from one PointPlot."
        }
        return "\(change) \(summary(locale: locale).headline)"
    }

    /// The slider's value as shown beside its title.
    func countText(locale: Locale) -> String {
        orders.count.formatted(.number.locale(locale))
    }

    /// The slider's value as spoken: the headline alone, as it already gives the count.
    func countSpokenValue(locale: Locale) -> String {
        summary(locale: locale).headline
    }
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum MarksAndPlotsWording {
    /// The `.value` label for the time an order was placed, and the x axis's visible title.
    static let timeOfDay = TimeOfDayWording.timeOfDay
    /// The `.value` label for an order's wait.
    static let wait = TimeOfDayWording.wait
    static let waitAxisTitle = TimeOfDayWording.waitAxisTitle
    /// The descriptor's one series.
    static let seriesName = "Orders"

    static func minutes(_ amount: Double, locale: Locale) -> String {
        TimeOfDayWording.minutes(amount, locale: locale)
    }

    static func time(hour: Double, locale: Locale) -> String {
        TimeOfDayWording.time(hour: hour, locale: locale)
    }
}

/// What the chart says in words: the headline and what the Audio Graph is given.
nonisolated struct MarksAndPlotsSummary {
    let orders: [CafeOrder]
    let locale: Locale

    /// The most points the Audio Graph is given: an even sample, as thousands of tones say nothing more.
    static let audioGraphSampleSize = 200

    /// The order with the longest wait: the highest point in the chart.
    var longestWait: CafeOrder? {
        orders.max { $0.waitMinutes < $1.waitMinutes }
    }

    var shortestWait: CafeOrder? {
        orders.min { $0.waitMinutes < $1.waitMinutes }
    }

    /// The span of time the orders cover.
    var hourRange: ClosedRange<Double>? {
        guard let first = orders.map(\.hour).min(), let last = orders.map(\.hour).max() else { return nil }
        return first ... last
    }

    /// The chart's message in a sentence. Its figure is the highest point, so it can be found in the chart,
    /// and it is the same whichever way the chart is drawn.
    var headline: String {
        guard let longest = longestWait else { return "No orders to draw." }
        return "\(CafeWording.orders(orders.count, locale: locale)), one point each. "
            + "The longest wait was \(MarksAndPlotsWording.minutes(longest.waitMinutes, locale: locale))."
    }

    /// The orders the Audio Graph plays: evenly spaced through the data, then in order of time,
    /// so the tones run left to right as the chart does.
    var audioGraphSample: [CafeOrder] {
        guard orders.count > Self.audioGraphSampleSize else { return orders.sorted { $0.hour < $1.hour } }
        let stride = Double(orders.count) / Double(Self.audioGraphSampleSize)
        return (0 ..< Self.audioGraphSampleSize)
            .map { orders[Int(Double($0) * stride)] }
            .sorted { $0.hour < $1.hour }
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let longest = longestWait, let shortest = shortestWait, let hours = hourRange else {
            return "No orders to draw."
        }
        let sampleNote = orders.count > Self.audioGraphSampleSize
            ? " The Audio Graph plays an even sample of \(CafeWording.orders(Self.audioGraphSampleSize, locale: locale))."
            : ""
        return "\(CafeWording.orders(orders.count, locale: locale)), one point each, from "
            + "\(MarksAndPlotsWording.time(hour: hours.lowerBound, locale: locale)) to "
            + "\(MarksAndPlotsWording.time(hour: hours.upperBound, locale: locale)).\(sampleNote) "
            + "Waits from \(MarksAndPlotsWording.minutes(shortest.waitMinutes, locale: locale)) to "
            + "\(MarksAndPlotsWording.minutes(longest.waitMinutes, locale: locale)); the longest at "
            + "\(MarksAndPlotsWording.time(hour: longest.hour, locale: locale))."
    }
}

/// The chart for the Audio Graph: both axes numeric, a sample of the orders as one series of separate points.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct MarksAndPlotsChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [CafeOrder]
    let locale: Locale

    /// The wait axis as drawn and as given here: 0 to the longest wait, rounded up to a tidy step.
    static func waitDomain(for orders: [CafeOrder]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.waitMinutes))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = MarksAndPlotsSummary(orders: orders, locale: locale)
        let locale = locale
        // The drawn x scale's domain, so the Audio Graph's axis is the one on screen.
        let xAxis = AXNumericDataAxisDescriptor(
            title: MarksAndPlotsWording.timeOfDay,
            range: TimeOfDayWording.dayHours,
            gridlinePositions: []
        ) { hour in MarksAndPlotsWording.time(hour: hour, locale: locale) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: MarksAndPlotsWording.waitAxisTitle,
            range: Self.waitDomain(for: orders),
            gridlinePositions: []
        ) { minutes in minutes.isFinite ? MarksAndPlotsWording.minutes(minutes, locale: locale) : "" }
        let series = AXDataSeriesDescriptor(
            name: MarksAndPlotsWording.seriesName,
            isContinuous: false,
            dataPoints: summary.audioGraphSample.map { AXDataPoint(x: $0.hour, y: $0.waitMinutes) }
        )
        return AXChartDescriptor(
            title: "Wait for each order by time of day, across the chain",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
