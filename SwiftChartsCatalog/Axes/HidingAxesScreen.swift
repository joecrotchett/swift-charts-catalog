import Accessibility
import Charts
import SwiftUI

/// "Hiding axes": `.hidden` on each axis, what it takes away, and what the chart then has to say instead.
struct HidingAxesScreen: View {
    let screen: CatalogScreen
    var sales = CafeData.drinkSales
    @State private var model = HidingAxesViewModel()
    /// Read here and passed in, so the headline, the labels and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink",
            message: HidingAxesSummary(sales: sales, locale: locale).headline,
            explanation: """
            chartXAxis(.hidden) and chartYAxis(.hidden) each remove a whole axis: its labels, its ticks and its \
            grid lines. The bars keep their lengths, but what the axis told the reader, how many or which drink, \
            has to be written on the chart some other way. VoiceOver loses nothing: axes are never accessibility \
            elements, and the chart descriptor still names both.
            """,
            snippets: model.snippets
        ) {
            HidingAxesChart(
                sales: sales, hidesXAxis: model.hidesXAxis, hidesYAxis: model.hidesYAxis, locale: locale
            )
        } controls: {
            HidingAxesControls(model: model)
        }
    }
}

/// The two toggles, each with a note on what its axis gives the reader, or what took its place.
private struct HidingAxesControls: View {
    @Bindable var model: HidingAxesViewModel

    var body: some View {
        ControlsSection {
            HidingAxesToggle(title: "Hide the x axis (cups)", note: model.xAxisNote, isOn: $model.hidesXAxis)
            HidingAxesToggle(title: "Hide the y axis (drinks)", note: model.yAxisNote, isOn: $model.hidesYAxis)
        }
    }
}

private struct HidingAxesToggle: View {
    let title: String
    let note: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Toggle(title, isOn: $isOn)
            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// The chart's own constants.
private enum HidingAxesMetrics {
    /// Bars with their names written on them are faded so the text stays readable.
    static let fadedBarOpacity = 0.5
    /// The gap between the start of a bar and the name written inside it.
    static let nameInset: CGFloat = 4
}

/// Horizontal bars of cups by drink, with either axis hidden and its information written on the bars instead.
struct HidingAxesChart: View {
    let sales: [DrinkSales]
    let hidesXAxis: Bool
    let hidesYAxis: Bool
    let locale: Locale

    var body: some View {
        // No cups sold is no data: bars of zero would leave axes under a headline that is not true.
        if HidingAxesSummary(sales: sales, locale: locale).total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            Chart(sales) { item in
                // The label and value sit on a Plot around the mark, so VoiceOver reads the drink and its
                // cups whichever axes are drawn.
                Plot {
                    BarMark(
                        x: .value(CafeWording.cups, item.cups),
                        y: .value(CafeWording.drink, item.drink)
                    )
                    // snippet:hiding-axes-values
                    // With the x axis hidden nothing measures the bars, so each one carries its value.
                    // padScale extends the scale until the longest bar's label fits.
                    .annotation(position: .trailing, overflowResolution: .init(x: .padScale)) {
                        if hidesXAxis {
                            Text(item.cups, format: .number.locale(locale))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    // end
                    // snippet:hiding-axes-names
                    // With the y axis hidden the bars have no names, so each name is written inside the
                    // start of its bar, and the bars are faded so it stays readable.
                    .opacity(hidesYAxis ? HidingAxesMetrics.fadedBarOpacity : 1)
                    .annotation(
                        position: .leading, alignment: .leading, overflowResolution: .init(x: .fit(to: .plot))
                    ) {
                        if hidesYAxis {
                            Text(item.drink)
                                .font(.caption)
                                .padding(.leading, HidingAxesMetrics.nameInset)
                        }
                    }
                    // end
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            // snippet:hiding-axes-hide
            // .hidden removes the axis whole: its labels, ticks and grid lines.
            .chartXAxis(hidesXAxis ? .hidden : .automatic)
            .chartYAxis(hidesYAxis ? .hidden : .automatic)
            // end
            // One value axis for the chart and the descriptor: the most cups, rounded up to the axis step.
            .chartXScale(domain: ChartAxis.valueDomain(for: sales.map(\.cups)))
            .accessibilityChartDescriptor(HidingAxesChartDescriptor(sales: sales, locale: locale))
        }
    }
}

/// What the chart says in words: the headline, and the summary the Audio Graph speaks.
nonisolated struct HidingAxesSummary {
    let sales: [DrinkSales]
    /// The locale every count is written in; the view passes its environment's.
    let locale: Locale

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// Every drink that sold the most, in data order: more than one on a tie, none when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order; none when nothing sold.
    var slowestSellers: [DrinkSales] {
        guard total > 0, let fewest = sales.map(\.cups).min() else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The message, carrying the key value. The same whichever axis is hidden: the value is on the scale
    /// when the x axis is drawn, and on the bar when it is not.
    var headline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    /// Actual values, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
    }
}

/// The chart for the Audio Graph. It is the same whichever axis is drawn: hiding an axis changes what is
/// seen, not the data. Not tied to the main actor, as the accessibility system calls it when it chooses.
nonisolated struct HidingAxesChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = HidingAxesSummary(sales: sales, locale: locale)
        let locale = locale
        // Categories go on the descriptor's x axis, though the chart draws them on y.
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: sales.map(\.drink))
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: ChartAxis.valueDomain(for: sales.map(\.cups)),
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

#Preview("Hiding axes") {
    NavigationStack {
        HidingAxesScreen(
            screen: CatalogScreen(
                id: "axes/hiding-axes", title: "Hiding axes", summary: "", apiSince: "16.0",
                skillReferences: ["axes.md"], snippets: [HidingAxesSnippets.hide]
            )
        )
    }
}

#Preview("Both axes hidden") {
    HidingAxesChart(sales: CafeData.drinkSales, hidesXAxis: true, hidesYAxis: true, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No sales") {
    HidingAxesChart(sales: [], hidesXAxis: false, hidesYAxis: false, locale: .current)
}
