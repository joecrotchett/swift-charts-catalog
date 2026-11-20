import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ExploreAtRestTests {
    private let english = Locale(identifier: "en_US")

    /// Two cafés over `cups.count` days from 1 March 2026, with the given cups each day.
    private func stores(_ cups: [(Int, Int)]) -> [StoreSales] {
        [
            StoreSales(store: CafeWording.harbour, days: cups.enumerated().map { DailySales(day: CafeData.day($0), cups: $1.0) }),
            StoreSales(store: CafeWording.station, days: cups.enumerated().map { DailySales(day: CafeData.day($0), cups: $1.1) }),
        ]
    }

    // MARK: The message at rest

    @Test("Given the sample data, when the headline is written, then it names Harbour's run from Saturday, March 21")
    func sampleHeadline() {
        let viewModel = ExploreAtRestViewModel()

        #expect(viewModel.days.count == 28)
        #expect(viewModel.headline(locale: english) == "Harbour has sold more than Station every day since Saturday, March 21.")
    }

    @Test("Given the sample data, when the shading is worked out, then it covers the eight days from March 21 and is labelled with its first day")
    func sampleShading() {
        let words = ExploreAtRestViewModel().words(locale: english)

        #expect(words.shadedDays == (20 ..< 28).map { CafeData.day($0) })
        #expect(words.shadedLabel == "Harbour ahead since Mar 21")
        #expect(words.bandLabels == ["Since Mar 21", "Mar 21"])
    }

    @Test("Given the eight shaded days, when the explanation is written at each text size, then it says where the first day is written")
    func explanationFollowsTextSize() {
        let words = ExploreAtRestViewModel().words(locale: english)

        #expect(words.labelsShadingInPlot(isAccessibilitySize: false))
        #expect(!words.labelsShadingInPlot(isAccessibilitySize: true))
        #expect(words.explanation(isAccessibilitySize: false, isShowingMistake: false)
            .contains("with the day they start written in the shading"))
        #expect(words.explanation(isAccessibilitySize: true, isShowingMistake: false)
            .contains("the key under the chart gives the day they start"))
        #expect(words.explanation(isAccessibilitySize: false, isShowingMistake: true)
            .hasPrefix("With the mistake on, nothing is shaded"))
    }

    @Test("Given a run too short to hold its label, when the shading is drawn, then its first day goes to the key under the chart")
    func shortRunUsesKey() {
        let words = ExploreAtRestViewModel(stores: stores([(10, 20), (30, 20), (30, 20)])).words(locale: english)

        #expect(words.shadedDays.count == 2)
        #expect(!words.labelsShadingInPlot(isAccessibilitySize: false))
        #expect(words.explanation(isAccessibilitySize: false, isShowingMistake: false)
            .contains("the key under the chart gives the day they start"))
    }

    @Test("Given a run of one day, when the headline is written, then it names the last day alone")
    func oneDayRun() {
        let viewModel = ExploreAtRestViewModel(stores: stores([(10, 20), (10, 20), (30, 20)]))
        let words = viewModel.words(locale: english)

        #expect(viewModel.headline(locale: english) == "Harbour sold more than Station on the last day, Tuesday, March 3.")
        #expect(words.shadedLabel == "Harbour ahead on Mar 3")
    }

    @Test("Given one café ahead on every day, when the headline is written, then it says so and nothing is shaded")
    func everyDay() {
        let viewModel = ExploreAtRestViewModel(stores: stores([(5, 20), (6, 20), (7, 20)]))
        let words = viewModel.words(locale: english)

        #expect(viewModel.headline(locale: english) == "Station sold more than Harbour on every one of the 3 days.")
        #expect(words.shadedDays.isEmpty)
        #expect(words.shadedLabel == nil)
    }

    @Test("Given a tie on the last day, when the headline is written, then it counts the days each café led")
    func tieOnLastDay() {
        let viewModel = ExploreAtRestViewModel(stores: stores([(30, 20), (30, 20), (10, 20), (20, 20)]))

        #expect(viewModel.headline(locale: english) == "Harbour sold more than Station on 2 of 4 days.")
        #expect(viewModel.words(locale: english).shadedDays.isEmpty)
    }

    @Test("Given only zeros, when the headline is written, then it says neither café sold a cup")
    func allZeros() {
        let viewModel = ExploreAtRestViewModel(stores: stores([(0, 0), (0, 0)]))

        #expect(viewModel.hasData)
        #expect(viewModel.headline(locale: english) == "Neither café sold a cup in these 2 days.")
        #expect(viewModel.cupsDomain == 0 ... 50)
    }

    @Test("Given no data, when the headline is written, then it says nothing was recorded, even with the mistake on")
    func noData() {
        let viewModel = ExploreAtRestViewModel(stores: [])
        viewModel.isShowingMistake = true

        #expect(!viewModel.hasData)
        #expect(viewModel.headline(locale: english) == "No sales recorded at either café.")
    }

    // MARK: The mistake

    @Test("Given the mistake, when the headline is written, then it is the instruction and the announcement says what changed")
    func mistakeHeadline() {
        let viewModel = ExploreAtRestViewModel()
        viewModel.isShowingMistake = true
        let words = viewModel.words(locale: english)

        #expect(viewModel.headline(locale: english) == "Touch and hold the chart to compare the cafés.")
        #expect(words.announcement(isShowingMistake: true)
            == "Mistake shown: the shading is gone and the headline asks for a gesture. Touch and hold the chart to compare the cafés.")
        #expect(words.announcement(isShowingMistake: false)
            == "Mistake hidden: the message is back on the chart. Harbour has sold more than Station every day since Saturday, March 21.")
    }

    @Test("Given each setting, when the snippets are chosen, then the mistake swaps the at-rest region for its own and keeps the rest")
    func snippetsFollowMistake() {
        #expect(ExploreAtRestSnippets.references(isShowingMistake: false).map(\.name) == [
            "interaction-explore-do-not-require-at-rest", "interaction-explore-do-not-require-binding",
            "interaction-explore-do-not-require-selection", "interaction-explore-do-not-require-elements",
        ])
        #expect(ExploreAtRestSnippets.references(isShowingMistake: true).map(\.name) == [
            "interaction-explore-do-not-require-mistake", "interaction-explore-do-not-require-binding",
            "interaction-explore-do-not-require-selection", "interaction-explore-do-not-require-elements",
        ])
    }

    @Test("Given the app bundle, when every snippet this screen names is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = Set((ExploreAtRestSnippets.references(isShowingMistake: false)
                + ExploreAtRestSnippets.references(isShowingMistake: true)).map(\.name))
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    // MARK: Selection

    @Test("Given a raw selection in the afternoon of March 23, when it is snapped, then it reveals that day's cups at both cafés")
    func snapsSelection() throws {
        let viewModel = ExploreAtRestViewModel()
        viewModel.rawSelection = CafeData.day(22).addingTimeInterval(15 * 3600)

        let selection = try #require(viewModel.selection(locale: english))
        #expect(selection.day == CafeData.day(22))
        #expect(selection.dayText == "Monday, March 23")
        #expect(selection.firstCups == 222)
        #expect(selection.secondCups == 218)
    }

    @Test("Given no selection, or one beyond the data, when it is snapped, then nothing is selected")
    func noSelection() {
        let viewModel = ExploreAtRestViewModel()
        #expect(viewModel.selection(locale: english) == nil)

        viewModel.rawSelection = CafeData.day(40)
        #expect(viewModel.selectedDay == nil)
    }

    @Test("Given a day, when its element is written, then it gives the day and the same two figures a selection shows")
    func elementText() throws {
        let viewModel = ExploreAtRestViewModel()
        let words = viewModel.words(locale: english)
        let day = try #require(viewModel.days.first { $0.day == CafeData.day(22) })

        #expect(words.elementLabel(day) == "Monday, March 23")
        #expect(words.elementValue(day) == "Harbour 222 cups, Station 218 cups")
    }

    @Test("Given one cup, when an element is written, then the count agrees in number")
    func oneCup() throws {
        let viewModel = ExploreAtRestViewModel(stores: stores([(1, 2)]))
        let day = try #require(viewModel.days.first)

        #expect(viewModel.words(locale: english).elementValue(day) == "Harbour 1 cup, Station 2 cups")
    }

    // MARK: Axis and Audio Graph

    @Test("Given the sample data, when the value axis is worked out, then it runs from 150 to 300 in steps of 50")
    func sampleAxis() {
        let viewModel = ExploreAtRestViewModel()

        #expect(viewModel.cupsDomain == 150 ... 300)
        #expect(viewModel.cupsAxisValues == [150, 200, 250, 300])
    }

    @Test("Given the sample data, when the descriptor is made, then it has both cafés as lines over 28 written-out days on the drawn axis")
    func descriptor() throws {
        let viewModel = ExploreAtRestViewModel()
        let chart = ExploreAtRestDescriptor(
            words: viewModel.words(locale: english), cupsDomain: viewModel.cupsDomain, isShowingMistake: false
        ).makeChartDescriptor()

        #expect(chart.title == "Cups sold a day at Harbour and Station")
        #expect(chart.series.map(\.name) == ["Harbour", "Station"])
        #expect(chart.series.allSatisfy { $0.isContinuous && $0.dataPoints.count == 28 })
        let xAxis = try #require(chart.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.last == "Saturday, March 28")
        let yAxis = try #require(chart.yAxis)
        #expect(yAxis.range == 150 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(222) == "222 cups")
    }

    @Test("Given each setting, when the summary is written, then the shading is mentioned only when it is drawn")
    func summaryFollowsMistake() {
        let words = ExploreAtRestViewModel().words(locale: english)

        #expect(words.audioGraphSummary(isShowingMistake: false) == "28 days, Sunday, March 1 to Saturday, March 28. "
            + "Harbour has sold more than Station every day since Saturday, March 21. Those days are shaded on the chart. "
            + "Harbour from 152 cups to 282 cups. Station from 155 cups to 223 cups.")
        #expect(!words.audioGraphSummary(isShowingMistake: true).contains("shaded"))
    }

    @Test("Given a German locale, when the figures are written, then numbers follow the locale")
    func germanNumbers() throws {
        let viewModel = ExploreAtRestViewModel(stores: stores([(1200, 900)]))
        let day = try #require(viewModel.days.first)

        #expect(viewModel.words(locale: Locale(identifier: "de_DE")).elementValue(day).contains("1.200"))
    }
}
