import Accessibility
import Charts
import SwiftUI

/// "Plot frame and container frame": in a scrolling chart, the whole plot against its visible part.
struct PlotFramesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: PlotFramesViewModel
    /// Read here and passed in, so the headline, the bars' labels and the Audio Graph write
    /// numbers and dates the way the chart's axes do.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.harbourSales) {
        self.screen = screen
        _viewModel = State(initialValue: PlotFramesViewModel(days: days))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups a day at the \(CafeWording.harbour) café",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            PlotFramesChart(viewModel: viewModel, locale: locale)
        } controls: {
            PlotFramesControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.followsPlotFrame) {
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// Constants that belong to this chart's border.
private enum PlotFramesStyle {
    static let borderWidth: CGFloat = 2
}

/// A week of four in view, and a border around one of the proxy's two frames.
struct PlotFramesChart: View {
    let viewModel: PlotFramesViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The width the chart settled at. A scrolling chart laid out first at another width (the split view
    /// collapsing on iPhone) keeps its offset in points and opens part-scrolled, so it is rebuilt at its
    /// settled width (`interaction.md`, *Scrolling*).
    @State private var settledWidth: CGFloat = 0

    /// Fewer day labels as the text grows, so they do not collide.
    private var daysPerLabel: Int {
        if dynamicTypeSize >= .accessibility3 { return 7 }
        if dynamicTypeSize >= .xxLarge { return 2 }
        return 1
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        if !viewModel.hasMarks {
            ContentUnavailableView(
                "No cups sold",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one bar per day.")
            )
        } else {
            // snippet:plot-frame-and-container-frame-chart
            Chart(viewModel.days) { day in
                Plot {
                    BarMark(
                        x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                        y: .value(CafeWording.cups, day.cups)
                    )
                }
                .accessibilityLabel(summary.dayName(day.day))
                .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
            }
            // A week is in view; the rest of the plot is scrolled out of it.
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: viewModel.visibleSeconds)
            // It comes to rest on midnight, so whole days are in view; a swipe moves a week.
            .chartScrollTargetBehavior(.valueAligned(matching: DateComponents(hour: 0), majorAlignment: .page))
            // end
            // One value axis, the same in the representation and its descriptor.
            .chartYScale(domain: summary.valueDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.abbreviated).day(),
                        centered: daysPerLabel == 1
                    )
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if viewModel.followsPlotFrame {
                        // snippet:plot-frame-and-container-frame-plot-frame
                        // The whole plot, the days out of view included: the border moves as the chart scrolls.
                        if let frame = proxy.plotFrame {
                            Path(geometry[frame])
                                .stroke(.orange, lineWidth: PlotFramesStyle.borderWidth)
                                .allowsHitTesting(false)
                        }
                        // end
                    } else {
                        // snippet:plot-frame-and-container-frame-container-frame
                        // Only the visible part: the border stays put while the bars scroll beneath it.
                        if let frame = proxy.plotContainerFrame {
                            Path(geometry[frame])
                                .stroke(.orange, lineWidth: PlotFramesStyle.borderWidth)
                                .allowsHitTesting(false)
                        }
                        // end
                    }
                    PlotFramesReporter(
                        measurement: PlotFramesMeasurement(
                            plot: proxy.plotFrame.map { geometry[$0] },
                            container: proxy.plotContainerFrame.map { geometry[$0] }
                        ),
                        record: viewModel.record
                    )
                }
                // The overlay is not clipped: the plot frame's rectangle runs beyond the chart, and its
                // border would be drawn across the screen. Keep it within the chart.
                .clipped()
                // The border is decoration over the bars: it carries no data.
                .accessibilityHidden(true)
            }
            // A scrolling chart ignores a descriptor set on it: the Audio Graph got the default ("Chart", dates
            // as seconds, read on iOS). Assistive technologies get this chart in its place: every day at once, the
            // same scale, and the descriptor inside, where it is kept.
            .accessibilityRepresentation {
                Chart(viewModel.days) { day in
                    Plot {
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                    }
                    .accessibilityLabel(summary.dayName(day.day))
                    .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                }
                .chartYScale(domain: summary.valueDomain)
                .accessibilityChartDescriptor(PlotFramesChartDescriptor(days: viewModel.days, summary: summary))
            }
            .id(settledWidth)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { settledWidth = $0 }
        }
    }
}

/// Hands the frames, as plain rectangles, to the view model whenever they change.
private struct PlotFramesReporter: View {
    let measurement: PlotFramesMeasurement
    let record: (PlotFramesMeasurement) -> Void

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onChange(of: measurement, initial: true) { _, new in
                record(new)
            }
    }
}

/// The toggle, and both frames as last measured, so the moving one can be seen to move.
struct PlotFramesControls: View {
    @Bindable var viewModel: PlotFramesViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        ControlsSection {
            Toggle("Border on the whole plot (plotFrame)", isOn: $viewModel.followsPlotFrame)
                // With no bars the placeholder has no plot to draw a border on.
                .disabled(!viewModel.hasMarks)
            LabeledContent(
                "plotFrame",
                value: PlotFramesViewModel.readout(viewModel.measurement?.plot, locale: locale)
            )
            LabeledContent(
                "plotContainerFrame",
                value: PlotFramesViewModel.readout(viewModel.measurement?.container, locale: locale)
            )
            Text("Positions are in the chart's own coordinates.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// The chart for the Audio Graph: every day, written out in the data's time zone, with its cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PlotFramesChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let summary: PlotFramesSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let names = days.map { summary.dayName($0.day) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: zip(names, days).map { AXDataPoint(x: $0, y: Double($1.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups a day at the \(CafeWording.harbour) café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Four weeks") {
    NavigationStack {
        if let screen = Catalog.screen(id: "plot-area/plot-frame-and-container-frame") {
            PlotFramesScreen(screen: screen)
        }
    }
}

#Preview("Five days") {
    PlotFramesChart(
        viewModel: PlotFramesViewModel(days: Array(CafeData.harbourSales.prefix(5))), locale: .current
    )
    .frame(height: Layout.chartHeightCompact)
    .padding(Layout.screenPadding)
}
