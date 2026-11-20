import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct LayeringMarksTests {
    private func summary(
        _ months: [MonthlySummary] = CafeData.monthlySummaries,
        range: Bool = true, tick: Bool = true, rule: Bool = true
    ) -> LayeringMarksSummary {
        LayeringMarksSummary(months: months, layers: LayeringMarksLayers(range: range, tick: tick, rule: rule))
    }

    private func month(_ offset: Int, _ low: Int, _ high: Int, _ average: Int) -> MonthlySummary {
        MonthlySummary(month: CafeData.month(offset), lowestDay: low, highestDay: high, averageDay: average)
    }

    // MARK: View model

    @Test("Given a new screen, when it appears, then every layer is on and every layer's snippet is shown")
    func startsWithEveryLayer() {
        let viewModel = LayeringMarksViewModel()

        #expect(viewModel.layers == LayeringMarksLayers(range: true, tick: true, rule: true))
        #expect(viewModel.snippets.map(\.name) == ["layering-marks-range", "layering-marks-tick", "layering-marks-rule"])
        #expect(viewModel.months == CafeData.monthlySummaries)
    }

    @Test("Given a layer switched off, when the snippets are listed, then that layer's snippet is left out")
    func snippetsFollowLayers() {
        let viewModel = LayeringMarksViewModel()

        viewModel.layers.tick = false
        #expect(viewModel.snippets.map(\.name) == ["layering-marks-range", "layering-marks-rule"])

        viewModel.layers.range = false
        #expect(viewModel.snippets.map(\.name) == ["layering-marks-rule"])

        viewModel.layers = LayeringMarksLayers(range: false, tick: true, rule: false)
        #expect(viewModel.snippets.map(\.name) == ["layering-marks-tick"])
    }

    @Test("Given every layer switched off, when the snippets are listed, then the whole composition is shown")
    func noLayersShowsAllSnippets() {
        let viewModel = LayeringMarksViewModel()
        viewModel.layers = LayeringMarksLayers(range: false, tick: false, rule: false)

        #expect(viewModel.layers.isEmpty)
        #expect(viewModel.snippets == LayeringMarksViewModel.allSnippets)
        #expect(viewModel.summary.headline == "Every layer is switched off.")
    }

    @Test("Given a layer switched, when the summary is read, then it is for the new setting")
    func summaryFollowsLayers() {
        let viewModel = LayeringMarksViewModel()
        viewModel.layers.rule = false

        #expect(viewModel.summary.layers == viewModel.layers)
        #expect(viewModel.summary.ruleValue == nil)
    }

    // MARK: Headline

    @Test("Given the rule is drawn, when the headline is written, then it gives the figure written on the rule")
    func headlineWithRule() {
        #expect(summary().overallAverage == 231)
        #expect(summary().headline == "The 6-month average is 231 cups a day.")
        #expect(summary(range: false, tick: false).headline == "The 6-month average is 231 cups a day.")
        #expect(summary().calloutMonths.isEmpty)
    }

    @Test("Given the ticks without the rule, when the headline is written, then it names the month with the highest average day")
    func headlineWithTicks() {
        let ticks = summary(rule: false)

        #expect(ticks.headline == "July 2026 had the highest average day: 253 cups.")
        #expect(ticks.calloutMonths.map(\.month) == [CafeData.month(4)])
        #expect(ticks.calloutMonths.map { ticks.calloutValue(for: $0) } == [253])
        #expect(summary(range: false, rule: false).headline == ticks.headline)
    }

    @Test("Given only the range bars, when the headline is written, then it names the month with the busiest day")
    func headlineWithRangeOnly() {
        let range = summary(tick: false, rule: false)

        #expect(range.headline == "July 2026 had the busiest day: 347 cups.")
        #expect(range.calloutMonths.map { range.calloutValue(for: $0) } == [347])
    }

    @Test("Given two months tied, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [month(0, 100, 240, 180), month(1, 110, 240, 180), month(2, 90, 200, 150)]

        #expect(summary(tied, rule: false).headline == "March 2026 and April 2026 had the highest average day: 180 cups.")
        #expect(summary(tied, tick: false, rule: false).headline == "March 2026 and April 2026 had the busiest day: 240 cups.")
        #expect(summary(tied, tick: false, rule: false).calloutMonths.count == 2)
    }

    @Test("Given no months or only zeros, when the chart's words are written, then they say there is nothing to show")
    func emptyAndZeroData() {
        let zeros = [month(0, 0, 0, 0), month(1, 0, 0, 0)]

        for empty in [summary([]), summary(zeros), summary(zeros, rule: false)] {
            #expect(!empty.hasData)
            #expect(empty.overallAverage == nil)
            #expect(empty.ruleValue == nil)
            #expect(empty.calloutMonths.isEmpty)
            #expect(empty.headline == "No sales to show yet.")
            #expect(empty.audioGraphSummary == "No sales to show yet.")
        }
    }

    @Test("Given an average of one cup, when it is written, then the unit agrees in number")
    func oneCup() {
        #expect(LayeringMarksSummary.cupsText(1) == "1 cup")
        #expect(summary([month(0, 0, 2, 1)]).headline == "The 1-month average is 1 cup a day.")
    }

    // MARK: Accessibility text

    @Test("Given layers on and off, when a month's value is read, then it gives only what is drawn for it")
    func monthValueFollowsLayers() {
        let march = CafeData.monthlySummaries[0]

        #expect(LayeringMarksSummary.monthName(march.month) == "March 2026")
        #expect(summary().accessibilityValue(for: march) == "Lowest day: 152 cups, Highest day: 282 cups, Average day: 205 cups")
        #expect(summary(tick: false).accessibilityValue(for: march) == "Lowest day: 152 cups, Highest day: 282 cups")
        #expect(summary(range: false).accessibilityValue(for: march) == "Average day: 205 cups")
    }

    @Test("Given a layer switched, when the change is announced, then it says what is shown and the new headline")
    func changeAnnouncement() {
        #expect(
            summary(tick: false).changeAnnouncement
                == "Showing the range bars and the average rule. The 6-month average is 231 cups a day."
        )
        #expect(
            summary(range: false, tick: false, rule: false).changeAnnouncement
                == "Showing no layers. Every layer is switched off."
        )
    }

    @Test("Given layers on and off, when the Audio Graph summary is written, then it states only the drawn layers in actual values")
    func audioGraphSummary() {
        #expect(
            summary().audioGraphSummary
                == "6 months, March 2026 to August 2026. Lowest day: 152 cups, in March 2026. "
                + "Highest day: 347 cups, in July 2026. Highest average day: 253 cups, in July 2026. "
                + "6-month average: 231 cups a day."
        )
        #expect(summary(range: false, tick: false).audioGraphSummary == "6-month average: 231 cups a day.")
        #expect(
            summary(range: false, rule: false).audioGraphSummary
                == "6 months, March 2026 to August 2026. Highest average day: 253 cups, in July 2026."
        )
    }

    // MARK: Chart descriptor

    @Test("Given every layer, when the descriptor is made, then it has a series per monthly value, named axes and units")
    func descriptorWithEveryLayer() throws {
        let descriptor = LayeringMarksChartDescriptor(summary: summary()).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups a day at the Harbour café, by month")
        #expect(descriptor.summary == summary().audioGraphSummary)
        #expect(xAxis.title == "Month")
        #expect(xAxis.categoryOrder == ["March 2026", "April 2026", "May 2026", "June 2026", "July 2026", "August 2026"])
        #expect(yAxis.title == "Cups")
        // The highest day is 347; the axis is drawn to 400, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 400)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(231) == "231 cups")
        #expect(descriptor.series.map(\.name) == ["Lowest day", "Highest day", "Average day"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 6 && !$0.isContinuous })
    }

    @Test("Given layers switched off, when the descriptor is made, then it describes only what is drawn")
    func descriptorFollowsLayers() throws {
        let ticksOnly = LayeringMarksChartDescriptor(summary: summary(range: false, rule: false)).makeChartDescriptor()
        let ruleOnly = LayeringMarksChartDescriptor(summary: summary(range: false, tick: false)).makeChartDescriptor()
        let ruleAxis = try #require(ruleOnly.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(ticksOnly.series.map(\.name) == ["Average day"])
        #expect(ruleOnly.series.isEmpty)
        #expect(ruleAxis.categoryOrder.isEmpty)
        #expect(ruleOnly.summary == "6-month average: 231 cups a day.")
        // The axis does not move as layers go.
        #expect(ticksOnly.yAxis?.range == 0 ... 400)
        #expect(ruleOnly.yAxis?.range == 0 ... 400)
    }
}
