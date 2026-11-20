import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct AxisDensityTests {
    private let locale = Locale(identifier: "en_US")

    private func totals(_ days: [DailySales] = CafeData.thirtyDays) -> AxisDensityTotals {
        AxisDensityTotals(days: days, locale: locale)
    }

    // MARK: The view model

    @Test("Given a new screen, when it appears, then it asks for three quiet grid lines with short labels")
    func startsQuietAndShort() {
        let viewModel = AxisDensityViewModel()

        #expect(viewModel.requestedCount == 3)
        #expect(!viewModel.isHeavy)
        #expect(viewModel.labelLength == .short)
        #expect(viewModel.snippets.map(\.name) == ["axes-density-and-weight-quiet", "axes-density-and-weight-short-labels"])
    }

    @Test("Given the quiet axis, when heavy is switched on, then the heavy snippet replaces the quiet one")
    func heavySnippet() {
        let viewModel = AxisDensityViewModel()

        viewModel.isHeavy = true

        #expect(viewModel.snippets.map(\.name) == ["axes-density-and-weight-heavy", "axes-density-and-weight-short-labels"])
    }

    @Test("Given short labels, when full labels are chosen, then the full-labels snippet is shown")
    func fullLabelsSnippet() {
        let viewModel = AxisDensityViewModel()

        viewModel.labelLength = .full

        #expect(viewModel.snippets.map(\.name) == ["axes-density-and-weight-quiet", "axes-density-and-weight-full-labels"])
    }

    @Test("Given each label length, when a value is formatted, then short gives 5K and full gives 5,000")
    func labelFormats() {
        let viewModel = AxisDensityViewModel()

        viewModel.labelLength = .short
        let short = viewModel.valueFormat(locale: locale)
        viewModel.labelLength = .full
        let full = viewModel.valueFormat(locale: locale)

        #expect(short.format(5000) == "5K")
        #expect(short.format(2500) == "2.5K")
        #expect(full.format(5000) == "5,000")
    }

    @Test("Given a German locale, when a full label is formatted, then it groups thousands the German way")
    func labelLocale() {
        let viewModel = AxisDensityViewModel()
        viewModel.labelLength = .full

        #expect(viewModel.valueFormat(locale: Locale(identifier: "de_DE")).format(5000) == "5.000")
    }

    @Test("Given a count, when the stepper's text is read, then it says the count asked for")
    func countText() {
        let viewModel = AxisDensityViewModel()
        viewModel.requestedCount = 10

        #expect(viewModel.countText(locale: locale) == "Grid lines asked for: 10")
    }

    @Test("Given a measured plot, when its width is written, then it is rounded and agrees in number")
    func plotWidthText() {
        let viewModel = AxisDensityViewModel()
        #expect(viewModel.plotWidthText(locale: locale) == nil)

        viewModel.plotWidth = 300.6
        #expect(viewModel.plotWidthText(locale: locale) == "Plot width: 301 points")

        viewModel.plotWidth = 1
        #expect(viewModel.plotWidthText(locale: locale) == "Plot width: 1 point")
    }

    // MARK: The running total

    @Test("Given thirty days, when they are totalled, then the line ends at the headline's figure")
    func runningTotal() {
        let totals = totals()

        #expect(totals.running.count == 30)
        #expect(totals.running.first?.cupsSoFar == CafeData.thirtyDays.first?.cups)
        #expect(totals.running.last?.cupsSoFar == 5596)
        #expect(totals.total == 5596)
        #expect(totals.headline == "5,596 cups sold in 30 days.")
        #expect(totals.valueDomain == 0 ... 6000)
    }

    @Test("Given thirty days, when they are split into weeks, then there are five, the last of two days")
    func weeks() throws {
        let totals = totals()
        let weeks = totals.weeks

        #expect(weeks.count == 5)
        #expect(weeks.last?.days.count == 2)
        let first = try #require(weeks.first)
        #expect(totals.label(for: first) == "March 1 to March 7")
        #expect(totals.value(for: first) == "From 174 cups to 1,141 cups so far")
    }

    @Test("Given a week of one day, when it is described, then it names the day and one total")
    func oneDayWeek() throws {
        let totals = totals(Array(CafeData.thirtyDays.prefix(8)))
        let last = try #require(totals.weeks.last)

        #expect(totals.label(for: last) == "March 8")
        #expect(totals.value(for: last).hasSuffix("cups so far"))
        #expect(!totals.value(for: last).hasPrefix("From"))
    }

    @Test("Given the data, when the caption is read, then it names the month")
    func caption() {
        #expect(totals().caption == "Invented sample: cups sold so far at the Harbour café, March 2026")
        #expect(totals(Array(CafeData.harbourSales.prefix(3))).caption == "Cups sold so far at the Harbour café, March 2026")
        #expect(totals([]).caption == "Cups sold so far at the Harbour café")
    }

    @Test("Given the default and accessibility text sizes, when a date label is formatted, then the large size drops the month")
    func dateLabels() {
        let totals = totals()
        let day = CafeData.day(14)

        #expect(day.formatted(totals.axisDateFormat(accessibilitySize: false)) == "Mar 15")
        #expect(day.formatted(totals.axisDateFormat(accessibilitySize: true)) == "15")
    }

    @Test("Given no days, when the chart is described, then the headline and summary say so and the axis still has a range")
    func noDays() {
        let totals = totals([])

        #expect(!totals.hasData)
        #expect(totals.headline == "No days recorded yet.")
        #expect(totals.audioGraphSummary == "No days recorded yet.")
        #expect(totals.valueDomain == 0 ... 1000)
        #expect(totals.weeks.isEmpty)
    }

    @Test("Given only zero days, when the chart is described, then the headline says no cups and the line is drawn flat")
    func zeroDays() {
        let zeros = CafeData.thirtyDays.map { DailySales(day: $0.day, cups: 0) }
        let totals = totals(zeros)

        #expect(totals.hasData)
        #expect(totals.headline == "0 cups sold in 30 days.")
        #expect(totals.running.allSatisfy { $0.cupsSoFar == 0 })
        #expect(totals.valueDomain == 0 ... 1000)
    }

    @Test("Given one day of one cup, when the headline is written, then the counts agree in number")
    func singular() {
        let totals = totals([DailySales(day: CafeData.firstDay, cups: 1)])

        #expect(totals.headline == "1 cup sold in 1 day.")
    }

    // MARK: The Audio Graph

    @Test("Given thirty days, when the descriptor is made, then it has a title, summary, days and a continuous series")
    func descriptor() throws {
        let descriptor = AxisDensityChartDescriptor(totals: totals()).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold so far at the Harbour café, day by day")
        #expect(descriptor.summary == "30 days, March 1 to March 30. Cups so far: 174 cups after the first day, 5,596 cups after the last.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder.first == "March 1")
        #expect(xAxis.categoryOrder.count == 30)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == AxisDensityWording.cupsSoFar)
        #expect(yAxis.range == 0 ... 6000)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(5596) == "5,596 cups")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 30)
    }

    @Test("Given thirty days or none, when the explanation is written, then it names the unmarked top only when there is a chart")
    func explanationNamesTop() {
        #expect(totals(CafeData.thirtyDays).explanation.contains("nothing marks the top of the axis at 6,000"))
        #expect(!totals([]).explanation.contains("top of the axis"))
    }

    @Test("Given the app's snippets, when they are loaded, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for name in [
            "axes-density-and-weight-quiet", "axes-density-and-weight-heavy",
            "axes-density-and-weight-full-labels", "axes-density-and-weight-short-labels",
        ] {
            #expect(store[name] != nil, "missing \(name)")
        }
    }
}
