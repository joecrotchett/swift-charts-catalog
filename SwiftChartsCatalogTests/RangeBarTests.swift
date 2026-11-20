import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct RangeBarTests {
    private let english = Locale(identifier: "en_US")

    private func month(_ offset: Int, _ low: Int, _ high: Int, _ average: Int) -> MonthlySummary {
        MonthlySummary(month: CafeData.month(offset), lowestDay: low, highestDay: high, averageDay: average)
    }

    private func summary(_ months: [MonthlySummary]) -> RangeBarSummary {
        RangeBarSummary(months: months, locale: english)
    }

    // MARK: The view model

    @Test("Given a new view model, when its months are read, then they are the café's six monthly summaries")
    func drawsTheSampleMonths() {
        let viewModel = RangeBarViewModel()

        #expect(viewModel.months == CafeData.monthlySummaries)
        #expect(viewModel.summary(locale: english).headline == summary(CafeData.monthlySummaries).headline)
    }

    @Test("Given the view model, when its snippets are read, then they are the marks and the axis, in that order")
    func showsItsSnippets() {
        #expect(RangeBarViewModel().snippets.map(\.name) == ["range-bar-marks", "range-bar-axis"])
    }

    @Test("Given the built app, when the screen's snippets are looked up, then each one exists in this screen's source")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        for snippet in RangeBarViewModel().snippets {
            #expect(store[snippet.name]?.file == "Marks/RangeBarScreen.swift", "\(snippet.name) is missing")
        }
    }

    // MARK: The headline

    @Test("Given the café's sample data, when the headline is written, then it names July and the ends of its bar")
    func headlineNamesTheWidestMonth() {
        #expect(
            summary(CafeData.monthlySummaries).headline
                == "July had the widest gap between its quietest and busiest day: 171 to 347 cups."
        )
    }

    @Test("Given two months tied for the widest gap, when the headline is written, then it names both and gives the gap")
    func tieNamesBothMonths() {
        let tied = [month(0, 100, 200, 150), month(1, 150, 250, 200), month(2, 120, 180, 150)]

        #expect(summary(tied).widestMonths.count == 2)
        #expect(summary(tied).headline == "March and April had the widest gap between quietest and busiest day: 100 cups.")
    }

    @Test("Given months whose lowest and highest day are equal, when the headline is written, then it claims no widest month")
    func flatMonthsClaimNoGap() {
        let flat = [month(0, 100, 100, 100), month(1, 120, 120, 120)]

        #expect(summary(flat).hasData)
        #expect(summary(flat).headline == "No month had a gap between its quietest and busiest day.")
    }

    @Test("Given no months, when the chart's words are written, then they say nothing was sold")
    func emptyDataSaysSo() {
        #expect(!summary([]).hasData)
        #expect(summary([]).headline == "No cups sold yet.")
        #expect(summary([]).audioGraphSummary == "No cups sold yet.")
    }

    @Test("Given months that are all zero, when the chart's words are written, then they say nothing was sold")
    func allZeroDataSaysSo() {
        let zeros = [month(0, 0, 0, 0), month(1, 0, 0, 0)]

        #expect(!summary(zeros).hasData)
        #expect(summary(zeros).widestMonths.isEmpty)
        #expect(summary(zeros).headline == "No cups sold yet.")
        #expect(summary(zeros).audioGraphSummary == "No cups sold yet.")
    }

    // MARK: Derived text

    @Test("Given a count, when it is written with its unit, then the unit agrees with the number")
    func countsAgreeInNumber() {
        #expect(summary([]).cupsText(1) == "1 cup")
        #expect(summary([]).cupsText(0) == "0 cups")
        #expect(summary([]).cupsText(301) == "301 cups")
        #expect(summary([]).monthsText(1) == "1 month")
        #expect(summary([]).monthsText(6) == "6 months")
    }

    @Test("Given a month, when its element is written, then the label is the month and year and the value names all three figures in cups")
    func elementSaysAllThreeValues() {
        let july = month(4, 137, 301, 219)

        #expect(summary([july]).elementLabel(july) == "July 2026")
        #expect(summary([july]).elementValue(july) == "Lowest day 137 cups, highest day 301 cups, average day 219 cups")
    }

    @Test("Given a month that starts at midnight UTC, when it is named, then it is the month in the data's time zone, not the device's")
    func monthNamedInTheDataTimeZone() {
        #expect(summary([]).monthName(CafeData.month(0)) == "March")
        #expect(summary([]).monthName(CafeData.month(5), withYear: true) == "August 2026")
    }

    @Test("Given a German locale, when the headline is written, then its numbers are grouped the German way")
    func headlineTakesTheLocale() {
        let german = RangeBarSummary(months: [month(0, 1200, 2400, 1800)], locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("1.200"))
        #expect(german.headline.contains("2.400"))
    }

    @Test("Given the sample data, when the Audio Graph summary is written, then it gives the period and the lowest, highest and average days in actual values")
    func summaryGivesActualValues() {
        #expect(
            summary(CafeData.monthlySummaries).audioGraphSummary
                == "6 months, March 2026 to August 2026. Lowest day: 152 cups, in March 2026. "
                + "Highest day: 347 cups, in July 2026. Average day: between 205 and 253 cups."
        )
    }

    // MARK: The chart descriptor

    @Test("Given the sample data, when the chart descriptor is made, then it has a title, the summary and three named series of separate values")
    func descriptorDescribesTheChart() {
        let months = CafeData.monthlySummaries
        let descriptor = RangeBarChartDescriptor(months: months, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Cups a day at the Harbour café: each month's lowest, average and highest day")
        #expect(descriptor.summary == summary(months).audioGraphSummary)
        #expect(descriptor.series.map(\.name) == ["Lowest day", "Average day", "Highest day"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == months.count })
    }

    @Test("Given the sample data, when the descriptor's axes are read, then the months are written out in order and values are said in cups from zero")
    func descriptorAxesHaveDatesAndUnits() throws {
        let descriptor = RangeBarChartDescriptor(months: CafeData.monthlySummaries, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Month")
        #expect(xAxis.categoryOrder == ["March 2026", "April 2026", "May 2026", "June 2026", "July 2026", "August 2026"])
        #expect(yAxis.title == "Cups")
        // The busiest day is 347; the axis is drawn to 400, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 400)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(219) == "219 cups")
    }
}
