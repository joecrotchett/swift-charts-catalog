import Accessibility
import CoreGraphics
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct PlotFramesTests {
    private let english = Locale(identifier: "en_US")

    private func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    @Test("Given four weeks and the border on the container, when the headline is written, then it names the week in view of 28 days")
    func containerHeadline() {
        let viewModel = PlotFramesViewModel()

        #expect(viewModel.headline(locale: english) == "Only the 7 days in view are inside plotContainerFrame, of 28 days.")
    }

    @Test("Given four weeks, when the border moves to the plot frame, then the headline says every day is inside it")
    func plotHeadline() {
        let viewModel = PlotFramesViewModel()
        viewModel.followsPlotFrame = true

        #expect(viewModel.headline(locale: english) == "All 28 days are inside plotFrame, with 7 days in view.")
    }

    @Test("Given fewer days than a week, when the headline is written, then it says the two frames are the same, for either setting")
    func shortDataHeadline() {
        let viewModel = PlotFramesViewModel(days: days([10, 20, 30]))
        let container = viewModel.headline(locale: english)
        viewModel.followsPlotFrame = true

        #expect(container == "The whole plot, 3 days, is in view, so plotFrame and plotContainerFrame are the same.")
        #expect(viewModel.headline(locale: english) == container)
        #expect(viewModel.visibleDayCount == 3)
        #expect(viewModel.visibleSeconds == 3 * 86400)
    }

    @Test("Given one day, when the headline is written, then the count agrees in number")
    func oneDayAgrees() {
        let viewModel = PlotFramesViewModel(days: days([12]))

        #expect(viewModel.headline(locale: english) == "The whole plot, 1 day, is in view, so plotFrame and plotContainerFrame are the same.")
    }

    @Test("Given no days, when the chart's words are written, then they say there is nothing to chart and no bars are drawn")
    func emptyData() {
        let viewModel = PlotFramesViewModel(days: [])

        #expect(!viewModel.hasMarks)
        #expect(viewModel.headline(locale: english) == "No days to chart yet.")
        #expect(viewModel.summary(locale: english).audioGraphSummary == "No days to chart yet.")
    }

    @Test("Given only zeros, when the headline is written, then it says nothing sold and the chart shows its placeholder")
    func allZeroData() {
        let viewModel = PlotFramesViewModel(days: days(Array(repeating: 0, count: 10)))

        #expect(!viewModel.hasMarks)
        #expect(viewModel.headline(locale: english) == "No cups sold in 10 days.")
    }

    @Test("Given one day of zeros, when the headline is written, then it reads as a sentence")
    func oneZeroDay() {
        #expect(PlotFramesViewModel(days: days([0])).headline(locale: english) == "No cups sold in 1 day.")
    }

    @Test("Given four weeks, when the explanation is written, then it says the chart scrolls and to watch the border")
    func explanationScrolling() {
        let text = PlotFramesViewModel().explanation

        #expect(text.contains("Scroll the chart and watch the border"))
        #expect(!text.contains("does not scroll"))
    }

    @Test("Given a week or fewer days, when the explanation is written, then it says the chart does not scroll and the frames are the same")
    func explanationFits() {
        for count in [3, 7] {
            let text = PlotFramesViewModel(days: days(Array(repeating: 5, count: count))).explanation

            #expect(text.contains("does not scroll and the two frames are the same"))
            #expect(!text.contains("Scroll the chart"))
        }
    }

    @Test("Given no bars to draw, when the explanation is written, then it states the concept and nothing about this chart's border")
    func explanationPlaceholder() {
        for rows in [[], days([0, 0])] {
            let text = PlotFramesViewModel(days: rows).explanation

            #expect(text.contains("plotContainerFrame"))
            #expect(!text.contains("border"))
            #expect(!text.contains("Here"))
        }
    }

    @Test("Given the built app, when the chart's snippet is read, then it shows where scrolling comes to rest")
    func snippetShowsScrollTarget() throws {
        let code = try #require(try SnippetStore()["plot-frame-and-container-frame-chart"]?.code)

        #expect(code.contains("chartScrollTargetBehavior(.valueAligned(matching: DateComponents(hour: 0), majorAlignment: .page))"))
    }

    @Test("Given the default setting, when snippets are listed, then they are the chart and the container frame's border")
    func containerSnippets() {
        #expect(PlotFramesViewModel().snippetNames == [
            "plot-frame-and-container-frame-chart", "plot-frame-and-container-frame-container-frame",
        ])
    }

    @Test("Given the border on the plot frame, when snippets are listed, then they are the chart and the plot frame's border")
    func plotSnippets() {
        let viewModel = PlotFramesViewModel()
        viewModel.followsPlotFrame = true

        #expect(viewModel.snippets.map(\.name) == [
            "plot-frame-and-container-frame-chart", "plot-frame-and-container-frame-plot-frame",
        ])
    }

    @Test("Given the built app, when every snippet the screen can show is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for name in [
            "plot-frame-and-container-frame-chart",
            "plot-frame-and-container-frame-plot-frame",
            "plot-frame-and-container-frame-container-frame",
        ] {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    @Test("Given the toggle moved, when the change is announced, then it says what changed and then the headline")
    func announcement() {
        let viewModel = PlotFramesViewModel()
        viewModel.followsPlotFrame = true

        #expect(viewModel.announcement(locale: english) == "Border on plotFrame. All 28 days are inside plotFrame, with 7 days in view.")
        viewModel.followsPlotFrame = false
        #expect(viewModel.announcement(locale: english).hasPrefix("Border on plotContainerFrame. Only the 7 days"))
    }

    @Test("Given frames reported by the chart, when they are recorded, then the readout gives each width and position")
    func readout() {
        let viewModel = PlotFramesViewModel()
        viewModel.record(PlotFramesMeasurement(
            plot: CGRect(x: -340.4, y: 0, width: 1092, height: 200),
            container: CGRect(x: 0, y: 0, width: 273, height: 200)
        ))

        #expect(PlotFramesViewModel.readout(viewModel.measurement?.plot, locale: english) == "1,092 points wide, at x -340 points")
        #expect(PlotFramesViewModel.readout(viewModel.measurement?.container, locale: english) == "273 points wide, at x 0 points")
        #expect(PlotFramesViewModel.readout(nil, locale: english) == "—")
    }

    @Test("Given a German locale, when the headline is written, then its numbers follow that locale")
    func localeReachesHeadline() {
        let viewModel = PlotFramesViewModel(days: days(Array(repeating: 5, count: 1200)))

        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")).contains("1.200 days"))
    }

    @Test("Given four weeks, when the bars' labels are written, then a day is written out in the data's time zone")
    func dayNames() {
        let summary = PlotFramesViewModel().summary(locale: english)

        #expect(summary.dayName(CafeData.day(0)) == "Sunday, March 1")
    }

    @Test("Given four weeks, when the chart descriptor is made, then it has the title, summary, days and range of the chart")
    func descriptor() throws {
        let days = CafeData.harbourSales
        let summary = PlotFramesSummary(days: days, visibleDays: PlotFramesViewModel.visibleDays, locale: english)
        let descriptor = PlotFramesChartDescriptor(days: days, summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Cups a day at the Harbour café")
        #expect(descriptor.summary == summary.audioGraphSummary)
        #expect(summary.audioGraphSummary.hasPrefix("28 days, Sunday, March 1 to Saturday, March 28. First day"))
        #expect(summary.audioGraphSummary.hasSuffix("7 days are in view at a time; the chart scrolls."))
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.count == 28)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        let yAxis = try #require(descriptor.yAxis)
        // The drawn axis: the most cups (282) rounded up to 300, the domain the chart is given.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Harbour"])
        #expect(descriptor.series.first?.dataPoints.count == 28)
        #expect(descriptor.series.first?.isContinuous == false)
    }
}
