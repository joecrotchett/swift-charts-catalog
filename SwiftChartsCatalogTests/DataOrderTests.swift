import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DataOrderTests {
    private let english = Locale(identifier: "en_US")

    private func model(sorted: Bool = false, reversed: Bool = false, orders: [DrinkOrder] = CafeData.drinkOrders) -> DataOrderViewModel {
        let viewModel = DataOrderViewModel(orders: orders)
        viewModel.sortsByTotal = sorted
        viewModel.reversesScaleDomain = reversed
        return viewModel
    }

    // MARK: State

    @Test("Given a new screen, when it opens, then the rows and the domain are in data order")
    func startsInDataOrder() {
        let viewModel = DataOrderViewModel()

        #expect(!viewModel.sortsByTotal)
        #expect(!viewModel.reversesScaleDomain)
        #expect(viewModel.drawnOrders == CafeData.drinkOrders)
        #expect(viewModel.drinkOrder == ["Latte", "Tea", "Mocha"])
        #expect(viewModel.stackOrder == ["Small", "Medium", "Large"])
        #expect(viewModel.legendOrder == ["Small", "Medium", "Large"])
    }

    @Test("Given the sort, when it is on, then the bars are ranked and the stacks and legend stay")
    func sortingMovesOnlyTheBars() {
        let viewModel = model(sorted: true)

        #expect(viewModel.drinkOrder == ["Tea", "Latte", "Mocha"])
        #expect(viewModel.totals.map(\.cups) == [164, 128, 92])
        #expect(viewModel.stackOrder == ["Small", "Medium", "Large"])
        #expect(viewModel.legendOrder == ["Small", "Medium", "Large"])
    }

    @Test("Given the reversed domain, when it is on, then only the legend's order changes")
    func reversingMovesOnlyTheLegend() {
        let viewModel = model(reversed: true)

        #expect(viewModel.legendOrder == ["Large", "Medium", "Small"])
        #expect(viewModel.scaleDomain == ["Large", "Medium", "Small"])
        #expect(viewModel.drinkOrder == ["Latte", "Tea", "Mocha"])
        #expect(viewModel.stackOrder == ["Small", "Medium", "Large"])
        #expect(viewModel.sizesInDataOrder == ["Small", "Medium", "Large"])
    }

    @Test("Given a tie in totals, when sorted, then the tied drinks keep the order of the data")
    func tiesKeepDataOrder() {
        let orders = [
            DrinkOrder(drink: "Cocoa", size: "Small", cups: 5),
            DrinkOrder(drink: "Tea", size: "Small", cups: 9),
            DrinkOrder(drink: "Latte", size: "Small", cups: 5),
        ]

        #expect(DataOrderViewModel.sortedByTotal(orders).map(\.drink) == ["Tea", "Cocoa", "Latte"])
    }

    @Test("Given the drawn rows, when segments are made, then only each drink's last row tops its stack")
    func topOfStackIsTheLastRow() {
        let tops = model(sorted: true).segments.filter(\.isTopOfStack)

        #expect(tops.map(\.id) == ["Tea-Large", "Latte-Large", "Mocha-Large"])
        #expect(model().segments.count == 9)
    }

    // MARK: Words

    @Test("Given each setting, when the headline is read, then it names the bars' order and the most cups")
    func headlineFollowsTheBars() {
        #expect(model().headline(locale: english, layoutDirection: .leftToRight) == "Latte, Tea, and Mocha, from left to right. Tea sold the most: 164 cups.")
        #expect(model(sorted: true).headline(locale: english, layoutDirection: .leftToRight) == "Tea, Latte, and Mocha, from left to right. Tea sold the most: 164 cups.")
        #expect(model(reversed: true).headline(locale: english, layoutDirection: .leftToRight) == model().headline(locale: english, layoutDirection: .leftToRight))
    }

    @Test("Given a tie for the most, when the headline is read, then it names both, with each")
    func headlineOnATie() {
        let orders = [DrinkOrder(drink: "Tea", size: "Small", cups: 1), DrinkOrder(drink: "Latte", size: "Small", cups: 1)]

        #expect(model(orders: orders).headline(locale: english, layoutDirection: .leftToRight) == "Tea and Latte, from left to right. Tea and Latte sold the most: 1 cup each.")
    }

    @Test("Given no rows or only zeros, when the words are read, then they say nothing was ordered")
    func emptyAndZero() {
        let zeros = [DrinkOrder(drink: "Tea", size: "Small", cups: 0)]
        for orders in [[], zeros] {
            let viewModel = model(orders: orders)
            #expect(viewModel.isEmpty)
            #expect(viewModel.headline(locale: english, layoutDirection: .leftToRight) == "No cups ordered yet today.")
            #expect(viewModel.audioGraphSummary(locale: english) == "No cups ordered yet today.")
        }
    }

    @Test("Given the reversed domain and the sort, when the summary is read, then it states both orders as drawn")
    func audioGraphSummaryStatesTheOrders() {
        #expect(model(sorted: true, reversed: true).audioGraphSummary(locale: english) == """
        3 drinks, 384 cups in total. In order: Tea 164 cups, Latte 128 cups, and Mocha 92 cups. \
        Each bar stacks Small, Medium, and Large from the bottom up. The legend lists Large, Medium, and Small.
        """)
    }

    @Test("Given a German locale, when the headline is read, then its number is written the German way")
    func headlineTakesTheLocale() {
        let orders = [DrinkOrder(drink: "Tea", size: "Small", cups: 1200)]

        #expect(model(orders: orders).headline(locale: Locale(identifier: "de_DE"), layoutDirection: .leftToRight).contains("1.200 cups"))
    }

    @Test("Given a right-to-left layout, when the headline and announcements are read, then the bars run from right to left")
    func rightToLeftNamesTheDirection() {
        let sorted = model(sorted: true)
        let headline = sorted.headline(locale: english, layoutDirection: .rightToLeft)

        #expect(headline == "Tea, Latte, and Mocha, from right to left. Tea sold the most: 164 cups.")
        #expect(sorted.sortAnnouncement(locale: english, layoutDirection: .rightToLeft).hasSuffix(headline))
        #expect(sorted.domainAnnouncement(locale: english, layoutDirection: .rightToLeft).hasSuffix(headline))
        #expect(!sorted.audioGraphSummary(locale: english).contains("left"))
    }

    @Test("Given each control, when it changes, then the announcement says what changed and then the headline")
    func announcements() {
        let sorted = model(sorted: true)
        #expect(sorted.sortAnnouncement(locale: english, layoutDirection: .leftToRight) == "Rows sorted by total; the bars moved. \(sorted.headline(locale: english, layoutDirection: .leftToRight))")
        #expect(model().sortAnnouncement(locale: english, layoutDirection: .leftToRight).hasPrefix("Rows back in data order; the bars moved. "))

        let reversed = model(reversed: true)
        #expect(reversed.domainAnnouncement(locale: english, layoutDirection: .leftToRight) == """
        Legend now lists Large, Medium, and Small; the bars and stacks did not move. \(reversed.headline(locale: english, layoutDirection: .leftToRight))
        """)
    }

    // MARK: Descriptor

    @Test("Given the sorted, reversed chart, when its descriptor is made, then it has the drawn axes and a series per size")
    func descriptor() throws {
        let viewModel = model(sorted: true, reversed: true)
        let descriptor = DataOrderChartDescriptor(
            title: "Cups sold today, by drink and size",
            summary: viewModel.audioGraphSummary(locale: english),
            drinks: viewModel.drinkOrder,
            sizes: viewModel.legendOrder,
            segments: viewModel.segments,
            highestTotal: viewModel.highestTotal,
            locale: english
        ).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today, by drink and size")
        #expect(descriptor.summary == viewModel.audioGraphSummary(locale: english))
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(xAxis?.title == "Drink")
        #expect(xAxis?.categoryOrder == ["Tea", "Latte", "Mocha"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        // The tallest stack is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Large", "Medium", "Small"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 3 && !$0.isContinuous })
    }

    // MARK: Snippets

    @Test("Given each setting, when the snippets are listed, then they follow the controls and exist in the bundle")
    func snippetsFollowTheControls() throws {
        #expect(model().snippets.map(\.name) == ["data-order-chart"])
        #expect(model(sorted: true).snippets.map(\.name) == ["data-order-chart", "data-order-sort"])
        #expect(model(reversed: true).snippets.map(\.name) == ["data-order-chart", "data-order-domain"])

        let store = try SnippetStore()
        for reference in model(sorted: true, reversed: true).snippets {
            #expect(store[reference.name] != nil)
        }
    }
}
