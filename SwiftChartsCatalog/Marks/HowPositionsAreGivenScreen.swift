import Accessibility
import Charts
import SwiftUI

/// "How positions are given": on each axis a mark takes a value, an interval or nothing.
struct HowPositionsAreGivenScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = HowPositionsAreGivenViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let description = viewModel.description(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Queue and wait per order, \(PositionsDescription.store) café",
            message: description.headline,
            explanation: """
            Bar, rectangle, rule and point marks have many initializers and one pattern: on each axis a mark is \
            given a value, an interval or nothing. A value puts the mark there, and a bar with no interval also grows \
            from zero to a value; an interval spans from one value to the other. Given nothing, a mark spans the \
            whole plot on that axis, except a point, or a rule with an interval on the other axis, which is centred. \
            Not every mark takes every combination, and where there is no initializer this screen says so.
            """,
            snippets: description.snippets
        ) {
            PositionsChart(description: description)
        } controls: {
            PositionsControls(viewModel: viewModel)
        }
        // The chart changes without animation, so say what it now shows. Every control is in the message.
        .onChange(of: description.announcement) { _, announcement in
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// The mark picker and one picker per axis.
private struct PositionsControls: View {
    @Bindable var viewModel: HowPositionsAreGivenViewModel

    var body: some View {
        ControlsSection {
            SegmentedRow(title: "Mark", selection: $viewModel.mark, options: PositionedMark.allCases, optionTitle: \.title)
            SegmentedRow(title: "On x", selection: $viewModel.x, options: AxisInput.allCases, optionTitle: \.title)
            SegmentedRow(title: "On y", selection: $viewModel.y, options: AxisInput.allCases, optionTitle: \.title)
        }
    }
}

/// A segmented picker under a visible title, on the kit's picker, which names it.
private struct SegmentedRow<Option: Hashable & Identifiable>: View {
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let optionTitle: KeyPath<Option, String>

    var body: some View {
        LabeledSegmentedPicker(title: title, selection: $selection) {
            ForEach(options) { option in
                Text(option[keyPath: optionTitle]).tag(option)
            }
        }
    }
}

/// The orders as points, with the chosen mark behind them; or a sentence where there is nothing to draw.
struct PositionsChart: View {
    let description: PositionsDescription

    var body: some View {
        if let summary = description.summary {
            if let form = description.form {
                Chart {
                    // One element for the mark: what it is, then what it shows, with units.
                    Plot {
                        switch form {
                        case let .bar(form):
                            BarPositions(form: form, summary: summary)
                                .opacity(MarkStyle.fillOpacity)
                        case let .rectangle(form):
                            RectanglePositions(form: form, summary: summary)
                                .opacity(MarkStyle.fillOpacity)
                        case let .rule(form):
                            RulePositions(form: form, summary: summary)
                                .lineStyle(StrokeStyle(lineWidth: MarkStyle.ruleWidth))
                        case let .point(form):
                            PointPositions(form: form, summary: summary)
                                .symbolSize(MarkStyle.pointArea)
                        }
                    }
                    .accessibilityLabel("\(description.mark.title) for the \(PositionsDescription.store) café's orders")
                    .accessibilityValue(description.markValue ?? "")

                    // The orders the mark summarises. The Audio Graph plays them; as elements they would be
                    // stretches of bare numbers, so the mark's element and the descriptor speak for them.
                    ForEach(description.orders) { order in
                        PointMark(
                            x: .value("Queue", order.queueLength),
                            y: .value("Wait", order.waitSeconds)
                        )
                    }
                    .foregroundStyle(Color.gray)
                    .symbolSize(MarkStyle.orderArea)
                    .accessibilityHidden(true)
                }
                .chartXAxisLabel(PositionsDescription.queueAxisTitle)
                .yAxisTitle(PositionsDescription.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
                // Both axes worked out once, for the chart and the Audio Graph: a mark given nothing on an axis
                // still spans this whole extent.
                .chartXScale(domain: description.queueDomain)
                .chartYScale(domain: description.waitDomain)
                .accessibilityChartDescriptor(PositionsChartDescriptor(description: description))
            } else {
                ContentUnavailableView(
                    "No such initializer",
                    systemImage: "xmark.square",
                    // The headline above already says which initializer is missing.
                    description: Text("Change what the mark is given. See Code lists the combinations that exist.")
                )
            }
        } else {
            ContentUnavailableView(
                "No orders",
                systemImage: "cup.and.saucer",
                description: Text("Each order's queue and wait appear here, with one mark that summarises them.")
            )
        }
    }
}

/// Sizes and strengths that belong to this chart's marks.
private enum MarkStyle {
    /// Bars and rectangles are faint enough for the grid lines to show through.
    static let fillOpacity = 0.35
    static let ruleWidth: CGFloat = 3
    /// The area of the chosen point, in square points: large enough to tell from an order.
    static let pointArea: CGFloat = 260
    static let orderArea: CGFloat = 30
}

/// Every `BarMark` initializer, one per combination.
private struct BarPositions: ChartContent {
    let form: BarForm
    let summary: OrderSummary

    var body: some ChartContent {
        erased
    }

    /// A plain switch over erased content, outside the chart builder: as a builder's switch,
    /// seven or more branches do not type-check in reasonable time.
    private var erased: AnyChartContent {
        switch form {
        case .valueValue: AnyChartContent(valueValue)
        case .valueInterval: AnyChartContent(valueInterval)
        case .valueNothing: AnyChartContent(valueNothing)
        case .intervalValue: AnyChartContent(intervalValue)
        case .intervalNothing: AnyChartContent(intervalNothing)
        case .nothingValue: AnyChartContent(nothingValue)
        case .nothingInterval: AnyChartContent(nothingInterval)
        }
    }

    private var valueValue: some ChartContent {
        // snippet:how-positions-are-given-bar-value-value
        BarMark(
            x: .value("Average queue", summary.averageQueue),
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var valueInterval: some ChartContent {
        // snippet:how-positions-are-given-bar-value-interval
        BarMark(
            x: .value("Average queue", summary.averageQueue),
            yStart: .value("Shortest wait", summary.shortestWait),
            yEnd: .value("Longest wait", summary.longestWait)
        )
        // end
    }

    private var valueNothing: some ChartContent {
        // snippet:how-positions-are-given-bar-value-nothing
        BarMark(
            x: .value("Average queue", summary.averageQueue)
        )
        // end
    }

    private var intervalValue: some ChartContent {
        // snippet:how-positions-are-given-bar-interval-value
        BarMark(
            xStart: .value("Shortest queue", summary.shortestQueue),
            xEnd: .value("Longest queue", summary.longestQueue),
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var intervalNothing: some ChartContent {
        // snippet:how-positions-are-given-bar-interval-nothing
        BarMark(
            xStart: .value("Shortest queue", summary.shortestQueue),
            xEnd: .value("Longest queue", summary.longestQueue)
        )
        // end
    }

    private var nothingValue: some ChartContent {
        // snippet:how-positions-are-given-bar-nothing-value
        BarMark(
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var nothingInterval: some ChartContent {
        // snippet:how-positions-are-given-bar-nothing-interval
        BarMark(
            yStart: .value("Shortest wait", summary.shortestWait),
            yEnd: .value("Longest wait", summary.longestWait)
        )
        // end
    }
}

/// Every `RectangleMark` initializer, one per combination.
private struct RectanglePositions: ChartContent {
    let form: RectangleForm
    let summary: OrderSummary

    var body: some ChartContent {
        erased
    }

    /// A plain switch over erased content, outside the chart builder: as a builder's switch,
    /// seven or more branches do not type-check in reasonable time.
    private var erased: AnyChartContent {
        switch form {
        case .valueValue: AnyChartContent(valueValue)
        case .valueInterval: AnyChartContent(valueInterval)
        case .valueNothing: AnyChartContent(valueNothing)
        case .intervalValue: AnyChartContent(intervalValue)
        case .intervalInterval: AnyChartContent(intervalInterval)
        case .intervalNothing: AnyChartContent(intervalNothing)
        case .nothingValue: AnyChartContent(nothingValue)
        case .nothingInterval: AnyChartContent(nothingInterval)
        case .nothingNothing: AnyChartContent(nothingNothing)
        }
    }

    private var valueValue: some ChartContent {
        // snippet:how-positions-are-given-rectangle-value-value
        RectangleMark(
            x: .value("Average queue", summary.averageQueue),
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var valueInterval: some ChartContent {
        // snippet:how-positions-are-given-rectangle-value-interval
        RectangleMark(
            x: .value("Average queue", summary.averageQueue),
            yStart: .value("Shortest wait", summary.shortestWait),
            yEnd: .value("Longest wait", summary.longestWait)
        )
        // end
    }

    private var valueNothing: some ChartContent {
        // snippet:how-positions-are-given-rectangle-value-nothing
        RectangleMark(
            x: .value("Average queue", summary.averageQueue)
        )
        // end
    }

    private var intervalValue: some ChartContent {
        // snippet:how-positions-are-given-rectangle-interval-value
        RectangleMark(
            xStart: .value("Shortest queue", summary.shortestQueue),
            xEnd: .value("Longest queue", summary.longestQueue),
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var intervalInterval: some ChartContent {
        // snippet:how-positions-are-given-rectangle-interval-interval
        RectangleMark(
            xStart: .value("Shortest queue", summary.shortestQueue),
            xEnd: .value("Longest queue", summary.longestQueue),
            yStart: .value("Shortest wait", summary.shortestWait),
            yEnd: .value("Longest wait", summary.longestWait)
        )
        // end
    }

    private var intervalNothing: some ChartContent {
        // snippet:how-positions-are-given-rectangle-interval-nothing
        RectangleMark(
            xStart: .value("Shortest queue", summary.shortestQueue),
            xEnd: .value("Longest queue", summary.longestQueue)
        )
        // end
    }

    private var nothingValue: some ChartContent {
        // snippet:how-positions-are-given-rectangle-nothing-value
        RectangleMark(
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var nothingInterval: some ChartContent {
        // snippet:how-positions-are-given-rectangle-nothing-interval
        RectangleMark(
            yStart: .value("Shortest wait", summary.shortestWait),
            yEnd: .value("Longest wait", summary.longestWait)
        )
        // end
    }

    private var nothingNothing: some ChartContent {
        // snippet:how-positions-are-given-rectangle-nothing-nothing
        RectangleMark()
        // end
    }
}

/// Every `RuleMark` initializer, one per combination.
private struct RulePositions: ChartContent {
    let form: RuleForm
    let summary: OrderSummary

    var body: some ChartContent {
        erased
    }

    /// A plain switch over erased content, outside the chart builder: as a builder's switch,
    /// seven or more branches do not type-check in reasonable time.
    private var erased: AnyChartContent {
        switch form {
        case .valueInterval: AnyChartContent(valueInterval)
        case .valueNothing: AnyChartContent(valueNothing)
        case .intervalValue: AnyChartContent(intervalValue)
        case .intervalNothing: AnyChartContent(intervalNothing)
        case .nothingValue: AnyChartContent(nothingValue)
        case .nothingInterval: AnyChartContent(nothingInterval)
        }
    }

    private var valueInterval: some ChartContent {
        // snippet:how-positions-are-given-rule-value-interval
        RuleMark(
            x: .value("Average queue", summary.averageQueue),
            yStart: .value("Shortest wait", summary.shortestWait),
            yEnd: .value("Longest wait", summary.longestWait)
        )
        // end
    }

    private var valueNothing: some ChartContent {
        // snippet:how-positions-are-given-rule-value-nothing
        RuleMark(
            x: .value("Average queue", summary.averageQueue)
        )
        // end
    }

    private var intervalValue: some ChartContent {
        // snippet:how-positions-are-given-rule-interval-value
        RuleMark(
            xStart: .value("Shortest queue", summary.shortestQueue),
            xEnd: .value("Longest queue", summary.longestQueue),
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var intervalNothing: some ChartContent {
        // snippet:how-positions-are-given-rule-interval-nothing
        RuleMark(
            xStart: .value("Shortest queue", summary.shortestQueue),
            xEnd: .value("Longest queue", summary.longestQueue)
        )
        // end
    }

    private var nothingValue: some ChartContent {
        // snippet:how-positions-are-given-rule-nothing-value
        RuleMark(
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var nothingInterval: some ChartContent {
        // snippet:how-positions-are-given-rule-nothing-interval
        RuleMark(
            yStart: .value("Shortest wait", summary.shortestWait),
            yEnd: .value("Longest wait", summary.longestWait)
        )
        // end
    }
}

/// Every `PointMark` initializer, one per combination.
private struct PointPositions: ChartContent {
    let form: PointForm
    let summary: OrderSummary

    var body: some ChartContent {
        erased
    }

    /// A plain switch over erased content, outside the chart builder: as a builder's switch,
    /// seven or more branches do not type-check in reasonable time.
    private var erased: AnyChartContent {
        switch form {
        case .valueValue: AnyChartContent(valueValue)
        case .valueNothing: AnyChartContent(valueNothing)
        case .nothingValue: AnyChartContent(nothingValue)
        }
    }

    private var valueValue: some ChartContent {
        // snippet:how-positions-are-given-point-value-value
        PointMark(
            x: .value("Average queue", summary.averageQueue),
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }

    private var valueNothing: some ChartContent {
        // snippet:how-positions-are-given-point-value-nothing
        PointMark(
            x: .value("Average queue", summary.averageQueue)
        )
        // end
    }

    private var nothingValue: some ChartContent {
        // snippet:how-positions-are-given-point-nothing-value
        PointMark(
            y: .value("Average wait", summary.averageWait)
        )
        // end
    }
}

/// The chart for the Audio Graph: the orders as one series of queue and wait, and what the mark shows
/// in the summary. Not tied to the main actor: the accessibility system calls it when it chooses.
nonisolated struct PositionsChartDescriptor: AXChartDescriptorRepresentable {
    let description: PositionsDescription

    func makeChartDescriptor() -> AXChartDescriptor {
        let orders = description.orders
        let locale = description.locale
        let xAxis = AXNumericDataAxisDescriptor(
            title: PositionsDescription.queueDescriptorTitle,
            range: description.queueDomain,
            gridlinePositions: []
        ) { CafeWording.people($0, locale: locale) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: PositionsDescription.waitDescriptorTitle,
            range: description.waitDomain,
            gridlinePositions: []
        ) { CafeWording.seconds($0, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: PositionsDescription.store,
            isContinuous: false,
            dataPoints: orders.map { AXDataPoint(x: Double($0.queueLength), y: Double($0.waitSeconds)) }
        )
        return AXChartDescriptor(
            title: "Queue and wait for each order at the \(PositionsDescription.store) café",
            summary: description.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/how-positions-are-given") {
            HowPositionsAreGivenScreen(screen: screen)
        }
    }
}

#Preview("No initializer") {
    PositionsChart(description: PositionsDescription(
        mark: .rule, x: .value, y: .value, orders: CafeData.orderWaits.filter { $0.store == PositionsDescription.store }, locale: .current
    ))
}

#Preview("No orders") {
    PositionsChart(description: PositionsDescription(mark: .bar, x: .value, y: .interval, orders: [], locale: .current))
}
