import Accessibility
import Charts
import SwiftUI

/// "Modifier order": on a vectorized plot, key-path modifiers first and plain-value modifiers after,
/// with the compiler error the wrong order gives shown as text.
struct ModifierOrderScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ModifierOrderViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, orders: [CafeOrder] = CafeData.manyOrders(count: ModifierOrderViewModel.orderCount)) {
        self.screen = screen
        _viewModel = State(initialValue: ModifierOrderViewModel(orders: orders))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Wait by time of day, \(CafeWording.orders(viewModel.orders.count, locale: locale))",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            if viewModel.isShowingMistake {
                ModifierOrderErrorPanel()
            } else {
                ModifierOrderChart(orders: viewModel.orders, locale: locale)
            }
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Put the plain-value modifiers first", isShowingMistake: $viewModel.isShowingMistake)
                    .disabled(viewModel.showsPlaceholder)
            }
        }
        .onChange(of: viewModel.isShowingMistake) {
            // The chart is replaced by text, or comes back: say so, then the headline.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// Orders as points, wait against time of day, coloured by drink; or a placeholder with no orders.
struct ModifierOrderChart: View {
    let orders: [CafeOrder]
    let locale: Locale

    var body: some View {
        let summary = ModifierOrderSummary(orders: orders, locale: locale)
        if orders.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "cup.and.saucer",
                description: Text("Each order's wait appears here, by the time it was placed.")
            )
        } else {
            // snippet:modifier-order-right
            Chart {
                PointPlot(
                    orders,
                    x: .value(ModifierOrderWording.timeOfDay, \.hour),
                    y: .value(ModifierOrderWording.wait, \.waitMinutes)
                )
                // Key-path modifiers first: they read a value from each order...
                .foregroundStyle(by: .value(CafeWording.drink, \.drink))
                .symbol(by: .value(CafeWording.drink, \.drink))
                // ...then plain-value modifiers, which style the whole plot.
                .symbolSize(40)
                .opacity(0.6)
            }
            // end
            .chartYScale(domain: summary.waitDomain)
            // Each drink has a colour and a shape, so the series do not differ by colour alone.
            .chartForegroundStyleScale(domain: CafeData.manyOrderDrinks, mapping: CafeDrinkStyle.colour(for:))
            .chartSymbolScale(domain: CafeData.manyOrderDrinks)
            .timeOfDayAxis(locale: locale)
            .waitAxisTitle()
            // A plot's own elements give no units, so VoiceOver gets labelled stretches of the day instead.
            .accessibilityRepresentation {
                TimeOfDaySpokenChart(portions: summary.portions, locale: locale)
                    .accessibilityChartDescriptor(ModifierOrderChartDescriptor(orders: orders, locale: locale))
            }
        }
    }
}

// snippet:modifier-order-wrong
// Does not compile: the key-path modifiers come after symbolSize(_:) and opacity(_:),
// which return ordinary chart content with no key-path modifiers.
// Chart {
//     PointPlot(
//         orders,
//         x: .value(ModifierOrderWording.timeOfDay, \.hour),
//         y: .value(ModifierOrderWording.wait, \.waitMinutes)
//     )
//     .symbolSize(40)
//     .opacity(0.6)
//     .foregroundStyle(by: .value(CafeWording.drink, \.drink))
//     .symbol(by: .value(CafeWording.drink, \.drink))
// }
//
// Xcode 27.0 (27A266a), on the plain-value lines, not the key-path ones:
// .symbolSize(40)
//     error: no exact matches in call to instance method 'symbolSize'
// .opacity(0.6)
//     error: cannot convert value of type 'Double' to expected argument type
//            'KeyPath<PointPlot<VectorizedPointPlotContent<[CafeOrder]>>.DataElement, CGFloat>'
//            (aka 'KeyPath<CafeOrder, CGFloat>')
// end

/// What the wrong order leaves on screen: no chart, only the errors the build gave, as text.
/// It scrolls only when the text is too tall for the panel, at the larger text sizes.
struct ModifierOrderErrorPanel: View {
    var body: some View {
        ViewThatFits(in: .vertical) {
            ModifierOrderErrorText()
            ScrollView {
                ModifierOrderErrorText()
            }
        }
    }
}

/// The errors, word for word, and the Xcode version that gave them.
struct ModifierOrderErrorText: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Label(ModifierOrderCompilerError.title, systemImage: "xmark.octagon.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
            ForEach(ModifierOrderCompilerError.messages, id: \.self) { message in
                Text(message)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
            Text("From \(ModifierOrderCompilerError.xcodeVersion). \(ModifierOrderCompilerError.note)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The chart for the Audio Graph: both axes numbers, one series per drink.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct ModifierOrderChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [CafeOrder]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = ModifierOrderSummary(orders: orders, locale: locale)
        let locale = locale
        let xAxis = AXNumericDataAxisDescriptor(
            title: ModifierOrderWording.timeOfDay,
            range: ModifierOrderSummary.hourDomain,
            gridlinePositions: []
        ) { value in ModifierOrderWording.clockTime(value, locale: locale) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: ModifierOrderWording.waitAxisTitle,
            range: summary.waitDomain,
            gridlinePositions: []
        ) { value in value.isFinite ? ModifierOrderWording.minutes(value, locale: locale) : "" }
        let series = summary.drinks.map { drink in
            AXDataSeriesDescriptor(
                name: drink,
                isContinuous: false,
                dataPoints: orders.filter { $0.drink == drink }.map { AXDataPoint(x: $0.hour, y: $0.waitMinutes) }
            )
        }
        return AXChartDescriptor(
            title: "Wait against time of day, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Right order") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/modifier-order") {
            ModifierOrderScreen(screen: screen)
        }
    }
}

#Preview("Error panel") {
    ChartPanel {
        ModifierOrderErrorPanel()
    }
    .padding()
}

#Preview("No orders") {
    ModifierOrderChart(orders: [], locale: .current)
}
