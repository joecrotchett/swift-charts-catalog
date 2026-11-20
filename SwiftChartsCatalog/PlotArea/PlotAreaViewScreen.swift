import Accessibility
import Charts
import SwiftUI

/// "A view in the plot area": `chartBackground` with `plotFrame`, text centred in a donut's hole,
/// and the same view drawn in front of the marks with `chartOverlay`.
struct PlotAreaViewScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: PlotAreaViewViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales) {
        self.screen = screen
        _viewModel = State(initialValue: PlotAreaViewViewModel(sales: sales))
    }

    /// At the accessibility text sizes the label no longer fits in the hole, so it is left out.
    private var isLabelShown: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: summary.headline,
            explanation: viewModel.explanation(isLabelShown: isLabelShown),
            snippets: viewModel.snippets
        ) {
            PlotAreaViewChart(summary: summary, placement: viewModel.placement, isLabelShown: isLabelShown)
        } controls: {
            ControlsSection {
                LabeledSegmentedPicker(title: "Place the label with", selection: $viewModel.placement) {
                    ForEach(PlotAreaViewPlacement.allCases) { placement in
                        Text(placement.modifierName).tag(placement)
                    }
                }
            }
        }
    }
}

/// The donut with its label behind or in front of the sectors, or a placeholder when nothing sold.
struct PlotAreaViewChart: View {
    let summary: PlotAreaViewSummary
    let placement: PlotAreaViewPlacement
    let isLabelShown: Bool

    var body: some View {
        if summary.shares.isEmpty {
            // Sectors of zero draw nothing: a placeholder, not an empty ring under a headline.
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one sector per drink.")
            )
        } else {
            PlotAreaViewPlacedChart(summary: summary, placement: placement, isLabelShown: isLabelShown)
                .accessibilityChartDescriptor(PlotAreaViewChartDescriptor(summary: summary))
        }
    }

    /// The ring with the label attached by the modifier the picker chose.
    struct PlotAreaViewPlacedChart: View {
        let summary: PlotAreaViewSummary
        let placement: PlotAreaViewPlacement
        let isLabelShown: Bool

        var body: some View {
            switch placement {
            case .background:
                // snippet:a-view-in-the-plot-area-background
                PlotAreaViewRing(summary: summary)
                    // Behind the marks. The view is laid out over the whole chart, legend included.
                    // VoiceOver still reads a background's text, so a label drawn behind is hidden.
                    .chartBackground { proxy in
                        PlotAreaViewHoleLabel(proxy: proxy, summary: summary, isLabelShown: isLabelShown)
                            .accessibilityHidden(true)
                    }
            // end
            case .overlay:
                // snippet:a-view-in-the-plot-area-overlay
                PlotAreaViewRing(summary: summary)
                    // In front of the marks: the same view now covers what lies under it,
                    // and its text is read by VoiceOver.
                    .chartOverlay { proxy in
                        PlotAreaViewHoleLabel(proxy: proxy, summary: summary, isLabelShown: isLabelShown)
                    }
                // end
            }
        }
    }
}

/// The donut itself, the best seller at full strength. Donuts are the subject of the Sector screen.
struct PlotAreaViewRing: View {
    let summary: PlotAreaViewSummary

    var body: some View {
        Chart(summary.shares) { share in
            Plot {
                SectorMark(
                    angle: .value(CafeWording.cups, share.cups),
                    innerRadius: .ratio(PlotAreaViewMetrics.innerRadiusRatio),
                    angularInset: PlotAreaViewMetrics.angularInset
                )
                .cornerRadius(PlotAreaViewMetrics.cornerRadius)
                .foregroundStyle(by: .value(CafeWording.drink, share.drink))
                .opacity(summary.isHighlighted(share) ? 1 : PlotAreaViewMetrics.fadedOpacity)
            }
            .accessibilityLabel(share.drink)
            .accessibilityValue(summary.sectorValue(share))
        }
        // The app's one colour per drink, so each drink matches every other screen.
        .chartForegroundStyleScale(domain: CafeDrinkStyle.domain(for: summary.shares.map(\.drink)), mapping: CafeDrinkStyle.colour(for:))
        .chartLegend(alignment: .center, spacing: PlotAreaViewMetrics.legendSpacing)
    }
}

/// A view placed against the plot area: a disc wider than the hole, and the best seller written in the hole.
struct PlotAreaViewHoleLabel: View {
    let proxy: ChartProxy
    let summary: PlotAreaViewSummary
    let isLabelShown: Bool

    var body: some View {
        // snippet:a-view-in-the-plot-area-hole-label
        GeometryReader { geometry in
            // plotFrame is an optional anchor: resolve it in this geometry to get the plot's rectangle,
            // whose centre is the centre of the ring. The chart's own centre is not: the legend is below.
            if let plotFrame = proxy.plotFrame {
                let layout = PlotAreaViewSummary.holeLayout(in: geometry[plotFrame])
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: layout.discDiameter, height: layout.discDiameter)
                        .accessibilityHidden(true)
                    if isLabelShown {
                        PlotAreaViewLabelText(summary: summary)
                            .frame(width: layout.labelSide, height: layout.labelSide)
                    }
                }
                .position(layout.center)
            }
        }
        // end
    }
}

/// The words in the hole, in the largest form that fits it. The headline says the same, so nothing
/// is said only here.
struct PlotAreaViewLabelText: View {
    let summary: PlotAreaViewSummary

    var body: some View {
        ViewThatFits(in: [.horizontal, .vertical]) {
            VStack(spacing: Layout.tightSpacing) {
                Text(summary.labelCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(summary.bestSellerNames)
                    .font(.title2.bold())
                Text(summary.bestSellerCups)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: Layout.tightSpacing) {
                Text(summary.bestSellerNames)
                    .font(.headline)
                Text(summary.bestSellerCups)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(summary.bestSellerCups)
                .font(.headline)
        }
        .multilineTextAlignment(.center)
        // Read as one element when it is in an overlay: "Most sold, Tea, 164 cups".
        .accessibilityElement(children: .combine)
    }
}

/// The donut for the Audio Graph, which has none of its own: the drinks as categories, cups as values.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PlotAreaViewChartDescriptor: AXChartDescriptorRepresentable {
    let summary: PlotAreaViewSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: summary.shares.map(\.drink)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            // A donut's value range runs from 0 to the total, of which each sector is a share.
            range: summary.valueRange,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: summary.shares.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today at the \(CafeWording.harbour) café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Background") {
    NavigationStack {
        if let screen = Catalog.screen(id: "plot-area/a-view-in-the-plot-area") {
            PlotAreaViewScreen(screen: screen)
        }
    }
}

#Preview("Overlay") {
    PlotAreaViewChart(
        summary: PlotAreaViewSummary(sales: CafeData.drinkSales, locale: .current),
        placement: .overlay,
        isLabelShown: true
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No sales") {
    PlotAreaViewChart(
        summary: PlotAreaViewSummary(sales: [], locale: .current),
        placement: .background,
        isLabelShown: true
    )
}
