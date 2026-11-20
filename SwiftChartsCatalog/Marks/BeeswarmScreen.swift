import Accessibility
import Charts
import SwiftUI

/// "Beeswarm": points on one value axis, dodged into rows computed in the data so that none overlap.
struct BeeswarmScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = BeeswarmViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: BeeswarmWording.chartTitle,
            message: summary.headline,
            explanation: """
            Every point is one order, placed along the axis by its wait. Swift Charts does not move points apart, \
            so the data gives each one a row: the first free row among the orders whose waits are closer than the \
            crowding. The row is plotted on a hidden y axis; it measures nothing, and the height of a pile shows \
            how many waits fall close together.
            """
        ) {
            BeeswarmChart(summary: summary)
        } controls: {
            ControlsSection {
                LabeledSlider(
                    title: "Crowding",
                    value: $viewModel.crowding,
                    range: BeeswarmViewModel.crowdingRange,
                    step: BeeswarmViewModel.crowdingStep,
                    valueText: summary.crowdingText,
                    spokenValue: summary.spokenCrowding
                )
            }
        }
    }
}

/// Constants that belong to this chart's marks.
private enum BeeswarmMetrics {
    /// The area of one point, in square points.
    static let symbolSize: CGFloat = 50
    /// Translucent, so points the crowding failed to separate show as darker patches.
    static let pointOpacity = 0.7
    /// Room below row zero, in rows, so the bottom points are not cut by the axis.
    static let rowsBelow = 0.5
    /// The fewest rows the hidden axis covers, so a shallow swarm stays a strip and is not stretched.
    static let minimumRows = 8
}

/// The swarm, or a placeholder when there are no orders.
struct BeeswarmChart: View {
    let summary: BeeswarmSummary

    var body: some View {
        if summary.placed.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "clock",
                description: Text("Each order appears here as a point, placed by how long it waited.")
            )
        } else {
            // snippet:beeswarm-chart
            Chart(summary.placed) { item in
                Plot {
                    // A clear band the full height of the plot at the point's wait: every element then has the
                    // same top, so VoiceOver and Switch Control visit the orders along the wait axis, not by row.
                    RectangleMark(x: .value(CafeWording.waitAxisTitle, item.order.waitSeconds), width: .fixed(1))
                        .foregroundStyle(.clear)
                    PointMark(
                        x: .value(CafeWording.waitAxisTitle, item.order.waitSeconds),
                        // The row only keeps points apart; it measures nothing, so its axis is hidden.
                        y: .value(BeeswarmWording.row, item.row)
                    )
                    .symbolSize(BeeswarmMetrics.symbolSize)
                    .opacity(BeeswarmMetrics.pointOpacity)
                }
                // Without this the row numbers would be read out as if they were data.
                .accessibilityLabel(BeeswarmWording.name(of: item.order, locale: summary.locale))
                .accessibilityValue(CafeWording.seconds(item.order.waitSeconds, locale: summary.locale))
            }
            .chartYAxis(.hidden)
            // Room for every row, and never fewer than a fixed number, so piles stay compact.
            .chartYScale(domain: -BeeswarmMetrics.rowsBelow ... Double(max(summary.depth, BeeswarmMetrics.minimumRows)))
            .chartXAxisLabel(CafeWording.waitAxisTitle)
            // end
            // One wait axis for the chart and the descriptor.
            .chartXScale(domain: summary.waitDomain)
            .accessibilityChartDescriptor(BeeswarmChartDescriptor(summary: summary))
        }
    }
}

/// The swarm for the Audio Graph. A strip of points has none of its own, and the rows are not data,
/// so it is described as one point per order, shortest wait first, with the wait as the value.
nonisolated struct BeeswarmChartDescriptor: AXChartDescriptorRepresentable {
    let summary: BeeswarmSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let waits = summary.placed.map { Double($0.order.waitSeconds) }
        let names = summary.placed.map { BeeswarmWording.name(of: $0.order, locale: locale) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: BeeswarmWording.order, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.waitAxisTitle,
            // The drawn wait axis, from zero to its rounded top.
            range: summary.waitDomain,
            gridlinePositions: []
        ) { value in
            // Called by the accessibility system with any number, so no conversion to Int that could trap.
            CafeWording.seconds(value, locale: locale)
        }
        let series = AXDataSeriesDescriptor(
            name: BeeswarmWording.seriesName,
            isContinuous: false,
            dataPoints: zip(names, waits).map { AXDataPoint(x: $0, y: $1) }
        )
        return AXChartDescriptor(
            title: BeeswarmWording.chartTitle,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Orders") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/beeswarm") {
            BeeswarmScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    BeeswarmChart(summary: BeeswarmSummary(placed: [], crowding: BeeswarmViewModel.defaultCrowding, locale: .current))
}
