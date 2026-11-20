import Charts
import SwiftUI

/// "Your own plottable types": a `String` enum and a custom type, each plotted directly.
struct PlottableTypesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: PlottableTypesViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, drinkOrders: [DrinkOrder] = CafeData.drinkOrders) {
        self.screen = screen
        _viewModel = State(initialValue: PlottableTypesViewModel(drinkOrders: drinkOrders))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: viewModel.summary.headline(locale: locale),
            explanation: """
            The bars are placed by a Drink, a struct whose primitivePlottable is its name, so each drink \
            is a category. The segments are coloured by a cup size, a String enum whose raw values name \
            the legend's entries. Neither is turned into a string at the .value call.
            """
        ) {
            PlottableTypesChart(orders: viewModel.orders)
        }
    }
}

/// The drinks' cups stacked by size, or a placeholder when nothing was sold.
struct PlottableTypesChart: View {
    let orders: [PlottableTypesOrder]
    @Environment(\.locale) private var locale

    var body: some View {
        if PlottableTypesSummary(orders: orders).isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink, divided by size.")
            )
        } else {
            // snippet:plottable-types-chart
            Chart(orders) { order in
                // The drink and the size go into .value as they are: no rawValue, no name.
                Plot {
                    BarMark(
                        x: .value(CafeWording.drink, order.drink),
                        y: .value(CafeWording.cups, order.cups)
                    )
                    .foregroundStyle(by: .value(CafeWording.size, order.size))
                    // A strip of space between the sizes, as on every other chart of these stacks.
                    .clipShape(Rectangle().inset(by: PlottableTypesStyle.segmentGap))
                }
                .accessibilityLabel(PlottableTypesSummary.elementLabel(for: order))
                .accessibilityValue(PlottableTypesSummary.elementValue(for: order, locale: locale))
            }
            // end
            // The sizes in the colours every screen gives them, in data order.
            .chartForegroundStyleScale(domain: PlottableTypesSummary(orders: orders).sizes) { size in
                CafeSizeStyle.colour(for: size.rawValue)
            }
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: PlottableTypesSummary(orders: orders).valueDomain)
            .accessibilityChartDescriptor(PlottableTypesChartDescriptor(orders: orders, locale: locale))
        }
    }
}

/// Constants for this chart's marks.
private enum PlottableTypesStyle {
    /// The strip of background between stacked segments.
    static let segmentGap: CGFloat = 1
}

#Preview("Drink orders") {
    NavigationStack {
        if let screen = Catalog.screen(id: "data/your-own-plottable-types") {
            PlottableTypesScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    PlottableTypesChart(orders: [])
}
