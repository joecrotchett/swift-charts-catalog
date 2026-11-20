import Accessibility
import Charts
import SwiftUI

/// "Box plot": a rule, a bar and a rectangle at one position, for the range, the middle half and the median.
struct BoxPlotScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = BoxPlotViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Waits by café",
            message: summary.headline,
            explanation: summary.explanation,
            snippets: viewModel.snippets
        ) {
            BoxPlotChart(summary: summary)
        } controls: {
            BoxPlotControls(layers: $viewModel.layers)
        }
        .onChange(of: viewModel.layers) { previous, _ in
            // Adding or removing a layer changes the marks drawn: say so, then what the chart now shows.
            AccessibilityNotification.Announcement(viewModel.announcement(after: previous, locale: locale)).post()
        }
    }
}

/// A switch per layer.
struct BoxPlotControls: View {
    @Binding var layers: BoxPlotLayers

    var body: some View {
        ControlsSection {
            Toggle(BoxPlotWording.range, isOn: $layers.range)
            Toggle(BoxPlotWording.middleHalf, isOn: $layers.middleHalf)
            Toggle(BoxPlotWording.medianLayer, isOn: $layers.median)
        }
    }
}

/// One box per café, or a placeholder when there is nothing to draw.
struct BoxPlotChart: View {
    let summary: BoxPlotSummary

    var body: some View {
        if summary.hasNoWaits {
            ContentUnavailableView(
                "No waits yet",
                systemImage: "clock",
                description: Text("Each café's waits appear here as a box plot.")
            )
        } else if summary.layers.isEmpty {
            ContentUnavailableView(
                "No layer switched on",
                systemImage: "square.stack.3d.up.slash",
                description: Text("Switch on the range, the middle half or the median to draw it.")
            )
        } else {
            // snippet:box-plot-chart
            Chart(summary.waits) { wait in
                // BoxPlotMark wraps its marks in one Plot, so this label and value describe the
                // whole box: one accessibility element per café, saying only what is drawn.
                BoxPlotMark(wait: wait, layers: summary.layers)
                    .accessibilityLabel(wait.store)
                    .accessibilityValue(summary.elementValue(for: wait))
            }
            // One domain for the scale and the descriptor: zero to the longest wait rounded up, whichever
            // layers are on, so a layer stays where it is when another is switched off.
            .chartYScale(domain: summary.valueDomain)
            .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
            // end
            .accessibilityChartDescriptor(BoxPlotChartDescriptor(summary: summary))
        }
    }
}

/// One café's box: up to three marks that share its position on the x axis.
struct BoxPlotMark: ChartContent {
    let wait: WaitQuartiles
    let layers: BoxPlotLayers

    var body: some ChartContent {
        // One Plot for the marks: one accessibility element per café.
        Plot {
            if layers.range {
                // snippet:box-plot-range
                // The whisker: a rule from the shortest wait to the longest.
                RuleMark(
                    x: .value(CafeWording.store, wait.store),
                    yStart: .value(BoxPlotWording.minimum, wait.minimum),
                    yEnd: .value(BoxPlotWording.maximum, wait.maximum)
                )
                // A colour, not the hierarchical .secondary, which a mark draws as a tint of blue.
                .foregroundStyle(Color.secondary)
                // end
            }
            if layers.middleHalf {
                // snippet:box-plot-middle-half
                // The box: a floating bar from the lower quartile to the upper.
                BarMark(
                    x: .value(CafeWording.store, wait.store),
                    yStart: .value(BoxPlotWording.lowerQuartile, wait.lowerQuartile),
                    yEnd: .value(BoxPlotWording.upperQuartile, wait.upperQuartile),
                    width: .ratio(BoxPlotMetrics.boxWidthRatio)
                )
                .foregroundStyle(.blue.opacity(BoxPlotMetrics.boxOpacity))
                // end
            }
            if layers.median {
                // snippet:box-plot-median
                // The median: a rectangle as wide as the box and a fixed two points high.
                RectangleMark(
                    x: .value(CafeWording.store, wait.store),
                    y: .value(BoxPlotWording.median, wait.median),
                    width: .ratio(BoxPlotMetrics.boxWidthRatio),
                    height: .fixed(BoxPlotMetrics.medianHeight)
                )
                .foregroundStyle(Color.primary)
                // end
            }
        }
    }
}

/// The sizes that belong to this chart's marks.
private enum BoxPlotMetrics {
    /// The box's width as a share of the café's band; the median line is the same width.
    static let boxWidthRatio: CGFloat = 0.4
    static let boxOpacity = 0.5
    static let medianHeight: CGFloat = 2
}

/// The chart for the Audio Graph: one series for each of the five numbers that is drawn.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct BoxPlotChartDescriptor: AXChartDescriptorRepresentable {
    let summary: BoxPlotSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = summary
        let waits = summary.waits
        let layers = summary.layers
        var series: [AXDataSeriesDescriptor] = []
        func add(_ name: String, _ value: KeyPath<WaitQuartiles, Double>) {
            series.append(AXDataSeriesDescriptor(
                name: name,
                isContinuous: false,
                dataPoints: waits.map { AXDataPoint(x: $0.store, y: $0[keyPath: value]) }
            ))
        }
        if layers.range { add(BoxPlotWording.minimum, \.minimum) }
        if layers.middleHalf { add(BoxPlotWording.lowerQuartile, \.lowerQuartile) }
        if layers.median { add(BoxPlotWording.median, \.median) }
        if layers.middleHalf { add(BoxPlotWording.upperQuartile, \.upperQuartile) }
        if layers.range { add(BoxPlotWording.maximum, \.maximum) }

        return AXChartDescriptor(
            title: "Waits at each café, in seconds",
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.store, categoryOrder: waits.map(\.store)),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.waitAxisTitle,
                // The drawn value axis: the same domain the chart's scale is given.
                range: summary.valueDomain,
                gridlinePositions: []
            ) { value in value.isFinite ? summary.seconds(value) : "" },
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Box plot") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/box-plot") {
            BoxPlotScreen(screen: screen)
        }
    }
}

#Preview("No waits") {
    BoxPlotChart(summary: BoxPlotSummary(waits: [], layers: BoxPlotLayers(), locale: .current))
}
