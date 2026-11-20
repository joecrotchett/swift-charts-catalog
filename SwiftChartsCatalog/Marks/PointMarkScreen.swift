import Accessibility
import Charts
import SwiftUI

/// "Point": `PointMark` as a scatter plot, with colour and symbol by group, and as points on one axis.
struct PointMarkScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = PointMarkViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Waits for an order",
            message: summary.headline,
            explanation: """
            PointMark draws one point for each order. Given a value on x and on y it makes a scatter plot, \
            which shows how two numbers relate; given a value on x alone, every point sits on one line and \
            shows how the values are spread. foregroundStyle(by:) and symbol(by:) on the same property \
            tell groups apart by colour and by shape together.
            """,
            snippets: viewModel.snippets
        ) {
            PointMarkChart(summary: summary)
        } controls: {
            PointMarkControls(viewModel: viewModel)
        }
        // The change is not animated, and an animation would not reach everyone: say it.
        .onChange(of: summary.announcement) { _, announcement in
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// The two controls: the encodings, and how many axes the points have a value on.
private struct PointMarkControls: View {
    @Bindable var viewModel: PointMarkViewModel

    var body: some View {
        ControlsSection {
            Toggle("Colour and symbol by café", isOn: $viewModel.showsEncodings)
            LabeledSegmentedPicker(title: "Values given to each point", selection: $viewModel.axes) {
                ForEach(PointAxes.allCases) { axes in
                    Text(axes.title).tag(axes)
                }
            }
        }
    }
}

/// The chart for the current setting, or a placeholder when there are no orders to draw.
struct PointMarkChart: View {
    let summary: PointMarkSummary

    var body: some View {
        if !summary.hasData {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "clock",
                description: Text("Each order appears here as a point: the queue it met and how long it waited.")
            )
        } else {
            // A scatter plot and a strip are different charts, so they are two views, not one that morphs.
            switch summary.axes {
            case .two: PointScatterChart(summary: summary)
            case .one: PointStripChart(summary: summary)
            }
        }
    }
}

/// A value on both axes: the queue on x, the wait on y.
private struct PointScatterChart: View {
    let summary: PointMarkSummary

    var body: some View {
        Chart {
            ForEach(summary.portions) { portion in
                // One Plot per stretch of the queue axis: one accessibility element for the points in it.
                Plot {
                    // A clear band the full height of the plot over the stretch: every element then has the same
                    // top, so VoiceOver and Switch Control visit them along the queue axis, not by the highest wait.
                    RectangleMark(
                        xStart: .value("Queue", portion.band.lower),
                        xEnd: .value("Queue", portion.band.upper)
                    )
                    .foregroundStyle(.clear)
                    ForEach(portion.orders) { order in
                        if summary.showsEncodings {
                            // snippet:point-scatter-encoded
                            PointMark(
                                x: .value("Queue", order.queueLength),
                                y: .value("Wait", order.waitSeconds)
                            )
                            // The same property twice: the cafés differ by colour and by shape,
                            // so the chart does not rely on colour alone. Both go in the legend.
                            .foregroundStyle(by: .value("Café", order.store))
                            .symbol(by: .value("Café", order.store))
                            // end
                        } else {
                            // snippet:point-scatter
                            // A number on x and a number on y: one point per order.
                            PointMark(
                                x: .value("Queue", order.queueLength),
                                y: .value("Wait", order.waitSeconds)
                            )
                            // end
                        }
                    }
                }
                .accessibilityLabel(portion.label)
                .accessibilityValue(portion.value)
            }
        }
        // Both axes worked out once, for the chart and the descriptor. When every wait is the same the domain
        // still has an extent, so the axis draws labels.
        .chartXScale(domain: summary.queueDomain)
        .chartYScale(domain: summary.waitDomain)
        // Each café in its colour and shape on every screen that draws the two.
        .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
        .chartSymbolScale(mapping: CafeSeriesStyle.symbol(for:))
        .chartXAxisLabel(CafeWording.queueAxisTitle)
        .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
        .accessibilityChartDescriptor(PointMarkChartDescriptor(summary: summary))
    }
}

/// A value on x only: every point on one line, showing how the waits are spread.
private struct PointStripChart: View {
    let summary: PointMarkSummary

    var body: some View {
        Chart {
            ForEach(summary.portions) { portion in
                // One Plot per band of waits: one accessibility element for the points in it.
                Plot {
                    ForEach(portion.orders) { order in
                        if summary.showsEncodings {
                            // snippet:point-strip-encoded
                            PointMark(x: .value("Wait", order.waitSeconds))
                                .foregroundStyle(by: .value("Café", order.store))
                                .symbol(by: .value("Café", order.store))
                                // Translucent, so crowded stretches look darker.
                                .opacity(PointStyle.stripOpacity)
                            // end
                        } else {
                            // snippet:point-strip
                            // No y: the point is centred on the plot's height.
                            PointMark(x: .value("Wait", order.waitSeconds))
                                // Translucent, so crowded stretches look darker.
                                .opacity(PointStyle.stripOpacity)
                            // end
                        }
                    }
                }
                .accessibilityLabel(portion.label)
                .accessibilityValue(portion.value)
            }
        }
        // One wait axis for the chart and the descriptor, with an extent even when every wait is the same.
        .chartXScale(domain: summary.waitDomain)
        // Each café in its colour and shape on every screen that draws the two.
        .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
        .chartSymbolScale(mapping: CafeSeriesStyle.symbol(for:))
        .chartXAxisLabel(CafeWording.waitAxisTitle)
        .accessibilityChartDescriptor(PointMarkChartDescriptor(summary: summary))
    }
}

/// Constants that belong to this chart's marks.
private enum PointStyle {
    static let stripOpacity = 0.4
}

/// The chart for the Audio Graph. The scatter plot is two number axes; the strip has no value on y,
/// so it is described as the number of orders in each band of waits.
nonisolated struct PointMarkChartDescriptor: AXChartDescriptorRepresentable {
    let summary: PointMarkSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        switch summary.axes {
        case .two: scatterDescriptor
        case .one: stripDescriptor
        }
    }

    private var scatterDescriptor: AXChartDescriptor {
        let locale = summary.locale
        // Both scales as drawn, from zero.
        let xAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.queueAxisTitle,
            range: summary.queueDomain,
            gridlinePositions: []
        ) { CafeWording.count($0, locale: locale, as: PointMarkSummary.queueText) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.waitAxisTitle,
            range: summary.waitDomain,
            gridlinePositions: []
        ) { CafeWording.count($0, locale: locale, as: CafeWording.seconds) }
        let series = zip(summary.seriesNames, summary.groups).map { name, group in
            AXDataSeriesDescriptor(
                name: name,
                isContinuous: false,
                dataPoints: group.orders
                    .sorted { ($0.queueLength, $0.waitSeconds) < ($1.queueLength, $1.waitSeconds) }
                    .map { AXDataPoint(x: Double($0.queueLength), y: Double($0.waitSeconds)) }
            )
        }
        return AXChartDescriptor(
            title: summary.audioGraphTitle, summary: summary.audioGraphSummary,
            xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: series
        )
    }

    private var stripDescriptor: AXChartDescriptor {
        let locale = summary.locale
        let categories = summary.bands.map { PointMarkSummary.bandText($0, locale: locale) }
        let counts = summary.groups.map { summary.counts(in: $0.orders) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Wait", categoryOrder: categories)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Orders",
            range: 0 ... Double(counts.joined().max() ?? 0),
            gridlinePositions: []
        ) { CafeWording.count($0, locale: locale, as: CafeWording.orders) }
        let series = zip(summary.seriesNames, counts).map { name, counts in
            AXDataSeriesDescriptor(
                name: name,
                isContinuous: false,
                dataPoints: zip(categories, counts).map { AXDataPoint(x: $0, y: Double($1)) }
            )
        }
        return AXChartDescriptor(
            title: summary.audioGraphTitle, summary: summary.audioGraphSummary,
            xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: series
        )
    }
}

#Preview("Point") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/point") {
            PointMarkScreen(screen: screen)
        }
    }
}

#Preview("One axis") {
    PointMarkChart(summary: PointMarkSummary(orders: CafeData.orderWaits, axes: .one, showsEncodings: true, locale: .current))
        .padding()
}

#Preview("No orders") {
    PointMarkChart(summary: PointMarkSummary(orders: [], axes: .two, showsEncodings: true, locale: .current))
}
