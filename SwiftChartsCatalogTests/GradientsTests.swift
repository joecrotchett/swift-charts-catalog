import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct GradientsTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the café's sales, when the screen opens, then the gradient is per mark and the bars are ranked")
    func startsPerMarkRanked() {
        let viewModel = GradientsViewModel()
        #expect(viewModel.alignment == .perMark)
        #expect(viewModel.sales.map(\.drink) == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
    }

    @Test("Given each setting, when it is passed to the modifier, then only the plot area aligns")
    func alignmentFlag() {
        #expect(GradientsAlignment.perMark.alignsWithPlotArea == false)
        #expect(GradientsAlignment.plotArea.alignsWithPlotArea == true)
    }

    @Test("Given a gradient per mark, when the headline is read, then it names the tallest and shortest bars")
    func perMarkHeadline() {
        let viewModel = GradientsViewModel()
        #expect(viewModel.summary(locale: english).headline
            == "The tops of Tea, 164 cups, and Cocoa, 57 cups, are the same red.")
    }

    @Test("Given the gradient on the plot area, when the headline is read, then colour follows height")
    func plotAreaHeadline() {
        let viewModel = GradientsViewModel()
        viewModel.alignment = .plotArea
        #expect(viewModel.summary(locale: english).headline
            == "Colour now follows height. The reddest: Tea, 164 cups. The most yellow: Cocoa, 57 cups.")
    }

    @Test("Given two drinks tied for most, when the headline is read, then both are named")
    func tiedHeadline() {
        let sales = [DrinkSales(drink: "Tea", cups: 10), DrinkSales(drink: "Latte", cups: 10), DrinkSales(drink: "Cocoa", cups: 1)]
        let viewModel = GradientsViewModel(sales: sales)
        viewModel.alignment = .plotArea
        #expect(viewModel.summary(locale: english).headline
            == "Colour now follows height. The reddest: Tea and Latte, 10 cups. The most yellow: Cocoa, 1 cup.")
    }

    @Test("Given every bar the same height, when the headline is read in each setting, then it says so")
    func equalHeadline() {
        let viewModel = GradientsViewModel(sales: [DrinkSales(drink: "Tea", cups: 1)])
        #expect(viewModel.summary(locale: english).headline
            == "Every bar runs the whole gradient, yellow at its base to red at its top.")
        viewModel.alignment = .plotArea
        #expect(viewModel.summary(locale: english).headline
            == "Every bar is 1 cup, so each shows the same stretch of the gradient.")
    }

    @Test("Given one drink with no cups, when the headline is read, then its colour sentences name only drawn bars")
    func zeroDrinkHeadline() {
        let sales = [DrinkSales(drink: "Tea", cups: 10), DrinkSales(drink: "Latte", cups: 4), DrinkSales(drink: "Cocoa", cups: 0)]
        let viewModel = GradientsViewModel(sales: sales)
        #expect(viewModel.summary(locale: english).headline
            == "The tops of Tea, 10 cups, and Latte, 4 cups, are the same red.")
        viewModel.alignment = .plotArea
        #expect(viewModel.summary(locale: english).headline
            == "Colour now follows height. The reddest: Tea, 10 cups. The most yellow: Latte, 4 cups.")
    }

    @Test("Given one drink with no cups, when the Audio Graph summary is read, then it still gives that drink's value")
    func zeroDrinkAudioGraph() {
        let sales = [DrinkSales(drink: "Tea", cups: 10), DrinkSales(drink: "Latte", cups: 4), DrinkSales(drink: "Cocoa", cups: 0)]
        let summary = GradientsViewModel(sales: sales).summary(locale: english)
        #expect(summary.audioGraphSummary
            == "3 drinks, 14 cups in total. Most: Tea, 10 cups. Fewest: Cocoa, 0 cups.")
    }

    @Test("Given one drawn bar and one drink with no cups, when the headline is read, then it treats the one bar as all the bars")
    func zeroDrinkBesideOneBar() {
        let viewModel = GradientsViewModel(sales: [DrinkSales(drink: "Tea", cups: 3), DrinkSales(drink: "Cocoa", cups: 0)])
        #expect(viewModel.summary(locale: english).headline
            == "Every bar runs the whole gradient, yellow at its base to red at its top.")
        viewModel.alignment = .plotArea
        #expect(viewModel.summary(locale: english).headline
            == "Every bar is 3 cups, so each shows the same stretch of the gradient.")
    }

    @Test("Given each setting, when the picker changes, then the announcement says what changed and then the headline")
    func announcement() {
        let viewModel = GradientsViewModel()
        viewModel.alignment = .plotArea
        #expect(viewModel.announcement(locale: english)
            == "The gradient is now laid out across the plot area. "
            + "Colour now follows height. The reddest: Tea, 164 cups. The most yellow: Cocoa, 57 cups.")
        viewModel.alignment = .perMark
        #expect(viewModel.announcement(locale: english).hasPrefix(
            "The gradient is now laid out inside each bar. The tops of Tea"
        ))
    }

    @Test("Given no data or only zeros, when the headline is read, then it says nothing sold and the chart is empty")
    func emptyHeadline() {
        for sales in [[], [DrinkSales(drink: "Tea", cups: 0)]] {
            for alignment in GradientsAlignment.allCases {
                let summary = GradientsSummary(sales: sales, alignment: alignment, locale: english)
                #expect(summary.isEmpty)
                #expect(summary.headline == "No cups sold yet today.")
                #expect(summary.audioGraphSummary == "No cups sold yet today.")
            }
        }
    }

    @Test("Given a German locale, when the headline is written, then numbers take that locale")
    func localeHeadline() {
        let summary = GradientsSummary(
            sales: [DrinkSales(drink: "Tea", cups: 1200), DrinkSales(drink: "Cocoa", cups: 3)],
            alignment: .plotArea, locale: Locale(identifier: "de_DE")
        )
        #expect(summary.headline.contains("1.200 cups"))
    }

    @Test("Given either setting, when See Code opens, then it shows the chart snippet, which exists")
    func snippets() throws {
        let viewModel = GradientsViewModel()
        let store = try SnippetStore()
        for alignment in GradientsAlignment.allCases {
            viewModel.alignment = alignment
            #expect(viewModel.snippets.map(\.name) == ["gradients-chart"])
        }
        let code = try #require(store["gradients-chart"]).code
        #expect(code.contains("alignsMarkStylesWithPlotArea"))
    }

    @Test("Given the café's sales, when the descriptor is made, then it describes the ranked bars with units")
    func descriptor() throws {
        let sales = GradientsSummary.ranked(CafeData.drinkSales)
        let descriptor = GradientsChartDescriptor(sales: sales, locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary
            == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        let yAxis = try #require(descriptor.yAxis)
        // The tallest bar is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.infinity) == "")
        #expect(descriptor.series.count == 1)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 5)
    }
}
