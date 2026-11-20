import Accessibility
import Charts
import SwiftUI

/// "One data set, three charts": the same days and cups as bars, as a line, and as a line per café.
struct OneDataSetThreeChartsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = OneDataSetThreeChartsViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption,
            message: viewModel.headline,
            explanation: """
            The form of a chart is a choice of mark. The bars and the line plot the same days and cups with the same \
            x and y values: only BarMark became LineMark, and the scales and axes stayed as they were. A line per café \
            draws every café: the café value on each mark keeps a café's marks in a line of their own, and the legend \
            comes from it.
            """,
            snippets: viewModel.snippets,
            chart: {
                ThreeFormsChart(
                    form: viewModel.form,
                    stores: viewModel.shownStores,
                    cafes: viewModel.cafes,
                    hasData: viewModel.hasData,
                    valueDomain: viewModel.valueDomain,
                    descriptor: ThreeChartsDescriptor(
                        title: viewModel.caption,
                        summary: viewModel.audioGraphSummary,
                        stores: viewModel.shownStores,
                        isContinuous: viewModel.isContinuous,
                        valueRange: viewModel.valueDomain
                    )
                )
            },
            controls: {
                ControlsSection {
                    // The binding carries the animation, so the chart changes inside it.
                    Picker("Chart form", selection: $viewModel.form.animation(.easeInOut)) {
                        ForEach(ThreeChartsForm.allCases) { form in
                            Text(form.title).tag(form)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Chart form")
                }
            }
        )
        .onChange(of: viewModel.form) {
            // Animation alone does not tell someone who cannot see it that the chart changed.
            AccessibilityNotification.Announcement(viewModel.announcement).post()
        }
    }
}

/// The chart in the chosen form, or a placeholder when there is nothing to draw.
struct ThreeFormsChart: View {
    let form: ThreeChartsForm
    /// The cafés the form draws: one for the bars and the line, all of them for a line per café.
    let stores: [StoreSales]
    /// Every café any form can draw, in data order.
    let cafes: [String]
    let hasData: Bool
    /// The cups axis, the same in every form and in the descriptor.
    let valueDomain: ClosedRange<Double>
    let descriptor: ThreeChartsDescriptor

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no marks under a headline that is not true.
        if hasData {
            Group {
                switch form {
                case .bars: DailyBarsChart(cafe: stores.first?.store ?? "", days: stores.first?.days ?? [])
                case .line: DailyLineChart(cafe: stores.first?.store ?? "", days: stores.first?.days ?? [])
                case .linePerCafe: LinePerCafeChart(stores: stores)
                }
            }
            // A fixed domain: each café keeps its colour whichever cafés the form on screen draws.
            .chartForegroundStyleScale(domain: cafes, mapping: CafeSeriesStyle.colour(for:))
            .chartYScale(domain: valueDomain)
            .chartXAxis {
                // The days were counted in the data's calendar, so the axis is told too:
                // left alone, its marks and labels follow the device's calendar and time zone.
                AxisMarks(values: .stride(by: .day, count: ThreeChartsText.daysPerWeek, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: Date.FormatStyle(timeZone: CafeData.calendar.timeZone).month().day())
                }
            }
            .accessibilityChartDescriptor(descriptor)
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here.")
            )
        }
    }
}

/// One café's days as bars.
struct DailyBarsChart: View {
    let cafe: String
    let days: [DailySales]

    var body: some View {
        // snippet:one-data-set-three-charts-bars
        Chart(days) { day in
            // The Plot carries the words VoiceOver reads for this day: "Sunday, March 1, 190 cups".
            Plot {
                BarMark(
                    x: .value("Day", day.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", day.cups)
                )
                // The café's colour comes from the colour scale, so it is the same in every form.
                .foregroundStyle(by: .value("Café", cafe))
            }
            .accessibilityLabel(ThreeChartsText.day(day.day))
            .accessibilityValue(Text("^[\(day.cups) cup](inflect: true)"))
        }
        // One café, named in the caption: a legend would also list the cafés this form leaves out.
        .chartLegend(.hidden)
        // end
    }
}

/// The same days as a line: the mark is the only thing that changed.
struct DailyLineChart: View {
    let cafe: String
    let days: [DailySales]

    var body: some View {
        // snippet:one-data-set-three-charts-line
        Chart(days) { day in
            Plot {
                // The same x and y as the bars. Only the mark is different.
                LineMark(
                    x: .value("Day", day.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", day.cups)
                )
                .foregroundStyle(by: .value("Café", cafe))
            }
            .accessibilityLabel(ThreeChartsText.day(day.day))
            .accessibilityValue(Text("^[\(day.cups) cup](inflect: true)"))
        }
        .chartLegend(.hidden)
        // end
    }
}

/// A line for each café: the same mark again, with every café's days drawn.
struct LinePerCafeChart: View {
    let stores: [StoreSales]

    var body: some View {
        // snippet:one-data-set-three-charts-line-per-cafe
        Chart {
            ForEach(stores) { store in
                // Two cafés of 28 days are too many stops a day at a time: one Plot per café per week
                // is one VoiceOver element, saying the café, the dates and the cups. The line is still one line.
                ForEach(ThreeChartsText.weeks(of: store)) { week in
                    Plot {
                        ForEach(week.days) { day in
                            LineMark(
                                x: .value("Day", day.day, unit: .day, calendar: CafeData.calendar),
                                y: .value("Cups", day.cups)
                            )
                        }
                    }
                    .accessibilityLabel(week.label)
                    .accessibilityValue(week.value)
                }
                // Encoding the café keeps each café's marks in a line of their own, and makes the legend.
                // Colour and dash pattern together, so the lines can be told apart without colour.
                .foregroundStyle(by: .value("Café", store.store))
                .lineStyle(by: .value("Café", store.store))
            }
        }
        // end
    }
}

/// The chart for the Audio Graph: a title, a summary, written-out days, cups with their unit and a
/// named series per café. Not tied to the main actor: the accessibility system calls its value
/// description when it chooses.
nonisolated struct ThreeChartsDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let stores: [StoreSales]
    /// `true` for the lines, `false` for the bars.
    let isContinuous: Bool
    /// The cups axis as drawn (`chartYScale(domain:)`), not the data's highest value.
    let valueRange: ClosedRange<Double>

    func makeChartDescriptor() -> AXChartDescriptor {
        let days = Set(stores.flatMap(\.days).map(\.day)).sorted()
        // A date axis has no descriptor type of its own: the days are categories, written out.
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map(ThreeChartsText.day)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: valueRange,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in ThreeChartsText.cups(count) } }
        let series = stores.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: isContinuous,
                dataPoints: store.days.map { AXDataPoint(x: ThreeChartsText.day($0.day), y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "start-here/one-data-set-three-charts") {
            OneDataSetThreeChartsScreen(screen: screen)
        }
    }
}

#Preview("Line per café") {
    let viewModel = OneDataSetThreeChartsViewModel(form: .linePerCafe)
    ThreeFormsChart(
        form: viewModel.form,
        stores: viewModel.shownStores,
        cafes: viewModel.cafes,
        hasData: viewModel.hasData,
        valueDomain: viewModel.valueDomain,
        descriptor: ThreeChartsDescriptor(
            title: viewModel.caption, summary: viewModel.audioGraphSummary,
            stores: viewModel.shownStores, isContinuous: viewModel.isContinuous, valueRange: viewModel.valueDomain
        )
    )
    .padding()
}

#Preview("No sales") {
    ThreeFormsChart(
        form: .bars, stores: [], cafes: [], hasData: false, valueDomain: 0 ... 1,
        descriptor: ThreeChartsDescriptor(title: "", summary: "", stores: [], isContinuous: false, valueRange: 0 ... 1)
    )
}
