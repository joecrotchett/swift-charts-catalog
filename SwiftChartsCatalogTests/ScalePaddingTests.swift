import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ScalePaddingTests {
    private let english = Locale(identifier: "en_US")
    private let week = Array(CafeData.harbourSales.prefix(7))

    // MARK: View model

    @Test("Given a new screen, when it opens, then a week is drawn with no padding")
    func defaultState() {
        let viewModel = ScalePaddingViewModel()

        #expect(viewModel.days.count == 7)
        #expect(viewModel.startPadding == 0)
        #expect(viewModel.endPadding == 0)
        #expect(viewModel.form == .none)
        #expect(ScalePaddingViewModel.paddingRange.contains(viewModel.startPadding))
    }

    @Test("Given each pair of paddings, when the form is read, then it is the form that writes them", arguments: [
        (0.0, 0.0, ScalePaddingForm.none),
        (12.0, 12.0, .bothEnds),
        (40.0, 40.0, .bothEnds),
        (0.0, 16.0, .eachEnd),
        (8.0, 0.0, .eachEnd),
        (8.0, 24.0, .eachEnd),
    ])
    func forms(start: Double, end: Double, expected: ScalePaddingForm) {
        let viewModel = ScalePaddingViewModel()
        viewModel.startPadding = start
        viewModel.endPadding = end

        #expect(viewModel.form == expected)
    }

    @Test("Given each form, when the snippets are asked for, then the chart and that form's snippet are shown", arguments: [
        (0.0, 0.0, "scale-padding-none"),
        (20.0, 20.0, "scale-padding-both-ends"),
        (4.0, 20.0, "scale-padding-each-end"),
    ])
    func snippets(start: Double, end: Double, formSnippet: String) {
        let viewModel = ScalePaddingViewModel()
        viewModel.startPadding = start
        viewModel.endPadding = end

        #expect(viewModel.snippets.map(\.name) == ["scale-padding-chart", formSnippet])
    }

    @Test("Given the built app, when the snippets are read, then each form's code is the one it names")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        #expect(try #require(store["scale-padding-chart"]).code.contains(".chartXScale(range: xRange)"))
        #expect(try #require(store["scale-padding-none"]).code.contains(".plotDimension"))
        #expect(try #require(store["scale-padding-both-ends"]).code.contains(".plotDimension(padding: startPadding)"))
        #expect(try #require(store["scale-padding-each-end"]).code
            .contains(".plotDimension(startPadding: startPadding, endPadding: endPadding)"))
    }

    // MARK: Slider text

    @Test("Given a padding, when the slider's text is read, then it shows the points and speaks them before the headline")
    func sliderText() {
        let viewModel = ScalePaddingViewModel()

        #expect(viewModel.paddingText(1, locale: english) == "1 point")
        #expect(viewModel.paddingText(16, locale: english) == "16 points")
        #expect(viewModel.spokenPadding(16, locale: english)
            == "16 points. The most in a day: 219 cups, on Saturday, March 7.")
    }

    // MARK: Headline

    @Test("Given the sample week, when the headline is read, then it names the busiest day and its cups")
    func headline() {
        let summary = ScalePaddingSummary(days: week, locale: english)

        #expect(summary.headline == "The most in a day: 219 cups, on Saturday, March 7.")
    }

    @Test("Given any padding, when the headline is read, then it does not change")
    func headlineIgnoresPadding() {
        let viewModel = ScalePaddingViewModel()
        let before = viewModel.summary(locale: english).headline
        viewModel.startPadding = 10
        viewModel.endPadding = 30

        #expect(viewModel.summary(locale: english).headline == before)
    }

    @Test("Given two days tied for the most, when the headline is read, then it names both")
    func headlineTie() {
        let days = [
            DailySales(day: CafeData.day(0), cups: 200),
            DailySales(day: CafeData.day(1), cups: 150),
            DailySales(day: CafeData.day(2), cups: 200),
        ]

        #expect(ScalePaddingSummary(days: days, locale: english).headline
            == "The most in a day: 200 cups, on Sunday, March 1 and Tuesday, March 3.")
    }

    @Test("Given no days, zeros, or the same every day, when the headline is read, then it stays true", arguments: [
        ([Int](), "No days to show yet."),
        ([0, 0, 0], "No cups sold on any day: 0 cups each day."),
        ([1, 1], "Every day sold 1 cup."),
    ])
    func headlineEdgeCases(cups: [Int], expected: String) {
        let days = cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }

        #expect(ScalePaddingSummary(days: days, locale: english).headline == expected)
    }

    @Test("Given a German locale, when the headline is read, then the number is written the German way")
    func headlineLocale() {
        let days = [DailySales(day: CafeData.day(0), cups: 1234), DailySales(day: CafeData.day(1), cups: 10)]
        let headline = ScalePaddingSummary(days: days, locale: Locale(identifier: "de_DE")).headline

        #expect(headline.contains("1.234 cups"))
    }

    // MARK: Chart descriptor

    @Test("Given the sample week, when the descriptor is made, then it describes one continuous line of written-out days")
    func descriptor() throws {
        let descriptor = ScalePaddingChartDescriptor(days: week, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold each day at the Harbour café, March 1 to March 7")
        #expect(descriptor.summary == "7 days. First day 190 cups, last day 219 cups. "
            + "Highest 219 cups, on Saturday, March 7. Lowest 152 cups, on Tuesday, March 3.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.count == 7)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The busiest day is 219; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(219) == "219 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 7)
    }

    @Test("Given no days, when the descriptor is made, then its summary says so")
    func emptyDescriptor() {
        let descriptor = ScalePaddingChartDescriptor(days: [], locale: english).makeChartDescriptor()

        #expect(descriptor.summary == "No days to show yet.")
        #expect(descriptor.series.first?.dataPoints.isEmpty == true)
    }

    @Test("Given the catalog, when the screen is looked up, then it is a Scales screen titled Scale padding")
    func catalogEntry() throws {
        let screen = try #require(Catalog.screen(id: "scales/scale-padding"))

        #expect(screen.title == "Scale padding")
    }
}
