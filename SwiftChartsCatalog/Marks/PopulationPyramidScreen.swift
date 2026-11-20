import Accessibility
import Charts
import SwiftUI

/// "Population pyramid": back-to-back bars from negated values, with axis labels that leave the sign out.
struct PopulationPyramidScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = PopulationPyramidViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Visits in a month, by age group",
            message: viewModel.summary.headline(locale: locale),
            explanation: """
            A population pyramid compares two groups across the same rows. There is no mark for it: both cafés \
            are ordinary bars on one number axis, and one café's values are negated so its bars grow the other \
            way from zero. The axis would then count that side in negative numbers, so its labels are drawn from \
            the absolute value, and VoiceOver and the Audio Graph are given the real, positive visits.
            """,
            snippets: viewModel.snippets
        ) {
            PopulationPyramidChart(summary: viewModel.summary)
        }
    }
}

/// Two bars per age group growing in opposite directions from zero, or a placeholder when nobody visited.
struct PopulationPyramidChart: View {
    let summary: PopulationPyramidSummary
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Grows with the axis labels' text, so half of an end label always fits inside the chart.
    @ScaledMetric(relativeTo: .caption) private var endLabelRoom = PopulationPyramidMetrics.endLabelRoom

    /// Fewer value labels at the accessibility text sizes, so they do not collide. Nil keeps the default.
    private var valueLabelCount: Int? {
        dynamicTypeSize.isAccessibilitySize ? PopulationPyramidMetrics.valueLabelsAtAccessibilitySizes : nil
    }

    var body: some View {
        // Nothing to draw is no data: zeros would leave axes with no bars.
        if summary.isEmpty {
            ContentUnavailableView(
                "No visits yet",
                systemImage: "person.2",
                description: Text("A month's visits appear here, one row per age group and one side per café.")
            )
        } else {
            // snippet:population-pyramid-bars
            Chart(summary.rows) { item in
                // A Plot per bar, so each bar is its own element and is read with its real, positive number.
                // Left bare, the two bars of a row share one element whose value is their sum, one side negative.
                Plot {
                    BarMark(
                        // `plottedVisits` returns one café's visits negated, so its bars grow the other
                        // way from zero, and the other café's as they are.
                        x: .value(CafeWording.visits, summary.plottedVisits(item)),
                        y: .value(CafeWording.ageGroup, item.ageGroup)
                    )
                    .foregroundStyle(by: .value(CafeWording.store, item.store))
                }
                .accessibilityLabel(summary.elementLabel(item))
                .accessibilityValue(summary.elementValue(item, locale: locale))
            }
            // end
            // Each café keeps the colour it has on the other screens that draw the two.
            .chartForegroundStyleScale(domain: summary.stores, mapping: CafeSeriesStyle.colour(for:))
            // The same reach on both sides of zero, worked out once for the chart and the descriptor. The labels
            // below are centred on their grid lines; the padding keeps the two end ones inside the chart.
            .chartXScale(domain: summary.visitsDomain, range: .plotDimension(padding: endLabelRoom))
            // snippet:population-pyramid-axes
            .chartXAxis {
                // Centred on their grid lines, so both ends of the axis are labelled alike.
                AxisMarks(preset: .aligned, values: .automatic(desiredCount: valueLabelCount)) { value in
                    AxisGridLine()
                    // Both sides are labelled with the size of the value: the minus sign is how the bar
                    // was placed, not something the reader should see.
                    AxisValueLabel {
                        if let visits = value.as(Int.self) {
                            Text(abs(visits), format: .number.locale(locale))
                        }
                    }
                }
            }
            .chartYAxis {
                if dynamicTypeSize.isAccessibilitySize {
                    // At the largest text sizes the names stay inside the plot, above each row,
                    // where the default puts them: outside, they would take the width the bars need.
                    AxisMarks()
                } else {
                    // Outside the plot, so the names do not take height from the rows.
                    AxisMarks(preset: .aligned, position: .leading)
                }
            }
            // end
            .accessibilityChartDescriptor(PopulationPyramidChartDescriptor(summary: summary, locale: locale))
        }
    }
}

/// Constants that belong to this chart alone.
private enum PopulationPyramidMetrics {
    static let valueLabelsAtAccessibilitySizes = 3
    /// Room kept at each end of the value axis for half of an end label, at the default text size.
    static let endLabelRoom: CGFloat = 18
}

/// The chart for the Audio Graph: one series per café over the age groups, in real, positive visits.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PopulationPyramidChartDescriptor: AXChartDescriptorRepresentable {
    let summary: PopulationPyramidSummary
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        // Categories go on the descriptor's x axis whichever way the chart is drawn. They run in the
        // drawn order, top to bottom, oldest first: the order VoiceOver meets the bars in.
        let groups = summary.drawnAgeGroups
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.ageGroup, categoryOrder: groups)
        // Nothing here is negative: the negation is how the bars are placed, not what was counted.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.visits,
            // Each side's reach as drawn, from zero.
            range: 0 ... summary.visitsTop,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.visits) }
        let series = summary.stores.map { store in
            AXDataSeriesDescriptor(
                name: store,
                isContinuous: false,
                dataPoints: groups.compactMap { group in
                    summary.visits.first { $0.store == store && $0.ageGroup == group }
                        .map { AXDataPoint(x: group, y: Double($0.visits)) }
                }
            )
        }
        return AXChartDescriptor(
            title: "Visits in a month by age group, at each café",
            summary: summary.audioGraphSummary(locale: locale),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Visits") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/population-pyramid") {
            PopulationPyramidScreen(screen: screen)
        }
    }
}

#Preview("No visits") {
    PopulationPyramidChart(summary: PopulationPyramidSummary(visits: [], ageGroups: CafeData.ageGroups))
        .padding()
}
