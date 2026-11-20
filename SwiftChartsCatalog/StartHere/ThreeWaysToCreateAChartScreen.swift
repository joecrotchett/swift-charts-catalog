import Accessibility
import Charts
import SwiftUI

/// "Three ways to create a chart": `Chart(data)`, `Chart(data, id:)` and `Chart { }`, and when each fits.
struct ThreeWaysToCreateAChartScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ThreeWaysToCreateAChartViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.summary.caption,
            message: viewModel.summary.headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            ThreeWaysChart(viewModel: viewModel)
        } controls: {
            ThreeWaysControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.changeAnnouncement) { _, announcement in
            // The chart changes without moving focus, so say what it shows now.
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// The initializer, the number of series, and the mistake.
private struct ThreeWaysControls: View {
    @Bindable var viewModel: ThreeWaysToCreateAChartViewModel

    var body: some View {
        ControlsSection {
            Picker("Initializer", selection: $viewModel.way) {
                ForEach(ThreeWaysToCreateAChartViewModel.Way.allCases) { way in
                    Text(way.title).tag(way)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Initializer")
            Picker("Series", selection: $viewModel.seriesCount) {
                ForEach(ThreeWaysToCreateAChartViewModel.SeriesCount.allCases) { count in
                    Text(count.title).tag(count)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Number of series")
            MistakeToggle(title: "Write the average rule inside the closure", isShowingMistake: $viewModel.isShowingMistake)
                .disabled(!viewModel.canShowMistake)
            if !viewModel.canShowMistake {
                Text("Chart { } has a place for the rule beside the data, so the mistake cannot be made here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The chart for the current setting, or a placeholder when nothing has been sold.
struct ThreeWaysChart: View {
    let viewModel: ThreeWaysToCreateAChartViewModel

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no line under a headline that is not true.
        if !viewModel.summary.hasData {
            ContentUnavailableView(
                "No sales this week",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one line per café.")
            )
        } else {
            Group {
                switch viewModel.way {
                case .data:
                    ThreeWaysDataCharts(
                        days: viewModel.days, rows: viewModel.rows, average: viewModel.summary.average,
                        seriesCount: viewModel.seriesCount, isShowingMistake: viewModel.isShowingMistake
                    )
                case .dataWithID:
                    ThreeWaysIDCharts(
                        readings: viewModel.readings, average: viewModel.summary.average,
                        seriesCount: viewModel.seriesCount, isShowingMistake: viewModel.isShowingMistake
                    )
                case .content:
                    ThreeWaysContentCharts(
                        days: viewModel.days, stores: viewModel.stores, average: viewModel.summary.average,
                        seriesCount: viewModel.seriesCount
                    )
                }
            }
            .modifier(ThreeWaysWeekStyle(
                cafes: viewModel.cafes, showsLegend: viewModel.seriesCount == .several,
                valueDomain: viewModel.summary.valueDomain
            ))
            .accessibilityChartDescriptor(ThreeWaysChartDescriptor(summary: viewModel.summary))
        }
    }
}

/// `Chart(data)`: one collection of Identifiable elements, one mark per element.
private struct ThreeWaysDataCharts: View {
    let days: [DailySales]
    let rows: [ThreeWaysStoreDay]
    let average: Int
    let seriesCount: ThreeWaysToCreateAChartViewModel.SeriesCount
    let isShowingMistake: Bool

    var body: some View {
        switch (seriesCount, isShowingMistake) {
        case (.one, false):
            // snippet:three-ways-to-create-a-chart-data-one
            Chart(days) { day in
                ThreeWaysDayPoint(day: day.day, cups: day.cups)
            }
        // end
        case (.several, false):
            // snippet:three-ways-to-create-a-chart-data-several
            // One flat collection: a row per café and day.
            Chart(rows) { row in
                ThreeWaysDayPoint(day: row.day, cups: row.cups, store: row.store)
                    // Either encoding separates the lines; both, so they differ by more than colour.
                    .foregroundStyle(by: .value("Café", row.store))
                    .symbol(by: .value("Café", row.store))
            }
        // end
        case (.one, true):
            // snippet:three-ways-to-create-a-chart-data-one-mistake
            Chart(days) { day in
                ThreeWaysDayPoint(day: day.day, cups: day.cups)
                // Wrong: this closure runs once per element, so this is one rule per day.
                ThreeWaysAverageRule(average: average)
            }
        // end
        case (.several, true):
            // snippet:three-ways-to-create-a-chart-data-several-mistake
            Chart(rows) { row in
                ThreeWaysDayPoint(day: row.day, cups: row.cups, store: row.store)
                    .foregroundStyle(by: .value("Café", row.store))
                    .symbol(by: .value("Café", row.store))
                // Wrong: this closure runs once per element, so this is one rule per café and day.
                ThreeWaysAverageRule(average: average)
            }
            // end
        }
    }
}

/// `Chart(data, id:)`: the same, for elements that are not Identifiable.
private struct ThreeWaysIDCharts: View {
    let readings: [ThreeWaysReading]
    let average: Int
    let seriesCount: ThreeWaysToCreateAChartViewModel.SeriesCount
    let isShowingMistake: Bool

    var body: some View {
        switch (seriesCount, isShowingMistake) {
        case (.one, false):
            // snippet:three-ways-to-create-a-chart-id-one
            // The readings are not Identifiable. With one café, the day is unique per element.
            Chart(readings, id: \.day) { reading in
                ThreeWaysDayPoint(day: reading.day, cups: reading.cups)
            }
        // end
        case (.several, false):
            // snippet:three-ways-to-create-a-chart-id-several
            // Two cafés share each day, so the day is no longer unique: the whole Hashable element is.
            Chart(readings, id: \.self) { reading in
                ThreeWaysDayPoint(day: reading.day, cups: reading.cups, store: reading.store)
                    .foregroundStyle(by: .value("Café", reading.store))
                    .symbol(by: .value("Café", reading.store))
            }
        // end
        case (.one, true):
            // snippet:three-ways-to-create-a-chart-id-one-mistake
            Chart(readings, id: \.day) { reading in
                ThreeWaysDayPoint(day: reading.day, cups: reading.cups)
                // Wrong: this closure runs once per element, so this is one rule per day.
                ThreeWaysAverageRule(average: average)
            }
        // end
        case (.several, true):
            // snippet:three-ways-to-create-a-chart-id-several-mistake
            Chart(readings, id: \.self) { reading in
                ThreeWaysDayPoint(day: reading.day, cups: reading.cups, store: reading.store)
                    .foregroundStyle(by: .value("Café", reading.store))
                    .symbol(by: .value("Café", reading.store))
                // Wrong: this closure runs once per element, so this is one rule per café and day.
                ThreeWaysAverageRule(average: average)
            }
            // end
        }
    }
}

/// `Chart { }`: any mix of `ForEach` and individual marks.
private struct ThreeWaysContentCharts: View {
    let days: [DailySales]
    let stores: [StoreSales]
    let average: Int
    let seriesCount: ThreeWaysToCreateAChartViewModel.SeriesCount

    var body: some View {
        switch seriesCount {
        case .one:
            // snippet:three-ways-to-create-a-chart-content-one
            Chart {
                // The ForEach that Chart(data) wraps around its closure, written out.
                ForEach(days) { day in
                    ThreeWaysDayPoint(day: day.day, cups: day.cups)
                }
                // Outside the ForEach: one rule, however many days there are.
                ThreeWaysAverageRule(average: average)
            }
        // end
        case .several:
            // snippet:three-ways-to-create-a-chart-content-several
            Chart {
                // Nested data as it is: one ForEach per café around one per day.
                ForEach(stores) { store in
                    ForEach(store.days) { day in
                        ThreeWaysDayPoint(day: day.day, cups: day.cups, store: store.store)
                    }
                    // On the inner ForEach, so it styles a whole café's line at once.
                    .foregroundStyle(by: .value("Café", store.store))
                    .symbol(by: .value("Café", store.store))
                }
                ThreeWaysAverageRule(average: average)
            }
            // end
        }
    }
}

// snippet:three-ways-to-create-a-chart-mark
/// One day's point on a café's line. The label and value go on a Plot around the mark,
/// so VoiceOver reads "Harbour, Sunday, March 1, 190 cups" and not a range of date-times.
struct ThreeWaysDayPoint: ChartContent {
    let day: Date
    let cups: Int
    /// The café, when the chart shows more than one.
    var store: String?

    var body: some ChartContent {
        Plot {
            LineMark(
                x: .value("Day", day, unit: .day, calendar: CafeData.calendar),
                y: .value("Cups", cups)
            )
        }
        .accessibilityLabel(ThreeWaysDayPoint.label(day: day, store: store))
        .accessibilityValue(Text("^[\(cups) cup](inflect: true)"))
    }
}

// end

extension ThreeWaysDayPoint {
    /// Context first: the café, when there is more than one, then the written-out date.
    nonisolated static func label(day: Date, store: String?) -> String {
        let spokenDay = ThreeWaysFormat.spokenDay(day)
        guard let store else { return spokenDay }
        return "\(store), \(spokenDay)"
    }
}

// snippet:three-ways-to-create-a-chart-rule
/// The average across the plot. A rule is an accessibility element of its own, so it is labelled directly.
struct ThreeWaysAverageRule: ChartContent {
    let average: Int

    var body: some ChartContent {
        RuleMark(y: .value("Average", average))
            .foregroundStyle(Color.secondary)
            .accessibilityLabel("Average")
            .accessibilityValue(Text("^[\(average) cup](inflect: true)"))
            // The visible label; annotation views are not read, so the rule carries the words too.
            // Centred, where this week's lines leave room above the rule.
            .annotation(position: .top, alignment: .center) {
                Text("Average: \(average, format: .number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }
}

// end

/// What every chart on this screen shares: labels under the days, in the sample data's calendar and
/// time zone and fewer as the text grows; a café's colour and symbol, the same with one series or
/// several; and a value axis that fits the data, because a line far from zero does not have to include it.
struct ThreeWaysWeekStyle: ViewModifier {
    /// Every café the screen can show, in data order.
    let cafes: [String]
    /// False with one series: a fixed domain makes a legend of every café, drawn or not,
    /// and the one line is not encoded, so there is nothing for a legend to explain.
    let showsLegend: Bool
    /// The cups axis, off zero, shared with the descriptor.
    let valueDomain: ClosedRange<Double>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer labels as the text grows, so they do not collide: every day, every second day, one a week.
    nonisolated static func daysPerLabel(for dynamicTypeSize: DynamicTypeSize) -> Int {
        if dynamicTypeSize >= .accessibility3 { return 7 }
        if dynamicTypeSize >= .xxLarge { return 2 }
        return 1
    }

    func body(content: Content) -> some View {
        content
            .chartXAxis {
                AxisMarks(values: .stride(
                    by: .day, count: Self.daysPerLabel(for: dynamicTypeSize), calendar: CafeData.calendar
                )) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: ThreeWaysFormat.weekday, centered: true)
                }
            }
            // Fixed domains: the scales do not depend on which cafés the chart on screen happens to draw.
            .chartForegroundStyleScale(domain: cafes, mapping: CafeSeriesStyle.colour(for:))
            .chartSymbolScale(domain: cafes, mapping: CafeSeriesStyle.symbol(for:))
            .chartLegend(showsLegend ? .automatic : .hidden)
            .chartYScale(domain: valueDomain)
    }
}

/// The chart for the Audio Graph: a title, a summary in actual values, written-out dates,
/// a named line per café, and values said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ThreeWaysChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ThreeWaysSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let stores = summary.stores
        let allDays = stores.flatMap(\.days).map(\.day)
        let days = Set(allDays).sorted()
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map(ThreeWaysFormat.spokenDay)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in ThreeWaysFormat.cupsText(count) } }
        let series = stores.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: true,
                dataPoints: store.days.map { AXDataPoint(x: ThreeWaysFormat.spokenDay($0.day), y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold per day at \(summary.storeNames)",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "start-here/three-ways-to-create-a-chart") {
            ThreeWaysToCreateAChartScreen(screen: screen)
        }
    }
}

#Preview("Mistake, several series") {
    let viewModel = ThreeWaysToCreateAChartViewModel()
    viewModel.seriesCount = .several
    viewModel.isShowingMistake = true
    return ThreeWaysChart(viewModel: viewModel)
        .padding()
}

#Preview("No sales") {
    ThreeWaysChart(viewModel: ThreeWaysToCreateAChartViewModel(stores: []))
}
