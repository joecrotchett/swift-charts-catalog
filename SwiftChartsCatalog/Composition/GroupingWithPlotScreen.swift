import Accessibility
import Charts
import SwiftUI

/// "Grouping with Plot": the same marks and the same modifiers, applied to a `Plot` around the marks or to each mark.
struct GroupingWithPlotScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = GroupingWithPlotViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: CafeWording.monthlyRangesCaption,
            message: viewModel.headline,
            explanation: """
            Plot groups marks that are written out one by one into a single piece of chart content. \
            A modifier on the Plot applies to the group as a whole: an annotation is placed against the whole group, \
            and an accessibility label makes the group one element. \
            The same modifiers on each mark give every mark its own annotation; an accessibility label on marks \
            that share a position is not read.
            """,
            snippets: viewModel.snippets
        ) {
            MonthlyRangeChart(summary: viewModel.summary, usesPlot: viewModel.usesPlot)
        } controls: {
            GroupingWithPlotControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.usesPlot) {
            // The chart redraws its labels: say so, for people who cannot see it happen.
            AccessibilityNotification.Announcement(viewModel.announcement).post()
        }
    }
}

/// The one control: group each month's marks in a `Plot`, or not.
struct GroupingWithPlotControls: View {
    @Bindable var viewModel: GroupingWithPlotViewModel

    var body: some View {
        ControlsSection {
            Toggle("Group each month's marks in a Plot", isOn: $viewModel.usesPlot)
            Text(viewModel.settingNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// A range bar and an average tick per month, or a placeholder when there are no sales.
struct MonthlyRangeChart: View {
    let summary: MonthlyRangeSummary
    let usesPlot: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if summary.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each month's lowest, highest and average day appear here.")
            )
        } else {
            Chart {
                ForEach(summary.months) { month in
                    if usesPlot {
                        // snippet:grouping-with-plot-group
                        // The bar and the tick are one group. Each modifier is written once and applies to the
                        // group: one label above the whole group, and one accessibility element for the month.
                        Plot {
                            RangeBar(month: month)
                            AverageTick(month: month)
                        }
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .padScale)) {
                            AverageLabel(average: month.averageDay)
                        }
                        .accessibilityLabel(summary.accessibilityLabel(for: month))
                        .accessibilityValue(summary.accessibilityValue(for: month))
                        // end
                    } else {
                        // snippet:grouping-with-plot-each-mark
                        // The same modifiers on each mark: the bar gets a label above it, and so does the tick.
                        // The accessibility label and value are on two bare marks that share a month.
                        RangeBar(month: month)
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .padScale)) {
                                AverageLabel(average: month.averageDay)
                            }
                            .accessibilityLabel(summary.accessibilityLabel(for: month))
                            .accessibilityValue(summary.accessibilityValue(for: month))
                        AverageTick(month: month)
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .padScale)) {
                                AverageLabel(average: month.averageDay)
                            }
                            .accessibilityLabel(summary.accessibilityLabel(for: month))
                            .accessibilityValue(summary.accessibilityValue(for: month))
                        // end
                    }
                }
            }
            .chartXAxis {
                // The months were counted in UTC, so the axis is told the data's calendar and time zone too.
                AxisMarks(values: .stride(by: .month, count: 1, calendar: CafeData.calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    // At the accessibility text sizes a month's name no longer fits its band: use its initial.
                    AxisValueLabel(
                        format: Date.FormatStyle(timeZone: CafeData.calendar.timeZone)
                            .month(dynamicTypeSize.isAccessibilitySize ? .narrow : .abbreviated),
                        centered: true
                    )
                }
            }
            // One value axis for the chart and the descriptor, with room above the highest day for its label.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(MonthlyRangeChartDescriptor(summary: summary, usesPlot: usesPlot))
        }
    }
}

// snippet:grouping-with-plot-marks
/// A month's range: a faint bar from its lowest day to its highest.
struct RangeBar: ChartContent {
    let month: MonthlySummary

    var body: some ChartContent {
        BarMark(
            x: .value("Month", month.month, unit: .month, calendar: CafeData.calendar),
            yStart: .value("Lowest day", month.lowestDay),
            yEnd: .value("Highest day", month.highestDay),
            width: .ratio(MarkSize.widthRatio)
        )
        .opacity(MarkSize.rangeOpacity)
    }
}

/// A month's average day: a thin tick across its range bar.
struct AverageTick: ChartContent {
    let month: MonthlySummary

    var body: some ChartContent {
        RectangleMark(
            x: .value("Month", month.month, unit: .month, calendar: CafeData.calendar),
            y: .value("Average day", month.averageDay),
            width: .ratio(MarkSize.widthRatio),
            height: .fixed(MarkSize.tickHeight)
        )
    }
}

// end

/// The label an annotation shows: a month's average day.
struct AverageLabel: View {
    let average: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("avg")
            Text(average, format: .number)
                .fontWeight(.semibold)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        // A month's band is about fifty points wide on a phone: past this size the labels run into each other.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Sizes that belong to this chart's marks.
private nonisolated enum MarkSize {
    /// The bar and the tick take the same share of the month's band, so they line up.
    static let widthRatio: CGFloat = 0.6
    static let tickHeight: CGFloat = 2
    static let rangeOpacity = 0.3
}

/// The chart for the Audio Graph: the lowest, average and highest day of each month as three named series.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct MonthlyRangeChartDescriptor: AXChartDescriptorRepresentable {
    let summary: MonthlyRangeSummary
    let usesPlot: Bool

    func makeChartDescriptor() -> AXChartDescriptor {
        let months = summary.months
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.month,
            categoryOrder: months.map { summary.monthName($0) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            // The drawn value axis: from zero to the highest day rounded up.
            range: summary.valueDomain,
            gridlinePositions: []
        ) { [locale = summary.locale] value in CafeWording.count(value, locale: locale, as: MonthlyRangeSummary.cupsText) }
        return AXChartDescriptor(
            title: CafeWording.monthlyRangesCaption,
            summary: summary.audioGraphSummary(usesPlot: usesPlot),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [
                series("Lowest day", \.lowestDay),
                series("Average day", \.averageDay),
                series("Highest day", \.highestDay),
            ]
        )
    }

    private func series(_ name: String, _ value: KeyPath<MonthlySummary, Int>) -> AXDataSeriesDescriptor {
        AXDataSeriesDescriptor(
            name: name,
            // Separate range bars and ticks, one per month, not a connected line: not continuous.
            isContinuous: false,
            dataPoints: summary.months.map { AXDataPoint(x: summary.monthName($0), y: Double($0[keyPath: value])) }
        )
    }
}

#Preview("Grouping with Plot") {
    NavigationStack {
        if let screen = Catalog.screen(id: "composition/grouping-with-plot") {
            GroupingWithPlotScreen(screen: screen)
        }
    }
}

#Preview("Each mark") {
    MonthlyRangeChart(summary: MonthlyRangeSummary(months: CafeData.monthlySummaries), usesPlot: false)
        .padding()
}

#Preview("No sales") {
    MonthlyRangeChart(summary: MonthlyRangeSummary(months: []), usesPlot: true)
}
