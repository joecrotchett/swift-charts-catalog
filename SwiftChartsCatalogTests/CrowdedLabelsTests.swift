import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct CrowdedLabelsTests {
    private let english = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 42),
        DrinkSales(drink: "Hot chocolate", cups: 21),
        DrinkSales(drink: "Espresso", cups: 7),
    ]

    // MARK: View model

    @Test("Given a new screen, when it opens, then the axis truncates, the chart is full width, and it draws the menu")
    func defaults() {
        let model = CrowdedLabelsViewModel()

        #expect(model.resolution == .truncate)
        #expect(model.widthFraction == 1)
        #expect(model.sales == CrowdedLabelsData.menu)
    }

    @Test("Given each resolution, when the snippets are listed, then the bars come first and that resolution's axis second", arguments: CrowdedLabelsResolution.allCases)
    func snippetsFollowResolution(resolution: CrowdedLabelsResolution) {
        let model = CrowdedLabelsViewModel()
        model.resolution = resolution

        #expect(model.snippets.map(\.name) == ["crowded-labels-chart", "crowded-labels-\(resolution.rawValue)"])
    }

    @Test("Given the app's bundle, when the snippets are read, then every region the screen can show exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [CrowdedLabelsViewModel.chartSnippet.name] + CrowdedLabelsResolution.allCases.map(\.snippetName)

        for name in names {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    @Test("Given the greedy setting, when its snippet is read, then it shows the greedy collision resolution")
    func greedySnippetShowsTheAPI() throws {
        let store = try SnippetStore()

        #expect(try #require(store["crowded-labels-greedy"]).code.contains("collisionResolution: .greedy"))
        #expect(try #require(store["crowded-labels-vertical"]).code.contains("orientation: .vertical"))
    }

    @Test("Given a width of 60%, when the slider's text is written, then it shows and speaks the same share of the panel")
    func widthText() {
        let model = CrowdedLabelsViewModel()
        model.widthFraction = 0.6

        #expect(model.widthText(locale: english) == "60% of the panel")
        #expect(model.spokenWidth(locale: english) == model.widthText(locale: english))
    }

    @Test("Given the width range, when it is read, then the chart can be narrowed to 40% and widened to the full panel")
    func widthRange() {
        #expect(CrowdedLabelsViewModel.widthRange == 0.4 ... 1)
    }

    @Test("Given each resolution, when its note and title are read, then they are distinct and not empty")
    func resolutionWords() {
        let all = CrowdedLabelsResolution.allCases

        #expect(Set(all.map(\.title)).count == all.count)
        #expect(Set(all.map(\.note)).count == all.count)
        #expect(all.map(\.title) == ["Truncate", "Greedy", "Disabled", "Vertical"])
    }

    // MARK: Data

    @Test("Given the menu, when it is read, then it has ten drinks ranked from most to fewest cups")
    func menuIsRanked() {
        let cups = CrowdedLabelsData.menu.map(\.cups)

        #expect(cups.count == 10)
        #expect(cups == cups.sorted(by: >))
        #expect(Set(CrowdedLabelsData.menu.map(\.drink)).count == 10)
    }

    // MARK: Headline and summary

    @Test("Given drink sales, when the headline is written, then it names the best seller and its cups")
    func headlineNamesBestSeller() {
        #expect(CrowdedLabelsSummary(sales: sales, locale: english).headline == "Latte sold the most: 42 cups.")
    }

    @Test("Given the sample menu, when the headline is written, then it names the drink at the top of the scale")
    func headlineFollowsMenu() {
        #expect(CrowdedLabelsSummary(sales: CrowdedLabelsData.menu, locale: english).headline == "Latte sold the most: 42 cups.")
    }

    @Test("Given two drinks tied for the most, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [DrinkSales(drink: "Mocha", cups: 9), DrinkSales(drink: "Tea", cups: 9)]

        #expect(CrowdedLabelsSummary(sales: tied, locale: english).headline == "Mocha and Tea sold the most: 9 cups.")
    }

    @Test("Given no sales or only zeros, when the words are written, then they say nothing sold", arguments: [
        [DrinkSales](), [DrinkSales(drink: "Latte", cups: 0), DrinkSales(drink: "Tea", cups: 0)],
    ])
    func nothingSold(sales: [DrinkSales]) {
        let summary = CrowdedLabelsSummary(sales: sales, locale: english)

        #expect(summary.total == 0)
        #expect(summary.headline == "No cups sold yet today.")
        #expect(summary.audioGraphSummary == "No cups sold yet today.")
    }

    @Test("Given one cup, when the headline and summary are written, then the counts agree in number")
    func countsAgreeInNumber() {
        let summary = CrowdedLabelsSummary(sales: [DrinkSales(drink: "Tea", cups: 1)], locale: english)

        #expect(summary.headline == "Tea sold the most: 1 cup.")
        #expect(summary.audioGraphSummary == "1 drink, 1 cup in total. Most: Tea, 1 cup. Fewest: Tea, 1 cup.")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let summary = CrowdedLabelsSummary(sales: [DrinkSales(drink: "Tea", cups: 1200)], locale: Locale(identifier: "de_DE"))

        #expect(summary.headline.contains("1.200"))
    }

    @Test("Given drink sales, when the Audio Graph summary is written, then it gives the count, total, most and fewest")
    func summaryGivesActualValues() {
        #expect(
            CrowdedLabelsSummary(sales: sales, locale: english).audioGraphSummary
                == "3 drinks, 70 cups in total. Most: Latte, 42 cups. Fewest: Espresso, 7 cups."
        )
    }

    // MARK: Descriptor

    @Test("Given drink sales, when the descriptor is made, then it names the chart, the axes and one series of separate bars with full names")
    func descriptorDescribesTheChart() throws {
        let descriptor = CrowdedLabelsChartDescriptor(sales: sales, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold today at the Station café, by drink")
        #expect(descriptor.summary == "3 drinks, 70 cups in total. Most: Latte, 42 cups. Fewest: Espresso, 7 cups.")
        #expect(xAxis.title == CafeWording.drink)
        #expect(xAxis.categoryOrder == ["Latte", "Hot chocolate", "Espresso"])
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The tallest bar is 42; the axis is drawn to 60, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 60)
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.station)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 3)
    }

    @Test("Given the descriptor's value axis, when a value is described, then it is said with its unit and agrees in number")
    func descriptorValuesHaveUnits() throws {
        let descriptor = CrowdedLabelsChartDescriptor(sales: sales, locale: english).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(42) == "42 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }
}
