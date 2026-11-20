import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct OwnLegendTests {
    private let english = Locale(identifier: "en_US")

    private func model(_ rows: [(String, String, Int)]) -> OwnLegendViewModel {
        OwnLegendViewModel(orders: rows.map { DrinkOrder(drink: $0.0, size: $0.1, cups: $0.2) })
    }

    // MARK: State

    @Test("Given a new screen, when it opens, then the app's own legend is drawn")
    func startsWithOwnLegend() {
        #expect(OwnLegendViewModel().isShowingOwnLegend)
    }

    @Test("Given the café's orders, when the totals are read, then each size has its cups across the drinks")
    func totalsBySize() {
        let viewModel = OwnLegendViewModel()

        #expect(viewModel.total(for: .small) == 127)
        #expect(viewModel.total(for: .medium) == 161)
        #expect(viewModel.total(for: .large) == 96)
        #expect(viewModel.totalCups == 384)
        #expect(viewModel.drinks == ["Latte", "Tea", "Mocha"])
        #expect(viewModel.tallestBar == 164)
    }

    @Test("Given a row whose size is not one of the three, when the model is made, then the row is left out")
    func unknownSizeIsDropped() {
        let viewModel = model([("Tea", "Small", 5), ("Tea", "Huge", 9)])

        #expect(viewModel.orders.count == 1)
        #expect(viewModel.totalCups == 5)
    }

    @Test("Given rows in any size order, when the model is made, then each drink's rows follow the colour scale's order and the drinks keep theirs")
    func rowsFollowScaleOrder() {
        let viewModel = model([
            ("Tea", "Large", 3), ("Tea", "Small", 1), ("Latte", "Medium", 5), ("Tea", "Medium", 2), ("Latte", "Small", 4),
        ])

        #expect(viewModel.orders.map(\.id) == ["Tea-Small", "Tea-Medium", "Tea-Large", "Latte-Small", "Latte-Medium"])
        #expect(viewModel.drinks == ["Tea", "Latte"])
        #expect(OwnLegendViewModel().orders.map(\.size) == Array(repeating: OwnLegendSize.allCases, count: 3).flatMap(\.self))
    }

    // MARK: Explanation

    @Test("Given the app's legend beside the bars, when the explanation is written, then it says the legend is beside them")
    func explanationBeside() {
        let text = OwnLegendViewModel().explanation(isBesideBars: true)

        #expect(text.contains("beside the bars, in room the x scale's end padding keeps clear."))
        #expect(!text.contains("automatic legend below"))
    }

    @Test("Given the app's legend above the bars at a large text size, when the explanation is written, then it says the legend is above them")
    func explanationAbove() {
        let text = OwnLegendViewModel().explanation(isBesideBars: false)

        #expect(text.contains("above the bars, in room the y scale's end padding keeps clear"))
        #expect(!text.contains("beside the bars, in room"))
    }

    @Test("Given the switch off, when the explanation is written, then it describes the automatic legend, not the app's")
    func explanationAutomatic() {
        let viewModel = OwnLegendViewModel()
        viewModel.isShowingOwnLegend = false
        for isBesideBars in [true, false] {
            let text = viewModel.explanation(isBesideBars: isBesideBars)

            #expect(text.contains("shows the automatic legend below the bars"))
            #expect(!text.contains("This one lists"))
        }
    }

    @Test("Given no cups, when the explanation is written, then it states the technique and describes no legend as drawn")
    func explanationEmpty() {
        let text = model([]).explanation(isBesideBars: true)

        #expect(text.contains("foregroundStyleDomain"))
        #expect(!text.contains("This one lists"))
        #expect(!text.contains("automatic legend below"))
    }

    // MARK: Headline

    @Test("Given the app's legend, when the headline is written, then it gives the best size's cups, which the legend shows")
    func headlineWithOwnLegend() {
        #expect(OwnLegendViewModel().headline(locale: english) == "Medium cups sold the most: 161 cups.")
    }

    @Test("Given the automatic legend, when the headline is written, then it names the size without a figure the chart does not show")
    func headlineWithAutomaticLegend() {
        let viewModel = OwnLegendViewModel()
        viewModel.isShowingOwnLegend = false

        #expect(viewModel.headline(locale: english) == "Medium cups sold the most.")
    }

    @Test("Given two sizes tied for the most cups, when the headline is written, then it names both")
    func tieNamesBoth() {
        let viewModel = model([("Tea", "Small", 40), ("Tea", "Medium", 40), ("Tea", "Large", 10)])

        #expect(viewModel.bestSizes == [.small, .medium])
        #expect(viewModel.headline(locale: english) == "Small and Medium cups sold the most: 40 cups each.")
        viewModel.isShowingOwnLegend = false
        #expect(viewModel.headline(locale: english) == "Small and Medium cups sold the most.")
    }

    @Test("Given no orders, when the words are written, then the chart is a placeholder and both say nothing sold")
    func emptySaysSo() {
        let viewModel = model([])

        #expect(!viewModel.hasCups)
        #expect(viewModel.headline(locale: english) == "No cups sold yet today.")
        #expect(viewModel.audioGraphSummary(locale: english) == "No cups sold yet today.")
    }

    @Test("Given orders that are all zero, when the words are written, then no size is said to have sold the most")
    func allZeroSaysSo() {
        let viewModel = model([("Tea", "Small", 0), ("Latte", "Large", 0)])

        #expect(!viewModel.hasCups)
        #expect(viewModel.bestSizes.isEmpty)
        #expect(viewModel.headline(locale: english) == "No cups sold yet today.")
    }

    @Test("Given one cup, when the headline and legend are written, then the counts agree in number")
    func countsAgreeInNumber() {
        let viewModel = model([("Tea", "Small", 1)])

        #expect(viewModel.headline(locale: english) == "Small cups sold the most: 1 cup.")
        #expect(viewModel.legendEntry(for: .small, locale: english) == "Small, 1 cup")
        #expect(viewModel.legendEntry(for: .large, locale: english) == "Large, 0 cups")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let viewModel = model([("Tea", "Medium", 1200)])

        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")).contains("1.200"))
    }

    // MARK: The legend's words

    @Test("Given the sizes in the order the legend draws them, when its spoken value is written, then it follows that order, name first")
    func legendSpokenInDrawnOrder() {
        let value = OwnLegendViewModel().legendSpokenValue(sizes: [.large, .medium, .small], locale: english)

        #expect(value == "Large, 96 cups; Medium, 161 cups; Small, 127 cups")
    }

    @Test("Given each setting of the toggle, when the change is announced, then it says what changed and then the headline")
    func announcementFollowsToggle() {
        let viewModel = OwnLegendViewModel()

        #expect(viewModel.announcement(locale: english)
            == "Legend drawn by the app, in stacking order with each size's cups. Medium cups sold the most: 161 cups.")
        viewModel.isShowingOwnLegend = false
        #expect(viewModel.announcement(locale: english) == "Automatic legend. Medium cups sold the most.")
    }

    // MARK: Snippets

    @Test("Given each setting of the toggle, when the snippets are listed, then the legend's code is shown only while it is drawn")
    func snippetsFollowToggle() {
        let viewModel = OwnLegendViewModel()

        #expect(viewModel.snippets.map(\.name) == ["a-legend-of-your-own-chart", "a-legend-of-your-own-key"])
        viewModel.isShowingOwnLegend = false
        #expect(viewModel.snippets.map(\.name) == ["a-legend-of-your-own-chart"])
    }

    @Test("Given the built app, when the snippet store loads, then every snippet the screen names exists")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for reference in [OwnLegendViewModel.chartSnippet, OwnLegendViewModel.keySnippet] {
            let snippet = try #require(store[reference.name])
            #expect(snippet.file == "Legend/OwnLegendScreen.swift")
        }
        #expect(store[OwnLegendViewModel.keySnippet.name]?.code.contains("foregroundStyleDomain") == true)
        let chartCode = try #require(store[OwnLegendViewModel.chartSnippet.name]?.code)
        #expect(chartCode.contains("chartLegend(showsOwnLegend ? .hidden : .automatic)"))
        for name in ["let showsOwnLegend", "let isRightToLeft", "let xRoom", "let yRoom"] {
            #expect(chartCode.contains(name), "the snippet uses but does not show \(name)")
        }
    }

    // MARK: Audio Graph

    @Test("Given the café's orders, when the Audio Graph summary is written, then it gives actual values by size")
    func summaryGivesValues() {
        #expect(OwnLegendViewModel().audioGraphSummary(locale: english)
            == "3 drinks, 384 cups in total. By size: Small, 127 cups; Medium, 161 cups; Large, 96 cups. Most: Medium, 161 cups.")
    }

    @Test("Given the café's orders, when the descriptor is made, then there is one named series of separate bars per size over the drinks")
    func descriptorHasSeriesPerSize() throws {
        let viewModel = OwnLegendViewModel()
        let descriptor = OwnLegendChartDescriptor(viewModel: viewModel, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(descriptor.title == "Cups sold today, by drink and size")
        #expect(descriptor.summary == viewModel.audioGraphSummary(locale: english))
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha"])
        #expect(descriptor.series.map(\.name) == ["Small", "Medium", "Large"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 3 })
    }

    @Test("Given the café's orders, when the descriptor's value axis is read, then it runs from zero to the tallest bar and says cups")
    func descriptorValueAxis() throws {
        let yAxis = try #require(OwnLegendChartDescriptor(viewModel: OwnLegendViewModel(), locale: english)
            .makeChartDescriptor().yAxis)

        #expect(yAxis.title == "Cups")
        // The tallest stack is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(58) == "58 cups")
    }
}
