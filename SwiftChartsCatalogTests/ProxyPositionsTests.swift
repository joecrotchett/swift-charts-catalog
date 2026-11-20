import Accessibility
import CoreGraphics
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ProxyPositionsTests {
    private let english = Locale(identifier: "en_US")
    /// The plot frames measured on an iPhone 17 simulator, in a 370-point-wide chart panel: the value axis on the
    /// trailing edge leaves the plot at the overlay's corner; on the leading edge its labels push it in.
    private let trailingPlot = CGRect(x: 0, y: 0, width: 313, height: 242)
    private let leadingPlot = CGRect(x: 25, y: 0, width: 313, height: 242)
    /// A band the proxy might give for a drink, in plot coordinates.
    private let band: ClosedRange<CGFloat> = 60 ... 100

    // MARK: Value to position

    @Test("Given the default trailing axis, when a band's centre is placed, then it lands on the band in the overlay")
    func trailingBandPlacement() {
        let mapping = ProxyPositionsMapping(plotFrame: trailingPlot)
        let point = mapping.overlayPoint(forPlot: CGPoint(x: ProxyPositionsMapping.centre(of: band), y: 20))

        #expect(point == CGPoint(x: 80, y: 20))
    }

    @Test("Given a leading axis, when a band's centre is placed, then the plot's origin is added")
    func leadingBandPlacement() {
        let mapping = ProxyPositionsMapping(plotFrame: leadingPlot)
        let point = mapping.overlayPoint(forPlot: CGPoint(x: ProxyPositionsMapping.centre(of: band), y: 20))

        #expect(point == CGPoint(x: 105, y: 20))
    }

    @Test("Given the origin left out, when a band is placed on each axis, then only the leading axis misplaces it")
    func mistakenBandPlacement() {
        let plotPoint = CGPoint(x: ProxyPositionsMapping.centre(of: band), y: 20)

        #expect(ProxyPositionsMapping(plotFrame: trailingPlot, ignoresOrigin: true).overlayPoint(forPlot: plotPoint) == CGPoint(x: 80, y: 20))
        #expect(ProxyPositionsMapping(plotFrame: leadingPlot, ignoresOrigin: true).overlayPoint(forPlot: plotPoint) == CGPoint(x: 80, y: 20))
        #expect(ProxyPositionsMapping(plotFrame: leadingPlot).overlayPoint(forPlot: plotPoint) == CGPoint(x: 105, y: 20))
    }

    @Test("Given right to left, when a band's centre is placed, then it is mirrored across the overlay's width, with the axis on either edge")
    func rightToLeftBandPlacement() {
        // Measured on the iPhone 17 simulator in right to left, a 370-point overlay: the value axis on the
        // trailing edge (the left) leaves the plot at x 25; on the leading edge (the right) at x 0. The first
        // category's band is then 276...345, counted from the plot's left edge.
        let firstBand: ClosedRange<CGFloat> = 276 ... 345
        let plotPoint = CGPoint(x: ProxyPositionsMapping.centre(of: firstBand), y: 20)
        let trailing = ProxyPositionsMapping(
            plotFrame: CGRect(x: 25, y: 0, width: 345, height: 242), overlayWidth: 370, isRightToLeft: true
        )
        let leading = ProxyPositionsMapping(
            plotFrame: CGRect(x: 0, y: 0, width: 345, height: 242), overlayWidth: 370, isRightToLeft: true
        )

        #expect(trailing.overlayPoint(forPlot: plotPoint) == CGPoint(x: 34.5, y: 20))
        #expect(leading.overlayPoint(forPlot: plotPoint) == CGPoint(x: 59.5, y: 20))
    }

    @Test("Given right to left and the origin left out, when a band is placed, then only an axis on the left misplaces it")
    func rightToLeftMistake() {
        let plotPoint = CGPoint(x: 310.5, y: 20)
        let trailing = ProxyPositionsMapping(
            plotFrame: CGRect(x: 25, y: 0, width: 345, height: 242), overlayWidth: 370, isRightToLeft: true, ignoresOrigin: true
        )
        let leading = ProxyPositionsMapping(
            plotFrame: CGRect(x: 0, y: 0, width: 345, height: 242), overlayWidth: 370, isRightToLeft: true, ignoresOrigin: true
        )

        #expect(trailing.overlayPoint(forPlot: plotPoint) == CGPoint(x: 59.5, y: 20))
        #expect(leading.overlayPoint(forPlot: plotPoint) == CGPoint(x: 59.5, y: 20))
    }

    // MARK: Position to value

    @Test("Given right to left, when a touch is moved into plot coordinates, then only the origin is subtracted, with no mirroring")
    func rightToLeftTouch() {
        let mapping = ProxyPositionsMapping(
            plotFrame: CGRect(x: 25, y: 0, width: 345, height: 242), overlayWidth: 370, isRightToLeft: true
        )

        #expect(mapping.plotPoint(forOverlay: CGPoint(x: 335.5, y: 50)) == CGPoint(x: 310.5, y: 50))
    }

    @Test("Given each axis, when a touch is moved into plot coordinates, then the plot's origin is subtracted")
    func touchToPlot() {
        let touch = CGPoint(x: 110, y: 50)

        #expect(ProxyPositionsMapping(plotFrame: trailingPlot).plotPoint(forOverlay: touch) == CGPoint(x: 110, y: 50))
        #expect(ProxyPositionsMapping(plotFrame: leadingPlot).plotPoint(forOverlay: touch) == CGPoint(x: 85, y: 50))
        #expect(ProxyPositionsMapping(plotFrame: leadingPlot, ignoresOrigin: true).plotPoint(forOverlay: touch) == touch)
    }

    @Test("Given a leading axis, when a position is placed and touched, then the two conversions undo each other")
    func roundTrip() {
        let mapping = ProxyPositionsMapping(plotFrame: CGRect(x: 30, y: 6, width: 300, height: 200))
        let plotPoint = CGPoint(x: 80, y: 40)

        #expect(mapping.plotPoint(forOverlay: mapping.overlayPoint(forPlot: plotPoint)) == plotPoint)
    }

    @Test("Given a touch on the axis labels or past the plot, when it is checked, then it is rejected before conversion")
    func outsideIsRejected() {
        let mapping = ProxyPositionsMapping(plotFrame: leadingPlot)

        #expect(!mapping.contains(plotPoint: mapping.plotPoint(forOverlay: CGPoint(x: 10, y: 50))))
        #expect(!mapping.contains(plotPoint: mapping.plotPoint(forOverlay: CGPoint(x: 120, y: 250))))
        #expect(mapping.contains(plotPoint: mapping.plotPoint(forOverlay: CGPoint(x: 120, y: 50))))
    }

    // MARK: View model

    @Test("Given a new screen, when it opens, then the axis is trailing, the origin is used and nothing is read")
    func startsCorrect() {
        let viewModel = ProxyPositionsViewModel()

        #expect(viewModel.axisEdge == .trailing)
        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.reading == nil)
        #expect(viewModel.mapping == nil)
    }

    @Test("Given a reported plot frame, when the mistake is switched, then the view model's mapping follows it")
    func mappingFollowsState() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(leadingPlot, locale: english)

        #expect(viewModel.mapping == ProxyPositionsMapping(plotFrame: leadingPlot))
        viewModel.isShowingMistake = true
        #expect(viewModel.mapping == ProxyPositionsMapping(plotFrame: leadingPlot, ignoresOrigin: true))
    }

    @Test("Given the origin used or left out, when the snippets are listed, then the matching conversion is shown")
    func snippetsFollowMistake() {
        let viewModel = ProxyPositionsViewModel()

        #expect(viewModel.snippets.map(\.name) == ["chart-proxy-overlay", "chart-proxy-origin", "chart-proxy-axis"])
        viewModel.isShowingMistake = true
        #expect(viewModel.snippets.map(\.name) == ["chart-proxy-overlay", "chart-proxy-origin-mistake", "chart-proxy-axis"])
    }

    @Test("Given the app's snippets, when each state's names are looked up, then every one exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [
            "chart-proxy-overlay", "chart-proxy-origin", "chart-proxy-origin-mistake", "chart-proxy-axis",
        ]

        for name in names {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    @Test("Given a reading under the pointer, when it is written, then it names the band and the height, rounded")
    func readout() {
        let viewModel = ProxyPositionsViewModel()
        #expect(viewModel.readout(locale: english) == nil)

        viewModel.reading = ProxyPositionsReading(drink: "Tea", cups: 119.6)
        #expect(viewModel.readout(locale: english) == "Tea's band, 120 cups high")
        viewModel.reading = ProxyPositionsReading(drink: "Cocoa", cups: 1.2)
        #expect(viewModel.readout(locale: english) == "Cocoa's band, 1 cup high")
    }

    @Test("Given the sample sales, when the bars are made, then they are ranked most cups first, a tie in data order")
    func barsAreRanked() {
        #expect(ProxyPositionsViewModel().sales.map(\.drink) == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        let tied = [DrinkSales(drink: "Mocha", cups: 9), DrinkSales(drink: "Cocoa", cups: 1), DrinkSales(drink: "Tea", cups: 9)]
        #expect(ProxyPositionsViewModel(sales: tied).sales.map(\.drink) == ["Mocha", "Tea", "Cocoa"])
    }

    @Test("Given each layout direction, when the explanation is written, then it says which axis edge makes the corners meet there")
    func explanationFollowsDirection() {
        let viewModel = ProxyPositionsViewModel()
        let leftToRight = viewModel.explanation(isRightToLeft: false)
        let rightToLeft = viewModel.explanation(isRightToLeft: true)

        #expect(leftToRight.hasSuffix("With the value axis on the trailing edge the two corners meet and leaving the origin out goes unseen; on the leading edge it does not."))
        #expect(!leftToRight.contains("mirrored"))
        #expect(rightToLeft.contains("mirrored across the overlay's width"))
        #expect(rightToLeft.hasSuffix("Here the corners meet with the value axis on the leading edge, and leaving the origin out goes unseen; on the trailing edge it does not."))
    }

    // MARK: Headline and announcements

    @Test("Given the sample sales, when the headline is written with the origin used, then it names the best seller")
    func headline() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(leadingPlot, locale: english)

        #expect(viewModel.summary(locale: english).headline == "Tea sold the most: 164 cups.")
    }

    @Test("Given the origin left out, when the axis is trailing or leading, then the headline says how far the star is off only when it is")
    func headlineReportsMisplacedStar() {
        let viewModel = ProxyPositionsViewModel()
        viewModel.isShowingMistake = true

        _ = viewModel.updatePlotFrame(trailingPlot, locale: english)
        #expect(viewModel.summary(locale: english).headline == "Tea sold the most: 164 cups.")
        _ = viewModel.updatePlotFrame(leadingPlot, locale: english)
        #expect(viewModel.summary(locale: english).headline
            == "Tea sold the most: 164 cups. Each star is drawn 25 points before the bar it marks.")
    }

    @Test("Given a leading axis, when the mistake is switched on and off, then each change is announced with the headline")
    func mistakeIsAnnounced() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(leadingPlot, locale: english)

        viewModel.isShowingMistake = true
        #expect(viewModel.mistakeChanged(locale: english)
            == "Plot origin left out. Tea sold the most: 164 cups. Each star is drawn 25 points before the bar it marks.")
        viewModel.isShowingMistake = false
        #expect(viewModel.mistakeChanged(locale: english) == "Plot origin added back. Tea sold the most: 164 cups.")
    }

    @Test("Given a trailing axis, when the mistake is switched, then nothing drawn moves and nothing is announced")
    func mistakeOnTrailingIsSilent() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(trailingPlot, locale: english)

        viewModel.isShowingMistake = true
        #expect(viewModel.mistakeChanged(locale: english) == nil)
    }

    @Test("Given the mistake shown, when the axis moves and the plot frame follows, then the moved star is announced")
    func axisMoveWithMistakeIsAnnounced() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(trailingPlot, locale: english)
        viewModel.isShowingMistake = true
        _ = viewModel.mistakeChanged(locale: english)

        viewModel.axisEdge = .leading
        viewModel.axisEdgeChanged()
        #expect(viewModel.updatePlotFrame(leadingPlot, locale: english)
            == "Value axis moved to the leading edge. Tea sold the most: 164 cups. Each star is drawn 25 points before the bar it marks.")
    }

    @Test("Given a trailing axis, when the mistake is switched and later the plot moves for another reason, then the old switch is not announced")
    func staleChangeIsDropped() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(trailingPlot, locale: english)
        viewModel.isShowingMistake = true
        #expect(viewModel.mistakeChanged(locale: english) == nil)

        #expect(viewModel.updatePlotFrame(leadingPlot, locale: english) == nil)
    }

    @Test("Given the mistake shown and the axis moved, when a layout first changes only the plot's size, then the move is still announced when the plot moves")
    func axisChangeSurvivesResize() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(trailingPlot, locale: english)
        viewModel.isShowingMistake = true
        _ = viewModel.mistakeChanged(locale: english)

        viewModel.axisEdge = .leading
        viewModel.axisEdgeChanged()
        #expect(viewModel.updatePlotFrame(CGRect(x: 0, y: 0, width: 300, height: 242), locale: english) == nil)
        #expect(viewModel.updatePlotFrame(leadingPlot, locale: english)
            == "Value axis moved to the leading edge. Tea sold the most: 164 cups. Each star is drawn 25 points before the bar it marks.")
    }

    @Test("Given right to left and the origin left out, when the plot starts 25 points in, then the headline says the star is drawn after its bar")
    func rightToLeftHeadline() {
        let viewModel = ProxyPositionsViewModel()
        viewModel.isShowingMistake = true
        _ = viewModel.updatePlotFrame(CGRect(x: 25, y: 0, width: 345, height: 242), overlayWidth: 370, isRightToLeft: true, locale: english)

        #expect(viewModel.summary(locale: english).headline
            == "Tea sold the most: 164 cups. Each star is drawn 25 points after the bar it marks.")
        #expect(viewModel.mapping?.isRightToLeft == true)
        #expect(viewModel.mapping?.overlayWidth == 370)
    }

    @Test("Given the origin used, when the axis moves, then the picker's own value is enough and nothing is announced")
    func axisMoveWithoutMistakeIsSilent() {
        let viewModel = ProxyPositionsViewModel()
        _ = viewModel.updatePlotFrame(trailingPlot, locale: english)

        viewModel.axisEdge = .leading
        viewModel.axisEdgeChanged()
        #expect(viewModel.updatePlotFrame(leadingPlot, locale: english) == nil)
    }

    @Test("Given no sales or only zeros, when the words are written, then they say nothing sold")
    func emptyAndZeroSaySo() {
        for rows in [[], [DrinkSales(drink: "Tea", cups: 0), DrinkSales(drink: "Latte", cups: 0)]] {
            let viewModel = ProxyPositionsViewModel(sales: rows)
            viewModel.isShowingMistake = true
            _ = viewModel.updatePlotFrame(leadingPlot, locale: english)
            let summary = viewModel.summary(locale: english)

            #expect(summary.isEmpty)
            #expect(viewModel.bestSellers.isEmpty)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
        }
    }

    @Test("Given two drinks tied and one cup each, when the headline is written, then it names both and agrees in number")
    func tieAndSingular() {
        let tied = [DrinkSales(drink: "Mocha", cups: 1), DrinkSales(drink: "Tea", cups: 1)]

        #expect(ProxyPositionsSummary(sales: tied, badgeOffset: 0, locale: english).headline == "Mocha and Tea sold the most: 1 cup.")
        #expect(ProxyPositionsSummary(sales: tied, badgeOffset: 1, locale: english).badgeSentence
            == "Each star is drawn 1 point before the bar it marks.")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let summary = ProxyPositionsSummary(sales: [DrinkSales(drink: "Tea", cups: 1200)], badgeOffset: 0, locale: Locale(identifier: "de_DE"))

        #expect(summary.headline == "Tea sold the most: 1.200 cups.")
    }

    // MARK: Audio Graph

    @Test("Given the sample sales, when the descriptor is made, then it has a title, actual values and the drinks in order")
    func descriptor() throws {
        let summary = ProxyPositionsViewModel().summary(locale: english)
        let descriptor = ProxyPositionsChartDescriptor(summary: summary).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups, marked with a star. Fewest: Cocoa, 57 cups.")
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        #expect(descriptor.series.map(\.name) == ["Harbour"])
        // The drawn axis: 164 cups rounds up to 200, the same domain the chart is given.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 5)
    }

    @Test("Given the star misplaced, when the descriptor is made, then its summary says so, as the chart draws it")
    func descriptorDescribesMistake() {
        let summary = ProxyPositionsSummary(sales: CafeData.drinkSales, badgeOffset: 25, locale: english)

        #expect(ProxyPositionsChartDescriptor(summary: summary).makeChartDescriptor().summary?
            .hasSuffix("Fewest: Cocoa, 57 cups. Each star is drawn 25 points before the bar it marks.") == true)
    }
}
