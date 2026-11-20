import Accessibility
import CoreGraphics
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct PlotHeightTests {
    private let english = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    // MARK: Height

    @Test("Given a row count and a row height, when the plot's height is worked out, then it is one row height per row")
    func plotHeightIsRowsTimesRowHeight() {
        #expect(PlotHeightViewModel.plotHeight(rows: 6, rowHeight: 44) == 264)
        #expect(PlotHeightViewModel.plotHeight(rows: 1, rowHeight: 44) == 44)
        #expect(PlotHeightViewModel.plotHeight(rows: 12, rowHeight: 44) == 528)
    }

    @Test("Given no rows, when the plot's height is worked out, then it is zero and never negative")
    func plotHeightOfNoRowsIsZero() {
        #expect(PlotHeightViewModel.plotHeight(rows: 0, rowHeight: 44) == 0)
        #expect(PlotHeightViewModel.plotHeight(rows: -2, rowHeight: 44) == 0)
    }

    @Test("Given the stepper at each row count, when the model's plot height is read, then it grows by one row height per step")
    func modelHeightFollowsTheStepper() {
        let model = PlotHeightViewModel()
        for rows in model.rowRange {
            model.rowCount = rows
            #expect(model.shownSales.count == rows)
            #expect(model.plotHeight(rowHeight: 44) == CGFloat(rows) * 44)
        }
    }

    @Test("Given a larger text size, when the plot's height is worked out, then the scaled row height is what is multiplied")
    func plotHeightUsesTheScaledRowHeight() {
        let model = PlotHeightViewModel(rowCount: 4)

        #expect(model.plotHeight(rowHeight: 66) == 264)
        #expect(model.plotHeightText(rowHeight: 66, locale: english) == "264 points")
    }

    @Test("Given one row and a one-point row height, when the height is written out, then the count agrees in number")
    func plotHeightTextAgreesInNumber() {
        let model = PlotHeightViewModel(sales: sales, rowCount: 1)

        #expect(model.plotHeightText(rowHeight: 1, locale: english) == "1 point")
    }

    // MARK: Rows

    @Test("Given the menu, when the model is made, then it offers one to twelve rows and starts at five")
    func rowRangeCoversTheMenu() {
        let model = PlotHeightViewModel()

        #expect(model.rowRange == 1 ... 12)
        #expect(model.rowCount == 5)
        #expect(model.shownSales.count == 5)
    }

    @Test("Given drinks in any order, when rows are shown, then they are the best sellers, most cups first")
    func rowsAreRankedBestFirst() {
        let model = PlotHeightViewModel(sales: sales, rowCount: 2)

        #expect(model.shownSales.map(\.drink) == ["Tea", "Latte"])
    }

    @Test("Given drinks with the same cups, when they are ranked, then they keep name order")
    func tiesRankByName() {
        let tied = [DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Mocha", cups: 90)]

        #expect(PlotHeightSummary.ranked(tied).map(\.drink) == ["Mocha", "Tea"])
    }

    @Test("Given the menu, when it is read, then it keeps the café's five drinks with their counts and adds seven")
    func menuExtendsTheSampleData() {
        #expect(PlotHeightMenu.drinks.count == 12)
        #expect(Array(PlotHeightMenu.drinks.prefix(5)) == CafeData.drinkSales)
        #expect(Set(PlotHeightMenu.drinks.map(\.drink)).count == 12)
    }

    @Test("Given no drinks, when the model is made, then it offers one row, draws none and has no height")
    func emptyMenuHasNoHeight() {
        let model = PlotHeightViewModel(sales: [], rowCount: 5)

        #expect(model.rowRange == 1 ... 1)
        #expect(model.shownSales.isEmpty)
        #expect(model.plotHeight(rowHeight: 44) == 0)
    }

    // MARK: Words

    @Test("Given five rows of the menu, when the headline is written, then it counts the rows and names the best seller")
    func headlineCountsRowsAndNamesBest() {
        let model = PlotHeightViewModel()

        #expect(model.summary(locale: english).headline == "Of 5 drinks shown, Tea sold the most: 164 cups.")
    }

    @Test("Given one row, when the headline is written, then the count agrees in number")
    func headlineAgreesInNumber() {
        let model = PlotHeightViewModel(rowCount: 1)

        #expect(model.summary(locale: english).headline == "Of 1 drink shown, Tea sold the most: 164 cups.")
    }

    @Test("Given two drinks tied for the most, when the headline is written, then it names both")
    func headlineNamesTies() {
        let tied = [DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Cocoa", cups: 40)]
        let model = PlotHeightViewModel(sales: tied, rowCount: 3)

        #expect(model.summary(locale: english).headline == "Of 3 drinks shown, Mocha and Tea sold the most: 90 cups.")
    }

    @Test("Given no sales or only zeros, when the chart's words are written, then they say nothing sold")
    func emptyAndZeroSaySo() {
        let zeros = PlotHeightSummary(sales: [DrinkSales(drink: "Tea", cups: 0)], locale: english)
        let empty = PlotHeightSummary(sales: [], locale: english)

        for summary in [zeros, empty] {
            #expect(!summary.hasCups)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
        }
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let summary = PlotHeightSummary(sales: [DrinkSales(drink: "Tea", cups: 1200)], locale: Locale(identifier: "de_DE"))

        #expect(summary.headline.contains("1.200"))
    }

    @Test("Given a row count, when the stepper's value is spoken, then it is the headline alone, since the label already gives the count")
    func stepperSpeaksHeadline() {
        let model = PlotHeightViewModel(rowCount: 3)

        #expect(model.rowCountText(locale: english) == "3")
        #expect(model.spokenRowCount(locale: english) == "Of 3 drinks shown, Tea sold the most: 164 cups.")
    }

    @Test("Given drinks, when the Audio Graph summary is written, then it gives the count, total, most and fewest")
    func audioGraphSummaryGivesValues() {
        let summary = PlotHeightSummary(sales: PlotHeightSummary.ranked(sales), locale: english)

        #expect(summary.audioGraphSummary == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
    }

    // MARK: Descriptor

    @Test("Given the shown rows, when the chart descriptor is made, then it describes those rows in drawn order as separate bars")
    func descriptorDescribesShownRows() throws {
        let shown = PlotHeightViewModel(sales: sales, rowCount: 2).shownSales
        let descriptor = PlotHeightChartDescriptor(sales: shown, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let series = try #require(descriptor.series.first)

        #expect(descriptor.title == "Cups sold today at the Harbour café, best sellers first")
        #expect(descriptor.summary == PlotHeightSummary(sales: shown, locale: english).audioGraphSummary)
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Tea", "Latte"])
        #expect(descriptor.series.count == 1)
        #expect(series.name == "Harbour")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 2)
    }

    @Test("Given the shown rows, when the descriptor's value axis is read, then it runs from zero to the longest bar in cups")
    func descriptorValueAxisHasUnits() throws {
        let yAxis = try #require(PlotHeightChartDescriptor(sales: sales, locale: english).makeChartDescriptor().yAxis)

        #expect(yAxis.title == "Cups")
        // The drawn axis: 164 cups rounds up to 200, the same domain the chart is given.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
    }

    // MARK: Snippets

    @Test("Given any row count, when the snippets are listed, then they are the chart, the row height and the height")
    func snippetsAreTheSameForEveryRowCount() {
        let model = PlotHeightViewModel()
        let names = [
            "plot-height-from-content-chart", "plot-height-from-content-row-height", "plot-height-from-content-height",
        ]
        for rows in model.rowRange {
            model.rowCount = rows
            #expect(model.snippets.map(\.name) == names)
        }
    }

    @Test("Given the screen's snippets, when they are looked up in the bundle, then each one exists")
    func snippetsAreInTheBundle() throws {
        let store = try SnippetStore()
        for snippet in PlotHeightViewModel().snippets {
            #expect(store[snippet.name] != nil, "missing \(snippet.name)")
        }
    }
}
