import Charts
import SwiftUI

/// A line per café or per drink over the 28 days. A tap on the plot selects the day under it for every
/// panel, shown here as a band; the selected drink is drawn at full strength and the rest faded.
struct DashboardCupsPerDayPanel: View {
    @Environment(DashboardModel.self) private var model
    @Environment(\.locale) private var locale

    var body: some View {
        DashboardPanel(title: "\(CafeWording.cups) per \(CafeWording.day.lowercased())", subtitle: model.cupsPerDaySubtitle()) {
            if model.isEmpty {
                ContentUnavailableView("No sales", systemImage: "cup.and.saucer", description: Text("Cups per day appear here."))
            } else {
                // Everything the chart draws is read here, in the body, and handed in as plain values.
                DashboardCupsPerDayChart(
                    points: model.dayPoints,
                    seriesNames: model.seriesNames,
                    seriesLabel: model.breakdown.seriesLabel,
                    emphasised: model.emphasisedSeries,
                    selectedDay: model.selectedDay,
                    calendar: model.calendar,
                    dayDomain: model.dayDomain,
                    cupsDomain: model.cupsDomain,
                    labels: model.dayPoints.map { (model.dayPointLabel($0, locale: locale), model.dayPointValue($0, locale: locale)) },
                    descriptor: model.cupsPerDayDescriptor(locale: locale),
                    select: { model.selectDay($0) }
                )
                .id(model.cupsPerDayIdentity)
            }
        }
    }
}

private struct DashboardCupsPerDayChart: View {
    let points: [DashboardDayPoint]
    let seriesNames: [String]
    let seriesLabel: String
    let emphasised: Set<String>
    let selectedDay: Date?
    let calendar: Calendar
    let dayDomain: ClosedRange<Date>
    let cupsDomain: ClosedRange<Double>
    let labels: [(label: String, value: String)]
    let descriptor: DashboardCupsPerDayDescriptor
    let select: (Date?) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var chartHeight = DashboardLayout.chartHeight
    @ScaledMetric(relativeTo: .caption) private var topPadding = DashboardLayout.valueAxisEndPadding

    /// Month and day, or the day alone at the largest sizes, where "Mar 22" no longer fits four times.
    private var dayLabelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        return dynamicTypeSize >= .accessibility3 ? style.day() : style.month().day()
    }

    var body: some View {
        Chart {
            if let selectedDay {
                DashboardSelectedDayBand(day: selectedDay, calendar: calendar)
            }
            ForEach(Array(zip(points, labels)), id: \.0.id) { point, text in
                // One element per day holding every series, read in date order.
                Plot {
                    ForEach(point.values) { value in
                        LineMark(
                            x: .value(CafeWording.day, point.day, unit: .day, calendar: calendar),
                            y: .value(CafeWording.cups, value.cups)
                        )
                        .foregroundStyle(by: .value(seriesLabel, value.series))
                        .symbol(by: .value(seriesLabel, value.series))
                        .symbolSize(DashboardLayout.lineSymbolSize)
                        .opacity(emphasised.contains(value.series) ? 1 : DashboardLayout.fadedOpacity)
                    }
                }
                .accessibilityLabel(text.label)
                .accessibilityValue(text.value)
            }
        }
        .chartXScale(domain: dayDomain)
        .chartYScale(domain: cupsDomain, range: .plotDimension(endPadding: min(topPadding, DashboardLayout.valueAxisEndPaddingCap)))
        .chartForegroundStyleScale(domain: seriesNames, mapping: DashboardSeriesStyle.colour(for:))
        .chartSymbolScale(domain: seriesNames, mapping: DashboardSeriesStyle.symbol(for:))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7, calendar: calendar)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: dayLabelFormat)
            }
        }
        .chartYAxis {
            // Light grid lines on an interactive chart; the labels stay at secondary.
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(DashboardLayout.gridLineOpacity))
                AxisValueLabel().foregroundStyle(Color.secondary)
            }
        }
        // The selection is the model's. A tap selects the day under it and keeps it after the finger lifts;
        // the built-in press would clear it on lift, and with it every other panel's view of that day.
        .chartXSelection(value: Binding(get: { selectedDay }, set: { select($0) }))
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { tap in
                    proxy.selectXValue(at: tap.location.x)
                }
        }
        .accessibilityChartDescriptor(descriptor)
        .accessibilityIdentifier("dashboard-cups-per-day")
        .frame(height: chartHeight)
    }
}

#Preview {
    ScrollView {
        DashboardCupsPerDayPanel()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environment(DashboardModel())
}
