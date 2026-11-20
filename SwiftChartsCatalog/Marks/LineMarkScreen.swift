import Accessibility
import Charts
import SwiftUI

/// "Line": one `LineMark` series, its interpolation, its stroke and its point symbols.
struct LineMarkScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = LineMarkViewModel()
    /// The one locale the screen's words are written in: the headline here, and the chart reads the same value.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Harbour café, cups sold per day",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            WeekLineChart(
                days: viewModel.days,
                interpolation: viewModel.interpolation,
                showsSymbols: viewModel.showsSymbols
            )
        } controls: {
            LineMarkControls(viewModel: viewModel)
        }
        // The line changes shape without its data changing; say so for people who cannot see it happen.
        .onChange(of: viewModel.drawingDescription) { _, description in
            AccessibilityNotification.Announcement(description).post()
        }
    }
}

/// The interpolation picker and the symbols switch.
private struct LineMarkControls: View {
    @Bindable var viewModel: LineMarkViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Interpolation", selection: $viewModel.interpolation) {
                ForEach(LineInterpolation.allCases) { interpolation in
                    Text(interpolation.title).tag(interpolation)
                }
            }
            Toggle("Symbols on the points", isOn: $viewModel.showsSymbols)
        }
    }
}

/// Constants that belong to this chart's marks.
private enum LineMetrics {
    static let lineWidth: CGFloat = 3
    /// A symbol's area in square points.
    static let symbolArea: CGFloat = 70
    /// Room kept free above the highest point, so its symbol is not drawn against the plot's edge.
    static let topPadding: CGFloat = 8
}

// snippet:line-mark
/// One point of the sales line. Marks with no series and no `by:` encoding join into a single line.
struct SalesLinePoint: ChartContent {
    let day: DailySales
    let method: InterpolationMethod

    var body: some ChartContent {
        LineMark(
            // The days were counted in UTC, so the unit is cut in that calendar, not the device's.
            x: .value("Day", day.day, unit: .day, calendar: CafeData.calendar),
            y: .value("Cups", day.cups)
        )
        // How the line travels between its points.
        .interpolationMethod(method)
        // The StrokeStyle replaces the line's default width, cap and join, so all three are set.
        .lineStyle(StrokeStyle(lineWidth: LineMetrics.lineWidth, lineCap: .round, lineJoin: .round))
    }
}

// end

/// The week as one line, or a placeholder when there is no line to draw.
struct WeekLineChart: View {
    let days: [DailySales]
    let interpolation: LineInterpolation
    let showsSymbols: Bool
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let summary = WeekSalesSummary(days: days, locale: locale)
        if summary.hasLine {
            Chart(days) { day in
                // The label and value go on a Plot around the mark: each day is one element that reads
                // "Sunday, March 1, 162 cups", not a range of date-times and a bare number.
                Plot {
                    if showsSymbols {
                        // snippet:line-symbols
                        SalesLinePoint(day: day, method: interpolation.method)
                            // A marker on each data point. It adds no marks, so nothing is read twice.
                            .symbol(.circle)
                            // The size is an area in square points.
                            .symbolSize(LineMetrics.symbolArea)
                        // end
                    } else {
                        SalesLinePoint(day: day, method: interpolation.method)
                    }
                }
                .accessibilityLabel(summary.dayName(day.day))
                .accessibilityValue(summary.cupsText(day.cups))
            }
            // A week of sales sits far from zero; fitting the scale to the data keeps the line's shape readable.
            // The descriptor is given the same domain, so the Audio Graph's ends are the drawn ones.
            .chartYScale(
                domain: WeekSalesSummary.valueDomain(for: days),
                range: .plotDimension(endPadding: LineMetrics.topPadding)
            )
            .chartXAxis {
                // The axis is told the data's calendar too, or its marks and labels follow the device.
                AxisMarks(values: .stride(by: .day, calendar: CafeData.calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: weekdayFormat, centered: true)
                }
            }
            .accessibilityChartDescriptor(
                WeekLineChartDescriptor(
                    days: days, locale: locale,
                    drawing: interpolation.drawingDescription(showsSymbols: showsSymbols)
                )
            )
        } else {
            ContentUnavailableView(
                "No line to draw",
                systemImage: "chart.xyaxis.line",
                description: Text(summary.noLineMessage)
            )
        }
    }

    /// Weekday names in the view's locale and the data's time zone; initials at the accessibility text sizes.
    private var weekdayFormat: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
            .weekday(dynamicTypeSize.isAccessibilitySize ? .narrow : .abbreviated)
    }
}

/// The chart for the Audio Graph: a title, a summary in actual values, written-out days and cups with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct WeekLineChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let locale: Locale
    /// How the line is drawn now, in a sentence.
    let drawing: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = WeekSalesSummary(days: days, locale: locale)
        // A date axis has no descriptor type of its own: the days are categories, written out.
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.dayName($0.day) }
        )
        // The drawn scale: the domain the chart's y scale is given, which leaves out zero.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: WeekSalesSummary.valueDomain(for: days),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) { count, _ in summary.cupsText(count) } }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            // Days are an ordered, continuous measure.
            isContinuous: true,
            dataPoints: days.map { AXDataPoint(x: summary.dayName($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold per day at the Harbour café",
            summary: summary.audioGraphSummary(drawnAs: drawing),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Line") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/line") {
            LineMarkScreen(screen: screen)
        }
    }
}

#Preview("Smooth, no symbols") {
    WeekLineChart(days: LineMarkViewModel.sampleWeek, interpolation: .smooth, showsSymbols: false)
        .padding()
}

#Preview("No sales") {
    WeekLineChart(days: [], interpolation: .straight, showsSymbols: true)
}
