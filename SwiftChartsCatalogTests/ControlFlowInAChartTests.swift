import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ControlFlowInAChartTests {
    private static let locale = Locale(identifier: "en_US")

    private static func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    /// 1 to 5 March 2026: the fewest on the 2nd, the most on the 4th, 100 cups a day on average.
    private let days = ControlFlowInAChartTests.days([90, 60, 120, 150, 80])

    private func viewModel(_ days: [DailySales]) -> ControlFlowInAChartViewModel {
        ControlFlowInAChartViewModel(days: days, locale: Self.locale)
    }

    // MARK: The view model's states

    @Test("Given a new screen, when nothing has been changed, then there is no average, no highlighted day and the sample data")
    func startsWithNoOverlays() {
        let viewModel = ControlFlowInAChartViewModel()

        #expect(!viewModel.showsAverage)
        #expect(viewModel.highlight == .none)
        #expect(viewModel.highlightedDay == nil)
        #expect(viewModel.days == CafeData.harbourSales)
    }

    @Test("Given days of sales, when a highlight is chosen, then the optional day is the one it names")
    func highlightGivesTheDay() {
        let viewModel = viewModel(days)

        viewModel.highlight = .busiest
        #expect(viewModel.highlightedDay == days[3])
        viewModel.highlight = .quietest
        #expect(viewModel.highlightedDay == days[1])
        viewModel.highlight = .latest
        #expect(viewModel.highlightedDay == days[4])
        viewModel.highlight = .none
        #expect(viewModel.highlightedDay == nil)
    }

    @Test("Given two days tied for the most, when the busiest is highlighted, then it is the earlier one")
    func tieHighlightsTheEarlierDay() {
        let tied = Self.days([70, 150, 150])
        let viewModel = viewModel(tied)

        viewModel.highlight = .busiest

        #expect(viewModel.highlightedDay == tied[1])
    }

    @Test("Given no sales or only zeros, when a highlight is chosen, then there is no day to highlight", arguments: [[], [0, 0, 0]])
    func noDataHighlightsNothing(cups: [Int]) {
        let viewModel = viewModel(Self.days(cups))

        viewModel.highlight = .busiest
        viewModel.showsAverage = true

        #expect(viewModel.highlightedDay == nil)
        #expect(!viewModel.summary.hasData)
        #expect(viewModel.summary.drawnAverage == nil)
        #expect(viewModel.headline == "No cups sold in this period.")
        #expect(viewModel.summary.audioGraphSummary == "No cups sold in this period.")
    }

    @Test("Given the switch, when it is turned on and off, then the average exists only while it is on")
    func averageFollowsTheSwitch() {
        let viewModel = viewModel(days)

        #expect(viewModel.summary.drawnAverage == nil)
        viewModel.showsAverage = true
        #expect(viewModel.summary.drawnAverage == 100)
        viewModel.showsAverage = false
        #expect(viewModel.summary.drawnAverage == nil)
    }

    @Test("Given an average that is not a whole number, when the rule is drawn, then it is at the rounded figure its label and the headline give")
    func ruleIsDrawnAtTheLabelledValue() {
        let viewModel = viewModel(Self.days([204, 205]))
        viewModel.showsAverage = true

        #expect(viewModel.summary.average == 204.5)
        #expect(viewModel.summary.drawnAverage == 205)
        #expect(viewModel.summary.drawnAverage == viewModel.summary.roundedAverage)
        #expect(viewModel.headline == "The Harbour café averaged 205 cups a day.")
        #expect(viewModel.summary.audioGraphSummary.contains("An average line is drawn at 205 cups."))
    }

    // MARK: Snippets

    @Test("Given any setting of the controls, when the snippets are read, then they are ForEach, if and if let, named for the screen")
    func snippetsAreTheSameInEveryState() {
        let viewModel = viewModel(days)
        let expected = [
            "control-flow-in-a-chart-for-each", "control-flow-in-a-chart-if", "control-flow-in-a-chart-if-let",
        ]

        for showsAverage in [false, true] {
            for highlight in ControlFlowHighlight.allCases {
                viewModel.showsAverage = showsAverage
                viewModel.highlight = highlight
                #expect(viewModel.snippets.map(\.name) == expected)
            }
        }
    }

    @Test("Given the screen's snippets, when the bundle is read, then each region was extracted from the source")
    func snippetsExistInTheBundle() throws {
        let store = try SnippetStore()

        for snippet in viewModel(days).snippets {
            #expect(store[snippet.name] != nil)
        }
    }

    // MARK: Derived text

    @Test("Given no overlay, when the headline is written, then it gives the range the line covers")
    func headlineGivesTheRange() {
        #expect(viewModel(days).headline == "Daily sales ranged from 60 to 150 cups.")
    }

    @Test("Given every day the same, when the headline is written, then it does not claim a range")
    func headlineForFlatSales() {
        #expect(viewModel(Self.days([40, 40])).headline == "Every day sold 40 cups.")
    }

    @Test("Given the average is shown, when the headline is written, then its figure is the one on the rule")
    func headlineGivesTheAverage() {
        let viewModel = viewModel(days)
        viewModel.showsAverage = true

        #expect(viewModel.headline == "The Harbour café averaged 100 cups a day.")
    }

    @Test("Given a highlighted day, when the headline is written, then it names the day and its cups")
    func headlineNamesTheHighlightedDay() {
        let viewModel = viewModel(days)

        viewModel.highlight = .busiest
        #expect(viewModel.headline == "The busiest day was Wednesday, March 4: 150 cups.")
        viewModel.highlight = .quietest
        #expect(viewModel.headline == "The quietest day was Monday, March 2: 60 cups.")
        viewModel.highlight = .latest
        #expect(viewModel.headline == "The latest day was Thursday, March 5: 80 cups.")
    }

    @Test("Given a highlighted day and the average, when the headline is written, then it carries both figures")
    func headlineWithBothOverlays() {
        let viewModel = viewModel(days)
        viewModel.highlight = .busiest
        viewModel.showsAverage = true

        #expect(viewModel.headline == "The busiest day was Wednesday, March 4: 150 cups, against a daily average of 100 cups.")
    }

    @Test("Given the café's sample data, when the headline is written, then its figures are in that data")
    func headlineFollowsSampleData() throws {
        let cups = CafeData.harbourSales.map(\.cups)
        let lowest = try #require(cups.min())
        let highest = try #require(cups.max())

        let headline = ControlFlowInAChartViewModel(locale: Self.locale).headline

        #expect(headline == "Daily sales ranged from \(lowest) to \(highest) cups.")
    }

    @Test("Given a day, when its VoiceOver value is written, then it has the unit and says when it is the highlighted day")
    func accessibilityValueMarksTheHighlight() {
        let viewModel = viewModel(days)
        viewModel.highlight = .busiest

        #expect(viewModel.summary.accessibilityValue(for: days[3]) == "150 cups, highlighted")
        #expect(viewModel.summary.accessibilityValue(for: days[0]) == "90 cups")
        #expect(ControlFlowSummary.cupsText(1) == "1 cup")
    }

    @Test("Given the overlays, when the Audio Graph summary is written, then it says each one only while it is drawn")
    func audioGraphSummaryFollowsTheOverlays() {
        let viewModel = viewModel(days)
        let base = "5 days, Sunday, March 1 to Thursday, March 5. Lowest 60 cups, highest 150 cups."

        #expect(viewModel.summary.audioGraphSummary == base)
        viewModel.showsAverage = true
        #expect(viewModel.summary.audioGraphSummary == base + " An average line is drawn at 100 cups.")
        viewModel.highlight = .quietest
        #expect(
            viewModel.summary.audioGraphSummary
                == base + " An average line is drawn at 100 cups. Highlighted: Monday, March 2, 60 cups."
        )
    }

    // MARK: The chart descriptor

    @Test("Given days of sales, when the chart descriptor is made, then it has a title, the summary and one continuous named series")
    func descriptorDescribesTheChart() throws {
        let summary = viewModel(days).summary
        let descriptor = ControlFlowChartDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold each day at the Harbour café")
        #expect(descriptor.summary == summary.audioGraphSummary)
        #expect(descriptor.series.count == 1)
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Harbour")
        #expect(series.isContinuous)
        #expect(series.dataPoints.count == days.count)
    }

    @Test("Given days of sales, when the descriptor's axes are read, then dates are written out and values are in cups from the lowest to the highest")
    func descriptorAxes() throws {
        let descriptor = ControlFlowChartDescriptor(summary: viewModel(days).summary).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.count == days.count)
        #expect(yAxis.title == "Cups")
        // 60 to 150 cups, rounded out to the drawn axis's step of 50.
        #expect(yAxis.range == 50 ... 150)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
    }
}
