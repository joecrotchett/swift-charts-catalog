import Accessibility
import SwiftUI

/// One named series for a descriptor: its categories in order, each with a count of cups.
nonisolated struct DashboardDescribedSeries {
    let name: String
    let values: [(category: String, cups: Int)]
}

/// The Audio Graph of the per-day chart: one continuous series per café or drink over the written-out days,
/// on the chart's own value domain.
nonisolated struct DashboardCupsPerDayDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let categories: [String]
    let series: [DashboardDescribedSeries]
    let cupsDomain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: categories),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: cupsDomain, gridlinePositions: []) { value in
                CafeWording.count(value, locale: locale)
            },
            additionalAxes: [],
            series: series.map { series in
                AXDataSeriesDescriptor(
                    name: series.name,
                    isContinuous: true,
                    dataPoints: series.values.map { AXDataPoint(x: $0.category, y: Double($0.cups)) }
                )
            }
        )
    }
}

/// The Audio Graph of the drink mix: one series of separate totals, a bar per drink.
nonisolated struct DashboardDrinkMixDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let bars: [(drink: String, cups: Int)]
    let domain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        return AXChartDescriptor(
            title: title,
            summary: summary,
            // Categories go on the descriptor's x axis whichever way the bars are drawn.
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: bars.map(\.drink)),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: domain, gridlinePositions: []) { value in
                CafeWording.count(value, locale: locale)
            },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.cups,
                isContinuous: false,
                dataPoints: bars.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )]
        )
    }
}

/// The Audio Graph of the weekday heat map, which has none by default: one series per row over the weekdays.
nonisolated struct DashboardWeekdayDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let categories: [String]
    let series: [DashboardDescribedSeries]
    let cupsDomain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.weekday, categoryOrder: categories),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: cupsDomain, gridlinePositions: []) { value in
                CafeWording.count(value, locale: locale)
            },
            additionalAxes: [],
            series: series.map { series in
                AXDataSeriesDescriptor(
                    name: series.name,
                    isContinuous: false,
                    dataPoints: series.values.map { AXDataPoint(x: $0.category, y: Double($0.cups)) }
                )
            }
        )
    }
}
