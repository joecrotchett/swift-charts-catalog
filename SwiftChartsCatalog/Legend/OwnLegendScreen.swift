import Accessibility
import Charts
import SwiftUI

/// "A legend of your own": the automatic legend hidden, and one drawn by the app from the chart's own
/// colour scale through `ChartProxy`.
struct OwnLegendScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = OwnLegendViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: viewModel.headline(locale: locale),
            // The same test the chart uses to place its legend, so the words say where it is.
            explanation: viewModel.explanation(isBesideBars: !dynamicTypeSize.isAccessibilitySize),
            snippets: viewModel.snippets
        ) {
            OwnLegendChart(viewModel: viewModel, locale: locale)
        } controls: {
            OwnLegendControls(viewModel: viewModel)
        }
        // The headline changes with the legend, so the change is said aloud as well as drawn.
        .onChange(of: viewModel.isShowingOwnLegend) {
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The one control: which legend the chart has.
struct OwnLegendControls: View {
    @Bindable var viewModel: OwnLegendViewModel

    var body: some View {
        ControlsSection {
            Toggle("Draw your own legend", isOn: $viewModel.isShowingOwnLegend)
                // With nothing sold there is no chart, so neither legend is drawn.
                .disabled(!viewModel.hasCups)
        }
    }
}

/// Sizes that belong to this chart's marks alone.
private enum OwnLegendMetrics {
    /// The strip of empty space between neighbouring segments of a bar.
    static let segmentGap: CGFloat = 1
    static let swatchSide: CGFloat = 10
    static let swatchCornerRadius: CGFloat = 2
}

/// Stacked bars of cups by drink, coloured by size, with either legend.
struct OwnLegendChart: View {
    let viewModel: OwnLegendViewModel
    let locale: Locale
    /// The size of the app's legend, measured after layout: the scale leaves that much room at its end.
    @State private var legendSize = CGSize.zero
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        if viewModel.hasCups {
            chart
        } else {
            ContentUnavailableView(
                "No cups sold yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink, split by size.")
            )
        }
    }

    private var chart: some View {
        // snippet:a-legend-of-your-own-chart
        let showsOwnLegend = viewModel.isShowingOwnLegend
        let orders = viewModel.orders
        let locale = locale
        let isRightToLeft = layoutDirection == .rightToLeft
        // Beside the bars at most text sizes; above them at the accessibility sizes, where a column
        // that wide would leave the bars no room.
        let isBesideBars = !dynamicTypeSize.isAccessibilitySize
        let xRoom = showsOwnLegend && isBesideBars ? legendSize.width + Layout.itemSpacing : 0
        let yRoom = showsOwnLegend && !isBesideBars ? legendSize.height + Layout.itemSpacing : 0
        return Chart(orders) { order in
            Plot {
                BarMark(
                    x: .value(CafeWording.drink, order.drink),
                    y: .value(CafeWording.cupsAxisTitle, order.cups)
                )
                .foregroundStyle(by: .value(CafeWording.size, order.size))
                .clipShape(Rectangle().inset(by: OwnLegendMetrics.segmentGap))
            }
            .accessibilityLabel("\(order.drink), \(order.size.rawValue)")
            .accessibilityValue(CafeWording.cups(order.cups, locale: locale))
        }
        // A fixed domain: each size keeps its colour (the app's size colours), and both legends list all three.
        .chartForegroundStyleScale(domain: OwnLegendSize.allCases) { CafeSizeStyle.colour(for: $0.rawValue) }
        // One chain, given a Visibility: the automatic legend is hidden while the app draws its own.
        .chartLegend(showsOwnLegend ? .hidden : .automatic)
        // Room at the end of a scale, so no bar runs under the app's legend.
        .chartXScale(range: .plotDimension(endPadding: xRoom))
        // One value axis for the chart and its descriptor (the tallest stack, rounded up to the axis step).
        .chartYScale(domain: viewModel.valueDomain, range: .plotDimension(endPadding: yRoom))
        // The descriptor goes on the chart before the overlay that draws the legend, so it is not handed to the
        // legend's element as well (with it after, the Audio Graph was offered on both).
        .accessibilityChartDescriptor(OwnLegendChartDescriptor(viewModel: viewModel, locale: locale))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                // The proxy's frames are anchors: resolve the plot's, and place the legend against it.
                if showsOwnLegend, let plotFrame = proxy.plotFrame {
                    let plot = geometry[plotFrame]
                    // In a right-to-left layout the resolved frame and `position` measure x from
                    // opposite edges (seen on the iOS simulator), so the centre is mirrored.
                    let centreX = isRightToLeft ? geometry.size.width - plot.midX : plot.midX
                    OwnLegendKey(proxy: proxy, viewModel: viewModel, locale: locale)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { legendSize = $0 }
                        .frame(width: plot.width, height: plot.height, alignment: .topTrailing)
                        .position(x: centreX, y: plot.midY)
                }
            }
        }
        // end
    }
}

/// The app's legend: every value of the chart's colour scale, in the colour the chart gave it, listed
/// top to bottom in the order the segments stack, with that size's cups beside its name.
struct OwnLegendKey: View {
    let proxy: ChartProxy
    let viewModel: OwnLegendViewModel
    let locale: Locale
    @ScaledMetric(relativeTo: .caption) private var swatchSide = OwnLegendMetrics.swatchSide

    var body: some View {
        // snippet:a-legend-of-your-own-key
        // The scale's own values, reversed: the bottom segment's size goes at the bottom of the legend.
        let sizes = Array(proxy.foregroundStyleDomain(dataType: OwnLegendSize.self).reversed())
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            ForEach(sizes, id: \.self) { size in
                Label {
                    VStack(alignment: .leading) {
                        Text(size.rawValue)
                        Text(CafeWording.cups(viewModel.total(for: size), locale: locale))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } icon: {
                    // The colour the chart assigned to this value, so the swatch always matches the marks.
                    RoundedRectangle(cornerRadius: OwnLegendMetrics.swatchCornerRadius)
                        .fill(proxy.foregroundStyle(for: size) ?? AnyShapeStyle(Color.gray))
                        .frame(width: swatchSide, height: swatchSide)
                }
            }
        }
        // A chartOverlay view is an accessibility element, unlike the automatic legend: one stop for all of it.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend")
        .accessibilityValue(viewModel.legendSpokenValue(sizes: sizes, locale: locale))
        // end
        .fixedSize()
        .padding(.horizontal, Layout.tightSpacing)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

/// The chart for the Audio Graph: drinks on x, one series per size, each point that segment's own cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct OwnLegendChartDescriptor: AXChartDescriptorRepresentable {
    let drinks: [String]
    let orders: [OwnLegendOrder]
    let sizes: [OwnLegendSize]
    let tallestBar: Int
    let summary: String
    let locale: Locale

    @MainActor
    init(viewModel: OwnLegendViewModel, locale: Locale) {
        drinks = viewModel.drinks
        orders = viewModel.orders
        sizes = viewModel.sizes
        tallestBar = viewModel.tallestBar
        summary = viewModel.audioGraphSummary(locale: locale)
        self.locale = locale
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: drinks)
        // The bars stack from zero to the tallest bar's total, on an axis rounded up to the step.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: ChartAxis.valueDomain(for: [tallestBar]),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = sizes.map { size in
            AXDataSeriesDescriptor(
                name: size.rawValue,
                isContinuous: false,
                dataPoints: orders.filter { $0.size == size }.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold today, by drink and size",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Own legend") {
    NavigationStack {
        if let screen = Catalog.screen(id: "legend/a-legend-of-your-own") {
            OwnLegendScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    OwnLegendChart(viewModel: OwnLegendViewModel(orders: []), locale: .current)
}
