import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DivergingBarTests {
    private let locale = Locale(identifier: "en_US")
    private let changes = [
        DrinkChange(drink: "Latte", change: 212),
        DrinkChange(drink: "Tea", change: -148),
        DrinkChange(drink: "Mocha", change: 64),
        DrinkChange(drink: "Cocoa", change: -305),
    ]

    private func summary(_ changes: [DrinkChange]) -> DivergingBarSummary {
        DivergingBarSummary(changes: changes, locale: locale)
    }

    // MARK: The view model

    @Test("Given a new screen, when it opens, then the rows are sorted from the largest fall to the largest rise")
    func opensSorted() {
        let viewModel = DivergingBarViewModel(changes: changes)

        #expect(viewModel.isSorted)
        #expect(viewModel.drawnChanges.map(\.drink) == ["Cocoa", "Tea", "Mocha", "Latte"])
    }

    @Test("Given the sort is turned off, when the rows are read, then they are in the order of the data")
    func unsortedKeepsDataOrder() {
        let viewModel = DivergingBarViewModel(changes: changes)
        viewModel.isSorted = false

        #expect(viewModel.drawnChanges == changes)
    }

    @Test("Given the café's sample data, when it is sorted, then every drink is still drawn once")
    func sortingKeepsEveryDrink() {
        let viewModel = DivergingBarViewModel()

        #expect(viewModel.drawnChanges.count == CafeData.drinkChanges.count)
        #expect(Set(viewModel.drawnChanges) == Set(CafeData.drinkChanges))
        #expect(viewModel.drawnChanges.map(\.change) == CafeData.drinkChanges.map(\.change).sorted())
    }

    @Test("Given either order, when the headline is written, then it is the same sentence, since the bars are the same")
    func headlineHoldsInBothOrders() {
        let viewModel = DivergingBarViewModel(changes: changes)
        let sorted = viewModel.summary(locale: locale).headline
        viewModel.isSorted = false

        #expect(viewModel.summary(locale: locale).headline == sorted)
        #expect(sorted == "Cocoa fell the most, by 305 cups; Latte rose the most, by 212 cups.")
    }

    @Test("Given the order changes, when the announcement is written, then it says what changed and then the headline")
    func announcementSaysWhatChanged() {
        let viewModel = DivergingBarViewModel(changes: changes)
        let headline = viewModel.summary(locale: locale).headline

        #expect(
            viewModel.announcement(locale: locale)
                == "Drinks sorted from the largest fall to the largest rise. \(headline)"
        )
        viewModel.isSorted = false
        #expect(viewModel.announcement(locale: locale) == "Drinks in the order of the data. \(headline)")
    }

    @Test("Given the labels sit above the bars, when the explanation is written, then it describes that layout and not the two annotations beside a bar")
    func explanationFollowsTheLabelLayout() {
        let viewModel = DivergingBarViewModel(changes: changes)

        #expect(viewModel.explanation(labelsAboveBars: false).contains("two annotations placed by its sign"))
        #expect(!viewModel.explanation(labelsAboveBars: false).contains("above it"))
        #expect(viewModel.explanation(labelsAboveBars: true).contains("both sit above it"))
        #expect(!viewModel.explanation(labelsAboveBars: true).contains("two annotations"))
    }

    // MARK: Snippets

    @Test("Given each order, when the snippets are listed, then the last one is the code for that order")
    func snippetsFollowTheOrder() {
        let viewModel = DivergingBarViewModel(changes: changes)

        #expect(viewModel.snippets(labelsAboveBars: false).map(\.name) == ["diverging-bar-marks", "diverging-bar-axes", "diverging-bar-sorted"])
        viewModel.isSorted = false
        #expect(viewModel.snippets(labelsAboveBars: false).map(\.name) == ["diverging-bar-marks", "diverging-bar-axes", "diverging-bar-data-order"])
    }

    @Test("Given the labels sit above the bars, when the snippets are listed, then the first is the large-text row that is drawn, not the row with labels beside the bar")
    func snippetsFollowTheLabelLayout() {
        let viewModel = DivergingBarViewModel(changes: changes)
        let largeText = viewModel.snippets(labelsAboveBars: true)

        #expect(largeText.map(\.name) == ["diverging-bar-large-text", "diverging-bar-axes", "diverging-bar-sorted"])
        #expect(largeText.first?.title == "At large text sizes: the label above the bar")
        viewModel.isSorted = false
        #expect(viewModel.snippets(labelsAboveBars: true).map(\.name) == ["diverging-bar-large-text", "diverging-bar-axes", "diverging-bar-data-order"])
    }

    @Test("Given the sort is off, when the explanation is written, then it says the bars are in data order and the largest must be hunted for, and says neither when sorted")
    func explanationOwnsUpToDataOrder() {
        let viewModel = DivergingBarViewModel(changes: changes)

        for labelsAboveBars in [false, true] {
            viewModel.isSorted = true
            #expect(!viewModel.explanation(labelsAboveBars: labelsAboveBars).contains("hunt"))
            viewModel.isSorted = false
            let unsorted = viewModel.explanation(labelsAboveBars: labelsAboveBars)
            #expect(unsorted.contains("the bars are in data order"))
            #expect(unsorted.hasSuffix("the reader has to hunt for the largest fall and the largest rise."))
        }
    }

    @Test("Given the built app, when each snippet the screen can show is looked up, then it exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let viewModel = DivergingBarViewModel(changes: changes)
        var names = Set<String>()
        for isSorted in [true, false] {
            viewModel.isSorted = isSorted
            names.formUnion(viewModel.snippets(labelsAboveBars: false).map(\.name))
            names.formUnion(viewModel.snippets(labelsAboveBars: true).map(\.name))
        }

        #expect(names.count == 5)
        for name in names {
            #expect(store[name] != nil, "Missing snippet \(name)")
        }
    }

    // MARK: The words

    @Test("Given the café's sample data, when the headline is written, then it names the largest fall and the largest rise in that data")
    func headlineFollowsSampleData() {
        #expect(
            summary(CafeData.drinkChanges).headline
                == "Cocoa fell the most, by 305 cups; Latte rose the most, by 212 cups."
        )
    }

    @Test("Given two drinks tied for the largest rise, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [
            DrinkChange(drink: "Mocha", change: 90), DrinkChange(drink: "Tea", change: 90),
            DrinkChange(drink: "Chai", change: -1),
        ]

        #expect(summary(tied).largestRises.map(\.drink) == ["Mocha", "Tea"])
        #expect(summary(tied).headline == "Chai fell the most, by 1 cup; Mocha and Tea rose the most, by 90 cups.")
    }

    @Test("Given changes on one side only, when the headline is written, then it says no drink went the other way")
    func oneSidedHeadlines() {
        #expect(
            summary([DrinkChange(drink: "Latte", change: 20), DrinkChange(drink: "Tea", change: 0)]).headline
                == "Latte rose the most, by 20 cups; no drink fell."
        )
        #expect(
            summary([DrinkChange(drink: "Cocoa", change: -1200)]).headline
                == "Cocoa fell the most, by 1,200 cups; no drink rose."
        )
    }

    @Test("Given no rows, or rows that are all zero, when the words are written, then they say nothing changed and there are no bars")
    func emptyAndZeroSaySo() {
        let zeros = summary([DrinkChange(drink: "Latte", change: 0), DrinkChange(drink: "Tea", change: 0)])

        #expect(!summary([]).hasBars)
        #expect(summary([]).headline == "No changes to show yet.")
        #expect(summary([]).audioGraphSummary == "No changes to show yet.")
        #expect(!zeros.hasBars)
        #expect(zeros.headline == "No drink sold more or fewer cups than last month.")
        #expect(zeros.audioGraphSummary == zeros.headline)
    }

    @Test("Given a change, when it is said in words, then it has its unit, agrees in number and names its direction")
    func valueTextNamesDirection() {
        #expect(summary(changes).valueText(212) == "212 cups more than last month")
        #expect(summary(changes).valueText(-305) == "305 cups fewer than last month")
        #expect(summary(changes).valueText(1) == "1 cup more than last month")
        #expect(summary(changes).valueText(-1) == "1 cup fewer than last month")
        #expect(summary(changes).valueText(0) == "No change from last month")
    }

    @Test("Given a German locale, when a count is written, then its number is grouped the German way")
    func countsTakeTheLocale() {
        let german = DivergingBarSummary(changes: changes, locale: Locale(identifier: "de_DE"))

        #expect(german.cupsText(1200).hasPrefix("1.200"))
    }

    @Test("Given changes, when the Audio Graph summary is written, then it counts each side and gives the largest of each in actual values")
    func summaryGivesActualValues() {
        #expect(
            summary(changes).audioGraphSummary
                == "4 drinks: 2 sold more cups than last month, 2 sold fewer. "
                + "Largest rise: Latte, 212 cups more than last month. "
                + "Largest fall: Cocoa, 305 cups fewer than last month."
        )
    }

    @Test("Given a change, when its direction is chosen, then zero and rises are more and falls are fewer")
    func directionFollowsSign() {
        #expect(DivergingBarDirection(change: 5) == .more)
        #expect(DivergingBarDirection(change: 0) == .more)
        #expect(DivergingBarDirection(change: -5) == .fewer)
    }

    // MARK: The chart descriptor

    @Test("Given drawn rows, when the chart descriptor is made, then it has a title, the summary and one named series of separate bars")
    func descriptorDescribesTheChart() throws {
        let descriptor = DivergingBarChartDescriptor(changes: changes, locale: locale).makeChartDescriptor()

        #expect(descriptor.title == "Change in cups against last month, by drink")
        #expect(descriptor.summary == summary(changes).audioGraphSummary)
        #expect(descriptor.series.count == 1)
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Change against last month")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == changes.count)
    }

    @Test("Given sorted rows, when the chart descriptor is made, then its categories are in the drawn order")
    func descriptorFollowsDrawnOrder() throws {
        let drawn = DivergingBarViewModel(changes: changes).drawnChanges
        let descriptor = DivergingBarChartDescriptor(changes: drawn, locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Cocoa", "Tea", "Mocha", "Latte"])
    }

    @Test("Given rises and falls, when the descriptor's value axis is read, then it spans both sides of zero and says values with unit and direction")
    func descriptorValueAxis() throws {
        let yAxis = try #require(DivergingBarChartDescriptor(changes: changes, locale: locale).makeChartDescriptor().yAxis)

        #expect(yAxis.title == "Change in cups")
        // From the fall of 305 to the rise of 212, on an axis drawn from -400 to 400.
        #expect(yAxis.range == -400 ... 400)
        #expect(yAxis.valueDescriptionProvider(-148) == "148 cups fewer than last month")
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup more than last month")
    }

    @Test("Given rises only, when the descriptor's value axis is read, then it still starts at zero, as the drawn scale does")
    func descriptorRangeIncludesZero() throws {
        let rises = [DrinkChange(drink: "Latte", change: 40), DrinkChange(drink: "Tea", change: 10)]
        let yAxis = try #require(DivergingBarChartDescriptor(changes: rises, locale: locale).makeChartDescriptor().yAxis)

        #expect(yAxis.range == 0 ... 40)
    }
}
