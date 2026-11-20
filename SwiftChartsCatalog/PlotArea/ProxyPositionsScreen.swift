import Accessibility
import Charts
import SwiftUI

/// "Chart proxy": converting between positions on screen and values in the data, both ways.
struct ProxyPositionsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ProxyPositionsViewModel
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales) {
        self.screen = screen
        _viewModel = State(initialValue: ProxyPositionsViewModel(sales: sales))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: viewModel.summary(locale: locale).headline,
            explanation: viewModel.explanation(isRightToLeft: layoutDirection == .rightToLeft),
            snippets: viewModel.snippets
        ) {
            ProxyPositionsChart(viewModel: viewModel, locale: locale)
        } controls: {
            ProxyPositionsControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The value axis's edge, and the switch that leaves out the plot area's origin.
struct ProxyPositionsControls: View {
    @Bindable var viewModel: ProxyPositionsViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            Text("Drag across the chart to read the band and the height under your finger.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledSegmentedPicker(title: "Value axis", selection: $viewModel.axisEdge) {
                ForEach(ProxyPositionsAxisEdge.allCases) { edge in
                    Text(edge.rawValue).tag(edge)
                }
            }
            MistakeToggle(title: "Leave out the plot's origin", isShowingMistake: $viewModel.isShowingMistake)
        }
        .onChange(of: viewModel.axisEdge) {
            viewModel.axisEdgeChanged()
        }
        .onChange(of: viewModel.isShowingMistake) {
            if let message = viewModel.mistakeChanged(locale: locale) {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }
}

/// Constants that belong to this chart's own marks and overlay.
private enum ProxyPositionsMetrics {
    /// The bars not under the pointer while a drag is on the plot.
    static let fadedOpacity = 0.3
    static let readoutPadding: CGFloat = 4
    static let readoutCornerRadius: CGFloat = 4
    static let readoutOpacity = 0.9
}

/// One bar per drink, a star over the best seller placed through the proxy, and a live reading of the
/// drink and cups under the pointer. A placeholder when nothing has been sold.
struct ProxyPositionsChart: View {
    let viewModel: ProxyPositionsViewModel
    let locale: Locale
    /// How far above the bar's top the star's centre sits. It grows with the star, which is body text.
    @ScaledMetric(relativeTo: .body) private var starLift: CGFloat = 14
    /// Half the star's height, which is body text: the star's centre comes no closer than this to the plot's
    /// top, so at the largest text sizes it stays inside the plot instead of rising out of the panel.
    @ScaledMetric(relativeTo: .body) private var starRadius: CGFloat = 9
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        if summary.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            Chart {
                ForEach(viewModel.sales) { item in
                    Plot {
                        BarMark(
                            x: .value(CafeWording.drink, item.drink),
                            y: .value(CafeWording.cupsAxisTitle, item.cups)
                        )
                    }
                    .opacity(viewModel.reading == nil || viewModel.reading?.drink == item.drink ? 1 : ProxyPositionsMetrics.fadedOpacity)
                    .accessibilityLabel(item.drink)
                    .accessibilityValue(barValue(item, bestCups: summary.bestSellers.first?.cups))
                }
                if let reading = viewModel.reading, let readout = viewModel.readout(locale: locale) {
                    // The height under the pointer, drawn as a mark so the chart places it. It only
                    // repeats what the bars say, so it is hidden from assistive technologies.
                    RuleMark(y: .value(CafeWording.cupsAxisTitle, reading.cups))
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                        .annotation(
                            position: .top,
                            overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                        ) {
                            Text(readout)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(ProxyPositionsMetrics.readoutPadding)
                                .background(Color(.systemBackground).opacity(ProxyPositionsMetrics.readoutOpacity), in: .rect(cornerRadius: ProxyPositionsMetrics.readoutCornerRadius))
                        }
                }
            }
            // One value axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartYScale(domain: summary.valueDomain)
            // snippet:chart-proxy-axis
            .chartYAxis {
                // On the leading edge the axis labels push the plot area away from the overlay's corner.
                AxisMarks(position: viewModel.axisEdge.markPosition)
            }
            // end
            // snippet:chart-proxy-overlay
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotAnchor = proxy.plotFrame {
                        let plotFrame = geometry[plotAnchor]
                        let mapping = ProxyPositionsMapping(
                            plotFrame: plotFrame,
                            overlayWidth: geometry.size.width,
                            isRightToLeft: layoutDirection == .rightToLeft,
                            ignoresOrigin: viewModel.isShowingMistake
                        )
                        // Value to position: a drink's band and a number of cups, in plot coordinates.
                        ForEach(summary.bestSellers) { best in
                            if let band = proxy.positionRange(forX: best.drink), let top = proxy.position(forY: best.cups) {
                                let plotPoint = CGPoint(x: ProxyPositionsMapping.centre(of: band), y: max(top - starLift, starRadius))
                                Image(systemName: "star.fill")
                                    .font(.body)
                                    .foregroundStyle(.yellow)
                                    .position(mapping.overlayPoint(forPlot: plotPoint))
                                    // The bar's own value says it sold the most.
                                    .accessibilityHidden(true)
                            }
                        }
                        // Position to value: a touch, moved into plot coordinates, then converted.
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { drag in
                                        let point = mapping.plotPoint(forOverlay: drag.location)
                                        guard mapping.contains(plotPoint: point),
                                              let drink = proxy.value(atX: point.x, as: String.self),
                                              let cups = proxy.value(atY: point.y, as: Double.self)
                                        else {
                                            viewModel.reading = nil
                                            return
                                        }
                                        viewModel.reading = ProxyPositionsReading(drink: drink, cups: cups)
                                    }
                                    .onEnded { _ in viewModel.reading = nil }
                            )
                            .accessibilityHidden(true)
                            .onChange(of: mapping, initial: true) {
                                if let message = viewModel.updatePlotFrame(
                                    mapping.plotFrame,
                                    overlayWidth: mapping.overlayWidth,
                                    isRightToLeft: mapping.isRightToLeft,
                                    locale: locale
                                ) {
                                    AccessibilityNotification.Announcement(message).post()
                                }
                            }
                    }
                }
            }
            // end
            .accessibilityChartDescriptor(ProxyPositionsChartDescriptor(summary: summary))
        }
    }

    /// "164 cups, the most" for a best seller, "128 cups" for the rest.
    private func barValue(_ item: DrinkSales, bestCups: Int?) -> String {
        let cups = CafeWording.cups(item.cups, locale: locale)
        return item.cups == bestCups ? "\(cups), the most, marked with a star" : cups
    }
}

/// The chart for the Audio Graph: a title, a summary in actual values, and cups said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ProxyPositionsChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ProxyPositionsSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let sales = summary.sales
        return AXChartDescriptor(
            title: "Cups sold today at the \(CafeWording.harbour) café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: sales.map(\.drink)),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle,
                range: summary.valueDomain,
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: false,
                dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )]
        )
    }
}

#Preview("Chart proxy") {
    NavigationStack {
        if let screen = Catalog.screen(id: "plot-area/chart-proxy") {
            ProxyPositionsScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    ProxyPositionsChart(viewModel: ProxyPositionsViewModel(sales: []), locale: .current)
}
