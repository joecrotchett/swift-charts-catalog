import Accessibility
import Charts
import SwiftUI

/// "Order comes from the data": the order of the bars, of each stack's segments and of the legend
/// all come from the rows and the colour scale, not from a chart setting.
struct DataOrderScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: DataOrderViewModel
    @Environment(\.locale) private var locale
    /// The chart mirrors in a right-to-left layout, so the words that name the bars' direction follow it.
    @Environment(\.layoutDirection) private var layoutDirection

    init(screen: CatalogScreen, orders: [DrinkOrder] = CafeData.drinkOrders) {
        self.screen = screen
        _viewModel = State(initialValue: DataOrderViewModel(orders: orders))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: viewModel.headline(locale: locale, layoutDirection: layoutDirection),
            explanation: """
            Swift Charts places the bars in the order each drink first appears in the rows, and stacks each bar's \
            segments in the order each size first appears: sort the rows and the bars move. The legend follows \
            the colour scale's domain instead, so reversing it moves only the legend, which then reads against \
            the stacks. Write the domain in the data's order and the two agree.
            """,
            snippets: viewModel.snippets
        ) {
            DataOrderChart(viewModel: viewModel, locale: locale)
        } controls: {
            DataOrderControls(viewModel: viewModel, locale: locale, layoutDirection: layoutDirection)
        }
    }
}

/// The two controls: the rows' order and the colour scale's domain order. Each change is announced.
struct DataOrderControls: View {
    @Bindable var viewModel: DataOrderViewModel
    let locale: Locale
    let layoutDirection: LayoutDirection

    var body: some View {
        ControlsSection {
            Toggle("Sort the rows by total", isOn: $viewModel.sortsByTotal.animation(.easeInOut))
            Toggle("Reverse the colour scale's domain", isOn: $viewModel.reversesScaleDomain.animation(.easeInOut))
        }
        .onChange(of: viewModel.sortsByTotal) {
            DataOrderScreen.announce(viewModel.sortAnnouncement(locale: locale, layoutDirection: layoutDirection))
        }
        .onChange(of: viewModel.reversesScaleDomain) {
            DataOrderScreen.announce(viewModel.domainAnnouncement(locale: locale, layoutDirection: layoutDirection))
        }
    }
}

extension DataOrderScreen {
    /// Says aloud that the chart changed, for people who cannot see it happen.
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// Stacked bars of the drink orders, or a placeholder when nothing was ordered.
struct DataOrderChart: View {
    let viewModel: DataOrderViewModel
    let locale: Locale

    var body: some View {
        if viewModel.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one stacked bar per drink.")
            )
        } else {
            // snippet:data-order-chart
            // No setting orders anything here: the bars follow the order the drinks appear in the
            // rows, each stack follows the order the sizes appear, and the legend follows the domain.
            Chart(viewModel.segments) { segment in
                Plot {
                    BarMark(
                        x: .value(CafeWording.drink, segment.drink),
                        y: .value(CafeWording.cups, segment.cups)
                    )
                    .foregroundStyle(by: .value(CafeWording.size, segment.size))
                    // A strip of empty space between neighbouring segments.
                    .clipShape(Rectangle().inset(by: 1))
                    .annotation(position: .top) {
                        if segment.isTopOfStack {
                            DataOrderTotalLabel(cups: viewModel.totals.first { $0.drink == segment.drink }?.cups ?? 0)
                        }
                    }
                }
                .accessibilityLabel("\(segment.drink), \(segment.size)")
                .accessibilityValue(CafeWording.cups(segment.cups, locale: locale))
            }
            // The domain's order is the legend's order. Mapping by name keeps each size's colour.
            // The colours are the app's size colours (CafeSizeStyle).
            .chartForegroundStyleScale(domain: viewModel.scaleDomain) { size in
                CafeSizeStyle.colour(for: size)
            }
            // end
            // One value axis for the chart and the descriptor, with room above the tallest stack for its total.
            .chartYScale(domain: ChartAxis.valueDomain(for: [viewModel.highestTotal]))
            .accessibilityChartDescriptor(DataOrderChartDescriptor(
                title: "Cups sold today, by drink and size",
                summary: viewModel.audioGraphSummary(locale: locale),
                drinks: viewModel.drinkOrder,
                sizes: viewModel.legendOrder,
                segments: viewModel.segments,
                highestTotal: viewModel.highestTotal,
                locale: locale
            ))
        }
    }
}

/// A bar's total above its top segment, so the headline's figure can be found on the chart.
struct DataOrderTotalLabel: View {
    let cups: Int

    var body: some View {
        Text(cups, format: .number)
            .font(.caption)
            .foregroundStyle(.secondary)
            // The total is in the descriptor's summary; the segments carry their own values.
            .accessibilityHidden(true)
    }
}

/// The chart for the Audio Graph: one series per size, each point a segment's own cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct DataOrderChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    /// The bars in order.
    let drinks: [String]
    /// The series, in the legend's order.
    let sizes: [String]
    let segments: [DataOrderSegment]
    let highestTotal: Int
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: drinks)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            // The drawn axis: the tallest stack rounded up to the axis step (164 → 200).
            range: ChartAxis.valueDomain(for: [highestTotal]),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = sizes.map { size in
            AXDataSeriesDescriptor(
                name: size,
                isContinuous: false,
                dataPoints: drinks.compactMap { drink in
                    segments.first { $0.drink == drink && $0.size == size }.map {
                        AXDataPoint(x: drink, y: Double($0.cups))
                    }
                }
            )
        }
        return AXChartDescriptor(
            title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: series
        )
    }
}

#Preview("Orders") {
    NavigationStack {
        if let screen = Catalog.screen(id: "data/order-comes-from-the-data") {
            DataOrderScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    DataOrderChart(viewModel: DataOrderViewModel(orders: []), locale: .current)
}
