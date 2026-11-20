import Accessibility
import Charts
import SwiftUI

/// "Range bar": a floating bar from each month's lowest day to its highest, with a tick at an average day.
struct RangeBarScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = RangeBarViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: CafeWording.monthlyRangesCaption,
            message: viewModel.summary(locale: locale).headline,
            explanation: """
            A range bar floats: BarMark takes yStart and yEnd in place of y, so each bar runs from the month's \
            quietest day to its busiest and its length is the gap between them. A RectangleMark two points high, \
            at the same x and the same width, marks an average day inside the bar.
            """,
            snippets: viewModel.snippets
        ) {
            RangeBarChart(months: viewModel.months)
        }
    }
}

/// The sizes of this chart's marks.
private enum RangeBarMetrics {
    /// The share of a month's band the bar and its tick both take, so they line up.
    static let widthRatio: CGFloat = 0.6
    /// The range is faint, so the tick inside it can be seen.
    static let rangeOpacity = 0.3
    /// The tick's height in points: a thin line whatever the scale.
    static let tickHeight: CGFloat = 2
}

/// One floating bar per month, or a placeholder when there is nothing to draw.
struct RangeBarChart: View {
    let months: [MonthlySummary]
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The calendar the months were counted in. The marks and the axis both cut their months in it.
    private let calendar = CafeData.calendar

    var body: some View {
        let summary = RangeBarSummary(months: months, locale: locale)
        if summary.hasData {
            // snippet:range-bar-marks
            Chart(months) { month in
                // Both marks in one Plot: one accessibility element per month, saying all three values.
                Plot {
                    // yStart and yEnd in place of y: the bar floats from the low value to the high one.
                    BarMark(
                        x: .value(CafeWording.month, month.month, unit: .month, calendar: calendar),
                        yStart: .value(RangeBarWording.lowestDay, month.lowestDay),
                        yEnd: .value(RangeBarWording.highestDay, month.highestDay),
                        width: .ratio(RangeBarMetrics.widthRatio)
                    )
                    .opacity(RangeBarMetrics.rangeOpacity)
                    // The same x and width as the bar, and a fixed height: a tick across it.
                    RectangleMark(
                        x: .value(CafeWording.month, month.month, unit: .month, calendar: calendar),
                        y: .value(RangeBarWording.averageDay, month.averageDay),
                        width: .ratio(RangeBarMetrics.widthRatio),
                        height: .fixed(RangeBarMetrics.tickHeight)
                    )
                }
                .accessibilityLabel(summary.elementLabel(month))
                .accessibilityValue(summary.elementValue(month))
            }
            // end
            // snippet:range-bar-axis
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, calendar: calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    // Every month is labelled, so each label can sit under the middle of its bar.
                    AxisValueLabel(format: monthFormat, centered: true)
                }
            }
            // end
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(RangeBarChartDescriptor(months: months, locale: locale))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each month's quietest and busiest day appear here, one bar per month.")
            )
        }
    }

    /// The month's short name in the view's locale and the data's time zone; its initial at the
    /// accessibility text sizes, where six short names no longer fit side by side.
    private var monthFormat: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(dynamicTypeSize.isAccessibilitySize ? .narrow : .abbreviated)
    }
}

/// The chart for the Audio Graph: a series each for the lowest, average and highest day, over the months.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct RangeBarChartDescriptor: AXChartDescriptorRepresentable {
    let months: [MonthlySummary]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = RangeBarSummary(months: months, locale: locale)
        let names = months.map { summary.elementLabel($0) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.month, categoryOrder: names)
        // The drawn scale, from zero.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) { count, _ in summary.cupsText(count) } }
        return AXChartDescriptor(
            title: "Cups a day at the Harbour café: each month's lowest, average and highest day",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [
                series(RangeBarWording.lowestDay, names: names, value: \.lowestDay),
                series(RangeBarWording.averageDay, names: names, value: \.averageDay),
                series(RangeBarWording.highestDay, names: names, value: \.highestDay),
            ]
        )
    }

    /// One value per month: separate bars, not a connected line.
    private func series(_ name: String, names: [String], value: KeyPath<MonthlySummary, Int>) -> AXDataSeriesDescriptor {
        AXDataSeriesDescriptor(
            name: name,
            isContinuous: false,
            dataPoints: zip(names, months).map { AXDataPoint(x: $0, y: Double($1[keyPath: value])) }
        )
    }
}

#Preview("Six months") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/range-bar") {
            RangeBarScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    RangeBarChart(months: [])
}
