import Accessibility
import Charts
import SwiftUI

/// "Plot height from content": horizontal bars with a fixed height per row, so the chart grows with its categories.
struct PlotHeightScreen: View {
    let screen: CatalogScreen
    @State private var model = PlotHeightViewModel()
    /// The locale the screen's words are written in, read here and passed in.
    @Environment(\.locale) private var locale
    // snippet:plot-height-from-content-row-height
    /// The height of one row. It grows with the text size: the drink names sit inside the plot, above each bar,
    /// and take their room from the row.
    @ScaledMetric(relativeTo: .body) private var rowHeight = PlotHeightMetrics.rowHeight
    // end

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, best sellers first",
            message: model.summary(locale: locale).headline,
            explanation: """
            The plot area is given a height of its own in chartPlotStyle: a fixed height for each row, times the \
            number of rows. The axes are added around it, so every bar keeps its thickness and the chart grows \
            with its categories instead of squeezing them: the panel grows to fit. The cup values are along the \
            top, so the scale is in view above the first row.
            """,
            snippets: model.snippets,
            panelHeight: .fitsContent
        ) {
            PlotHeightChart(sales: model.shownSales, plotHeight: model.plotHeight(rowHeight: rowHeight), locale: locale)
        } controls: {
            PlotHeightControls(model: model, rowHeight: rowHeight, locale: locale)
        }
    }
}

/// Constants that belong to this chart's marks.
private enum PlotHeightMetrics {
    /// One row at the default text size: room for the drink's name above a bar of a comfortable thickness.
    static let rowHeight: CGFloat = 44
}

/// One bar per drink, in a plot as tall as its rows, or a placeholder when nothing has been sold.
struct PlotHeightChart: View {
    let sales: [DrinkSales]
    let plotHeight: CGFloat
    let locale: Locale

    var body: some View {
        if PlotHeightSummary(sales: sales, locale: locale).hasCups {
            // The panel fits its content, so the chart is as tall as its rows and the page scrolls past it.
            // snippet:plot-height-from-content-chart
            Chart(sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.cups, item.cups),
                        y: .value(CafeWording.drink, item.drink)
                    )
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            // The plot area takes the height its rows need; the axes are added around it.
            .chartPlotStyle { plotArea in
                plotArea.frame(height: plotHeight)
            }
            // One value axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartXScale(domain: PlotHeightSummary(sales: sales, locale: locale).valueDomain)
            // The cup values along the top, so the scale is in view above the first row.
            .chartXAxis {
                AxisMarks(position: .top)
            }
            // end
            .accessibilityChartDescriptor(PlotHeightChartDescriptor(sales: sales, locale: locale))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one row per drink.")
            )
        }
    }
}

/// The row count, and the plot height it leads to.
private struct PlotHeightControls: View {
    @Bindable var model: PlotHeightViewModel
    let rowHeight: CGFloat
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledStepper(
                title: "Rows", value: $model.rowCount, in: model.rowRange,
                valueText: model.rowCountText(locale: locale), spokenValue: model.spokenRowCount(locale: locale)
            )
            LabeledContent("Plot height", value: model.plotHeightText(rowHeight: rowHeight, locale: locale))
        }
    }
}

/// The chart for the Audio Graph: a title, a summary, named axes, and values said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PlotHeightChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = PlotHeightSummary(sales: sales, locale: locale)
        let locale = locale
        // A horizontal bar chart is described with its categories on x: a descriptor's y axis is always numeric.
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
            title: "Cups sold today at the \(CafeWording.harbour) café, best sellers first",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Five rows") {
    NavigationStack {
        if let screen = Catalog.screen(id: "plot-area/plot-height-from-content") {
            PlotHeightScreen(screen: screen)
        }
    }
}

#Preview("Twelve rows") {
    PlotHeightChart(
        sales: PlotHeightSummary.ranked(PlotHeightMenu.drinks),
        plotHeight: PlotHeightViewModel.plotHeight(rows: PlotHeightMenu.drinks.count, rowHeight: PlotHeightMetrics.rowHeight),
        locale: .current
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No sales") {
    PlotHeightChart(sales: [], plotHeight: 0, locale: .current)
}
