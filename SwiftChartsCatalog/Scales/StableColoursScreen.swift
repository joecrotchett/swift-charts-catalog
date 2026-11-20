import Accessibility
import Charts
import SwiftUI

/// "Stable colours": a fixed colour-scale domain keeps each size's colour whatever the filter leaves.
struct StableColoursScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = StableColoursViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: viewModel.headline(locale: locale),
            explanation: """
            Colours are handed out in the order values appear in the data, so filtering out Small gives \
            Medium Small’s colour. chartForegroundStyleScale(domain:) lists every size the chart can show: \
            each keeps its colour whatever the data holds, and the legend keeps every size, even one filtered out.
            """,
            snippets: viewModel.snippets
        ) {
            StableColoursChart(viewModel: viewModel, locale: locale)
        } controls: {
            ControlsSection {
                StableColoursFilterChips(viewModel: viewModel, locale: locale)
                StableColoursDomainToggle(viewModel: viewModel, locale: locale)
            }
        }
    }
}

/// The stacked bars, with the colour domain fixed or, as the mistake, left to the data.
struct StableColoursChart: View {
    let viewModel: StableColoursViewModel
    let locale: Locale

    var body: some View {
        if viewModel.hasBars {
            StableColoursBars(orders: viewModel.visibleOrders, locale: locale)
                .stableColoursScale(isFixed: viewModel.isDomainFixed)
                // One value axis for the chart and the descriptor: the tallest stack drawn, rounded up.
                .chartYScale(domain: StableColoursChartDescriptor.valueDomain(for: viewModel.visibleOrders))
                .accessibilityChartDescriptor(StableColoursChartDescriptor(
                    orders: viewModel.visibleOrders,
                    sizes: viewModel.visibleSizes,
                    summary: viewModel.audioGraphSummary(locale: locale),
                    locale: locale
                ))
        } else {
            ContentUnavailableView(
                "No bars to draw",
                systemImage: "cup.and.saucer",
                description: Text(viewModel.headline(locale: locale))
            )
        }
    }
}

/// One bar per drink, split into a segment per size.
struct StableColoursBars: View {
    let orders: [StableColoursOrder]
    let locale: Locale

    var body: some View {
        // snippet:stable-colours-bars
        Chart(orders) { order in
            // A labelled Plot makes each segment its own element: "Latte, Medium, 58 cups".
            Plot {
                BarMark(
                    x: .value(CafeWording.drink, order.drink),
                    y: .value(CafeWording.cupsAxisTitle, order.cups)
                )
                .foregroundStyle(by: .value(CafeWording.size, order.size))
                // A point of space between touching segments, so neighbouring sizes stay apart.
                .clipShape(Rectangle().inset(by: 1))
            }
            .accessibilityLabel("\(order.drink), \(order.size.rawValue)")
            .accessibilityValue(CafeWording.cups(order.cups, locale: locale))
        }
        // end
    }
}

extension View {
    /// The colour scale: fixed to every size, or (the mistake) left for the data to decide.
    @ViewBuilder
    func stableColoursScale(isFixed: Bool) -> some View {
        if isFixed {
            // snippet:stable-colours-fixed-domain
            // Every size the chart can show, in order: each keeps its colour whatever the filter leaves.
            chartForegroundStyleScale(domain: StableColoursSize.allCases)
            // end
        } else {
            // snippet:stable-colours-no-domain
            // No chartForegroundStyleScale(domain:): colours go to sizes in the order the filtered
            // data lists them, so hiding Small hands its colour to Medium.
            self
            // end
        }
    }
}

/// A chip per size. Each one changes the chart's data, so it announces what changed and the headline.
struct StableColoursFilterChips: View {
    let viewModel: StableColoursViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("Sizes shown")
                .accessibilityHidden(true)
            HStack(spacing: Layout.itemSpacing) {
                ForEach(StableColoursSize.allCases) { size in
                    Toggle(size.rawValue, isOn: Binding(
                        get: { viewModel.isShown(size) },
                        set: { isShown in
                            let message = withAnimation { viewModel.setShown(size, isShown, locale: locale) }
                            AccessibilityNotification.Announcement(message).post()
                        }
                    ))
                    .toggleStyle(.button)
                    // Named for what it does: the "Sizes shown" heading above is not read with it.
                    .accessibilityLabel("Show \(size.rawValue)")
                    .accessibilityHint("Shows or hides \(size.rawValue) in the chart")
                }
            }
        }
    }
}

/// The domain switch. On is right; off is the mistake, and says so.
struct StableColoursDomainToggle: View {
    let viewModel: StableColoursViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Toggle("Fix the colour domain", isOn: Binding(
                get: { viewModel.isDomainFixed },
                set: { isFixed in
                    let message = viewModel.setDomainFixed(isFixed, locale: locale)
                    AccessibilityNotification.Announcement(message).post()
                }
            ))
            if !viewModel.isDomainFixed {
                Label("This is the mistake, shown on purpose.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

/// The chart for the Audio Graph: one series per size drawn, each over the drinks, values with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct StableColoursChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [StableColoursOrder]
    let sizes: [StableColoursSize]
    let summary: String
    let locale: Locale

    /// Drinks in the order they first appear, as the bars are drawn.
    var drinks: [String] {
        var drinks: [String] = []
        for order in orders where !drinks.contains(order.drink) {
            drinks.append(order.drink)
        }
        return drinks
    }

    /// The tallest stack, so the range matches the drawn scale, which starts at zero.
    var highestTotal: Int {
        drinks.map { drink in orders.filter { $0.drink == drink }.map(\.cups).reduce(0, +) }.max() ?? 0
    }

    /// The cups axis as drawn: from zero to the tallest stack of the sizes shown, rounded up to the axis step
    /// (164 → 200). The chart's scale and the descriptor's range.
    static func valueDomain(for orders: [StableColoursOrder]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: [Self(orders: orders, sizes: [], summary: "", locale: .current).highestTotal])
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: drinks)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: Self.valueDomain(for: orders),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        // Each point is the segment's own cups, not its height in the stack.
        let series = sizes.map { size in
            AXDataSeriesDescriptor(
                name: size.rawValue,
                isContinuous: false,
                dataPoints: orders.filter { $0.size == size }.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold today, by drink and size",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Stable colours") {
    NavigationStack {
        if let screen = Catalog.screen(id: "scales/stable-colours") {
            StableColoursScreen(screen: screen)
        }
    }
}

#Preview("Small filtered out, no domain") {
    let viewModel = StableColoursViewModel()
    viewModel.setShown(.small, false, locale: .current)
    viewModel.isDomainFixed = false
    return StableColoursChart(viewModel: viewModel, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
