import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct PlottableTypesTests {
    private let english = Locale(identifier: "en_US")

    private func order(_ drink: String, _ size: String, _ cups: Int) -> DrinkOrder {
        DrinkOrder(drink: drink, size: size, cups: cups)
    }

    // MARK: The types

    @Test("Given the size enum, when its cases are read, then their raw values are the sample data's sizes")
    func sizeRawValues() {
        #expect(PlottableTypesCupSize.allCases.map(\.rawValue) == ["Small", "Medium", "Large"])
        #expect(PlottableTypesCupSize(rawValue: "Medium") == .medium)
        #expect(PlottableTypesCupSize(rawValue: "Huge") == nil)
    }

    @Test("Given a drink, when it goes to its primitive value and back, then it is the same drink")
    func drinkRoundTrips() throws {
        let tea = try #require(PlottableTypesDrink(primitivePlottable: "Tea"))

        #expect(tea.primitivePlottable == "Tea")
        #expect(PlottableTypesDrink(primitivePlottable: tea.primitivePlottable) == tea)
    }

    @Test("Given a name that is not on the menu, when a drink is made from it, then there is none")
    func unknownDrinkIsNil() {
        #expect(PlottableTypesDrink(primitivePlottable: "Cocoa") == nil)
        #expect(PlottableTypesDrink(primitivePlottable: "") == nil)
    }

    // MARK: State

    @Test("Given the sample data, when the screen opens, then every row converts, in data order")
    func convertsEverySampleRow() throws {
        let viewModel = PlottableTypesViewModel()
        let summary = viewModel.summary
        let latte = try #require(PlottableTypesDrink(primitivePlottable: "Latte"))

        #expect(viewModel.orders.count == CafeData.drinkOrders.count)
        #expect(summary.drinks.map(\.name) == ["Latte", "Tea", "Mocha"])
        #expect(summary.sizes == [.small, .medium, .large])
        #expect(viewModel.orders.first == PlottableTypesOrder(drink: latte, size: .small, cups: 34))
    }

    @Test("Given rows with an unknown drink or size, when they are converted, then only those rows are left out")
    func dropsRowsThatDoNotConvert() {
        let viewModel = PlottableTypesViewModel(drinkOrders: [
            order("Tea", "Small", 10), order("Cocoa", "Small", 99), order("Tea", "Huge", 99), order("Latte", "Large", 4),
        ])

        #expect(viewModel.orders.map(\.id) == ["Tea-Small", "Latte-Large"])
        #expect(viewModel.summary.total == 14)
    }

    @Test("Given the screen's one state, when its snippets are looked up, then each exists in the bundle")
    func snippetsExist() throws {
        let store = try SnippetStore()

        #expect(PlottableTypesViewModel.snippetNames == [
            "plottable-types-size-enum", "plottable-types-drink-struct", "plottable-types-chart",
        ])
        for name in PlottableTypesViewModel.snippetNames {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    // MARK: Derived text

    @Test("Given the sample data, when the headline is written, then it names the tallest stack and its cups")
    func headlineNamesTheBestSeller() {
        let summary = PlottableTypesViewModel().summary

        #expect(summary.highestTotal == 164)
        #expect(summary.headline(locale: english) == "Tea sold the most: 164 cups.")
    }

    @Test("Given two drinks with the same total, when the headline is written, then it names both and says the figure is each one's")
    func headlineOnATie() {
        let summary = PlottableTypesViewModel(drinkOrders: [
            order("Latte", "Small", 3), order("Latte", "Large", 2), order("Tea", "Small", 5), order("Mocha", "Small", 1),
        ]).summary

        #expect(summary.headline(locale: english) == "Latte and Tea sold the most: 5 cups each.")
    }

    @Test("Given one cup in total, when the headline is written, then the count agrees in number")
    func headlineSingular() {
        let summary = PlottableTypesViewModel(drinkOrders: [order("Mocha", "Small", 1)]).summary

        #expect(summary.headline(locale: english) == "Mocha sold the most: 1 cup.")
    }

    @Test("Given one drink in one size, when the Audio Graph summary is written, then every count agrees in number")
    func summarySingular() {
        let summary = PlottableTypesViewModel(drinkOrders: [order("Mocha", "Small", 1)]).summary

        #expect(summary.audioGraphSummary(locale: english) == "1 drink in 1 size, 1 cup in total. Most: Mocha, 1 cup. Fewest: Mocha, 1 cup.")
    }

    @Test("Given no rows or only zeros, when the chart is described, then it is empty and says so")
    func emptyAndZeroData() {
        for orders in [[], [order("Tea", "Small", 0), order("Latte", "Large", 0)]] {
            let summary = PlottableTypesViewModel(drinkOrders: orders).summary

            #expect(summary.isEmpty)
            #expect(summary.headline(locale: english) == "No cups sold yet today.")
            #expect(summary.audioGraphSummary(locale: english) == "No cups sold yet today.")
        }
    }

    @Test("Given a German locale, when the headline is written, then the number takes that locale")
    func headlineTakesTheLocale() {
        let summary = PlottableTypesViewModel(drinkOrders: [order("Tea", "Small", 1200)]).summary

        #expect(summary.headline(locale: Locale(identifier: "de_DE")) == "Tea sold the most: 1.200 cups.")
    }

    @Test("Given a segment, when its element text is read, then it gives drink and size, then cups")
    func elementText() throws {
        let order = try #require(PlottableTypesOrder(order("Tea", "Medium", 62)))

        #expect(PlottableTypesSummary.elementLabel(for: order) == "Tea, Medium")
        #expect(PlottableTypesSummary.elementValue(for: order, locale: english) == "62 cups")
    }

    // MARK: Chart descriptor

    @Test("Given the sample data, when the descriptor is made, then it has the drinks, a series per size and the summary")
    func descriptor() throws {
        let viewModel = PlottableTypesViewModel()
        let descriptor = PlottableTypesChartDescriptor(orders: viewModel.orders, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today, by drink and size")
        #expect(descriptor.summary == "3 drinks in 3 sizes, 384 cups in total. Most: Tea, 164 cups. Fewest: Mocha, 92 cups.")
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(xAxis?.title == "Drink")
        #expect(xAxis?.categoryOrder == ["Latte", "Tea", "Mocha"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        // The tallest stack is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Small", "Medium", "Large"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 3 })
    }
}
