import Accessibility
import Charts
import SwiftUI

/// "Ranges as values": a range of dates as a bar's x value, so each bar is exactly as wide as its period,
/// for periods that are not calendar units.
struct RangesAsValuesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = RangesAsValuesViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: summary.caption,
            message: summary.headline,
            explanation: summary.explanation,
            snippets: viewModel.snippets
        ) {
            RangesAsValuesChart(summary: summary)
        } controls: {
            RangesAsValuesControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.period) {
            // The data and the scale change with the period: say so, then the new headline.
            AccessibilityNotification.Announcement(viewModel.summary(locale: locale).announcement).post()
        }
    }
}

/// The period picker.
struct RangesAsValuesControls: View {
    @Bindable var viewModel: RangesAsValuesViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Period", selection: $viewModel.period) {
                ForEach(RangesAsValuesPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
        }
    }
}

/// One bar per period, each spanning its range of dates; a placeholder when nothing was ordered.
struct RangesAsValuesChart: View {
    let summary: RangesAsValuesSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room at each end of the time axis for the centred first and last hour labels, growing with the text.
    @ScaledMetric(relativeTo: .caption) private var endLabelRoom = RangesAsValuesChartMetrics.endLabelRoom

    /// The room kept at each end of the time axis, capped: uncapped, it grew to a fifth of the plot's width at
    /// the largest text size and squeezed the 24 half-hour bars to hairlines.
    private var cappedEndLabelRoom: CGFloat {
        min(endLabelRoom, RangesAsValuesChartMetrics.largestEndLabelRoom)
    }

    /// Fewer hour labels as the text grows, so they do not collide. Every stride divides 6 am.
    private var hoursPerLabel: Int {
        if dynamicTypeSize >= .accessibility1 { return 6 }
        if dynamicTypeSize >= .xxLarge { return 3 }
        return 2
    }

    var body: some View {
        if summary.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "cup.and.saucer",
                description: Text("Orders appear here, one bar per period of the day.")
            )
        } else {
            // snippet:ranges-as-values-chart
            Chart(summary.bars) { bar in
                Plot {
                    BarMark(
                        // A range of dates as the x value: the bar spans exactly start ..< end,
                        // whether that is half an hour or three and a half hours.
                        x: .value(CafeWording.slot, bar.time),
                        y: .value(CafeWording.orders, bar.orders),
                        // Neighbouring periods a hairline apart.
                        width: .inset(1)
                    )
                }
                .accessibilityLabel(summary.label(bar))
                .accessibilityValue(summary.orders(bar.orders))
            }
            // end
            .chartXAxis {
                // The times were recorded in UTC: the axis marks and labels the hours in that calendar.
                // Labels centred on their hour, so 6 pm at the trailing edge is labelled too.
                AxisMarks(preset: .aligned, values: .stride(by: .hour, count: hoursPerLabel, calendar: CafeData.calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: summary.locale, timeZone: CafeData.calendar.timeZone).hour()
                    )
                }
            }
            // Room at each end for the centred first and last hour labels.
            .chartXScale(range: .plotDimension(padding: cappedEndLabelRoom))
            .chartYAxis {
                // Two values at the accessibility sizes, so the value labels take less of the width the bars need.
                if dynamicTypeSize.isAccessibilitySize {
                    AxisMarks(values: [summary.valueDomain.lowerBound, summary.valueDomain.upperBound])
                } else {
                    AxisMarks()
                }
            }
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(RangesAsValuesChartDescriptor(summary: summary))
        }
    }
}

/// Constants that belong to this chart's axis.
private enum RangesAsValuesChartMetrics {
    /// Points kept free at each end of the time axis at the default text size, about half the width of "6 PM".
    static let endLabelRoom: CGFloat = 18
    /// The most room kept at each end, whatever the text size.
    static let largestEndLabelRoom: CGFloat = 32
}

/// The chart for the Audio Graph: one category per bar, named with its times, and orders said with their unit.
nonisolated struct RangesAsValuesChartDescriptor: AXChartDescriptorRepresentable {
    let summary: RangesAsValuesSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let bars = summary.bars
        let locale = summary.locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.slot, categoryOrder: bars.map(summary.label))
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.orders,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.orders(_:locale:)) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.orders,
            isContinuous: false,
            dataPoints: bars.map { AXDataPoint(x: summary.label($0), y: Double($0.orders)) }
        )
        return AXChartDescriptor(
            title: summary.title,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Ranges as values") {
    NavigationStack {
        if let screen = Catalog.screen(id: "data/ranges-as-values") {
            RangesAsValuesScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    RangesAsValuesChart(summary: RangesAsValuesSummary(bars: [], period: .halfHour, locale: .current))
}
