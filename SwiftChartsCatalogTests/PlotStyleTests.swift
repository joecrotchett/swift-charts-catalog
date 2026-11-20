import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct PlotStyleTests {
    private let english = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    @Test("Given a new screen, when it opens, then the plot area is styled")
    func startsStyled() {
        #expect(PlotStyleViewModel().isStyled)
    }

    @Test("Given drink sales, when the view model takes them, then the bars are ranked from most cups to fewest")
    func barsAreRanked() {
        let viewModel = PlotStyleViewModel(sales: sales)

        #expect(viewModel.sales.map(\.drink) == ["Tea", "Latte", "Cocoa"])
    }

    @Test("Given two drinks tied, when they are ranked, then they keep the data's order")
    func tieKeepsDataOrder() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Cocoa", cups: 40), DrinkSales(drink: "Tea", cups: 90)]

        #expect(PlotStyleSummary.ranked(tied).map(\.drink) == ["Mocha", "Tea", "Cocoa"])
    }

    @Test("Given the plot area styled or not, when the headline is written, then it is the same and names the top bar")
    func toggleKeepsHeadline() {
        let viewModel = PlotStyleViewModel(sales: sales)
        let styled = PlotStyleSummary(sales: viewModel.sales, locale: english).headline
        viewModel.isStyled = false
        let plain = PlotStyleSummary(sales: viewModel.sales, locale: english).headline

        #expect(styled == "Tea sold the most: 164 cups.")
        #expect(plain == styled)
        #expect(viewModel.sales.first?.drink == "Tea")
    }

    @Test("Given two drinks tied for the most cups, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Cocoa", cups: 40)]

        #expect(PlotStyleSummary(sales: tied, locale: english).headline == "Mocha and Tea sold the most: 90 cups.")
    }

    @Test("Given no sales or only zeros, when the words are written, then they say nothing sold and the chart is empty")
    func emptyAndZeroSaySo() {
        for rows in [[], [DrinkSales(drink: "Tea", cups: 0), DrinkSales(drink: "Latte", cups: 0)]] {
            let summary = PlotStyleSummary(sales: rows, locale: english)

            #expect(summary.isEmpty)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
        }
    }

    @Test("Given one cup, when the headline and summary are written, then the counts agree in number")
    func cupsAgreeInNumber() {
        let summary = PlotStyleSummary(sales: [DrinkSales(drink: "Tea", cups: 1)], locale: english)

        #expect(summary.headline == "Tea sold the most: 1 cup.")
        #expect(summary.audioGraphSummary == "1 drink, 1 cup in total. Most: Tea, 1 cup. Fewest: Tea, 1 cup.")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let summary = PlotStyleSummary(sales: [DrinkSales(drink: "Tea", cups: 1200)], locale: Locale(identifier: "de_DE"))

        #expect(summary.headline == "Tea sold the most: 1.200 cups.")
    }

    @Test("Given drink sales, when the Audio Graph summary is written, then it gives actual values")
    func summaryGivesActualValues() {
        #expect(
            PlotStyleSummary(sales: sales, locale: english).audioGraphSummary
                == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups."
        )
    }

    @Test("Given ranked sales, when the chart descriptor is made, then it names the axes, the series and the ranked categories")
    func descriptorDescribesTheChart() throws {
        let ranked = PlotStyleSummary.ranked(sales)
        let descriptor = PlotStyleChartDescriptor(sales: ranked, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == PlotStyleSummary(sales: ranked, locale: english).audioGraphSummary)
        #expect(xAxis.title == CafeWording.drink)
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Cocoa"])
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The drawn axis: 164 cups rounds up to 200, the same domain the chart is given.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(164) == "164 cups")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 3)
    }

    @Test("Given the app's snippets, when the screen's are looked up, then each exists and shows chartPlotStyle")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for name in PlotStyleViewModel.snippetNames {
            let snippet = try #require(store[name])
            #expect(snippet.code.contains("chartPlotStyle"))
            #expect(snippet.code.contains(".border("))
        }
    }
}
