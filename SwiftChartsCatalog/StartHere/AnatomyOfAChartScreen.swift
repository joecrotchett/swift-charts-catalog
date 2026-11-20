import Accessibility
import Charts
import SwiftUI

/// "Anatomy of a chart": marks, scales, axes, legend and plot area, each made to stand out on one chart.
struct AnatomyOfAChartScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = AnatomyOfAChartViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: viewModel.headline,
            explanation: """
            A chart is built from four kinds of block: marks, the shapes that stand for the data; scales, which turn \
            values into positions and colours; and the axes and the legend, which explain the scales. You write the \
            marks and the framework generates the rest. The axes, the legend and the plot area the marks are drawn in \
            each have modifiers that customise them.
            """,
            snippets: viewModel.snippets
        ) {
            AnatomyChart(orders: viewModel.orders, look: viewModel.look)
        } controls: {
            AnatomyControls(viewModel: viewModel)
        }
        // The change is animated, which not everyone sees: say it too.
        .onChange(of: viewModel.highlight) {
            AccessibilityNotification.Announcement(viewModel.announcement).post()
        }
    }
}

/// The picker for the part to highlight, and a sentence on the part chosen.
struct AnatomyControls: View {
    @Bindable var viewModel: AnatomyOfAChartViewModel

    var body: some View {
        ControlsSection {
            // The data stays the same and only its styling changes, so the change is animated.
            LabeledMenuPicker(title: "Highlight", selection: $viewModel.highlight.animation(.easeInOut)) {
                Text("None").tag(ChartPart?.none)
                ForEach(ChartPart.allCases) { part in
                    Text(part.title).tag(ChartPart?.some(part))
                }
            }
            Text(viewModel.highlightSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Stacked bars of cups per drink, split by size, or a placeholder when nothing has been sold.
struct AnatomyChart: View {
    let orders: [DrinkOrder]
    var look = AnatomyLook(highlight: nil)
    /// The height the note on the scales is expected to need, growing with the text, until it has been measured.
    @ScaledMetric(relativeTo: .caption) private var expectedNoteHeight = AnatomyMetrics.scaleNoteHeight
    /// The note's height as laid out: more than expected when large text wraps its lines.
    @State private var measuredNoteHeight: CGFloat = 0

    /// The room kept free at the top of the plot area while the note is shown.
    private var scaleNoteRoom: CGFloat {
        look.showsScaleNote ? max(expectedNoteHeight, measuredNoteHeight) : 0
    }

    private var summary: AnatomySummary {
        AnatomySummary(orders: orders)
    }

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no bars under a headline that is not true.
        if summary.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink, split by size.")
            )
        } else {
            Chart(orders) { order in
                // Each segment is one element for VoiceOver: "Latte, Small, 34 cups".
                Plot {
                    // snippet:anatomy-of-a-chart-marks
                    BarMark(
                        x: .value("Drink", order.drink),
                        y: .value("Cups", order.cups)
                    )
                    .foregroundStyle(by: .value("Size", order.size))
                    // A strip of space between the segments, so they differ by more than colour.
                    .clipShape(Rectangle().inset(by: AnatomyMetrics.segmentGap))
                    // end
                    .opacity(look.marksOpacity)
                }
                .accessibilityLabel("\(order.drink), \(order.size)")
                .accessibilityValue(Text("^[\(order.cups) cup](inflect: true)"))
            }
            // snippet:anatomy-of-a-chart-scales
            // Every size the colour scale has, in the order of the data: the order of the stack and the legend.
            .chartForegroundStyleScale(domain: summary.sizes, mapping: CafeSizeStyle.colour(for:))
            // The y scale's range is the height of the plot area, less the room kept free at the top for the note.
            .chartYScale(range: .plotDimension(endPadding: scaleNoteRoom))
            // end
            // snippet:anatomy-of-a-chart-axes
            .chartXAxis { axisMarks }
            .chartYAxis { axisMarks }
            // end
            // snippet:anatomy-of-a-chart-legend
            // Below the chart at the leading edge is the default, written out: this is where a legend is moved.
            .chartLegend(position: .bottom, alignment: .leading)
            // end
            // snippet:anatomy-of-a-chart-plot-area
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color.accentColor.opacity(look.styledPlotArea ? AnatomyMetrics.plotTintOpacity : 0))
                    .border(Color.accentColor.opacity(look.styledPlotArea ? 1 : 0), width: AnatomyMetrics.plotBorderWidth)
            }
            // end
            // snippet:anatomy-of-a-chart-scale-note
            .chartOverlay(alignment: .topLeading) { proxy in
                if look.showsScaleNote {
                    // The scales the framework made from the plotted values, as the chart reports them.
                    ScaleNote(
                        drinks: proxy.xDomain(dataType: String.self),
                        cups: proxy.yDomain(dataType: Int.self),
                        sizes: proxy.foregroundStyleDomain(dataType: String.self)
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredNoteHeight = $0 }
                }
            }
            // end
            .accessibilityChartDescriptor(AnatomyChartDescriptor(orders: orders))
        }
    }

    // snippet:anatomy-of-a-chart-axis-marks
    /// What each axis draws at its values. The test is inside the axis, so it stays one chart.
    @AxisContentBuilder
    private var axisMarks: some AxisContent {
        if look.axes == .emphasised {
            let stroke = StrokeStyle(lineWidth: AnatomyMetrics.emphasisedAxisLineWidth)
            AxisMarks { _ in
                AxisGridLine(stroke: stroke).foregroundStyle(Color.primary)
                AxisTick(stroke: stroke).foregroundStyle(Color.primary)
                AxisValueLabel().foregroundStyle(Color.primary)
            }
        } else if look.axes == .muted {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(AnatomyMetrics.mutedGridLineOpacity))
                AxisTick().foregroundStyle(Color.secondary.opacity(AnatomyMetrics.mutedGridLineOpacity))
                AxisValueLabel().foregroundStyle(Color.secondary.opacity(AnatomyMetrics.mutedLabelOpacity))
            }
        } else {
            // With no arguments, the axis the framework would have drawn anyway.
            AxisMarks()
        }
    }
    // end
}

/// The three scales of the chart in words, drawn over the plot while the scales are highlighted.
struct ScaleNote: View {
    let drinks: [String]
    let cups: [Int]
    let sizes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("Drink, along x: \(drinks.formatted(.list(type: .and)))")
            if let lowest = cups.min(), let highest = cups.max() {
                Text("Cups, up y: \(lowest.formatted()) to \(highest.formatted())")
            }
            Text("Size, as colour: \(sizes.formatted(.list(type: .and)))")
        }
        .font(.caption)
        .padding(Layout.tightSpacing)
        .background(.regularMaterial, in: .rect(cornerRadius: Layout.badgeCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

/// The chart for the Audio Graph: a title, a summary, named axes, a series per size, and values with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct AnatomyChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [DrinkOrder]

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = AnatomySummary(orders: orders)
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: summary.drinks)
        // The range is the drawn axis, not the tallest stack: 0 to 200 for a stack of 164.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in AnatomySummary.spokenCups(count) } }
        // One series per size; each point is that segment's own cups, not its height in the stack.
        let series = summary.sizes.map { size in
            AXDataSeriesDescriptor(
                name: size,
                isContinuous: false,
                dataPoints: orders.filter { $0.size == size }.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold today, by drink and size",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Anatomy") {
    NavigationStack {
        if let screen = Catalog.screen(id: "start-here/anatomy-of-a-chart") {
            AnatomyOfAChartScreen(screen: screen)
        }
    }
}

#Preview("Each part") {
    ScrollView {
        ForEach(ChartPart.allCases) { part in
            ChartPanel {
                AnatomyChart(orders: CafeData.drinkOrders, look: AnatomyLook(highlight: part))
            }
        }
        .padding()
    }
}

#Preview("No sales") {
    AnatomyChart(orders: [])
}
