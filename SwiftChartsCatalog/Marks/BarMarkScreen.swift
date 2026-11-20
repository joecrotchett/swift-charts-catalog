import Accessibility
import Charts
import SwiftUI

/// "Bar": vertical and horizontal bars, their thickness as a ratio or a fixed size, and one bar
/// with no category.
struct BarMarkScreen: View {
    let screen: CatalogScreen
    @State private var model = BarMarkViewModel()
    /// The one locale the screen's words are written in: the headline here, and the chart reads the same value.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: model.caption,
            message: model.headline(locale: locale),
            explanation: model.explanation,
            snippets: model.snippets
        ) {
            BarMarkChart(
                sales: model.sales,
                orientation: model.orientation,
                width: model.width,
                removesCategory: model.removesCategory
            )
        } controls: {
            BarMarkControls(model: model)
        }
        // The chart is redrawn by every control, so the announcement is built from all of them.
        .onChange(of: model.announcement(locale: locale)) { _, announcement in
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// The screen's three controls.
struct BarMarkControls: View {
    @Bindable var model: BarMarkViewModel

    var body: some View {
        ControlsSection {
            LabeledMenuPicker(title: "Orientation", selection: $model.orientation) {
                ForEach(BarMarkViewModel.Orientation.allCases) { orientation in
                    Text(orientation.rawValue).tag(orientation)
                }
            }
            if model.isThicknessAvailable {
                LabeledMenuPicker(title: "Thickness", selection: $model.width) {
                    ForEach(BarMarkViewModel.BarWidth.allCases) { width in
                        Text(width.rawValue).tag(width)
                    }
                }
            } else {
                // With no category the bar has no band, and a thickness changes nothing that is drawn:
                // the row says so, where a disabled picker would still show a setting that is not in effect.
                LabeledContent("Thickness", value: model.thicknessText)
            }
            Toggle("Remove the category", isOn: $model.removesCategory)
        }
    }
}

/// The three ways to say how thick a bar is. Each is a `MarkDimension`.
private enum BarSize {
    // snippet:bar-width-automatic
    /// The default, and the same as leaving the parameter out: the framework chooses.
    static let automatic: MarkDimension = .automatic
    // end

    // snippet:bar-width-ratio
    /// A fraction, from 0 to 1, of the band each category gets. At 1 neighbouring bars touch.
    static let ratio: MarkDimension = .ratio(0.9)
    // end

    // snippet:bar-width-fixed
    /// A size in points, the same however many bars share the chart.
    static let fixed: MarkDimension = .fixed(12)
    // end

    static func dimension(for width: BarMarkViewModel.BarWidth) -> MarkDimension {
        switch width {
        case .automatic: automatic
        case .ratio: ratio
        case .fixed: fixed
        }
    }
}

/// The one bar has no band to size it, so its chart is given a frame across the bar.
private enum OneBarLayout {
    /// The chart's size across the bar, in points, with the value axis's labels inside it.
    static let chartThickness: CGFloat = 96
}

/// The bars for one setting of the controls, or a placeholder when nothing has been sold.
struct BarMarkChart: View {
    let sales: [DrinkSales]
    let orientation: BarMarkViewModel.Orientation
    let width: BarMarkViewModel.BarWidth
    let removesCategory: Bool
    @Environment(\.locale) private var locale

    private var summary: BarMarkSummary {
        BarMarkSummary(sales: sales, removesCategory: removesCategory, locale: locale)
    }

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no bars under a headline that is not true.
        if summary.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here as bars.")
            )
        } else {
            // One value axis for the chart and the descriptor, on whichever axis carries the cups.
            Group {
                switch (orientation, removesCategory) {
                case (.vertical, false):
                    VerticalBars(sales: sales, size: BarSize.dimension(for: width))
                        .chartYScale(domain: summary.valueDomain)
                case (.horizontal, false):
                    HorizontalBars(sales: sales, size: BarSize.dimension(for: width))
                        .chartXScale(domain: summary.valueDomain)
                case (.vertical, true):
                    OneVerticalBar(sales: sales, total: summary.total)
                        .chartYScale(domain: summary.valueDomain)
                case (.horizontal, true):
                    OneHorizontalBar(sales: sales, total: summary.total)
                        .chartXScale(domain: summary.valueDomain)
                }
            }
            .accessibilityChartDescriptor(BarMarkChartDescriptor(sales: sales, removesCategory: removesCategory, locale: locale))
        }
    }
}

/// A drink on x, its cups on y: the bars rise from zero.
private struct VerticalBars: View {
    let sales: [DrinkSales]
    let size: MarkDimension
    @Environment(\.locale) private var locale

    var body: some View {
        // snippet:bar-vertical
        Chart(sales) { item in
            // The label and value go on a Plot around the mark, so VoiceOver reads "Tea, 164 cups".
            Plot {
                BarMark(
                    x: .value("Drink", item.drink),
                    y: .value("Cups", item.cups),
                    // Across a vertical bar is its width.
                    width: size
                )
            }
            .accessibilityLabel(item.drink)
            .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
        }
        // end
    }
}

/// The same two values swapped: the number on x makes the bars horizontal.
private struct HorizontalBars: View {
    let sales: [DrinkSales]
    let size: MarkDimension
    @Environment(\.locale) private var locale

    var body: some View {
        // snippet:bar-horizontal
        Chart(sales) { item in
            Plot {
                BarMark(
                    // The number is on x now, so the bars grow sideways.
                    x: .value("Cups", item.cups),
                    y: .value("Drink", item.drink),
                    // Across a horizontal bar is its height.
                    height: size
                )
            }
            .accessibilityLabel(item.drink)
            .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
        }
        // end
    }
}

/// Cups on y and nothing on x: every drink lands in the same bar.
private struct OneVerticalBar: View {
    let sales: [DrinkSales]
    let total: Int
    @Environment(\.locale) private var locale
    /// The chart's width, value axis included. It grows with the text so the axis labels keep their room.
    @ScaledMetric private var chartWidth = OneBarLayout.chartThickness

    var body: some View {
        // snippet:bar-vertical-one
        Chart {
            // One Plot around every mark: the bar is one thing, so it is one accessibility element.
            Plot {
                ForEach(sales) { item in
                    // No x. Each drink's cups stack on the one before, so the bar's height is the total.
                    BarMark(y: .value("Cups", item.cups))
                }
            }
            .accessibilityLabel(BarMarkSummary.allDrinks)
            .accessibilityValue(CafeWording.cups(total, locale: locale))
        }
        // With no category there is no band: the bar is as wide as the plot, so the frame sets its width.
        .frame(width: chartWidth)
        // The slim chart sits in the middle of the width it is offered, so the panel around it keeps its width.
        .frame(maxWidth: .infinity)
        // end
    }
}

/// Cups on x and nothing on y: every drink lands in the same bar.
private struct OneHorizontalBar: View {
    let sales: [DrinkSales]
    let total: Int
    @Environment(\.locale) private var locale
    /// The chart's height, value axis included. It grows with the text so the axis labels keep their room.
    @ScaledMetric private var chartHeight = OneBarLayout.chartThickness

    var body: some View {
        // snippet:bar-horizontal-one
        Chart {
            // One Plot around every mark: the bar is one thing, so it is one accessibility element.
            Plot {
                ForEach(sales) { item in
                    // No y. Each drink's cups follow the one before, so the bar's length is the total.
                    BarMark(x: .value("Cups", item.cups))
                }
            }
            .accessibilityLabel(BarMarkSummary.allDrinks)
            .accessibilityValue(CafeWording.cups(total, locale: locale))
        }
        // With no category there is no band: the bar is as tall as the plot, so the frame sets its height.
        .frame(height: chartHeight)
        // end
    }
}

/// The chart for the Audio Graph, describing what is drawn: a bar per drink, or the one bar of the total.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct BarMarkChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let removesCategory: Bool
    /// The locale the chart is drawn in, so what is heard matches what is read.
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let summary = BarMarkSummary(sales: sales, removesCategory: removesCategory, locale: locale)
        // One point for the single bar, carrying the total it is drawn to; otherwise a point per drink.
        let points: [(name: String, cups: Int)] = removesCategory
            ? [(BarMarkSummary.allDrinks, summary.total)]
            : sales.map { ($0.drink, $0.cups) }
        // Categories go on the descriptor's x axis whichever way the bars are drawn.
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: removesCategory ? "Total" : CafeWording.drink,
            categoryOrder: points.map(\.name)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: points.map { AXDataPoint(x: $0.name, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: removesCategory
                ? "Cups sold today at the Harbour café, all drinks in one bar"
                : "Cups sold today at the Harbour café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Bars") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/bar") {
            BarMarkScreen(screen: screen)
        }
    }
}

#Preview("One bar") {
    BarMarkChart(sales: CafeData.drinkSales, orientation: .horizontal, width: .fixed, removesCategory: true)
        .padding()
}

#Preview("No sales") {
    BarMarkChart(sales: [], orientation: .vertical, width: .automatic, removesCategory: false)
}
