import Accessibility
import Charts
import SwiftUI

/// "Gradients and the plot area": `alignsMarkStylesWithPlotArea` lays a gradient inside each bar,
/// or once across the plot so that a bar's colour shows its height.
struct GradientsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: GradientsViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales) {
        self.screen = screen
        _viewModel = State(initialValue: GradientsViewModel(sales: sales))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: viewModel.summary(locale: locale).headline,
            explanation: """
            A gradient given to a mark's foregroundStyle is laid out inside that mark, so every bar runs from \
            the first colour to the last whatever its height, so its colour says nothing about its height. \
            alignsMarkStylesWithPlotArea lays the gradient \
            across the plot area instead, and each bar shows only the stretch it covers, so its colour repeats \
            what its height already says.
            """,
            snippets: viewModel.snippets
        ) {
            GradientsChart(sales: viewModel.sales, alignment: viewModel.alignment, locale: locale)
        } controls: {
            GradientsControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.alignment) {
            // The picker changes the headline, so say what changed, then the new headline.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The one control: where the gradient is laid out.
struct GradientsControls: View {
    @Bindable var viewModel: GradientsViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Gradient laid out", selection: $viewModel.alignment) {
                ForEach(GradientsAlignment.allCases) { alignment in
                    Text(alignment.title).tag(alignment)
                }
            }
        }
    }
}

/// The bars, filled with one gradient, or a placeholder when nothing has been sold.
struct GradientsChart: View {
    let sales: [DrinkSales]
    let alignment: GradientsAlignment
    let locale: Locale

    var body: some View {
        if GradientsSummary(sales: sales, alignment: alignment, locale: locale).isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            // snippet:gradients-chart
            Chart(sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.drink, item.drink),
                        y: .value(CafeWording.cups, item.cups)
                    )
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
                // The same gradient either way: yellow at the bottom, red at the top.
                .foregroundStyle(.linearGradient(colors: [.yellow, .red], startPoint: .bottom, endPoint: .top))
                // false: each bar holds the whole gradient.
                // true: the gradient spans the plot area, and each bar shows the part it covers.
                .alignsMarkStylesWithPlotArea(alignment.alignsWithPlotArea)
            }
            // end
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: GradientsSummary(sales: sales, alignment: alignment, locale: locale).valueDomain)
            .accessibilityChartDescriptor(GradientsChartDescriptor(sales: sales, locale: locale))
        }
    }
}

/// The chart for the Audio Graph. The gradient changes no value, so both settings describe the same bars.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct GradientsChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = GradientsSummary(sales: sales, alignment: .perMark, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: sales.map(\.drink)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
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

#Preview("Sales") {
    NavigationStack {
        GradientsScreen(
            screen: Catalog.screen(id: "mark-modifiers/gradients-and-the-plot-area") ?? CatalogScreen(
                id: "mark-modifiers/gradients-and-the-plot-area", title: "Gradients and the plot area",
                summary: "", apiSince: "16.0", skillReferences: ["mark-modifiers.md"],
                snippets: GradientsViewModel.snippets
            )
        )
    }
}

#Preview("Aligned") {
    GradientsChart(
        sales: GradientsSummary.ranked(CafeData.drinkSales), alignment: .plotArea, locale: .current
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No sales") {
    GradientsChart(sales: [], alignment: .perMark, locale: .current)
}
