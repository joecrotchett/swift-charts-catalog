import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ReusableChartContentTests {
    private let days = [
        DailySales(day: CafeData.day(0), cups: 100),
        DailySales(day: CafeData.day(1), cups: 151),
        DailySales(day: CafeData.day(2), cups: 200),
    ]

    @Test("Given a new screen, when nothing is switched, then the lines take the chart's colours and the three concept snippets show")
    func startsWithoutTheMistake() {
        let viewModel = ReusableChartContentViewModel()

        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.snippets.map(\.name) == [
            "reusable-chart-content-type", "reusable-chart-content-builder", "reusable-chart-content-use",
        ])
        #expect(viewModel.explanation.contains("ReferenceLine is a custom ChartContent type"))
        #expect(viewModel.explanation.contains("@ChartContentBuilder"))
    }

    @Test("Given the mistake is switched on, when the screen is read, then the snippets and the explanation are the mistake's")
    func mistakeShowsItsOwnCode() {
        let viewModel = ReusableChartContentViewModel()
        viewModel.isShowingMistake = true

        #expect(viewModel.snippets.map(\.name) == [
            "reusable-chart-content-mistake-type", "reusable-chart-content-mistake-use",
        ])
        #expect(viewModel.explanation.contains("a style set inside a custom type wins"))
        #expect(viewModel.changeAnnouncement == "Both lines are now drawn in red. The colours the chart asks for are ignored.")
    }

    @Test("Given the mistake is switched off again, when the change is announced, then it says which colours are back")
    func announcesTheWayBack() {
        let viewModel = ReusableChartContentViewModel()
        viewModel.isShowingMistake = true
        viewModel.isShowingMistake = false

        #expect(viewModel.changeAnnouncement == "The average line is orange and the target line is purple, as the chart asks.")
    }

    @Test("Given either state, when the headline is read, then it is the same: the mistake changes colour, not values")
    func headlineDoesNotDependOnTheMistake() {
        let viewModel = ReusableChartContentViewModel(days: days, target: 160)
        let before = viewModel.headline
        viewModel.isShowingMistake = true

        #expect(viewModel.headline == before)
        #expect(before == "150 cups a day on average, under the target of 160.")
    }

    @Test("Given every snippet either state shows, when the built app's snippets are read, then each one exists")
    func everySnippetIsExtracted() throws {
        let store = try SnippetStore()
        let viewModel = ReusableChartContentViewModel()
        let shown = viewModel.snippets
        viewModel.isShowingMistake = true

        for snippet in shown + viewModel.snippets {
            #expect(store[snippet.name] != nil, "\(snippet.name) is missing")
        }
    }

    @Test("Given the café's sample data, when the average is taken, then it is the mean rounded to a whole cup and under the target")
    func sampleDataAverage() throws {
        let summary = ReusableChartContentViewModel().summary
        let cups = CafeData.harbourSales.map(\.cups)
        let mean = Double(cups.reduce(0, +)) / Double(cups.count)
        let average = try #require(summary.average)

        #expect(average == Int(mean.rounded()))
        #expect(summary.headline == "\(average) cups a day on average, under the target of 250.")
    }

    @Test("Given an average above or equal to the target, when the headline is written, then it says over or exactly on")
    func headlineComparesWithTheTarget() {
        #expect(ReusableContentSummary(days: days, target: 120).headline == "150 cups a day on average, over the target of 120.")
        #expect(ReusableContentSummary(days: days, target: 150).headline == "150 cups a day on average, exactly on the target of 150.")
    }

    @Test("Given no days, when the chart's words are written, then they say nothing was sold and there is no average")
    func emptyDaysSaySo() {
        let summary = ReusableContentSummary(days: [], target: 250)

        #expect(summary.average == nil)
        #expect(summary.headline == "No cups sold yet.")
        #expect(summary.audioGraphSummary == "No cups sold yet.")
    }

    @Test("Given days that are all zero, when the chart's words are written, then they say nothing was sold, not an average of zero")
    func allZeroDaysSaySo() {
        let summary = ReusableContentSummary(
            days: [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)], target: 250
        )

        #expect(summary.average == nil)
        #expect(summary.headline == "No cups sold yet.")
        #expect(summary.audioGraphSummary == "No cups sold yet.")
    }

    @Test("Given a count of cups, when it is written for speech, then the unit agrees with the number")
    func cupsAgreeInNumber() {
        #expect(ReusableContentSummary.spokenCups(1) == "1 cup")
        #expect(ReusableContentSummary.spokenCups(0) == "0 cups")
        #expect(ReusableContentSummary.spokenCups(204) == "204 cups")
    }

    @Test("Given a day counted in UTC, when it is written for speech, then it names that day whatever the device's time zone")
    func dayIsWrittenInTheDataTimeZone() {
        #expect(ReusableContentSummary.spokenDay(CafeData.day(0)) == "Sunday, March 1")
    }

    @Test("Given daily sales, when the Audio Graph summary is written, then it gives the days, both lines and the extremes in actual values")
    func summaryGivesActualValues() {
        #expect(
            ReusableContentSummary(days: days, target: 160).audioGraphSummary
                == "3 days. Average 150 cups a day. Target 160 cups a day. Fewest in a day 100 cups, most 200 cups."
        )
    }

    @Test("Given daily sales, when the chart descriptor is made, then it has a title, the summary and one named series of separate bars")
    func descriptorDescribesTheChart() throws {
        let descriptor = ReusableContentChartDescriptor(days: days, target: 160).makeChartDescriptor()
        let series = try #require(descriptor.series.first)

        #expect(descriptor.title == "Cups sold each day at the Harbour café, with the average and the target")
        #expect(descriptor.summary == ReusableContentSummary(days: days, target: 160).audioGraphSummary)
        #expect(descriptor.series.count == 1)
        #expect(series.name == "Harbour")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == days.count)
    }

    @Test("Given daily sales, when the descriptor's axes are read, then days are written out in order and values are said in cups up to the drawn scale")
    func descriptorAxes() throws {
        let descriptor = ReusableContentChartDescriptor(days: days, target: 260).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder == ["Sunday, March 1", "Monday, March 2", "Tuesday, March 3"])
        #expect(yAxis.title == "Cups")
        // The target, 260, is above every day: the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
    }
}
