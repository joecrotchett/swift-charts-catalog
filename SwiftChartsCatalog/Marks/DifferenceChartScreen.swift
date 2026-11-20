import Accessibility
import Charts
import SwiftUI

/// "Difference chart": two lines with the gap between them filled by two area layers,
/// each drawing only where its series leads.
struct DifferenceChartScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = DifferenceChartViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption,
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            DifferenceChartView(comparison: viewModel.comparison, showsFills: viewModel.showsFills)
        } controls: {
            ControlsSection {
                Toggle("Fill the difference", isOn: $viewModel.showsFills)
            }
        }
        // Adding or removing the area layers changes the kind of mark drawn, so it is said aloud:
        // what changed, then the headline.
        .onChange(of: viewModel.showsFills) {
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The two cafés' lines, with or without the filled difference, or a placeholder when nothing has been sold.
struct DifferenceChartView: View {
    let comparison: DifferenceChartComparison
    let showsFills: Bool
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A label a week, or a fortnight at the accessibility text sizes, where four labels no longer fit.
    private var daysPerAxisMark: Int {
        dynamicTypeSize.isAccessibilitySize ? DifferenceChartMetrics.daysPerAxisMarkLargeText : DifferenceChartMetrics.daysPerAxisMark
    }

    var body: some View {
        if comparison.hasNoSales {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                // True whether or not the fills are on: the lines are drawn under both settings.
                description: Text("Each café's daily cups appear here, one line per café.")
            )
        } else {
            Chart {
                if showsFills {
                    // snippet:difference-chart-fills
                    ForEach(comparison.fillPoints) { point in
                        // Filled only where the first café is ahead: from the lower value up to its own.
                        // Where it is behind, start and end are equal and nothing is drawn.
                        AreaMark(
                            x: .value(CafeWording.day, point.day),
                            yStart: .value(CafeWording.cups, point.lower),
                            yEnd: .value(CafeWording.cups, point.first),
                            series: .value(CafeWording.store, comparison.firstName)
                        )
                        .foregroundStyle(by: .value(CafeWording.store, comparison.firstName))
                        // And only where the second café is ahead.
                        AreaMark(
                            x: .value(CafeWording.day, point.day),
                            yStart: .value(CafeWording.cups, point.lower),
                            yEnd: .value(CafeWording.cups, point.second),
                            series: .value(CafeWording.store, comparison.secondName)
                        )
                        .foregroundStyle(by: .value(CafeWording.store, comparison.secondName))
                    }
                    // Pale, so both lines stay visible along the fills' edges.
                    .opacity(DifferenceChartMetrics.fillOpacity)
                    // The fills repeat the lines' data. They are not read out.
                    .accessibilityHidden(true)
                    // end
                }
                // snippet:difference-chart-lines
                ForEach(comparison.portions) { portion in
                    // One Plot per week: one accessibility element saying who led in it. The lines still join.
                    Plot {
                        ForEach(portion.series) { store in
                            ForEach(store.days) { day in
                                LineMark(
                                    x: .value(CafeWording.day, day.day),
                                    y: .value(CafeWording.cups, day.cups)
                                )
                            }
                            // Colour and dash pattern together, so the cafés can be told apart without colour.
                            .foregroundStyle(by: .value(CafeWording.store, store.store))
                            .lineStyle(by: .value(CafeWording.store, store.store))
                        }
                    }
                    .accessibilityLabel(comparison.label(for: portion, locale: locale))
                    .accessibilityValue(comparison.value(for: portion, locale: locale))
                }
                // end
            }
            // Both scales are told the two cafés, in data order, so each keeps its colour and its dash
            // pattern whichever marks are drawn and whichever café the data names first.
            .chartForegroundStyleScale(domain: comparison.storeNames, mapping: CafeSeriesStyle.colour(for:))
            .chartLineStyleScale(domain: comparison.storeNames)
            // Neither the lines nor the floating fills grow from zero. One domain, off zero, for the chart and
            // the descriptor.
            .chartYScale(domain: comparison.valueRange)
            .chartXAxis {
                // The days were recorded in the data's calendar, so the axis is told it and its time zone.
                AxisMarks(values: .stride(by: .day, count: daysPerAxisMark, calendar: comparison.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, timeZone: comparison.calendar.timeZone).month().day()
                    )
                }
            }
            .accessibilityChartDescriptor(DifferenceChartDescriptor(comparison: comparison, locale: locale))
        }
    }
}

/// Constants that belong to this chart's marks and axis.
private enum DifferenceChartMetrics {
    static let fillOpacity = 0.35
    static let daysPerAxisMark = 7
    static let daysPerAxisMarkLargeText = 14
}

/// The chart for the Audio Graph: both cafés as named series over written-out dates, cups with their unit.
nonisolated struct DifferenceChartDescriptor: AXChartDescriptorRepresentable {
    let comparison: DifferenceChartComparison
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let dates = comparison.days.map { comparison.dayText($0.day, locale: locale) }
        let series = comparison.series.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: true,
                dataPoints: zip(dates, store.days).map { AXDataPoint(x: $0, y: Double($1.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Daily cups sold at the \(comparison.firstName) and \(comparison.secondName) cafés",
            summary: comparison.audioGraphSummary(locale: locale),
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: dates),
            // The drawn scale does not include zero: the chart's own domain.
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle, range: comparison.valueRange, gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Difference chart") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/difference-chart") {
            DifferenceChartScreen(screen: screen)
        }
    }
}

#Preview("Lines alone") {
    DifferenceChartView(comparison: DifferenceChartComparison(stores: CafeData.storeSales), showsFills: false)
        .padding()
}

#Preview("No sales") {
    DifferenceChartView(comparison: DifferenceChartComparison(stores: []), showsFills: true)
}
