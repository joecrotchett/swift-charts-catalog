import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct AxisStylingTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given a new screen, when nothing is toggled, then every axis mark is at its default")
    func startsAtDefaults() {
        let viewModel = AxisStylingViewModel()
        #expect(viewModel.style == AxisStylingStyle())
        #expect(viewModel.snippets(at: .large).map(\.name) == [
            "axis-styling-grid-default", "axis-styling-tick-default", "axis-styling-label-default",
        ])
    }

    @Test("Given dashed grid lines, when the snippets are listed, then the grid line's is the dashed one")
    func dashedGridSnippet() {
        let viewModel = AxisStylingViewModel()
        viewModel.style.dashedGridLines = true
        #expect(viewModel.snippets(at: .large).first?.name == "axis-styling-grid-dashed")
    }

    @Test("Given orange grid lines, when the snippets are listed, then the grid line's is the orange one")
    func orangeGridSnippet() {
        let viewModel = AxisStylingViewModel()
        viewModel.style.orangeGridLines = true
        #expect(viewModel.snippets(at: .large).first?.name == "axis-styling-grid-orange")
    }

    @Test("Given dashed and orange grid lines, when the snippets are listed, then one snippet shows both")
    func dashedOrangeGridSnippet() {
        let viewModel = AxisStylingViewModel()
        viewModel.style.dashedGridLines = true
        viewModel.style.orangeGridLines = true
        #expect(viewModel.snippets(at: .large).first?.name == "axis-styling-grid-dashed-orange")
    }

    @Test("Given longer ticks, when the snippets are listed, then the tick's is the long one")
    func longTickSnippet() {
        let viewModel = AxisStylingViewModel()
        viewModel.style.longTicks = true
        #expect(viewModel.snippets(at: .large).map(\.name) == [
            "axis-styling-grid-default", "axis-styling-tick-long", "axis-styling-label-default",
        ])
    }

    @Test("Given a text size from extra large up, when the style is drawn, then the names are vertical whatever the toggle says")
    func largeTextTurnsNames() {
        let viewModel = AxisStylingViewModel()
        #expect(viewModel.style.drawn(at: .large).verticalLabels == false)
        #expect(viewModel.style.drawn(at: .xLarge).verticalLabels == true)
        #expect(viewModel.style.drawn(at: .accessibility5).verticalLabels == true)
        #expect(viewModel.snippets(at: .accessibility1).last?.name == "axis-styling-label-vertical")
        viewModel.style.boldLabels = true
        #expect(viewModel.snippets(at: .xxxLarge).last?.name == "axis-styling-label-bold-vertical")
        #expect(viewModel.style.verticalLabels == false)
    }

    @Test("Given each label setting, when the snippets are listed, then the label's matches it")
    func labelSnippets() {
        let cases: [(bold: Bool, vertical: Bool, name: String)] = [
            (false, false, "axis-styling-label-default"),
            (true, false, "axis-styling-label-bold"),
            (false, true, "axis-styling-label-vertical"),
            (true, true, "axis-styling-label-bold-vertical"),
        ]
        for item in cases {
            let style = AxisStylingStyle(boldLabels: item.bold, verticalLabels: item.vertical)
            #expect(AxisStylingViewModel.snippets(for: style).last?.name == item.name)
        }
    }

    @Test("Given every combination of toggles, when the snippets are listed, then each one exists in the bundle")
    func everySnippetExists() throws {
        let store = try SnippetStore()
        for bits in 0 ..< 32 {
            let style = AxisStylingStyle(
                dashedGridLines: bits & 1 != 0, orangeGridLines: bits & 2 != 0, longTicks: bits & 4 != 0,
                boldLabels: bits & 8 != 0, verticalLabels: bits & 16 != 0
            )
            for snippet in AxisStylingViewModel.snippets(for: style) {
                #expect(store[snippet.name] != nil, "missing \(snippet.name)")
            }
        }
    }

    @Test("Given the sample sales, when the headline is written, then it names the tallest bar and its cups")
    func headline() {
        let summary = AxisStylingSummary(sales: CafeData.drinkSales, locale: english)
        #expect(summary.headline == "Tea sold the most: 164 cups.")
    }

    @Test("Given a tie for the most, when the headline is written, then it names both drinks")
    func headlineTie() {
        let sales = [DrinkSales(drink: "Tea", cups: 40), DrinkSales(drink: "Latte", cups: 40)]
        #expect(AxisStylingSummary(sales: sales, locale: english).headline == "Tea and Latte sold the most: 40 cups.")
    }

    @Test("Given one cup sold, when the headline is written, then the count agrees in number")
    func headlineSingular() {
        let sales = [DrinkSales(drink: "Tea", cups: 1)]
        #expect(AxisStylingSummary(sales: sales, locale: english).headline == "Tea sold the most: 1 cup.")
    }

    @Test("Given no sales or only zeros, when the headline is written, then it says nothing sold and nothing is drawn")
    func headlineEmpty() {
        for sales in [[], [DrinkSales(drink: "Tea", cups: 0)]] {
            let summary = AxisStylingSummary(sales: sales, locale: english)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
            #expect(summary.hasSales == false)
        }
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineLocale() {
        let sales = [DrinkSales(drink: "Tea", cups: 1200)]
        #expect(AxisStylingSummary(sales: sales, locale: Locale(identifier: "de_DE")).headline == "Tea sold the most: 1.200 cups.")
    }

    @Test("Given the sample sales, when the descriptor is made, then it has the title, summary, axes and one point per drink")
    func descriptor() throws {
        let descriptor = AxisStylingChartDescriptor(sales: CafeData.drinkSales, locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha", "Cocoa", "Americano"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        // The tallest bar is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(128) == "128 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 5)
    }
}
