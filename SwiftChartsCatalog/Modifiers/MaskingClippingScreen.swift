import Accessibility
import Charts
import SwiftUI

/// "Masking and clipping": `clipShape` cuts each bar to a shape, `mask` cuts it with other chart content.
struct MaskingClippingScreen: View {
    let screen: CatalogScreen
    @State private var model = MaskingClippingViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: model.summary(locale: locale).headline,
            explanation: """
            clipShape cuts each mark to a shape that fills the mark's frame: a Capsule turns a bar into a pill, \
            rounded at both ends. mask cuts a mark with the alpha channel of other chart content, here 20-cup \
            blocks, so each bar reads as a stack of units. Neither changes a value: every bar still ends at its cups.
            """,
            snippets: model.snippets
        ) {
            MaskingClippingChart(sales: model.sales, shape: model.shape, locale: locale)
        } controls: {
            ControlsSection {
                LabeledSegmentedPicker(title: "Shape", selection: $model.shape) {
                    ForEach(MaskingClippingShape.allCases) { shape in
                        Text(shape.title).tag(shape)
                    }
                }
            }
        }
    }
}

/// The bar chart, cut to the chosen shape, or a placeholder when nothing has been sold.
struct MaskingClippingChart: View {
    let sales: [DrinkSales]
    let shape: MaskingClippingShape
    let locale: Locale

    var body: some View {
        if MaskingClippingSummary(sales: sales, locale: locale).total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            Chart(sales) { item in
                // The label and value go on a Plot around the mark, whatever it is cut to.
                Plot {
                    MaskingClippingBar(item: item, shape: shape)
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: MaskingClippingSummary(sales: sales, locale: locale).valueDomain)
            .accessibilityChartDescriptor(MaskingClippingChartDescriptor(sales: sales, locale: locale))
        }
    }
}

/// One drink's bar, drawn plain, clipped to a capsule, or masked by blocks.
struct MaskingClippingBar: ChartContent {
    let item: DrinkSales
    let shape: MaskingClippingShape

    var body: some ChartContent {
        switch shape {
        case .none:
            // snippet:masking-clipping-none
            BarMark(
                x: .value(CafeWording.drink, item.drink),
                y: .value(CafeWording.cups, item.cups),
                width: .ratio(MaskingClippingStyle.barWidth)
            )
        // end
        case .pill:
            // snippet:masking-clipping-pill
            BarMark(
                x: .value(CafeWording.drink, item.drink),
                y: .value(CafeWording.cups, item.cups),
                width: .ratio(MaskingClippingStyle.barWidth)
            )
            // Each bar is cut to a capsule that fills its frame: rounded at both ends.
            .clipShape(Capsule())
        // end
        case .blocks:
            // snippet:masking-clipping-blocks
            BarMark(
                x: .value(CafeWording.drink, item.drink),
                y: .value(CafeWording.cups, item.cups),
                width: .ratio(MaskingClippingStyle.barWidth)
            )
            // The bar shows only where the mask's content is drawn: one band per 20 cups,
            // each running the full width of the plot, with a thin gap between them.
            .mask {
                ForEach(maskingClippingBlocks(cups: item.cups)) { block in
                    RectangleMark(
                        yStart: .value(CafeWording.cups, block.start),
                        yEnd: .value(CafeWording.cups, block.end)
                    )
                }
            }
            // end
        }
    }
}

/// Constants that belong to this chart's marks.
private enum MaskingClippingStyle {
    /// The share of each drink's band the bar takes, the same for every shape so only the cut changes.
    static let barWidth = 0.5
}

/// The chart for the Audio Graph. The cut changes no value, so it is the same for every shape.
nonisolated struct MaskingClippingChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = MaskingClippingSummary(sales: sales, locale: locale)
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
            title: "Cups sold today at the Harbour café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Masking and clipping") {
    NavigationStack {
        if let screen = Catalog.screen(id: "mark-modifiers/masking-and-clipping") {
            MaskingClippingScreen(screen: screen)
        }
    }
}

#Preview("Blocks") {
    MaskingClippingChart(sales: MaskingClippingViewModel.ranked(CafeData.drinkSales), shape: .blocks, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No sales") {
    MaskingClippingChart(sales: [], shape: .pill, locale: .current)
}
