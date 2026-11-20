import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct BoxPlotTests {
    private let locale = Locale(identifier: "en_US")
    /// The five numbers worked out from `CafeData.orderWaits`, which `CafeData.waitQuartiles` must equal.
    private let waits = [
        WaitQuartiles(store: "Harbour", minimum: 59, lowerQuartile: 103, median: 143.5, upperQuartile: 183.5, maximum: 214),
        WaitQuartiles(store: "Station", minimum: 74, lowerQuartile: 120.5, median: 178, upperQuartile: 252.5, maximum: 309),
    ]

    private func summary(
        _ waits: [WaitQuartiles]? = nil, range: Bool = true, middleHalf: Bool = true, median: Bool = true
    ) -> BoxPlotSummary {
        BoxPlotSummary(
            waits: waits ?? self.waits,
            layers: BoxPlotLayers(range: range, middleHalf: middleHalf, median: median),
            locale: locale
        )
    }

    // MARK: View model

    @Test("Given a new screen, when it opens, then all three layers are on and it draws the café's waits")
    func startsWithEveryLayer() {
        let viewModel = BoxPlotViewModel()

        #expect(viewModel.layers == BoxPlotLayers(range: true, middleHalf: true, median: true))
        #expect(viewModel.waits == CafeData.waitQuartiles)
        #expect(!viewModel.layers.isEmpty)
    }

    @Test("Given every layer on, when the snippets are listed, then the chart and all three layers are shown")
    func snippetsForEveryLayer() {
        let viewModel = BoxPlotViewModel()

        #expect(viewModel.snippets.map(\.name) == ["box-plot-chart", "box-plot-range", "box-plot-middle-half", "box-plot-median"])
    }

    @Test("Given a layer switched off, when the snippets are listed, then that layer's code is left out")
    func snippetsFollowLayers() {
        let viewModel = BoxPlotViewModel()
        viewModel.layers.middleHalf = false
        #expect(viewModel.snippets.map(\.name) == ["box-plot-chart", "box-plot-range", "box-plot-median"])

        viewModel.layers.range = false
        #expect(viewModel.snippets.map(\.name) == ["box-plot-chart", "box-plot-median"])

        viewModel.layers.median = false
        #expect(viewModel.snippets.map(\.name) == ["box-plot-chart"])
        #expect(viewModel.layers.isEmpty)
    }

    @Test("Given the built app, when each snippet the screen can show is looked up, then it exists and holds its mark")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let expected = [
            "box-plot-chart": "BoxPlotMark(",
            "box-plot-range": "RuleMark(",
            "box-plot-middle-half": "BarMark(",
            "box-plot-median": "RectangleMark(",
        ]

        for reference in BoxPlotViewModel().snippets {
            let code = try #require(store[reference.name]?.code)
            let mark = try #require(expected[reference.name])
            #expect(code.contains(mark))
        }
    }

    @Test("Given the median switched off, when the change is announced, then it says what changed and then the new headline")
    func announcementSaysChangeThenHeadline() {
        let viewModel = BoxPlotViewModel(waits: waits)
        let previous = viewModel.layers
        viewModel.layers.median = false

        #expect(
            viewModel.announcement(after: previous, locale: locale)
                == "Median hidden. The middle half of waits ran highest at Station: up to 252.5 seconds."
        )
    }

    @Test("Given the range switched back on, when the change is announced, then it says the range is shown")
    func announcementSaysShown() {
        let viewModel = BoxPlotViewModel(waits: waits)
        viewModel.layers.range = false
        let previous = viewModel.layers
        viewModel.layers.range = true

        #expect(
            viewModel.announcement(after: previous, locale: locale)
                == "Range shown. The highest median wait was at Station: 178 seconds."
        )
    }

    // MARK: Headline

    @Test("Given the median drawn, when the headline is written, then its figure is the highest median")
    func headlineWithMedian() {
        #expect(summary().headline == "The highest median wait was at Station: 178 seconds.")
        #expect(summary(range: false, middleHalf: false).headline == "The highest median wait was at Station: 178 seconds.")
    }

    @Test("Given the median hidden and the box drawn, when the headline is written, then its figure is the top of a box")
    func headlineWithMiddleHalf() {
        #expect(summary(median: false).headline == "The middle half of waits ran highest at Station: up to 252.5 seconds.")
    }

    @Test("Given only the range drawn, when the headline is written, then its figure is the top of a whisker")
    func headlineWithRange() {
        #expect(summary(middleHalf: false, median: false).headline == "The longest wait was at Station: 309 seconds.")
    }

    @Test("Given no layer drawn, when the headline is written, then it claims no figure")
    func headlineWithNoLayer() {
        #expect(summary(range: false, middleHalf: false, median: false).headline == "No layer is switched on.")
    }

    @Test("Given two cafés with the same median, when the headline is written, then it names both")
    func headlineOnATie() {
        let tied = [
            WaitQuartiles(store: "Harbour", minimum: 50, lowerQuartile: 90, median: 150, upperQuartile: 180, maximum: 210),
            WaitQuartiles(store: "Station", minimum: 60, lowerQuartile: 100, median: 150, upperQuartile: 200, maximum: 300),
        ]

        #expect(summary(tied).headline == "The highest median wait was at Harbour and Station: 150 seconds.")
    }

    @Test("Given no rows, or rows of zeros, when the words are written, then they say there are no waits")
    func noWaitsSaySo() {
        let zeros = [WaitQuartiles(store: "Harbour", minimum: 0, lowerQuartile: 0, median: 0, upperQuartile: 0, maximum: 0)]

        for summary in [summary([]), summary(zeros)] {
            #expect(summary.hasNoWaits)
            #expect(summary.headline == "No waits recorded yet.")
            #expect(summary.audioGraphSummary == "No waits recorded yet.")
        }
        #expect(!summary().hasNoWaits)
    }

    // MARK: Derived text

    @Test("Given a count of seconds, when it is written, then the unit agrees with the number")
    func secondsAgreeInNumber() {
        #expect(summary().seconds(1) == "1 second")
        #expect(summary().seconds(0) == "0 seconds")
        #expect(summary().seconds(187) == "187 seconds")
        #expect(summary().seconds(143.5) == "143.5 seconds")
    }

    @Test("Given every layer drawn, when a café's element is described, then it gives all five numbers with their unit")
    func elementValueWithEveryLayer() {
        #expect(
            summary().elementValue(for: waits[0])
                == "Median 143.5 seconds. Middle half 103 to 183.5 seconds. Range 59 to 214 seconds."
        )
    }

    @Test("Given layers switched off, when a café's element is described, then it says only what is drawn")
    func elementValueFollowsLayers() {
        #expect(summary(middleHalf: false, median: false).elementValue(for: waits[1]) == "Range 74 to 309 seconds.")
        #expect(summary(range: false).elementValue(for: waits[1]) == "Median 178 seconds. Middle half 120.5 to 252.5 seconds.")
    }

    @Test("Given layers switched on or off, when the explanation is written, then it describes only the marks that are drawn")
    func explanationFollowsLayers() {
        let all = summary().explanation
        #expect(all.contains("RuleMark") && all.contains("BarMark") && all.contains("RectangleMark"))

        let rangeOnly = summary(middleHalf: false, median: false).explanation
        #expect(rangeOnly.contains("RuleMark") && !rangeOnly.contains("BarMark") && !rangeOnly.contains("RectangleMark"))

        let none = summary(range: false, middleHalf: false, median: false).explanation
        #expect(!none.contains("RuleMark") && none.hasSuffix("Switch a layer on to draw it."))
    }

    @Test("Given the data's extremes, when the scale's reach is read, then it is the shortest and the longest wait")
    func extremes() {
        #expect(summary().shortestWait == 59)
        #expect(summary().longestWait == 309)
        #expect(summary([]).longestWait == 0)
    }

    @Test("Given the café's waits, when the value axis is worked out, then it runs from zero to the longest wait rounded up, and never empty")
    func valueDomain() {
        #expect(summary().valueDomain == 0 ... 400)
        #expect(summary(range: false, middleHalf: false).valueDomain == 0 ... 400)
        #expect(summary([]).valueDomain == 0 ... 1)
    }

    @Test("Given the shared order waits, when the box plot's numbers are read, then they are the ones worked out from those orders")
    func quartilesComeFromTheOrders() {
        #expect(CafeData.waitQuartiles == waits)
        #expect(BoxPlotViewModel().summary(locale: locale).headline == "The highest median wait was at Station: 178 seconds.")
    }

    // MARK: Descriptor

    @Test("Given every layer drawn, when the descriptor is made, then it has a series for each of the five numbers")
    func descriptorWithEveryLayer() throws {
        let descriptor = BoxPlotChartDescriptor(summary: summary()).makeChartDescriptor()

        #expect(descriptor.title == "Waits at each café, in seconds")
        #expect(
            descriptor.summary
                == "Harbour: Median 143.5 seconds. Middle half 103 to 183.5 seconds. Range 59 to 214 seconds. "
                + "Station: Median 178 seconds. Middle half 120.5 to 252.5 seconds. Range 74 to 309 seconds."
        )
        #expect(descriptor.xAxis.title == "Café")
        #expect((descriptor.xAxis as? AXCategoricalDataAxisDescriptor)?.categoryOrder == ["Harbour", "Station"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Wait (seconds)")
        // The drawn axis, not the data's top: the same domain the chart's scale is given.
        #expect(yAxis.range == 0 ... 400)
        #expect(yAxis.valueDescriptionProvider(1) == "1 second")
        #expect(yAxis.valueDescriptionProvider(142) == "142 seconds")
        #expect(yAxis.valueDescriptionProvider(400) == "400 seconds")
        #expect(descriptor.series.map(\.name) == ["Shortest wait", "Lower quartile", "Median wait", "Upper quartile", "Longest wait"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 2 })
    }

    @Test("Given only the median drawn, when the descriptor is made, then it has the median's series alone on the same value range")
    func descriptorFollowsLayers() throws {
        let descriptor = BoxPlotChartDescriptor(summary: summary(range: false, middleHalf: false)).makeChartDescriptor()

        #expect(descriptor.series.map(\.name) == ["Median wait"])
        #expect(descriptor.summary == "Harbour: Median 143.5 seconds. Station: Median 178 seconds.")
        #expect(try #require(descriptor.yAxis).range == 0 ... 400)
    }
}
