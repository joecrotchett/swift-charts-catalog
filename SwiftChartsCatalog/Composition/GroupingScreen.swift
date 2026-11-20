import Accessibility
import Charts
import SwiftUI

/// "Grouping": `position(by:)` puts bars that share a category side by side instead of stacking them.
struct GroupingScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = GroupingViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: viewModel.headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            DrinkOrdersChart(orders: viewModel.orders, layout: viewModel.layout)
        } controls: {
            GroupingControls(viewModel: viewModel)
        }
        // Animation is not enough: say what changed for people who cannot see it happen.
        .onChange(of: viewModel.layout) {
            AccessibilityNotification.Announcement(viewModel.announcement).post()
        }
    }
}

/// Stacked or grouped, and how much of its band a group uses.
private struct GroupingControls: View {
    @Bindable var viewModel: GroupingViewModel

    var body: some View {
        ControlsSection {
            // The same bars for the same drinks and sizes in another place, so the change animates.
            Picker("Arrangement", selection: $viewModel.arrangement.animation(.easeInOut)) {
                ForEach(BarArrangement.allCases) { arrangement in
                    Text(arrangement.title).tag(arrangement)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Bar arrangement")
            LabeledContent("Span of a group in its band") {
                Picker("Span of a group in its band", selection: $viewModel.span.animation(.easeInOut)) {
                    ForEach(GroupSpan.allCases) { span in
                        Text(span.title).tag(span)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .labeledContentStyle(StackedLabeledContentStyle())
            .disabled(!viewModel.isSpanEnabled)
        }
    }
}

/// A control's name above the control, so a segmented picker keeps the full width.
private struct StackedLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            configuration.label
                .font(.subheadline)
                .foregroundStyle(.secondary)
            configuration.content
        }
    }
}

/// One bar per drink and size, stacked or side by side, or a placeholder when nothing has been sold.
struct DrinkOrdersChart: View {
    let orders: [DrinkOrder]
    let layout: GroupingLayout

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no bars under a headline that is not true.
        if orders.map(\.cups).reduce(0, +) == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink and size.")
            )
        } else {
            Chart(orders) { order in
                // A labelled Plot makes each bar its own element, stacked or grouped. Without it VoiceOver
                // reads one element per drink: its total when stacked, its average when grouped.
                Plot {
                    DrinkOrderBar(order: order, layout: layout)
                }
                .accessibilityLabel("\(order.drink), \(order.size)")
                .accessibilityValue(Text("^[\(order.cups) cup](inflect: true)"))
            }
            // Every size, in data order: the legend and the stacks agree, and a size keeps its colour
            // whichever rows are present. The sizes' own colours, shared by every screen that draws them.
            .chartForegroundStyleScale(
                domain: DrinkOrdersSummary(orders: orders, isStacked: layout == .stacked).sizes,
                mapping: CafeSizeStyle.colour(for:)
            )
            // One value axis for the chart and the descriptor: to the tallest stack, or the tallest single bar.
            .chartYScale(domain: DrinkOrdersSummary(orders: orders, isStacked: layout == .stacked).valueDomain)
            .accessibilityChartDescriptor(DrinkOrdersChartDescriptor(orders: orders, isStacked: layout == .stacked))
        }
    }
}

/// The bar for one drink in one size, placed as the layout says.
private struct DrinkOrderBar: ChartContent {
    let order: DrinkOrder
    let layout: GroupingLayout

    var body: some ChartContent {
        switch layout {
        case .stacked:
            // snippet:grouping-stacked
            // Three rows share each drink, so their bars stack. The colour only shows the pieces.
            BarMark(
                x: .value(CafeWording.drink, order.drink),
                y: .value(CafeWording.cups, order.cups)
            )
            .foregroundStyle(by: .value(CafeWording.size, order.size))
        // end
        case .grouped:
            // snippet:grouping-grouped
            BarMark(
                x: .value(CafeWording.drink, order.drink),
                y: .value(CafeWording.cups, order.cups)
            )
            .foregroundStyle(by: .value(CafeWording.size, order.size))
            // The same property as the colour: one bar per size, side by side in the drink's band.
            .position(by: .value(CafeWording.size, order.size), axis: .horizontal)
        // end
        case let .groupedWithSpan(ratio):
            // snippet:grouping-span
            BarMark(
                x: .value(CafeWording.drink, order.drink),
                y: .value(CafeWording.cups, order.cups)
            )
            .foregroundStyle(by: .value(CafeWording.size, order.size))
            // span: is how much of the drink's band the group may use. Here ratio is 0.5 or 1:
            // half the band draws narrow bars with wide gaps between drinks, the whole band the widest bars.
            .position(by: .value(CafeWording.size, order.size), axis: .horizontal, span: .ratio(ratio))
            // end
        }
    }
}

/// The chart for the Audio Graph: a series per size over the drinks, with values said in cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct DrinkOrdersChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [DrinkOrder]
    let isStacked: Bool

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = DrinkOrdersSummary(orders: orders, isStacked: isStacked)
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: summary.drinks)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            // The drawn scale: up to a drink's total when stacked, up to the tallest single bar when grouped.
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in DrinkOrdersSummary.cupsText(count) } }
        let series = summary.sizes.map { size in
            AXDataSeriesDescriptor(
                name: size,
                isContinuous: false,
                dataPoints: orders.filter { $0.size == size }.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: isStacked
                ? "Cups sold today by drink, with sizes stacked"
                : "Cups sold today by drink and size, sizes side by side",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Grouping") {
    NavigationStack {
        if let screen = Catalog.screen(id: "composition/grouping") {
            GroupingScreen(screen: screen)
        }
    }
}

#Preview("Stacked") {
    DrinkOrdersChart(orders: CafeData.drinkOrders, layout: .stacked)
        .padding()
}

#Preview("No sales") {
    DrinkOrdersChart(orders: [], layout: .grouped)
}
