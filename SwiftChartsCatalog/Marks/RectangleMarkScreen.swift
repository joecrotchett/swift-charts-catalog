import Accessibility
import Charts
import SwiftUI

/// "Rectangle": `RectangleMark` as a shaded region behind points, and as a tick on a bar's band.
struct RectangleMarkScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = RectangleMarkViewModel()
    /// The one locale the screen's words are written in: the headline here, and the charts read the same value.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption,
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            RectangleMarkChart(viewModel: viewModel)
        } controls: {
            RectangleMarkControls(viewModel: viewModel)
        }
        // Either control redraws the chart, so either one is said aloud.
        .onChange(of: viewModel.announcement(locale: locale)) { _, announcement in
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// The chart for the use the controls have chosen.
struct RectangleMarkChart: View {
    let viewModel: RectangleMarkViewModel

    var body: some View {
        switch viewModel.use {
        case .region:
            OrderRegionChart(orders: viewModel.orders, region: viewModel.region, bounds: viewModel.bounds)
        case .tick:
            MonthlyTickChart(months: viewModel.months)
        }
    }
}

/// Which use is shown and, for the region, which axes bound it.
struct RectangleMarkControls: View {
    @Bindable var viewModel: RectangleMarkViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "RectangleMark as", selection: $viewModel.use) {
                ForEach(RectangleUse.allCases) { use in
                    Text(use.rawValue).tag(use)
                }
            }
            if viewModel.showsBoundsControl {
                LabeledSegmentedPicker(title: "Region bounded on", selection: $viewModel.bounds) {
                    ForEach(RegionBounds.allCases) { bounds in
                        Text(bounds.rawValue).tag(bounds)
                    }
                }
            }
        }
    }
}

/// Sizes and strengths that belong to this screen's marks.
private enum RectangleMarkStyle {
    /// Faint enough that the points in front stay the most prominent thing.
    static let regionOpacity = 0.2
    /// The share of a month's band the range bar and its tick both take.
    static let bandRatio: CGFloat = 0.6
    /// The tick's height in points, the same whatever the scale.
    static let tickHeight: CGFloat = 2
    static let rangeOpacity = 0.3
}

/// A scatter of orders with a shaded region behind them, or a placeholder when there are no orders.
struct OrderRegionChart: View {
    let orders: [OrderWait]
    let region: OrderRegion
    let bounds: RegionBounds
    @Environment(\.locale) private var locale

    private var summary: OrderRegionSummary {
        OrderRegionSummary(orders: orders, region: region, bounds: bounds, locale: locale)
    }

    var body: some View {
        if orders.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "person.3",
                description: Text("Each order appears here as a point: the queue it joined and how long it waited.")
            )
        } else {
            // snippet:rectangle-region-layer
            Chart {
                // First in the chart, so the region is drawn behind the points.
                Plot {
                    shadedRegion
                }
                .foregroundStyle(Color.gray.opacity(RectangleMarkStyle.regionOpacity))
                .accessibilityLabel(summary.regionLabel)
                .accessibilityValue(summary.regionValue)

                ForEach(summary.portions) { portion in
                    // One element for each café's orders in a stretch of queue lengths.
                    Plot {
                        // A clear band the full height of the plot over the stretch: every element then has the
                        // same top, so they are visited along the queue axis, not by the highest wait in each.
                        RectangleMark(
                            xStart: .value(CafeWording.queueAxisTitle, Double(portion.queue.lowerBound)),
                            xEnd: .value(CafeWording.queueAxisTitle, Double(portion.queue.upperBound))
                        )
                        .foregroundStyle(.clear)
                        ForEach(portion.orders) { order in
                            PointMark(
                                x: .value(CafeWording.queueAxisTitle, Double(order.queueLength)),
                                y: .value("Wait", order.waitSeconds)
                            )
                        }
                        .foregroundStyle(by: .value("Café", portion.store))
                        .symbol(by: .value("Café", portion.store))
                    }
                    .accessibilityLabel(portion.label)
                    .accessibilityValue(portion.value)
                }
            }
            // end
            // Each café in its colour and shape on every screen that draws the two.
            .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
            .chartSymbolScale(mapping: CafeSeriesStyle.symbol(for:))
            .chartXAxisLabel(CafeWording.queueAxisTitle)
            .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
            // Both axes worked out once, for the chart and the descriptor.
            .chartXScale(domain: summary.queueDomain)
            .chartYScale(domain: summary.waitDomain)
            .accessibilityChartDescriptor(OrderRegionChartDescriptor(orders: orders, region: region, bounds: bounds, locale: locale))
        }
    }

    /// The region, with an interval on each axis that bounds it and nothing on the others.
    @ChartContentBuilder
    private var shadedRegion: some ChartContent {
        switch bounds {
        case .xOnly:
            // snippet:rectangle-region-x
            // An interval on x and nothing on y: a band the full height of the plot.
            RectangleMark(
                xStart: .value("Queue from", region.queueStart),
                xEnd: .value("Queue to", region.queueEnd)
            )
        // end
        case .yOnly:
            // snippet:rectangle-region-y
            // An interval on y and nothing on x: a band the full width of the plot.
            RectangleMark(
                yStart: .value("Wait from", region.wait.lowerBound),
                yEnd: .value("Wait to", region.wait.upperBound)
            )
        // end
        case .both:
            // snippet:rectangle-region-both
            // An interval on both axes: a box.
            RectangleMark(
                xStart: .value("Queue from", region.queueStart),
                xEnd: .value("Queue to", region.queueEnd),
                yStart: .value("Wait from", region.wait.lowerBound),
                yEnd: .value("Wait to", region.wait.upperBound)
            )
            // end
        }
    }
}

/// Each month's range of daily cups as a faint bar, with a tick at its average day.
struct MonthlyTickChart: View {
    let months: [MonthlySummary]
    /// The calendar the months were made in, so a month is cut where the data cut it.
    var calendar = CafeData.calendar
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer month labels at the accessibility text sizes, so they do not collide.
    private var monthsPerLabel: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    var body: some View {
        // What is spoken is written in the locale the axis is drawn in.
        let summary = MonthlyTickSummary(months: months, locale: locale)
        if summary.hasData {
            Chart(months) { month in
                // snippet:rectangle-tick
                Plot {
                    BarMark(
                        x: .value("Month", month.month, unit: .month, calendar: calendar),
                        yStart: .value("Lowest day", month.lowestDay),
                        yEnd: .value("Highest day", month.highestDay),
                        width: .ratio(RectangleMarkStyle.bandRatio)
                    )
                    .opacity(RectangleMarkStyle.rangeOpacity)
                    // The same x value and the same width as the bar, so the tick sits on its band.
                    // A fixed height keeps it a thin line whatever the scale.
                    RectangleMark(
                        x: .value("Month", month.month, unit: .month, calendar: calendar),
                        y: .value("Average day", month.averageDay),
                        width: .ratio(RectangleMarkStyle.bandRatio),
                        height: .fixed(RectangleMarkStyle.tickHeight)
                    )
                }
                // end
                .accessibilityLabel(RectangleMarkText.monthAndYear(month.month, locale: locale))
                .accessibilityValue(summary.value(for: month))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: monthsPerLabel, calendar: calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, timeZone: calendar.timeZone).month(.abbreviated),
                        // Centred only while every month is labelled: a label centred between two
                        // axis marks two months apart would sit between two months' bars.
                        centered: monthsPerLabel == 1
                    )
                }
            }
            .yAxisTitle(CafeWording.cupsAxisTitle)
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(MonthlyTickChartDescriptor(months: months, locale: locale))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each month's lowest, highest and average day appear here.")
            )
        }
    }
}

/// The scatter plot for the Audio Graph: a number on both axes and a series for each café.
/// The region is not a series, so the summary states it.
nonisolated struct OrderRegionChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [OrderWait]
    let region: OrderRegion
    let bounds: RegionBounds
    /// The locale the chart is drawn in, so what is heard matches what is read.
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let summary = OrderRegionSummary(orders: orders, region: region, bounds: bounds, locale: locale)
        let xAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.queueAxisTitle,
            range: summary.queueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.people) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.waitAxisTitle,
            range: summary.waitDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.seconds) }
        let series = summary.stores.map { store in
            AXDataSeriesDescriptor(
                name: store,
                isContinuous: false,
                dataPoints: orders.filter { $0.store == store }.map { order in
                    AXDataPoint(x: Double(order.queueLength), y: Double(order.waitSeconds))
                }
            )
        }
        return AXChartDescriptor(
            title: "Queue and wait for each order, by café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

/// The monthly chart for the Audio Graph: written-out months, and a series for each of the three figures.
nonisolated struct MonthlyTickChartDescriptor: AXChartDescriptorRepresentable {
    let months: [MonthlySummary]
    /// The locale the chart is drawn in, so what is heard matches the axis.
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let names = months.map { RectangleMarkText.monthAndYear($0.month, locale: locale) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.month, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: MonthlyTickSummary(months: months, locale: locale).valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let figures: [(name: String, value: KeyPath<MonthlySummary, Int>)] = [
            ("Lowest day", \.lowestDay), ("Average day", \.averageDay), ("Highest day", \.highestDay),
        ]
        let series = figures.map { figure in
            AXDataSeriesDescriptor(
                name: figure.name,
                isContinuous: false,
                dataPoints: zip(names, months).map { name, month in
                    AXDataPoint(x: name, y: Double(month[keyPath: figure.value]))
                }
            )
        }
        return AXChartDescriptor(
            title: CafeWording.monthlyRangesCaption,
            summary: MonthlyTickSummary(months: months, locale: locale).audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Rectangle") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/rectangle") {
            RectangleMarkScreen(screen: screen)
        }
    }
}

#Preview("Region, both axes") {
    OrderRegionChart(orders: CafeData.orderWaits, region: .sample, bounds: .both)
        .padding()
}

#Preview("Tick") {
    MonthlyTickChart(months: CafeData.monthlySummaries)
        .padding()
}

#Preview("No data") {
    OrderRegionChart(orders: [], region: .sample, bounds: .xOnly)
}
