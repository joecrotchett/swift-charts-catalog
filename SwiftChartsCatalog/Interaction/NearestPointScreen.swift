import Accessibility
import Charts
import SwiftUI

/// "Select the nearest point": x and y selection together on a scatter plot, accepting a point
/// only when it is close enough to the finger.
struct NearestPointScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: NearestPointViewModel
    /// The locale the screen's words are written in, read here and passed in.
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(screen: CatalogScreen, orders: [OrderWait] = CafeData.orderWaits) {
        self.screen = screen
        _viewModel = State(initialValue: NearestPointViewModel(orders: orders))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Waits against the queue, by café",
            message: viewModel.summary(locale: locale).headline,
            reservedMessage: viewModel.reservedHeadline(locale: locale),
            explanation: """
            chartXSelection and chartYSelection on the same chart report the finger's position in data values \
            on both axes. The two axes have different units, so the view model measures each order's distance \
            from the finger in points on screen, and accepts the nearest only inside the acceptance radius: \
            touching empty space, or outside the plot, selects nothing. The ring shows the radius while you touch.
            """ + (dynamicTypeSize.isAccessibilitySize
                ? " At this text size the label beside the selected point is left out; the headline above names the order."
                : "")
        ) {
            NearestPointChart(viewModel: viewModel, locale: locale)
        } controls: {
            NearestPointControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The scatter plot, the finger's reach and the accepted order, or a placeholder with no orders.
struct NearestPointChart: View {
    @Bindable var viewModel: NearestPointViewModel
    let locale: Locale
    /// At the accessibility text sizes the label beside the point no longer fits the plot; the headline names the order.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if viewModel.orders.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "person.3",
                description: Text("Each order appears here as a point: the queue it met and how long it waited.")
            )
        } else {
            let summary = viewModel.summary(locale: locale)
            // snippet:select-the-nearest-point-chart
            Chart {
                ForEach(viewModel.orders) { order in
                    Plot {
                        PointMark(
                            x: .value(CafeWording.queueAxisTitle, Double(order.queueLength)),
                            y: .value(CafeWording.waitAxisTitle, Double(order.waitSeconds))
                        )
                        .foregroundStyle(by: .value(CafeWording.store, order.store))
                        .symbol(by: .value(CafeWording.store, order.store))
                    }
                    .accessibilityLabel(summary.context(order))
                    .accessibilityValue(CafeWording.seconds(order.waitSeconds, locale: locale))
                }
                // The finger's reach: a ring of the acceptance radius around the selected position.
                if let queue = viewModel.selectedQueue, let wait = viewModel.selectedWait {
                    PointMark(
                        x: .value(CafeWording.queueAxisTitle, queue),
                        y: .value(CafeWording.waitAxisTitle, wait)
                    )
                    .symbol(.circle.strokeBorder(lineWidth: NearestPointMarks.reachLineWidth))
                    .symbolSize(CGSize(width: viewModel.radius * 2, height: viewModel.radius * 2))
                    .foregroundStyle(Color.gray)
                    .accessibilityHidden(true)
                }
                // The accepted order, ringed. It repeats a point that is already described.
                if let accepted = viewModel.accepted {
                    PointMark(
                        x: .value(CafeWording.queueAxisTitle, Double(accepted.queueLength)),
                        y: .value(CafeWording.waitAxisTitle, Double(accepted.waitSeconds))
                    )
                    .symbol(.circle.strokeBorder(lineWidth: NearestPointMarks.highlightLineWidth))
                    .symbolSize(NearestPointMarks.highlightSize)
                    .foregroundStyle(Color.primary)
                    .accessibilityHidden(true)
                    .annotation(
                        position: .top,
                        // Inside the plot, so the label never covers the axis titles outside it.
                        overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))
                    ) {
                        if let label = summary.annotation, !dynamicTypeSize.isAccessibilitySize {
                            NearestPointLabel(text: label)
                        }
                    }
                }
            }
            .chartXSelection(value: $viewModel.selectedQueue)
            .chartYSelection(value: $viewModel.selectedWait)
            // end
            // The same colour and shape for each café whichever order the data lists them in.
            .chartForegroundStyleScale(domain: NearestPointViewModel.stores, mapping: CafeSeriesStyle.colour(for:))
            .chartSymbolScale(domain: NearestPointViewModel.stores, mapping: CafeSeriesStyle.symbol(for:))
            .chartXScale(domain: NearestPointViewModel.queueDomain)
            .chartYScale(domain: NearestPointViewModel.waitDomain)
            .chartXAxisLabel(CafeWording.queueAxisTitle)
            .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
            .chartBackground { proxy in
                NearestPointScaleReader(proxy: proxy, viewModel: viewModel)
            }
            .accessibilityChartDescriptor(NearestPointChartDescriptor(orders: viewModel.orders, locale: locale))
        }
    }
}

/// The label beside the accepted order, on a solid background so marks behind it do not show through.
struct NearestPointLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(NearestPointMarks.labelPadding)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: NearestPointMarks.labelCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: NearestPointMarks.labelCornerRadius)
                    .stroke(Color.gray, lineWidth: NearestPointMarks.reachLineWidth)
            }
    }
}

/// Reads how many points one unit of each axis spans, after layout and whenever the plot is resized,
/// and hands the view model the two numbers. The view model never sees the proxy.
struct NearestPointScaleReader: View {
    let proxy: ChartProxy
    let viewModel: NearestPointViewModel

    var body: some View {
        GeometryReader { geometry in
            let plotSize = proxy.plotFrame.map { geometry[$0].size } ?? .zero
            Color.clear
                .onChange(of: plotSize, initial: true) {
                    viewModel.screenScale = scale(plotSize: plotSize)
                }
        }
    }

    private func scale(plotSize: CGSize) -> NearestPointScreenScale? {
        let queues = NearestPointViewModel.queueDomain
        let waits = NearestPointViewModel.waitDomain
        guard plotSize.width > 0, plotSize.height > 0,
              let left = proxy.position(forX: queues.lowerBound),
              let right = proxy.position(forX: queues.upperBound),
              let bottom = proxy.position(forY: waits.lowerBound),
              let top = proxy.position(forY: waits.upperBound) else { return nil }
        return NearestPointScreenScale(
            pointsPerPerson: abs(Double(right - left)) / (queues.upperBound - queues.lowerBound),
            pointsPerSecond: abs(Double(bottom - top)) / (waits.upperBound - waits.lowerBound)
        )
    }
}

/// The acceptance radius.
struct NearestPointControls: View {
    @Bindable var viewModel: NearestPointViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSlider(
                title: "Acceptance radius",
                value: $viewModel.radius,
                range: NearestPointViewModel.radiusRange,
                step: NearestPointViewModel.radiusStep,
                valueText: CafeWording.points(viewModel.radius, locale: locale)
            )
            .disabled(viewModel.orders.isEmpty)
        }
    }
}

/// Sizes that belong to this chart's marks.
private enum NearestPointMarks {
    static let reachLineWidth: CGFloat = 1
    static let highlightLineWidth: CGFloat = 2
    /// Area in square points: a ring clearly larger than a data point.
    static let highlightSize: CGFloat = 220
    static let labelPadding: CGFloat = 4
    static let labelCornerRadius: CGFloat = 4
}

/// The chart for the Audio Graph: both axes numeric, one series per café, values said with their unit.
nonisolated struct NearestPointChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [OrderWait]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = NearestPointSummary(orders: orders, isSelecting: false, accepted: nil, radius: 0, locale: locale)
        let locale = locale
        let xAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.queueAxisTitle,
            range: NearestPointViewModel.queueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) { CafeWording.people($0, locale: $1) } }
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.waitAxisTitle,
            range: NearestPointViewModel.waitDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) { CafeWording.seconds($0, locale: $1) } }
        let stores = NearestPointViewModel.stores
        let series = stores.map { store in
            AXDataSeriesDescriptor(
                name: store,
                isContinuous: false,
                dataPoints: orders.filter { $0.store == store }.map {
                    AXDataPoint(x: Double($0.queueLength), y: Double($0.waitSeconds))
                }
            )
        }
        return AXChartDescriptor(
            title: "Wait against the queue at the \(CafeWording.list(stores)) cafés",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Orders") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/select-the-nearest-point") {
            NearestPointScreen(screen: screen)
        }
    }
}

#Preview("Label") {
    NearestPointLabel(text: "Station: 309 seconds")
        .padding()
}

#Preview("No orders") {
    NearestPointChart(viewModel: NearestPointViewModel(orders: []), locale: .current)
}
