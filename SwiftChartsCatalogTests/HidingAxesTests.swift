import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct HidingAxesTests {
    private let english = Locale(identifier: "en_US")

    // MARK: View model

    @Test("Given a new screen, when it opens, then both axes are shown and only the hiding code is listed")
    func startsWithBothAxes() {
        let model = HidingAxesViewModel()
        #expect(!model.hidesXAxis)
        #expect(!model.hidesYAxis)
        #expect(model.snippets.map(\.name) == ["hiding-axes-hide"])
    }

    @Test("Given each combination of toggles, when the snippets are listed, then each hidden axis adds its replacement", arguments: [
        (false, false, ["hiding-axes-hide"]),
        (true, false, ["hiding-axes-hide", "hiding-axes-values"]),
        (false, true, ["hiding-axes-hide", "hiding-axes-names"]),
        (true, true, ["hiding-axes-hide", "hiding-axes-values", "hiding-axes-names"]),
    ])
    func snippetsFollowToggles(hidesX: Bool, hidesY: Bool, expected: [String]) {
        let model = HidingAxesViewModel()
        model.hidesXAxis = hidesX
        model.hidesYAxis = hidesY
        #expect(model.snippets.map(\.name) == expected)
    }

    @Test("Given the x axis hidden, when its note is read, then it says what went and that values are on the bars")
    func xAxisNoteFollowsToggle() {
        let model = HidingAxesViewModel()
        #expect(model.xAxisNote.contains("grid line"))
        #expect(!model.xAxisNote.hasPrefix("Gone"))
        model.hidesXAxis = true
        #expect(model.xAxisNote.hasPrefix("Gone: the cups scale"))
        #expect(model.xAxisNote.contains("value written at its end"))
    }

    @Test("Given the y axis hidden, when its note is read, then it says the names went and are written on the bars")
    func yAxisNoteFollowsToggle() {
        let model = HidingAxesViewModel()
        #expect(model.yAxisNote == "Each drink's name above its bar, and a line between the rows.")
        model.hidesYAxis = true
        #expect(model.yAxisNote.hasPrefix("Gone: the drink names"))
        #expect(model.yAxisNote.contains("inside its bar"))
    }

    @Test("Given the app's bundle, when the snippets are read, then every name the screen lists exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for reference in [HidingAxesSnippets.hide, HidingAxesSnippets.values, HidingAxesSnippets.names] {
            let snippet = try #require(store[reference.name])
            #expect(snippet.file == "Axes/HidingAxesScreen.swift")
        }
        #expect(store["hiding-axes-hide"]?.code.contains("chartXAxis") == true)
        #expect(store["hiding-axes-hide"]?.code.contains("chartYAxis") == true)
    }

    // MARK: Words

    @Test("Given the sample sales, when the headline is written, then it names the best seller and its cups")
    func headlineNamesBestSeller() {
        let summary = HidingAxesSummary(sales: CafeData.drinkSales, locale: english)
        #expect(summary.headline == "Tea sold the most: 164 cups.")
        #expect(summary.total == 551)
    }

    @Test("Given a tie for most, when the headline is written, then both drinks are named")
    func headlineOnTie() {
        let sales = [DrinkSales(drink: "Tea", cups: 10), DrinkSales(drink: "Latte", cups: 10)]
        #expect(HidingAxesSummary(sales: sales, locale: english).headline == "Tea and Latte sold the most: 10 cups.")
    }

    @Test("Given one cup as the most, when the headline is written, then the count agrees in number")
    func headlineAgreesInNumber() {
        let sales = [DrinkSales(drink: "Tea", cups: 1), DrinkSales(drink: "Latte", cups: 0)]
        #expect(HidingAxesSummary(sales: sales, locale: english).headline == "Tea sold the most: 1 cup.")
    }

    @Test("Given no data or only zeros, when the words are written, then they say nothing was sold", arguments: [
        [DrinkSales](),
        [DrinkSales(drink: "Tea", cups: 0), DrinkSales(drink: "Latte", cups: 0)],
    ])
    func emptyData(sales: [DrinkSales]) {
        let summary = HidingAxesSummary(sales: sales, locale: english)
        #expect(summary.total == 0)
        #expect(summary.headline == "No cups sold yet today.")
        #expect(summary.audioGraphSummary == "No cups sold yet today.")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let sales = [DrinkSales(drink: "Tea", cups: 1200)]
        #expect(HidingAxesSummary(sales: sales, locale: Locale(identifier: "de_DE")).headline.contains("1.200"))
    }

    // MARK: Descriptor

    @Test("Given the sample sales, when the descriptor is made, then it has the title, summary, axes and series")
    func descriptor() throws {
        let descriptor = HidingAxesChartDescriptor(sales: CafeData.drinkSales, locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.drink)
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha", "Cocoa", "Americano"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The longest bar is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(164) == "164 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 5)
    }
}
