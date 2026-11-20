import Accessibility
import Charts
import SwiftUI

/// "Crowded labels": what the x axis does when category names do not fit their bands.
struct CrowdedLabelsScreen: View {
    let screen: CatalogScreen
    @State private var model = CrowdedLabelsViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink",
            message: CrowdedLabelsSummary(sales: model.sales, locale: locale).headline,
            explanation: """
            Each category name on a bar chart's x axis gets the width of its band: its bar and the gap beside \
            it. By default a name that does not fit is truncated, not turned. AxisValueLabel's collisionResolution \
            can instead drop the names that collide (greedy) or draw them all anyway (disabled), and its \
            orientation can turn them to read vertically. The other remedies are shorter names, or horizontal \
            bars, where each name has the plot's width.
            """,
            snippets: model.snippets
        ) {
            CrowdedLabelsChart(
                sales: model.sales, resolution: model.resolution, widthFraction: model.widthFraction, locale: locale
            )
        } controls: {
            CrowdedLabelsControls(model: model, locale: locale)
        }
    }
}

/// The resolution picker, what the chosen setting does, and the width slider.
struct CrowdedLabelsControls: View {
    @Bindable var model: CrowdedLabelsViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Crowded names", selection: $model.resolution) {
                ForEach(CrowdedLabelsResolution.allCases) { resolution in
                    Text(resolution.title).tag(resolution)
                }
            }
            Text(model.resolution.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledSlider(
                title: "Chart width",
                value: $model.widthFraction,
                range: CrowdedLabelsViewModel.widthRange,
                step: CrowdedLabelsViewModel.widthStep,
                valueText: model.widthText(locale: locale),
                spokenValue: model.spokenWidth(locale: locale)
            )
        }
    }
}

/// The bar chart drawn at a share of the panel's width, or a placeholder when nothing has sold.
struct CrowdedLabelsChart: View {
    let sales: [DrinkSales]
    let resolution: CrowdedLabelsResolution
    let widthFraction: Double
    let locale: Locale

    var body: some View {
        // Nothing sold draws axes with no bars under a headline that is no longer true.
        if CrowdedLabelsSummary(sales: sales, locale: locale).total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            // The width slider narrows the chart inside its panel, so the names crowd as they would on a smaller screen.
            GeometryReader { proxy in
                CrowdedLabelsBars(sales: sales, resolution: resolution, locale: locale)
                    .frame(width: proxy.size.width * widthFraction)
            }
        }
    }
}

/// One bar per drink, with the x axis resolving crowded names as `resolution` says.
struct CrowdedLabelsBars: View {
    let sales: [DrinkSales]
    let resolution: CrowdedLabelsResolution
    let locale: Locale

    var body: some View {
        // snippet:crowded-labels-chart
        Chart(sales) { item in
            // The element carries the full name, whatever the axis draws of it.
            Plot {
                BarMark(
                    x: .value(CafeWording.drink, item.drink),
                    y: .value(CafeWording.cupsAxisTitle, item.cups)
                )
            }
            .accessibilityLabel(item.drink)
            .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
        }
        // end
        .chartXAxis {
            switch resolution {
            case .truncate:
                // snippet:crowded-labels-truncate
                // The default category axis: grid lines and names. A name wider than its band is cut short.
                AxisMarks()
            // end
            case .greedy:
                // snippet:crowded-labels-greedy
                AxisMarks { _ in
                    AxisGridLine()
                    // Only the names that fit are drawn; one that would collide is left out.
                    AxisValueLabel(collisionResolution: .greedy)
                }
            // end
            case .disabled:
                // snippet:crowded-labels-disabled
                AxisMarks { _ in
                    AxisGridLine()
                    // Every name in full, even where they run into each other.
                    AxisValueLabel(collisionResolution: .disabled)
                }
            // end
            case .vertical:
                // snippet:crowded-labels-vertical
                AxisMarks { _ in
                    AxisGridLine()
                    // Turned to read top to bottom: each name needs a line's height across its band.
                    AxisValueLabel(orientation: .vertical)
                }
                // end
            }
        }
        // One value axis for the chart and the descriptor: the most cups, rounded up to the axis step.
        .chartYScale(domain: ChartAxis.valueDomain(for: sales.map(\.cups)))
        .accessibilityChartDescriptor(CrowdedLabelsChartDescriptor(sales: sales, locale: locale))
    }
}

#Preview("Crowded labels") {
    NavigationStack {
        if let screen = Catalog.screen(id: "axes/crowded-labels") {
            CrowdedLabelsScreen(screen: screen)
        }
    }
}

#Preview("Each resolution at half width") {
    ScrollView {
        VStack(spacing: Layout.sectionSpacing) {
            ForEach(CrowdedLabelsResolution.allCases) { resolution in
                ChartPanel {
                    CrowdedLabelsChart(
                        sales: CrowdedLabelsData.menu, resolution: resolution, widthFraction: 0.5, locale: .current
                    )
                }
            }
        }
        .padding()
    }
}

#Preview("No sales") {
    CrowdedLabelsChart(sales: [], resolution: .truncate, widthFraction: 1, locale: .current)
}
