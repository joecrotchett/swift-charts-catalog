import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct GroupingWithPlotTests {
    private let locale = Locale(identifier: "en_US")

    private var months: [MonthlySummary] {
        [
            MonthlySummary(month: CafeData.month(0), lowestDay: 118, highestDay: 236, averageDay: 171),
            MonthlySummary(month: CafeData.month(1), lowestDay: 126, highestDay: 301, averageDay: 219),
            MonthlySummary(month: CafeData.month(2), lowestDay: 90, highestDay: 251, averageDay: 184),
        ]
    }

    private var summary: MonthlyRangeSummary {
        MonthlyRangeSummary(months: months, locale: locale)
    }

    // MARK: The view model's states

    @Test("Given a new screen, when it appears, then the marks are grouped in a Plot")
    func startsGrouped() {
        #expect(GroupingWithPlotViewModel().usesPlot)
    }

    @Test("Given the Plot setting, when the snippets are listed, then they are the marks and the modifiers on the Plot")
    func groupedSnippets() {
        let viewModel = GroupingWithPlotViewModel()

        #expect(viewModel.snippets.map(\.name) == ["grouping-with-plot-marks", "grouping-with-plot-group"])
    }

    @Test("Given the setting without a Plot, when the snippets are listed, then they are the marks and the modifiers on each mark")
    func ungroupedSnippets() {
        let viewModel = GroupingWithPlotViewModel()
        viewModel.usesPlot = false

        #expect(viewModel.snippets.map(\.name) == ["grouping-with-plot-marks", "grouping-with-plot-each-mark"])
    }

    @Test("Given the built app, when each snippet the screen can show is looked up, then it exists and holds the code it names")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        let group = try #require(store[GroupingWithPlotViewModel.groupSnippet.name])
        let eachMark = try #require(store[GroupingWithPlotViewModel.eachMarkSnippet.name])
        let marks = try #require(store[GroupingWithPlotViewModel.marksSnippet.name])
        #expect(group.code.contains("Plot {"))
        #expect(!eachMark.code.contains("Plot {"))
        #expect(marks.code.contains("BarMark(") && marks.code.contains("RectangleMark("))
    }

    @Test("Given either setting, when the headline is written, then it is the same, because its figure is on the chart in both")
    func headlineHoldsInBothSettings() {
        let viewModel = GroupingWithPlotViewModel(months: months, locale: locale)
        let grouped = viewModel.headline
        viewModel.usesPlot = false

        #expect(viewModel.headline == grouped)
        #expect(grouped == "April 2026 had the busiest average day: 219 cups.")
    }

    @Test("Given each setting, when its note and announcement are written, then they say how many times an average is written")
    func settingTextFollowsTheSetting() {
        let viewModel = GroupingWithPlotViewModel(months: months, locale: locale)

        #expect(viewModel.settingNote.contains("one group"))
        #expect(viewModel.settingNote.contains("one stop for VoiceOver"))
        #expect(viewModel.announcement == "Chart changed. Each month's average is now written once, above its range bar.")

        viewModel.usesPlot = false

        #expect(viewModel.settingNote.contains("written twice"))
        #expect(viewModel.settingNote.contains("are not read"))
        #expect(
            viewModel.announcement
                == "Chart changed. Each month's average is now written twice, above its range bar and above its average tick."
        )
    }

    @Test("Given no sales, when the switch changes, then the announcement says there is nothing to show")
    func announcementWithNoData() {
        let viewModel = GroupingWithPlotViewModel(months: [], locale: locale)
        viewModel.usesPlot = false

        #expect(viewModel.announcement == "No sales to show.")
    }

    // MARK: Derived text

    @Test("Given the café's sample data, when the headline is written, then it names the month whose average is highest")
    func headlineFollowsSampleData() {
        let sample = MonthlyRangeSummary(months: CafeData.monthlySummaries, locale: locale)

        #expect(sample.headline == "July 2026 had the busiest average day: 253 cups.")
    }

    @Test("Given two months tied for the highest average, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [
            MonthlySummary(month: CafeData.month(0), lowestDay: 100, highestDay: 200, averageDay: 150),
            MonthlySummary(month: CafeData.month(1), lowestDay: 110, highestDay: 190, averageDay: 150),
        ]

        #expect(
            MonthlyRangeSummary(months: tied, locale: locale).headline
                == "March 2026 and April 2026 had the busiest average day: 150 cups."
        )
    }

    @Test("Given no months, when the chart's words are written, then they say nothing was sold")
    func emptySaysSo() {
        let empty = MonthlyRangeSummary(months: [], locale: locale)

        #expect(empty.isEmpty)
        #expect(empty.headline == "No sales recorded yet.")
        #expect(empty.audioGraphSummary(usesPlot: true) == "No sales recorded yet.")
        #expect(empty.audioGraphSummary(usesPlot: false) == "No sales recorded yet.")
    }

    @Test("Given months that are all zero, when the chart's words are written, then they say nothing was sold, not that a month was busiest")
    func allZeroSaysSo() {
        let zeros = MonthlyRangeSummary(
            months: [
                MonthlySummary(month: CafeData.month(0), lowestDay: 0, highestDay: 0, averageDay: 0),
                MonthlySummary(month: CafeData.month(1), lowestDay: 0, highestDay: 0, averageDay: 0),
            ],
            locale: locale
        )

        #expect(zeros.isEmpty)
        #expect(zeros.busiestMonths.isEmpty)
        #expect(zeros.headline == "No sales recorded yet.")
    }

    @Test("Given a month, when its accessibility label and value are written, then the month comes first and the value has its unit")
    func monthLabelAndValue() throws {
        let march = try #require(months.first)

        #expect(summary.accessibilityLabel(for: march) == "March 2026")
        #expect(summary.accessibilityValue(for: march) == "118 to 236 cups a day, average 171 cups")
    }

    @Test("Given a month whose average day is one cup, when its accessibility value is written, then the average's unit agrees in number")
    func averageUnitAgreesInNumber() {
        let quiet = MonthlySummary(month: CafeData.month(0), lowestDay: 0, highestDay: 3, averageDay: 1)

        #expect(summary.accessibilityValue(for: quiet) == "0 to 3 cups a day, average 1 cup")
    }

    @Test("Given a count of cups, when it is written, then the unit agrees with the number")
    func cupsAgreeInNumber() {
        #expect(MonthlyRangeSummary.cupsText(1, locale: locale) == "1 cup")
        #expect(MonthlyRangeSummary.cupsText(0, locale: locale) == "0 cups")
        #expect(MonthlyRangeSummary.cupsText(219, locale: locale) == "219 cups")
    }

    @Test("Given each setting, when the Audio Graph summary is written, then it gives actual values and says where the averages are written")
    func summaryFollowsTheSetting() {
        let values = "3 months, March 2026 to May 2026. Lowest day 90 cups, in May 2026. "
            + "Highest day 301 cups, in April 2026. Average day from 171 to 219 cups. "

        #expect(summary.audioGraphSummary(usesPlot: true) == values + "Each month's average is written once, above its range bar.")
        #expect(
            summary.audioGraphSummary(usesPlot: false)
                == values + "Each month's average is written twice, above its range bar and above its average tick."
        )
    }

    // MARK: The chart descriptor

    @Test("Given monthly ranges, when the chart descriptor is made, then it has a title, the setting's summary and three named series of separate marks")
    func descriptorDescribesTheChart() {
        let descriptor = MonthlyRangeChartDescriptor(summary: summary, usesPlot: false).makeChartDescriptor()

        #expect(descriptor.title == "Cups a day at the Harbour café, by month")
        #expect(descriptor.summary == summary.audioGraphSummary(usesPlot: false))
        #expect(descriptor.series.map(\.name) == ["Lowest day", "Average day", "Highest day"])
        // A key path inside #expect does not compile here, and swiftformat rewrites a closure into one.
        // Range bars and ticks per month, not a connected line.
        #expect(descriptor.series.map(\.isContinuous) == [false, false, false])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == months.count })
    }

    @Test("Given monthly ranges, when the descriptor's axes are read, then months are written out in order and values are said in cups from zero")
    func descriptorAxes() throws {
        let descriptor = MonthlyRangeChartDescriptor(summary: summary, usesPlot: true).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Month")
        #expect(xAxis.categoryOrder == ["March 2026", "April 2026", "May 2026"])
        #expect(yAxis.title == "Cups")
        // The highest day is 301; the axis is drawn to 400, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 400)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(171) == "171 cups")
    }

    @Test("Given a summary in German formats, when the descriptor says a value and the headline is written, then both use that locale, not the device's")
    func descriptorValuesFollowTheInjectedLocale() throws {
        let busy = [MonthlySummary(month: CafeData.month(0), lowestDay: 900, highestDay: 2400, averageDay: 1500)]
        let german = MonthlyRangeSummary(months: busy, locale: Locale(identifier: "de_DE"))
        let yAxis = try #require(MonthlyRangeChartDescriptor(summary: german, usesPlot: true).makeChartDescriptor().yAxis)

        #expect(yAxis.valueDescriptionProvider(1500) == "1.500 cups")
        #expect(german.headline.hasSuffix("had the busiest average day: 1.500 cups."))
        #expect(german.accessibilityValue(for: busy[0]) == "900 to 2.400 cups a day, average 1.500 cups")
    }
}
