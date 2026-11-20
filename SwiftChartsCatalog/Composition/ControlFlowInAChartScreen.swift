import Accessibility
import Charts
import SwiftUI

/// "Control flow in a chart": `ForEach`, `if` and `if let` inside chart content.
struct ControlFlowInAChartScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ControlFlowInAChartViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups a day at the Harbour café",
            message: viewModel.headline,
            explanation: """
            A chart's content is written with ordinary control flow. ForEach makes a mark for each day. \
            An if adds the average rule only while the switch is on, and an if let adds the highlighted point \
            only while there is a day to highlight. When the state goes away, so does the mark.
            """,
            snippets: viewModel.snippets
        ) {
            ControlFlowChart(summary: viewModel.summary)
        } controls: {
            ControlFlowControls(viewModel: viewModel)
        }
        // The marks appear and disappear without a sound: say what the chart now shows.
        .onChange(of: viewModel.headline) { _, headline in
            AccessibilityNotification.Announcement(headline).post()
        }
    }
}

/// The switch for the optional overlay, and the picker that gives the optional value.
struct ControlFlowControls: View {
    @Bindable var viewModel: ControlFlowInAChartViewModel

    var body: some View {
        ControlsSection {
            Toggle("Show the average", isOn: $viewModel.showsAverage)
            LabeledSegmentedPicker(title: "Highlight a day", selection: $viewModel.highlight) {
                ForEach(ControlFlowHighlight.allCases) { highlight in
                    Text(highlight.rawValue).tag(highlight)
                }
            }
        }
    }
}

/// Sizes the chart's overlays use.
private enum ControlFlowChartMetrics {
    static let ruleLineWidth: CGFloat = 2
    /// The highlighted point's area, in square points.
    static let highlightSymbolArea: CGFloat = 90
    /// Room kept above the highest value and below the lowest for a label on it.
    static let plotLabelPadding: CGFloat = 24
    static let weekInDays = 7
}

/// A line of daily cups, with an average rule and a highlighted point that exist only while their state does.
struct ControlFlowChart: View {
    let summary: ControlFlowSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer date labels at the accessibility text sizes, so they do not collide.
    private var weeksPerLabel: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no line under a headline that is not true.
        if summary.hasData {
            let calendar = CafeData.calendar
            // The optional overlay and the optional value, as the chart content reads them.
            let showsAverage = summary.showsAverage
            // The rule is drawn at the whole number written on it and spoken for it, not at the unrounded mean.
            let average = summary.roundedAverage ?? 0
            let highlighted = summary.highlighted
            // One focus at a time: the line steps back while an overlay is drawn over it.
            let isMuted = summary.drawnAverage != nil || highlighted != nil
            Chart {
                // snippet:control-flow-in-a-chart-for-each
                // ForEach makes one mark per element of the collection.
                ForEach(summary.days) { day in
                    Plot {
                        LineMark(
                            x: .value("Day", day.day, unit: .day, calendar: calendar),
                            y: .value("Cups", day.cups)
                        )
                    }
                    .accessibilityLabel(summary.dayText(day.day))
                    .accessibilityValue(summary.accessibilityValue(for: day))
                }
                // end
                .foregroundStyle(isMuted ? Color.gray.opacity(0.6) : Color.blue)

                // snippet:control-flow-in-a-chart-if
                // An optional overlay: this rule is part of the chart only while the condition is true.
                if showsAverage {
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: ControlFlowChartMetrics.ruleLineWidth))
                        .accessibilityLabel("Average")
                        .accessibilityValue(ControlFlowSummary.cupsText(average))
                        .annotation(position: .bottom, alignment: .trailing) {
                            Text("Average: \(average, format: .number)")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                }
                // end

                // snippet:control-flow-in-a-chart-if-let
                // A mark that depends on an optional value: it exists only while there is a highlighted day.
                if let highlighted {
                    PointMark(
                        x: .value("Day", highlighted.day, unit: .day, calendar: calendar),
                        y: .value("Cups", highlighted.cups)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(ControlFlowChartMetrics.highlightSymbolArea)
                    // The point repeats a value the line already has; that day's element says it is highlighted.
                    .accessibilityHidden(true)
                    .annotation(
                        // Above a peak and below a trough, so the label stays clear of the line.
                        position: highlighted.cups < average ? .bottom : .top,
                        overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))
                    ) {
                        Text("\(summary.shortDayText(highlighted.day)): \(highlighted.cups, format: .number)")
                            .font(.caption.bold())
                    }
                }
                // end
            }
            // A line far from zero: fit the scale to the data, and keep room for a label on the highest
            // or the lowest day, so the scale does not move when the label appears.
            // The domain is worked out once, off zero, and given to the descriptor too.
            .chartYScale(
                domain: summary.valueDomain,
                range: .plotDimension(padding: ControlFlowChartMetrics.plotLabelPadding)
            )
            .chartXAxis {
                // The days were counted in UTC, so the axis is told which calendar to cut weeks in.
                AxisMarks(
                    format: Date.FormatStyle(timeZone: calendar.timeZone).month().day(),
                    values: .stride(by: .day, count: ControlFlowChartMetrics.weekInDays * weeksPerLabel, calendar: calendar)
                )
            }
            .accessibilityChartDescriptor(ControlFlowChartDescriptor(summary: summary))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here as a line.")
            )
        }
    }
}

/// The chart for the Audio Graph: a title, a summary of what is drawn, written-out dates and values in cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ControlFlowChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ControlFlowSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let days = summary.days
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.dayText($0.day) }
        )
        // The drawn scale does not include zero, so the range is the chart's own domain, off zero.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in ControlFlowSummary.cupsText(count) } }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: days.map { AXDataPoint(x: summary.dayText($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the Harbour café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "composition/control-flow-in-a-chart") {
            ControlFlowInAChartScreen(screen: screen)
        }
    }
}

#Preview("Average and highlight") {
    let days = CafeData.harbourSales
    ControlFlowChart(summary: ControlFlowSummary(
        days: days, showsAverage: true, highlight: .latest, highlighted: days.last
    ))
    .padding()
}

#Preview("No sales") {
    ControlFlowChart(summary: ControlFlowSummary(days: []))
}
