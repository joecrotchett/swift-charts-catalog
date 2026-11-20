import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ComposingAxisMarksTests {
    private let english = Locale(identifier: "en_US")

    private func summary(
        _ sales: [DrinkSales] = CafeData.drinkSales,
        composition: ComposingAxisMarksComposition = .oneSet,
        parts: ComposingAxisMarksParts = ComposingAxisMarksParts(),
        isLargeText: Bool = false
    ) -> ComposingAxisMarksSummary {
        let viewModel = ComposingAxisMarksViewModel(sales: sales)
        viewModel.composition = composition
        viewModel.parts = parts
        return viewModel.summary(locale: english, isLargeText: isLargeText)
    }

    // MARK: State

    @Test("Given a new screen, when it opens, then it shows one AxisMarks with every part")
    func startsWithEveryPart() {
        let viewModel = ComposingAxisMarksViewModel()

        #expect(viewModel.composition == .oneSet)
        #expect(viewModel.parts == ComposingAxisMarksParts(gridLines: true, ticks: true, labels: true))
        #expect(viewModel.sales == CafeData.drinkSales)
    }

    @Test("Given the drink sales, when the scale is worked out, then it runs to 200 with labels every 50 and grid lines every 25")
    func scaleFromTheData() {
        let scale = ComposingAxisMarksScale(sales: CafeData.drinkSales, isLargeText: false)

        #expect(scale.top == 200)
        #expect(scale.labelValues == [0, 50, 100, 150, 200])
        #expect(scale.minorGridValues == [0, 25, 50, 75, 100, 125, 150, 175, 200])
    }

    @Test("Given accessibility text sizes, when the scale is worked out, then labels are every 100 so they do not collide")
    func fewerLabelsAtLargeText() {
        let scale = ComposingAxisMarksScale(sales: CafeData.drinkSales, isLargeText: true)

        #expect(scale.top == 200)
        #expect(scale.labelValues == [0, 100, 200])
        #expect(scale.minorGridValues == [0, 50, 100, 150, 200])
    }

    @Test("Given no sales, when the scale is worked out, then it still has a top above zero")
    func scaleWithNoSales() {
        let scale = ComposingAxisMarksScale(sales: [], isLargeText: false)

        #expect(scale.top == 50)
        #expect(scale.labelValues == [0, 50])
    }

    @Test("Given each composition, when its grid lines are drawn, then the Audio Graph is given the values that have one")
    func gridlineValuesFollowTheSetting() {
        #expect(summary().gridlineValues == [0, 50, 100, 150, 200])
        #expect(summary(composition: .twoSets).gridlineValues == [0, 25, 50, 75, 100, 125, 150, 175, 200])
        #expect(summary(parts: ComposingAxisMarksParts(gridLines: false)).gridlineValues.isEmpty)
        #expect(summary(composition: .twoSets, parts: ComposingAxisMarksParts(gridLines: false)).gridlineValues.isEmpty)
    }

    // MARK: Snippets

    @Test("Given each composition, when its snippets are read, then they name the region for it")
    func snippetsFollowTheComposition() {
        let viewModel = ComposingAxisMarksViewModel()
        #expect(viewModel.snippets.map(\.name) == ["composing-axis-marks-one-set"])
        #expect(viewModel.snippets.map(\.title) == ["Grid line, tick, and label in one AxisMarks"])

        viewModel.composition = .twoSets
        #expect(viewModel.snippets.map(\.name) == ["composing-axis-marks-two-sets"])
        #expect(viewModel.snippets.map(\.title) == ["Labels at some values, grid lines at more"])
    }

    @Test("Given the grid lines switched off, when the snippet titles are read, then they say the closure drops them")
    func snippetTitlesWithoutGridLines() {
        let viewModel = ComposingAxisMarksViewModel()
        viewModel.parts.gridLines = false
        #expect(viewModel.snippets.map(\.title) == ["Tick and label: the closure drops the grid lines"])

        viewModel.parts.ticks = false
        #expect(viewModel.snippets.map(\.title) == ["Label: the closure drops the grid lines"])

        viewModel.parts.labels = false
        #expect(viewModel.snippets.map(\.title) == ["An empty closure draws nothing on the axis"])

        viewModel.composition = .twoSets
        #expect(viewModel.snippets.map(\.title) == ["The second closure drops the grid lines"])
    }

    @Test("Given the app's snippets, when the screen's names are looked up, then each is in this screen's source")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        for name in ["composing-axis-marks-one-set", "composing-axis-marks-two-sets"] {
            #expect(store[name]?.file == "Axes/ComposingAxisMarksScreen.swift", "\(name) is missing")
        }
    }

    // MARK: Headline

    @Test("Given labels drawn, when the headline is read, then its figure is the labelled value below the tallest bar")
    func headlineWithLabels() {
        #expect(summary().headline == "Tea sold the most: over 150 cups.")
        #expect(summary(composition: .twoSets).headline == "Tea sold the most: over 150 cups.")
        #expect(summary(isLargeText: true).headline == "Tea sold the most: over 100 cups.")
    }

    @Test("Given the labels switched off, when the headline is read, then it gives no figure the axis no longer shows")
    func headlineWithoutLabels() {
        let parts = ComposingAxisMarksParts(labels: false)

        #expect(summary(parts: parts).headline == "Tea sold the most of 5 drinks.")
        #expect(summary(parts: parts).labelledFigure == nil)
    }

    @Test("Given the grid lines or ticks switched off, when the headline is read, then it is unchanged")
    func headlineIgnoresRestyling() {
        let expected = "Tea sold the most: over 150 cups."

        #expect(summary(parts: ComposingAxisMarksParts(gridLines: false)).headline == expected)
        #expect(summary(parts: ComposingAxisMarksParts(ticks: false)).headline == expected)
    }

    @Test("Given a top on a label, under the first label, or a tie, when the headline is read, then it stays true")
    func headlineEdgeCases() {
        let exact = [DrinkSales(drink: "Latte", cups: 150), DrinkSales(drink: "Tea", cups: 20)]
        let small = [DrinkSales(drink: "Latte", cups: 1), DrinkSales(drink: "Tea", cups: 0)]
        let tie = [DrinkSales(drink: "Latte", cups: 80), DrinkSales(drink: "Tea", cups: 80)]

        #expect(summary(exact).headline == "Latte sold the most: 150 cups.")
        #expect(summary(small).headline == "Latte sold the most: under 50 cups.")
        #expect(summary(tie).headline == "Latte and Tea sold the most: over 50 cups.")
    }

    @Test("Given no sales or only zeros, when the headline is read, then it says nothing has sold")
    func headlineWithNoSales() {
        let zeros = [DrinkSales(drink: "Latte", cups: 0), DrinkSales(drink: "Tea", cups: 0)]

        #expect(summary([]).headline == "No cups sold yet today.")
        #expect(summary(zeros).headline == "No cups sold yet today.")
        #expect(summary(zeros).total == 0)
    }

    @Test("Given the labels switched, when the announcement is read, then it says what changed and then the headline")
    func labelsAnnouncement() {
        #expect(summary().labelsAnnouncement == "Axis labels shown. Tea sold the most: over 150 cups.")
        #expect(summary(parts: ComposingAxisMarksParts(labels: false)).labelsAnnouncement
            == "Axis labels hidden. Tea sold the most of 5 drinks.")
    }

    @Test("Given a German locale, when the headline is read, then the number is written the German way")
    func headlineTakesTheLocale() {
        let sales = [DrinkSales(drink: "Latte", cups: 1234)]
        let viewModel = ComposingAxisMarksViewModel(sales: sales)

        #expect(viewModel.summary(locale: Locale(identifier: "de_DE"), isLargeText: false).headline
            == "Latte sold the most: over 1.200 cups.")
    }

    @Test("Given two AxisMarks with grid lines, when the explanation is read at each text size, then it names the steps drawn here")
    func explanationFollowsTheTextSize() {
        #expect(summary(composition: .twoSets).explanation
            .hasSuffix("here labels every 50 cups and grid lines every 25 cups."))
        #expect(summary(composition: .twoSets, isLargeText: true).explanation
            .hasSuffix("here labels every 100 cups and grid lines every 50 cups."))
    }

    @Test("Given one AxisMarks or no grid lines, when the explanation is read, then it gives the steps as a possibility, not as what is drawn")
    func explanationWithoutTwoSetsOfGridLines() {
        let noGrid = ComposingAxisMarksParts(gridLines: false, ticks: true, labels: true)
        for explanation in [
            summary().explanation,
            summary(composition: .twoSets, parts: noGrid).explanation,
        ] {
            #expect(!explanation.contains("here"))
            #expect(explanation.hasSuffix("such as labels every 50 cups and grid lines every 25 cups."))
        }
        #expect(summary(isLargeText: true).explanation
            .hasSuffix("such as labels every 100 cups and grid lines every 50 cups."))
    }

    // MARK: Audio Graph

    @Test("Given the drink sales, when the descriptor is made, then it names the axes, matches the scale and summarises in values")
    func descriptor() throws {
        let descriptor = ComposingAxisMarksChartDescriptor(summary: summary()).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha", "Cocoa", "Americano"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.gridlinePositions == [0, 50, 100, 150, 200])
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(164) == "164 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Harbour"])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 5)
    }
}
