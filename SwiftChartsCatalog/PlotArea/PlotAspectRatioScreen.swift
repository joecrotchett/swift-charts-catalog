import Accessibility
import Charts
import SwiftUI

/// "Plot aspect ratio": the same circle in a plot that takes the chart's shape, and in one held to a ratio.
struct PlotAspectRatioScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = PlotAspectRatioViewModel()
    /// Read here and passed in, so the headline, the captions and the Audio Graphs write numbers
    /// the way the chart's own axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "A circle of radius 3, in two plots",
            message: summary.headline,
            explanation: """
            A plot area takes whatever shape the chart is given, so one unit across and one unit up are \
            usually different lengths, and a circle is drawn as an oval unless the plot happens to be square. aspectRatio(_:contentMode:) on the plot area, \
            inside chartPlotStyle, holds it to a ratio of width to height whatever the chart's frame. With the \
            same domain on both axes, a ratio of 1 makes the units equal and the circle round.
            """
        ) {
            PlotAspectRatioCharts(summary: summary) { width, height in
                viewModel.freePlotDidLayOut(width: width, height: height)
            }
        } controls: {
            ControlsSection {
                LabeledSlider(
                    title: "\(PlotAspectRatioWording.fixedPlot), width to height",
                    value: $viewModel.ratio,
                    range: PlotAspectRatioViewModel.ratioRange,
                    step: PlotAspectRatioViewModel.ratioStep,
                    valueText: summary.sliderValueText,
                    spokenValue: summary.sliderSpokenValue
                )
            }
        }
    }
}

/// The two plots side by side, each under a caption giving its ratio; one above the other at the accessibility
/// text sizes, where side by side the axis labels squeezed the free plot to a sliver.
struct PlotAspectRatioCharts: View {
    let summary: PlotAspectRatioSummary
    /// Called with the free plot's width and height whenever its layout changes.
    let onFreePlotLayout: (Double, Double) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Layout.sectionSpacing))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Layout.sectionSpacing))
    }

    var body: some View {
        layout {
            PlotAspectRatioCaptioned(caption: summary.freeCaption) {
                PlotAspectRatioFreeChart(summary: summary, onPlotLayout: onFreePlotLayout)
            }
            PlotAspectRatioCaptioned(caption: summary.fixedCaption) {
                PlotAspectRatioFixedChart(summary: summary)
            }
        }
    }
}

/// A chart with a short caption above it.
struct PlotAspectRatioCaptioned<Content: View>: View {
    let caption: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                // The ratio is in the element's value and the Audio Graph; the caption is not a stop of its own.
                .accessibilityHidden(true)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The circle, with the two axes through the origin. Shared by both plots.
struct PlotAspectRatioCircle: ChartContent {
    let label: String
    let value: String

    var body: some ChartContent {
        // snippet:plot-aspect-ratio-circle
        // Axis lines through the origin: decoration, so not a stop for VoiceOver.
        RuleMark(x: .value(PlotAspectRatioWording.x, 0))
            .foregroundStyle(Color.secondary)
            .accessibilityHidden(true)
        RuleMark(y: .value(PlotAspectRatioWording.y, 0))
            .foregroundStyle(Color.secondary)
            .accessibilityHidden(true)

        // A circle as a parametric curve; the label and value go on a Plot around it.
        let radius = PlotAspectRatioSummary.radius
        Plot {
            LinePlot(
                x: PlotAspectRatioWording.x, y: PlotAspectRatioWording.y, t: PlotAspectRatioWording.t,
                domain: 0 ... 2 * .pi
            ) { t in
                (x: radius * cos(t), y: radius * sin(t))
            }
        }
        .accessibilityLabel(label)
        .accessibilityValue(value)
        // end
    }
}

/// The circle in a plot that takes whatever shape the chart is given. It reports that shape,
/// read from the chart's own plot frame, as two plain numbers.
struct PlotAspectRatioFreeChart: View {
    let summary: PlotAspectRatioSummary
    let onPlotLayout: (Double, Double) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // snippet:plot-aspect-ratio-free
        Chart {
            PlotAspectRatioCircle(label: summary.freeCircleLabel, value: summary.freeCircleValue)
        }
        // The same domain on both axes: only the plot's shape decides how long a unit is.
        .chartXScale(domain: PlotAspectRatioSummary.domain)
        .chartYScale(domain: PlotAspectRatioSummary.domain)
        // end
        .plotAspectRatioAxes(PlotAspectRatioAxis.values(for: dynamicTypeSize))
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let size = geometry[plotFrame].size
                    Color.clear
                        .onChange(of: size, initial: true) {
                            onPlotLayout(size.width, size.height)
                        }
                }
            }
        }
        // The element's value changes with the plot's shape while the data does not.
        .id(summary.freeCircleValue)
        .accessibilityChartDescriptor(PlotAspectRatioDescriptor(
            title: summary.freeDescriptorTitle, summary: summary.freeDescriptorSummary, locale: summary.locale
        ))
    }
}

/// The circle in a plot held to the slider's ratio of width to height.
struct PlotAspectRatioFixedChart: View {
    let summary: PlotAspectRatioSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let ratio = summary.fixedRatio
        // snippet:plot-aspect-ratio-fixed
        Chart {
            PlotAspectRatioCircle(label: summary.fixedCircleLabel, value: summary.fixedCircleValue)
        }
        .chartXScale(domain: PlotAspectRatioSummary.domain)
        .chartYScale(domain: PlotAspectRatioSummary.domain)
        .chartPlotStyle { plotArea in
            // Width over height, whatever the chart's frame. At 1, with equal domains, the circle is round.
            plotArea.aspectRatio(ratio, contentMode: .fit)
        }
        // end
        .plotAspectRatioAxes(PlotAspectRatioAxis.values(for: dynamicTypeSize))
        // The element's value changes with the ratio while the data does not.
        .id(summary.fixedCircleValue)
        .accessibilityChartDescriptor(PlotAspectRatioDescriptor(
            title: summary.fixedDescriptorTitle, summary: summary.fixedDescriptorSummary, locale: summary.locale
        ))
    }
}

/// The values both axes mark. Each plot is about half the panel wide, so at the accessibility text
/// sizes the labels are thinned to the ends and the centre, or they run into each other.
nonisolated enum PlotAspectRatioAxis {
    static func values(for dynamicTypeSize: DynamicTypeSize) -> [Double] {
        dynamicTypeSize.isAccessibilitySize ? [-4, 0, 4] : [-4, -2, 0, 2, 4]
    }
}

extension View {
    /// Marks both axes at the same values, with the default grid line, tick and label at each.
    func plotAspectRatioAxes(_ values: [Double]) -> some View {
        chartXAxis { AxisMarks(values: values) }
            .chartYAxis { AxisMarks(values: values) }
    }
}

/// Words for this chart that `CafeWording` has no place for: it is a circle, not café data.
nonisolated enum PlotAspectRatioWording {
    static let x = "x"
    static let y = "y"
    static let t = "t"
    static let upperHalf = "Upper half"
    static let lowerHalf = "Lower half"
    static let freePlot = "Free plot"
    static let fixedPlot = "Fixed plot"
}

/// The circle for the Audio Graph. A circle is not a function of x, so it is described as its two
/// halves over the same x values, each a connected curve.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PlotAspectRatioDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let locale: Locale

    /// The x values the halves are sampled at, from one side of the circle to the other.
    static var sampleXs: [Double] {
        let radius = PlotAspectRatioSummary.radius
        return Array(stride(from: -radius, through: radius, by: 0.5))
    }

    /// The upper half's height at x; the lower half is its negative.
    static func upperY(atX x: Double) -> Double {
        let radius = PlotAspectRatioSummary.radius
        return max(0, radius * radius - x * x).squareRoot()
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let domain = PlotAspectRatioSummary.domain
        let describe: (Double) -> String = { value in
            value.isFinite ? value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale)) : ""
        }
        let xs = Self.sampleXs
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXNumericDataAxisDescriptor(
                title: PlotAspectRatioWording.x, range: domain, gridlinePositions: [], valueDescriptionProvider: describe
            ),
            yAxis: AXNumericDataAxisDescriptor(
                title: PlotAspectRatioWording.y, range: domain, gridlinePositions: [], valueDescriptionProvider: describe
            ),
            additionalAxes: [],
            series: [
                AXDataSeriesDescriptor(
                    name: PlotAspectRatioWording.upperHalf, isContinuous: true,
                    dataPoints: xs.map { AXDataPoint(x: $0, y: Self.upperY(atX: $0)) }
                ),
                AXDataSeriesDescriptor(
                    name: PlotAspectRatioWording.lowerHalf, isContinuous: true,
                    dataPoints: xs.map { AXDataPoint(x: $0, y: -Self.upperY(atX: $0)) }
                ),
            ]
        )
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "plot-area/plot-aspect-ratio") {
            PlotAspectRatioScreen(screen: screen)
        }
    }
}

#Preview("Wide fixed plot") {
    PlotAspectRatioCharts(
        summary: PlotAspectRatioSummary(fixedRatio: 2, freeRatio: 0.6, locale: .current)
    ) { _, _ in }
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
