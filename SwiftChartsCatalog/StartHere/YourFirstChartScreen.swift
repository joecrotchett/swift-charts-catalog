import Accessibility
import Charts
import SwiftUI

/// "Your first chart": data, `Chart`, and one `BarMark` per element.
struct YourFirstChartScreen: View {
    let screen: CatalogScreen
    /// Ranked, most first: the headline says which sold the most, and the five drinks are in this order on every
    /// screen that ranks them (`marks/bar`, `marks/sector`).
    var sales = CafeData.drinkSales.sorted { $0.cups > $1.cups }
    /// The locale the screen's words are written in, read here and passed in, so the headline, the
    /// elements and the Audio Graph write numbers the way the chart's own axis does.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: DrinkSalesSummary(sales: sales, locale: locale).headline,
            explanation: """
            A chart starts from data with one property for each thing it shows: here a drink and its cups. \
            Chart takes the collection and makes one BarMark per element. The text on y becomes the categories, \
            the number on x becomes each bar's length, and the scale, axis labels and grid lines come from the data.
            """
        ) {
            DrinkSalesChart(sales: sales, locale: locale)
        }
    }
}

/// One bar per drink, or a placeholder when nothing has been sold.
struct DrinkSalesChart: View {
    let sales: [DrinkSales]
    let locale: Locale

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no bars under a headline that is not true.
        if DrinkSalesSummary(sales: sales, locale: locale).total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            // snippet:first-chart
            Chart(sales) { item in
                // The label and value go on a Plot around the mark, so VoiceOver reads "Latte, 128 cups"
                // and not the bare "Latte, 128".
                Plot {
                    BarMark(
                        x: .value(CafeWording.cups, item.cups),
                        y: .value(CafeWording.drink, item.drink)
                    )
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            // end
            // One value axis for the chart and the Audio Graph: the descriptor reads the ends the chart draws.
            .chartXScale(domain: DrinkSalesSummary.valueDomain(for: sales))
            .accessibilityChartDescriptor(DrinkSalesChartDescriptor(sales: sales, locale: locale))
        }
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct DrinkSalesSummary {
    let sales: [DrinkSales]
    /// The locale every count and list is written in. It has no default: the view passes its environment's.
    let locale: Locale

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// The cups axis as drawn, from zero to the most rounded up to the axis step: the chart's scale and the
    /// descriptor's range.
    static func valueDomain(for sales: [DrinkSales]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    /// Every drink that sold the most, in data order. More than one when there is a tie.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order.
    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The chart's message in a sentence, carrying the key value. True on a tie, and when nothing sold.
    var headline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(names(bestSellers)) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(names(bestSellers)), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(names(slowestSellers)), \(CafeWording.cups(fewest, locale: locale))."
    }

    /// "Tea", "Mocha and Tea": joined the English way, as the sentence around it is English.
    func names(_ drinks: [DrinkSales]) -> String {
        CafeWording.list(drinks.map(\.drink))
    }
}

/// The chart for the Audio Graph: a title, a summary, named axes, and values said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct DrinkSalesChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = DrinkSalesSummary(sales: sales, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: sales.map(\.drink)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: DrinkSalesSummary.valueDomain(for: sales),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today at the Harbour café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Sales") {
    NavigationStack {
        if let screen = Catalog.screen(id: "start-here/your-first-chart") {
            YourFirstChartScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    DrinkSalesChart(sales: [], locale: .current)
}
