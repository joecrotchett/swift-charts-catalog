import Accessibility
@testable import SwiftChartsCatalog
import Testing

struct YourFirstChartTests {
    private let english = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    @Test("Given drink sales, when the headline is written, then it names the best seller and its cups")
    func headlineNamesBestSeller() {
        #expect(DrinkSalesSummary(sales: sales, locale: english).headline == "Tea sold the most: 164 cups.")
    }

    @Test("Given the café's sample data, when the headline is written, then it is about a drink in that data")
    func headlineFollowsSampleData() {
        let best = CafeData.drinkSales.max { $0.cups < $1.cups }

        #expect(DrinkSalesSummary(sales: CafeData.drinkSales, locale: english).headline.hasPrefix(best?.drink ?? "?"))
    }

    @Test("Given two drinks tied for the most cups, when the headline is written, then it names both and stays true")
    func tieNamesBoth() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Cocoa", cups: 40)]
        let summary = DrinkSalesSummary(sales: tied, locale: english)

        #expect(summary.bestSellers.map(\.drink) == ["Mocha", "Tea"])
        #expect(summary.headline == "Mocha and Tea sold the most: 90 cups.")
    }

    @Test("Given rows that are all zero, when the chart's words are written, then they say nothing sold, not that a drink sold the most")
    func allZeroSalesSaySo() {
        let summary = DrinkSalesSummary(
            sales: [DrinkSales(drink: "Latte", cups: 0), DrinkSales(drink: "Tea", cups: 0)], locale: english
        )

        #expect(summary.total == 0)
        #expect(summary.bestSellers.isEmpty)
        #expect(summary.headline == "No cups sold yet today.")
        #expect(summary.audioGraphSummary == "No cups sold yet today.")
    }

    @Test("Given no sales, when the headline and summary are written, then both say nothing was sold")
    func emptySalesSaySo() {
        let summary = DrinkSalesSummary(sales: [], locale: english)

        #expect(summary.headline == "No cups sold yet today.")
        #expect(summary.audioGraphSummary == "No cups sold yet today.")
        #expect(summary.total == 0)
    }

    @Test("Given one cup on the best seller, when the headline and summary are written, then the counts agree in number")
    func cupsAgreeInNumber() {
        let summary = DrinkSalesSummary(sales: [DrinkSales(drink: "Tea", cups: 1)], locale: english)

        #expect(summary.headline == "Tea sold the most: 1 cup.")
        #expect(summary.audioGraphSummary == "1 drink, 1 cup in total. Most: Tea, 1 cup. Fewest: Tea, 1 cup.")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let summary = DrinkSalesSummary(sales: [DrinkSales(drink: "Tea", cups: 1200)], locale: Locale(identifier: "de_DE"))

        #expect(summary.headline.contains("1.200"))
    }

    @Test("Given drink sales, when the Audio Graph summary is written, then it gives the count, total, most and fewest in actual values")
    func summaryGivesActualValues() {
        #expect(
            DrinkSalesSummary(sales: sales, locale: english).audioGraphSummary
                == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups."
        )
    }

    @Test("Given drink sales, when the chart descriptor is made, then it has a title, a summary and one named series of separate bars")
    func descriptorDescribesTheChart() throws {
        let descriptor = DrinkSalesChartDescriptor(sales: sales, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == DrinkSalesSummary(sales: sales, locale: english).audioGraphSummary)
        #expect(descriptor.series.count == 1)
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Harbour")
        #expect(!series.isContinuous)
    }

    @Test("Given drink sales, when the chart descriptor is made, then there is a point per drink and the categories are in data order")
    func descriptorHasAPointPerDrink() throws {
        let descriptor = DrinkSalesChartDescriptor(sales: sales, locale: english).makeChartDescriptor()
        let points = try #require(descriptor.series.first).dataPoints
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Cocoa"])
        #expect(points.count == sales.count)
    }

    @Test("Given drink sales, when the descriptor's value axis is read, then it runs from zero to the drawn axis top and says values in cups")
    func descriptorValueAxisHasUnits() throws {
        let yAxis = try #require(DrinkSalesChartDescriptor(sales: sales, locale: english).makeChartDescriptor().yAxis)

        #expect(yAxis.title == "Cups")
        // 164 at most: the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.range == DrinkSalesSummary.valueDomain(for: sales))
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
    }

    @Test("Given the screen's sales, when they are read, then the drinks are ranked most first, Tea to Cocoa")
    @MainActor func screenRanksTheDrinks() throws {
        let screen = try YourFirstChartScreen(screen: #require(Catalog.screen(id: "start-here/your-first-chart")))
        #expect(screen.sales.map(\.drink) == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
    }
}
