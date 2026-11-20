import Accessibility
import Charts
import SwiftUI

/// "Position and presets": `AxisMarks(position:)` puts an axis on an edge, and `AxisMarks(preset:)` decides
/// where its labels sit, on a bar chart and on a horizontal bar chart.
struct AxisPositionScreen: View {
    let screen: CatalogScreen
    var sales = AxisPositionData.sales
    @State private var model = AxisPositionViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers as the axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: AxisPositionSummary(sales: sales, locale: locale).caption,
            message: AxisPositionSummary(sales: sales, locale: locale).headline,
            explanation: """
            AxisMarks(position:) puts an axis on an edge: leading or trailing for a y axis, top or bottom for an x axis. \
            AxisMarks(preset:) decides where its labels sit: aligned puts them outside the plot, centred on their \
            value; extended runs the grid line out to them; inset draws them inside the plot, except names on a \
            trailing edge, which it pushes past the chart. One edge moves the value axis of one chart and the \
            category axis of the other, so each preset is seen on both kinds of axis.
            """,
            snippets: model.snippets,
            // Each chart of the pair sets its own height, so on a phone, where they stack, neither is squeezed
            // into half a standard panel.
            panelHeight: .fitsContent
        ) {
            AxisPositionCharts(sales: sales, model: model, locale: locale)
        } controls: {
            AxisPositionControls(model: model)
        }
    }
}

/// The two pickers: the edge, then the preset.
struct AxisPositionControls: View {
    @Bindable var model: AxisPositionViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Edge", selection: $model.edge) {
                ForEach(AxisPositionEdge.allCases) { edge in
                    Text(edge.title).tag(edge)
                }
            }
            LabeledSegmentedPicker(title: "Preset", selection: $model.preset) {
                ForEach(AxisPositionPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            if let note = model.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Both charts, one above the other, or a placeholder when nothing has been sold.
struct AxisPositionCharts: View {
    let sales: [DrinkSales]
    let model: AxisPositionViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Each chart's height, growing with the text so the value labels and the names keep their room.
    @ScaledMetric(relativeTo: .body) private var chartHeight = AxisPositionMetrics.chartHeight

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no bars under a headline that is not true.
        if AxisPositionSummary(sales: sales, locale: locale).total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            ChartPair(
                firstTitle: model.barsCaption(at: dynamicTypeSize),
                secondTitle: model.horizontalCaption(at: dynamicTypeSize)
            ) {
                AxisPositionBarChart(
                    sales: sales, edge: model.edge, preset: model.preset.markPreset, locale: locale
                )
                .chartYScale(domain: AxisPositionChartDescriptor.valueDomain(for: sales))
                .frame(height: min(chartHeight, AxisPositionMetrics.largestChartHeight))
            } second: {
                AxisPositionHorizontalBarChart(
                    sales: sales, edge: model.edge, preset: model.preset.markPreset, locale: locale
                )
                .chartXScale(domain: AxisPositionChartDescriptor.valueDomain(for: sales))
                .frame(height: min(chartHeight, AxisPositionMetrics.largestChartHeight))
            }
        }
    }
}

/// Sizes for the pair of charts.
private enum AxisPositionMetrics {
    /// One chart's height at the default text size: about three quarters of a standard panel.
    static let chartHeight: CGFloat = 200
    /// The most height one chart takes, whatever the text size.
    static let largestChartHeight: CGFloat = 360
}

/// Vertical bars: the categories on x, the numbers on y.
struct AxisPositionBarChart: View {
    let sales: [DrinkSales]
    let edge: AxisPositionEdge
    let preset: AxisMarkPreset
    let locale: Locale
    /// The chart is half the panel's height, so at the accessibility sizes it asks for fewer numbers and
    /// turns the names, as the skill's Dynamic Type advice says.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Every hundred cups at the large sizes, so the numbers do not pile up; the framework's choice below them.
    private var values: AxisMarkValues {
        AxisPositionTextSize.isLarge(dynamicTypeSize)
            ? .stride(by: AxisPositionTextSize.largeValueStride)
            : .automatic
    }

    private var namesAreVertical: Bool {
        AxisPositionTextSize.namesAreVertical(at: dynamicTypeSize)
    }

    var body: some View {
        Chart(sales) { item in
            Plot {
                BarMark(
                    x: .value(CafeWording.drink, item.drink),
                    y: .value(CafeWording.cups, item.cups)
                )
            }
            .accessibilityLabel(item.drink)
            .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
        }
        // The condition goes inside each axis closure, so this stays one chart whatever the edge.
        .chartYAxis {
            switch edge {
            case .leading:
                // snippet:axis-position-bars-leading
                // On vertical bars the y axis holds the numbers: the value axis moves to the leading edge.
                // `values` asks for fewer numbers at the accessibility sizes.
                AxisMarks(preset: preset, position: .leading, values: values)
            // end
            case .trailing:
                // snippet:axis-position-bars-trailing
                // On vertical bars the y axis holds the numbers: the value axis stays on the trailing edge.
                // `values` asks for fewer numbers at the accessibility sizes.
                AxisMarks(preset: preset, position: .trailing, values: values)
            // end
            case .top, .bottom:
                AxisMarks(values: values)
            }
        }
        .chartXAxis {
            switch edge {
            case .top:
                if namesAreVertical {
                    // Listed parts replace the defaults: the category axis's grid line, and its name turned.
                    AxisMarks(preset: preset, position: .top) { _ in
                        AxisGridLine()
                        AxisValueLabel(orientation: .vertical)
                    }
                } else {
                    // snippet:axis-position-bars-top
                    // On vertical bars the x axis holds the names: the category axis moves to the top.
                    AxisMarks(preset: preset, position: .top)
                    // end
                }
            case .bottom:
                if namesAreVertical {
                    AxisMarks(preset: preset, position: .bottom) { _ in
                        AxisGridLine()
                        AxisValueLabel(orientation: .vertical)
                    }
                } else {
                    // snippet:axis-position-bars-bottom
                    // On vertical bars the x axis holds the names: the category axis stays at the bottom.
                    AxisMarks(preset: preset, position: .bottom)
                    // end
                }
            case .leading, .trailing:
                if namesAreVertical {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(orientation: .vertical)
                    }
                } else {
                    AxisMarks()
                }
            }
        }
        .accessibilityChartDescriptor(
            AxisPositionChartDescriptor(sales: sales, form: "vertical bars", locale: locale)
        )
    }
}

/// Horizontal bars: the numbers on x, the categories on y.
struct AxisPositionHorizontalBarChart: View {
    let sales: [DrinkSales]
    let edge: AxisPositionEdge
    let preset: AxisMarkPreset
    let locale: Locale

    var body: some View {
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
        .chartYAxis {
            switch edge {
            case .leading:
                // snippet:axis-position-horizontal-leading
                // On horizontal bars the y axis holds the names: the category axis moves to the leading edge.
                AxisMarks(preset: preset, position: .leading)
            // end
            case .trailing:
                // snippet:axis-position-horizontal-trailing
                // On horizontal bars the y axis holds the names: the category axis moves to the trailing edge.
                AxisMarks(preset: preset, position: .trailing)
            // end
            case .top, .bottom:
                AxisMarks()
            }
        }
        .chartXAxis {
            switch edge {
            case .top:
                // snippet:axis-position-horizontal-top
                // On horizontal bars the x axis holds the numbers: the value axis moves to the top.
                AxisMarks(preset: preset, position: .top)
            // end
            case .bottom:
                // snippet:axis-position-horizontal-bottom
                // On horizontal bars the x axis holds the numbers: the value axis stays at the bottom.
                AxisMarks(preset: preset, position: .bottom)
            // end
            case .leading, .trailing:
                AxisMarks()
            }
        }
        .accessibilityChartDescriptor(
            AxisPositionChartDescriptor(sales: sales, form: "horizontal bars", locale: locale)
        )
    }
}

// snippet:axis-position-presets
extension AxisPositionPreset {
    /// The preset `AxisMarks(preset:)` is given. Automatic lets the framework choose from the axis and the data.
    var markPreset: AxisMarkPreset {
        switch self {
        case .automatic: .automatic
        case .aligned: .aligned
        case .extended: .extended
        case .inset: .inset
        }
    }
}

// end

/// The chart for the Audio Graph. The categories go on its x axis whichever way the bars run.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct AxisPositionChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    /// "vertical bars" or "horizontal bars", for the title.
    let form: String
    let locale: Locale

    /// The cups axis as drawn in both charts, from zero to the most rounded up to the axis step (164 → 200).
    static func valueDomain(for sales: [DrinkSales]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = AxisPositionSummary(sales: sales, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: sales.map(\.drink)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: Self.valueDomain(for: sales),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today at the \(CafeWording.harbour) café, \(summary.drinksDrawn), as \(form)",
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
        if let screen = Catalog.screen(id: "axes/position-and-presets") {
            AxisPositionScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    AxisPositionCharts(sales: [], model: AxisPositionViewModel(), locale: .current)
}
