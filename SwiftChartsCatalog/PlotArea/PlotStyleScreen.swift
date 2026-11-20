import Accessibility
import Charts
import SwiftUI

/// "Styling the plot area": `chartPlotStyle` gives the plot area a background and a border.
struct PlotStyleScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: PlotStyleViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers
    /// the way the chart's own axis does.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales) {
        self.screen = screen
        _viewModel = State(initialValue: PlotStyleViewModel(sales: sales))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: PlotStyleSummary(sales: viewModel.sales, locale: locale).headline,
            explanation: """
            chartPlotStyle hands you the plot area, the rectangle the marks are drawn in, as a view. \
            A background and a border added to it cover the plot alone: the cup numbers along the bottom \
            stay outside it, while the drink names, which horizontal bars carry inside the plot, sit on it. \
            Return the plot area unchanged and it is drawn as it is by default.
            """
        ) {
            PlotStyleChart(sales: viewModel.sales, isStyled: viewModel.isStyled, locale: locale)
        } controls: {
            PlotStyleControls(viewModel: viewModel)
        }
    }
}

/// The screen's one switch. It restyles the plot area only, and speaks its own state, so it posts
/// no announcement: the data, the scale, the marks and the headline stay as they are.
private struct PlotStyleControls: View {
    @Bindable var viewModel: PlotStyleViewModel

    var body: some View {
        ControlsSection {
            Toggle("Style the plot area", isOn: $viewModel.isStyled)
        }
    }
}

/// The styling this chart's plot area and marks take, from the skill's styled-plot-area recipe.
private enum PlotStyleLook {
    static let markColor = Color.pink
    static let plotBackground = Color.pink.opacity(0.2)
    static let plotBorder = Color.pink
    static let borderWidth: CGFloat = 1
}

/// Horizontal bars, one per drink, ranked; or a placeholder when nothing has been sold.
struct PlotStyleChart: View {
    let sales: [DrinkSales]
    let isStyled: Bool
    let locale: Locale

    var body: some View {
        // Nothing sold is no data: zeros would draw an empty plot under a headline that is not true.
        if PlotStyleSummary(sales: sales, locale: locale).isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            // snippet:styling-the-plot-area-chart
            Chart(sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.cups, item.cups),
                        y: .value(CafeWording.drink, item.drink)
                    )
                    .foregroundStyle(PlotStyleLook.markColor)
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            // The closure is given the plot area as a view. What it returns is drawn in its place,
            // inside the axes: the cup numbers below it are not tinted or framed.
            .chartPlotStyle { plotArea in
                if isStyled {
                    plotArea
                        .background(PlotStyleLook.plotBackground)
                        .border(PlotStyleLook.plotBorder, width: PlotStyleLook.borderWidth)
                } else {
                    // Returned as it is, the plot area is the default: no background, no border.
                    plotArea
                }
            }
            // end
            // One value axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartXScale(domain: PlotStyleSummary(sales: sales, locale: locale).valueDomain)
            .accessibilityChartDescriptor(PlotStyleChartDescriptor(sales: sales, locale: locale))
        }
    }
}

/// The chart for the Audio Graph. The plot area's styling is decoration and is not described.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PlotStyleChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = PlotStyleSummary(sales: sales, locale: locale)
        let locale = locale
        // Categories go on the descriptor's x axis, though the chart draws them down the side.
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

#Preview("Styled") {
    NavigationStack {
        if let screen = Catalog.screen(id: "plot-area/styling-the-plot-area") {
            PlotStyleScreen(screen: screen)
        }
    }
}

#Preview("Default plot area") {
    PlotStyleChart(
        sales: PlotStyleSummary.ranked(CafeData.drinkSales), isStyled: false, locale: .current
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No sales") {
    PlotStyleChart(sales: [], isStyled: true, locale: .current)
}
