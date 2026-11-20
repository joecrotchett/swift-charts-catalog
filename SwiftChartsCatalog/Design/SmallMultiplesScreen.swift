import Accessibility
import Charts
import SwiftUI

/// "Small multiples": three aligned charts on a shared scale, against one crowded chart of the same data.
struct SmallMultiplesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = SmallMultiplesViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups per month, March 2026 to February 2027",
            message: viewModel.headline(locale: locale),
            explanation: """
            Swift Charts has no faceting, so each drink is its own Chart in a VStack, all given one y domain: \
            a bar's height then means the same number of cups in every chart, and on A chart design system, which \
            draws these cups on the same scale. Only the last chart shows the months, \
            and every plot is given one height with chartPlotStyle; sized by the chart's frame instead, the last \
            plot would lose the height of the month labels and its bars would read smaller.
            """,
            snippets: viewModel.snippets,
            // Every plot is given its height, so the panel fits the charts instead of leaving bands above and below.
            panelHeight: .fitsContent
        ) {
            SmallMultiplesCharts(viewModel: viewModel, locale: locale)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Give each chart its own scale", isShowingMistake: $viewModel.usesIndependentScales)
                    .disabled(viewModel.hasNothingToDraw)
                if viewModel.usesIndependentScales {
                    Text(viewModel.mistakeNote(locale: locale))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            SmallMultiplesCrowdedSection(viewModel: viewModel, locale: locale)
        }
        .onChange(of: viewModel.usesIndependentScales) {
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The small multiples: a title and a chart per drink, or a placeholder when there is nothing to draw.
struct SmallMultiplesCharts: View {
    let viewModel: SmallMultiplesViewModel
    let locale: Locale

    var body: some View {
        if viewModel.hasNothingToDraw {
            SmallMultiplesPlaceholder()
        } else {
            // snippet:small-multiples-stack
            // No faceting in Swift Charts: one Chart per drink, stacked, the time axis on the last only.
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                ForEach(viewModel.drinks, id: \.self) { drink in
                    SmallMultiplesDrinkChart(
                        drink: drink,
                        rows: viewModel.summary.rows(for: drink),
                        drinks: viewModel.drinks,
                        domain: viewModel.domain(for: drink),
                        showsTimeAxis: drink == viewModel.drinks.last,
                        usesIndependentScales: viewModel.usesIndependentScales,
                        summary: viewModel.summary,
                        locale: locale
                    )
                }
            }
            // end
        }
    }
}

/// One drink's small chart under its title.
struct SmallMultiplesDrinkChart: View {
    let drink: String
    let rows: [MonthlyDrinkCups]
    /// Every drink, so the colour scale lists the same domain as the crowded chart does.
    let drinks: [String]
    let domain: ClosedRange<Double>
    let showsTimeAxis: Bool
    let usesIndependentScales: Bool
    let summary: SmallMultiplesSummary
    let locale: Locale

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The plot's own height, the same in every chart, growing with the text as the panel does.
    @ScaledMetric(relativeTo: .body) private var plotHeight = SmallMultiplesMetrics.plotHeight

    /// Fewer month labels at the largest text sizes, so the initials do not collide.
    private var monthsPerLabel: Int {
        dynamicTypeSize >= .accessibility3 ? 3 : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(drink)
                .font(.caption.bold())
                .accessibilityAddTraits(.isHeader)
            // snippet:small-multiples-chart
            Chart(rows) { row in
                Plot {
                    BarMark(
                        x: .value(CafeWording.month, row.month, unit: .month, calendar: CafeData.calendar),
                        y: .value(CafeWording.cups, row.cups)
                    )
                    .foregroundStyle(by: .value(CafeWording.drink, row.drink))
                }
                .accessibilityLabel("\(row.drink), \(SmallMultiplesWording.monthAndYear(row.month, locale: locale))")
                .accessibilityValue(CafeWording.cups(row.cups, locale: locale))
            }
            // Each drink's own colour from the shared table, the same as on every screen of these drinks.
            .chartForegroundStyleScale(domain: drinks, mapping: CafeDrinkStyle.colour(for:))
            .chartLegend(.hidden) // the title above names the drink
            // The shared domain (or, as the mistake, this chart's own), passed to the descriptor too.
            .chartYScale(domain: domain)
            .chartYAxis {
                AxisMarks(values: [domain.lowerBound, domain.upperBound])
            }
            .chartXAxis {
                // Grid lines in every chart, so the months line up; labels under the last chart only.
                if showsTimeAxis {
                    AxisMarks(values: .stride(by: .month, count: monthsPerLabel, calendar: CafeData.calendar)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(
                            format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.narrow),
                            centered: monthsPerLabel == 1
                        )
                    }
                } else {
                    AxisMarks(values: .stride(by: .month, count: monthsPerLabel, calendar: CafeData.calendar)) { _ in
                        AxisGridLine()
                    }
                }
            }
            // The plot's height, not the chart's: a chart frame would include the month labels,
            // and the last plot would come out shorter than the others.
            .chartPlotStyle { plotArea in
                plotArea.frame(height: plotHeight)
            }
            // end
            .accessibilityChartDescriptor(SmallMultiplesDrinkDescriptor(
                drink: drink, summary: summary, domain: domain, usesIndependentScales: usesIndependentScales, locale: locale
            ))
            // A new identity when the scale changes, or the Audio Graph keeps the first descriptor.
            .id("\(drink)-\(usesIndependentScales)")
        }
    }
}

/// The same twelve months drawn the crowded way: one chart, three bars to a month, told apart by colour.
struct SmallMultiplesCrowdedSection: View {
    let viewModel: SmallMultiplesViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("For comparison: one crowded chart")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("The same data on one plot and its one shared scale. The toggle above does not change it. Colour, and each bar's place in its group, are all that tell the drinks apart.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ChartPanel {
                if viewModel.hasNothingToDraw {
                    SmallMultiplesPlaceholder()
                } else {
                    SmallMultiplesCrowdedChart(summary: viewModel.summary, locale: locale)
                }
            }
        }
    }
}

/// Three drinks' bars side by side in every month, on the shared scale.
struct SmallMultiplesCrowdedChart: View {
    let summary: SmallMultiplesSummary
    let locale: Locale

    var body: some View {
        let domain = summary.sharedDomain
        // snippet:small-multiples-crowded
        Chart {
            ForEach(summary.months, id: \.self) { month in
                // One element per month holding all three drinks, read in month order.
                Plot {
                    ForEach(summary.trends.filter { $0.month == month }) { row in
                        BarMark(
                            x: .value(CafeWording.month, row.month, unit: .month, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, row.cups)
                        )
                        .foregroundStyle(by: .value(CafeWording.drink, row.drink))
                        .position(by: .value(CafeWording.drink, row.drink), axis: .horizontal)
                    }
                }
                .accessibilityLabel(SmallMultiplesWording.monthAndYear(month, locale: locale))
                .accessibilityValue(summary.crowdedValue(for: month, locale: locale))
            }
        }
        .chartForegroundStyleScale(domain: summary.drinks, mapping: CafeDrinkStyle.colour(for:))
        .chartYScale(domain: domain)
        // end
        .chartYAxis {
            AxisMarks(values: [domain.lowerBound, domain.upperBound])
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, calendar: CafeData.calendar)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(
                    format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.narrow),
                    centered: true
                )
            }
        }
        .accessibilityChartDescriptor(SmallMultiplesCrowdedDescriptor(summary: summary, locale: locale))
    }
}

/// Shown in place of a chart when no cups were sold: bars of zero would draw nothing under a headline.
struct SmallMultiplesPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "No cups sold",
            systemImage: "cup.and.saucer",
            description: Text("Cups per drink per month appear here, one chart per drink.")
        )
    }
}

/// Sizes that belong to this screen's charts alone.
private enum SmallMultiplesMetrics {
    /// The height of every small chart's plot at the default text size: three fit the panel with their titles
    /// and the month labels.
    static let plotHeight: CGFloat = 52
}

/// The Audio Graph of one drink's chart: its months, its cups, and the scale it is drawn on.
nonisolated struct SmallMultiplesDrinkDescriptor: AXChartDescriptorRepresentable {
    let drink: String
    let summary: SmallMultiplesSummary
    let domain: ClosedRange<Double>
    let usesIndependentScales: Bool
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let rows = summary.rows(for: drink)
        return AXChartDescriptor(
            title: "\(drink), \(CafeWording.cups.lowercased()) per month",
            summary: summary.audioGraphSummary(for: drink, usesIndependentScales: usesIndependentScales, locale: locale),
            xAxis: AXCategoricalDataAxisDescriptor(
                title: CafeWording.month,
                categoryOrder: rows.map { SmallMultiplesWording.monthAndYear($0.month, locale: locale) }
            ),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: domain, gridlinePositions: []) { value in
                CafeWording.count(value, locale: locale)
            },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: drink,
                isContinuous: false,
                dataPoints: rows.map {
                    AXDataPoint(x: SmallMultiplesWording.monthAndYear($0.month, locale: locale), y: Double($0.cups))
                }
            )]
        )
    }
}

/// The Audio Graph of the crowded chart: one series per drink over the same months.
nonisolated struct SmallMultiplesCrowdedDescriptor: AXChartDescriptorRepresentable {
    let summary: SmallMultiplesSummary
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let domain = summary.sharedDomain
        let tallest = CafeWording.list(summary.tallestBars.map {
            "\($0.drink) in \(SmallMultiplesWording.monthAndYear($0.month, locale: locale)), "
                + CafeWording.cups($0.cups, locale: locale)
        })
        return AXChartDescriptor(
            title: "Cups per month of \(CafeWording.list(summary.drinks)), on one chart",
            summary: summary.hasNothingToDraw
                ? "No cups sold in these months."
                : "\(CafeWording.drinks(summary.drinks.count, locale: locale)), "
                + "\(CafeWording.months(summary.months.count, locale: locale)), one scale of 0 to "
                + "\(SmallMultiplesWording.cups(domain.upperBound, locale: locale)). Highest: \(tallest).",
            xAxis: AXCategoricalDataAxisDescriptor(
                title: CafeWording.month,
                categoryOrder: summary.months.map { SmallMultiplesWording.monthAndYear($0, locale: locale) }
            ),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: domain, gridlinePositions: []) { value in
                CafeWording.count(value, locale: locale)
            },
            additionalAxes: [],
            series: summary.drinks.map { drink in
                AXDataSeriesDescriptor(
                    name: drink,
                    isContinuous: false,
                    dataPoints: summary.rows(for: drink).map {
                        AXDataPoint(x: SmallMultiplesWording.monthAndYear($0.month, locale: locale), y: Double($0.cups))
                    }
                )
            }
        )
    }
}

#Preview("Small multiples") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/small-multiples") {
            SmallMultiplesScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    SmallMultiplesCharts(viewModel: SmallMultiplesViewModel(trends: []), locale: .current)
        .frame(height: Layout.chartHeightCompact)
}
