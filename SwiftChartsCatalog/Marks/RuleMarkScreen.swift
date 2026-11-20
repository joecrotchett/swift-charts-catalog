import Accessibility
import Charts
import SwiftUI

/// "Rule": a `RuleMark` as a threshold, an average, or a line marking one position, over a scatter of orders.
struct RuleMarkScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = RuleMarkViewModel()
    /// The one locale the screen's words are written in: the headline here, and the chart is given the same value.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Orders at the Harbour café: queue and wait",
            message: viewModel.summary(locale: locale).headline,
            explanation: """
            A RuleMark given a value on one axis and nothing on the other crosses the whole plot: a y value \
            makes a horizontal line, an x value a vertical one. It is one mark for the whole chart, so it is \
            written beside the ForEach that draws the orders, not inside it. The label on the line is an \
            annotation attached to the rule, so it moves with the value.
            """,
            snippets: viewModel.snippets
        ) {
            RuleMarkChart(summary: viewModel.summary(locale: locale))
        } controls: {
            RuleMarkControls(viewModel: viewModel)
        }
        // The chart changing is announced, not only drawn: every control changes this sentence.
        .onChange(of: viewModel.announcement(locale: locale)) { _, announcement in
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// The screen's controls: which way the rule runs, what it stands for, and the order it marks.
struct RuleMarkControls: View {
    @Bindable var viewModel: RuleMarkViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Direction", selection: $viewModel.direction) {
                ForEach(RuleDirection.allCases) { direction in
                    Text(direction.rawValue).tag(direction)
                }
            }
            LabeledSegmentedPicker(title: "The rule shows", selection: $viewModel.use) {
                ForEach(RuleUse.allCases) { use in
                    Text(use.rawValue).tag(use)
                }
            }
            if viewModel.use == .markedOrder {
                // Named for what it sets, with the order as its value: read once, "Marked order, Order 5".
                LabeledStepper(
                    title: "Marked order",
                    value: $viewModel.markedNumber,
                    in: viewModel.markedNumberRange,
                    valueText: "Order \(viewModel.markedNumber.formatted(.number.locale(locale)))"
                )
            }
        }
    }
}

/// Sizes and colours that belong to this chart's marks.
private enum RuleChartStyle {
    static let ruleWidth: CGFloat = 2
    static let pointSize: CGFloat = 50
    static let markedPointSize: CGFloat = 140
    static let labelPadding: CGFloat = 2
    static let rule = Color.blue
    /// The orders step back so the rule is the one thing emphasised.
    static let points = Color.gray.opacity(0.6)
}

/// A point per order with one rule over them, or a placeholder when there are no orders.
struct RuleMarkChart: View {
    let summary: RuleMarkSummary

    var body: some View {
        if summary.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "person.3.sequence",
                description: Text("Each order appears here as a point, with a rule across them.")
            )
        } else {
            // snippet:rule-chart
            Chart {
                ForEach(summary.orders) { order in
                    Plot {
                        // A clear band the full height of the plot at the order's queue: every element then has
                        // the same top, so the orders are visited along the queue axis, not by their waits.
                        RectangleMark(x: .value("Queue", order.queueLength), width: .fixed(1))
                            .foregroundStyle(.clear)
                        PointMark(
                            x: .value("Queue", order.queueLength),
                            y: .value("Wait", order.waitSeconds)
                        )
                        .foregroundStyle(order == summary.markedOrder ? RuleChartStyle.rule : RuleChartStyle.points)
                        .symbolSize(order == summary.markedOrder ? RuleChartStyle.markedPointSize : RuleChartStyle.pointSize)
                    }
                    .accessibilityLabel(summary.accessibilityLabel(for: order))
                    .accessibilityValue(summary.accessibilityValue(for: order))
                }
                // One rule for the whole chart. Inside the ForEach it would be made once per order.
                RuleLayer(summary: summary)
            }
            // end
            .chartXAxisLabel(CafeWording.queueAxisTitle)
            .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
            // Both axes worked out once, reaching a rule beyond the data, for the chart and the descriptor.
            .chartXScale(domain: summary.queueDomain)
            .chartYScale(domain: summary.waitDomain)
            .accessibilityChartDescriptor(RuleMarkChartDescriptor(summary: summary))
        }
    }
}

/// The rule for the current setting: a labelled constant, or a line through the marked order.
struct RuleLayer: ChartContent {
    let summary: RuleMarkSummary

    var body: some ChartContent {
        if let value = summary.ruleValue, let valueText = summary.ruleValueText, let label = summary.ruleLabel,
           let placement = summary.labelPlacement
        {
            if summary.use == .markedOrder {
                MarkedPositionRule(direction: summary.direction, value: value, label: label, placement: placement)
            } else {
                ConstantRule(
                    direction: summary.direction, title: summary.ruleTitle, value: value,
                    valueText: valueText, label: label, placement: placement
                )
            }
        }
    }
}

/// A threshold or an average: a line at one value, named and given its unit for VoiceOver.
struct ConstantRule: ChartContent {
    let direction: RuleDirection
    let title: String
    let value: Double
    let valueText: String
    let label: String
    let placement: RuleLabelPlacement

    var body: some ChartContent {
        switch direction {
        case .horizontal:
            // snippet:rule-horizontal
            // A value on y and nothing on x: the rule runs across the whole plot.
            RuleMark(y: .value(title, value))
                .foregroundStyle(RuleChartStyle.rule)
                .lineStyle(StrokeStyle(lineWidth: RuleChartStyle.ruleWidth))
                // A rule across the plot is its own element; unlabelled it is read as a bare number.
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
                // The label hangs on the rule, so it moves with the value: above or below the rule, at
                // whichever end has no orders under it.
                .annotation(position: placement.acrossHorizontalRule, alignment: placement.alongHorizontalRule) {
                    RuleLabel(text: label)
                }
        // end
        case .vertical:
            // snippet:rule-vertical
            // A value on x and nothing on y: the rule runs up the whole plot.
            RuleMark(x: .value(title, value))
                .foregroundStyle(RuleChartStyle.rule)
                .lineStyle(StrokeStyle(lineWidth: RuleChartStyle.ruleWidth))
                // A rule across the plot is its own element; unlabelled it is read as a bare number.
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
                // The label hangs on the rule, so it moves with the value: beside the rule, on the side
                // with room for it, at whichever end has no orders under it.
                .annotation(position: placement.besideVerticalRule, alignment: placement.alongVerticalRule) {
                    RuleLabel(text: label)
                }
            // end
        }
    }
}

/// A line through one order's value. It repeats what that order's point says, so it is hidden from
/// assistive technologies; the point's own label says it is the marked one.
struct MarkedPositionRule: ChartContent {
    let direction: RuleDirection
    let value: Double
    let label: String
    let placement: RuleLabelPlacement

    var body: some ChartContent {
        switch direction {
        case .horizontal:
            // snippet:rule-horizontal-marked
            RuleMark(y: .value("Marked wait", value))
                .foregroundStyle(RuleChartStyle.rule)
                .lineStyle(StrokeStyle(lineWidth: RuleChartStyle.ruleWidth))
                // The rule repeats the marked point's value: left visible it reads as a position with no name.
                .accessibilityHidden(true)
                // The label hangs on the rule, so it moves with the value: above or below the rule, at
                // whichever end has no orders under it.
                .annotation(position: placement.acrossHorizontalRule, alignment: placement.alongHorizontalRule) {
                    RuleLabel(text: label)
                }
        // end
        case .vertical:
            // snippet:rule-vertical-marked
            RuleMark(x: .value("Marked queue", value))
                .foregroundStyle(RuleChartStyle.rule)
                .lineStyle(StrokeStyle(lineWidth: RuleChartStyle.ruleWidth))
                // The rule repeats the marked point's value: left visible it reads as a position with no name.
                .accessibilityHidden(true)
                // The label hangs on the rule, so it moves with the value: beside the rule, on the side
                // with room for it, at whichever end has no orders under it.
                .annotation(position: placement.besideVerticalRule, alignment: placement.alongVerticalRule) {
                    RuleLabel(text: label)
                }
            // end
        }
    }
}

/// A placement as the annotation's position (which side of the rule) and alignment (where along it).
private extension RuleLabelPlacement {
    // snippet:rule-label-placement
    /// A horizontal rule: `.top` or `.bottom` puts the label above or below the line.
    var acrossHorizontalRule: AnnotationPosition {
        isOnHigherSide ? .top : .bottom
    }

    /// The alignment then slides it to one end of the line.
    var alongHorizontalRule: Alignment {
        isAtHighEnd ? .trailing : .leading
    }

    /// A vertical rule: `.trailing` or `.leading` puts the label beside the line, inside the plot.
    var besideVerticalRule: AnnotationPosition {
        isOnHigherSide ? .trailing : .leading
    }

    /// The alignment then slides it to the top or the bottom of the line.
    var alongVerticalRule: Alignment {
        isAtHighEnd ? .top : .bottom
    }
    // end
}

/// The words written on the rule. An annotation's view is not read by VoiceOver; the rule or the
/// marked point carries the same words.
struct RuleLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(RuleChartStyle.labelPadding)
    }
}

/// The chart for the Audio Graph: both axes are numbers, each order is a point, and the rule is in the summary.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct RuleMarkChartDescriptor: AXChartDescriptorRepresentable {
    let summary: RuleMarkSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let orders = summary.orders
        let locale = summary.locale
        // The drawn scales: from zero, reaching the rule when it lies beyond the data, rounded up.
        return AXChartDescriptor(
            title: "Queue and wait for each order at the Harbour café",
            summary: summary.audioGraphSummary,
            xAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.queueAxisTitle, range: summary.queueDomain, gridlinePositions: []
            ) { RuleMarkSummary.peopleText($0, locale: locale) },
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.waitAxisTitle, range: summary.waitDomain, gridlinePositions: []
            ) { RuleMarkSummary.secondsText($0, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: false,
                dataPoints: orders.map { AXDataPoint(x: Double($0.queueLength), y: Double($0.waitSeconds)) }
            )]
        )
    }
}

#Preview("Rule") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/rule") {
            RuleMarkScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    RuleMarkChart(summary: RuleMarkSummary(orders: [], direction: .horizontal, use: .average, markedNumber: 1, locale: .current))
}
