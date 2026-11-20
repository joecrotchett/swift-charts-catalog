import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

struct PlotAspectRatioTests {
    private let english = Locale(identifier: "en_US")

    private func summary(fixed: Double, free: Double?) -> PlotAspectRatioSummary {
        PlotAspectRatioSummary(fixedRatio: fixed, freeRatio: free, locale: english)
    }

    // MARK: View model

    @Test("Given a new screen, when it opens, then the fixed plot is square and the free plot is not yet measured")
    func startsSquare() {
        let viewModel = PlotAspectRatioViewModel()

        #expect(viewModel.ratio == 1)
        #expect(viewModel.freeRatio == nil)
        #expect(viewModel.summary(locale: english).headline == "At 1:1 the circle is round.")
    }

    @Test("Given the free plot is laid out 130 by 220 points, when its size is passed in, then its ratio is stored to two places")
    func measuresFreePlot() {
        let viewModel = PlotAspectRatioViewModel()

        viewModel.freePlotDidLayOut(width: 130, height: 220)

        #expect(viewModel.freeRatio == 0.59)
    }

    @Test("Given a plot with no area yet, when its size is passed in, then no ratio is recorded")
    func ignoresEmptyPlot() {
        let viewModel = PlotAspectRatioViewModel()

        viewModel.freePlotDidLayOut(width: 120, height: 0)

        #expect(viewModel.freeRatio == nil)
        #expect(PlotAspectRatioSummary.ratio(width: .nan, height: 10) == nil)
    }

    @Test("Given the slider moved to 1.5, when the summary is read, then it describes the fixed plot at 1.5:1")
    func sliderChangesSummary() {
        let viewModel = PlotAspectRatioViewModel()

        viewModel.ratio = 1.5

        #expect(viewModel.summary(locale: english).fixedCaption == "Fixed plot, 1.5:1")
    }

    @Test("Given the slider's range, when it is read, then it runs from 0.5 to 2 and includes 1")
    func sliderRange() {
        #expect(PlotAspectRatioViewModel.ratioRange == 0.5 ... 2)
        #expect(PlotAspectRatioViewModel.ratioRange.contains(1))
    }

    // MARK: Shapes

    @Test("Given a ratio, when the circle's shape is written, then it says round only when the plot is square")
    func shapes() {
        let words = summary(fixed: 1, free: nil)

        #expect(words.shape(atRatio: 1) == "round")
        #expect(words.shape(atRatio: 1.002) == "round")
        #expect(words.shape(atRatio: 1.5) == "1.5 times as wide as it is tall")
        #expect(words.shape(atRatio: 0.5) == "2 times as tall as it is wide")
        #expect(words.shape(atRatio: 0.75) == "1.33 times as tall as it is wide")
    }

    // MARK: Headline and captions

    @Test("Given a square fixed plot and a tall free plot, when the headline is written, then it gives both ratios and shapes")
    func headlineSquare() {
        #expect(summary(fixed: 1, free: 0.6).headline
            == "At 1:1 the circle is round; in the free plot, 0.6:1 here, it is 1.67 times as tall as it is wide.")
    }

    @Test("Given a wide fixed plot, when the headline is written, then it says how much wider the circle is drawn")
    func headlineWide() {
        #expect(summary(fixed: 2, free: 0.6).headline
            == "At 2:1 the circle is 2 times as wide as it is tall; in the free plot, 0.6:1 here, it is 1.67 times as tall as it is wide.")
    }

    @Test("Given a free plot that happens to be square, when the headline is written, then it says that circle is round too")
    func headlineFreeSquare() {
        #expect(summary(fixed: 1, free: 1).headline == "At 1:1 the circle is round; in the free plot, 1:1 here, it is round.")
    }

    @Test("Given each ratio, when the captions are written, then each ratio in the headline is in a caption over its plot")
    func captionsCarryHeadlineFigures() {
        let words = summary(fixed: 1.25, free: 0.58)

        #expect(words.freeCaption == "Free plot, 0.58:1")
        #expect(words.fixedCaption == "Fixed plot, 1.25:1")
        #expect(words.headline.contains("0.58:1"))
        #expect(words.headline.contains("1.25:1"))
        #expect(summary(fixed: 1, free: nil).freeCaption == "Free plot")
    }

    @Test("Given a German locale, when the ratios are written, then they use its decimal comma")
    func germanNumbers() {
        let words = PlotAspectRatioSummary(fixedRatio: 1.5, freeRatio: 0.58, locale: Locale(identifier: "de_DE"))

        #expect(words.fixedCaption == "Fixed plot, 1,5:1")
        #expect(words.freeCaption == "Free plot, 0,58:1")
    }

    // MARK: Slider

    @Test("Given the slider at 1.5, when its value is shown and spoken, then both give the same setting and the spoken one adds the headline")
    func sliderValues() {
        let words = summary(fixed: 1.5, free: 0.6)

        #expect(words.sliderValueText == "1.5:1")
        #expect(words.sliderSpokenValue == "1.5 to 1. \(words.headline)")
    }

    // MARK: Accessibility

    @Test("Given each plot, when the circle's element is written, then its label names the plot and the circle and its value the drawn shape")
    func elementText() {
        let words = summary(fixed: 2, free: 0.6)

        #expect(words.freeCircleLabel == "Free plot: circle of radius 3, centred on 0, 0")
        #expect(words.fixedCircleLabel == "Fixed plot: circle of radius 3, centred on 0, 0")
        #expect(words.fixedCircleValue == "Drawn 2 times as wide as it is tall, in a plot 2 to 1")
        #expect(words.freeCircleValue == "Drawn 1.67 times as tall as it is wide, in a plot 0.6 to 1")
        #expect(summary(fixed: 1, free: nil).freeCircleValue == "In a plot that takes the chart's shape")
    }

    @Test("Given the fixed plot at 1:1, when its descriptor is made, then it has a title, a summary in values, both axes and two halves")
    func fixedDescriptor() throws {
        let words = summary(fixed: 1, free: 0.6)
        let descriptor = PlotAspectRatioDescriptor(
            title: words.fixedDescriptorTitle, summary: words.fixedDescriptorSummary, locale: english
        ).makeChartDescriptor()

        #expect(descriptor.title == "A circle of radius 3 in a plot fixed at 1 to 1")
        #expect(descriptor.summary
            == "Centre 0, 0, radius 3. Both axes run from -4 to 4. The plot is held at 1 to 1, width to height, so the circle is drawn round.")
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)
        #expect(xAxis.title == "x")
        #expect(yAxis.title == "y")
        #expect(xAxis.range == -4 ... 4)
        #expect(yAxis.range == -4 ... 4)
        #expect(yAxis.valueDescriptionProvider(2.5) == "2.5")
        #expect(yAxis.valueDescriptionProvider(.infinity) == "")
        #expect(descriptor.series.map(\.name) == ["Upper half", "Lower half"])
        #expect(descriptor.series.map(\.isContinuous) == [true, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [13, 13])
    }

    @Test("Given the free plot before and after layout, when its descriptor summary is written, then it says only what is known")
    func freeDescriptorSummary() {
        #expect(summary(fixed: 1, free: nil).freeDescriptorSummary
            == "Centre 0, 0, radius 3. Both axes run from -4 to 4. The plot takes the chart's shape.")
        #expect(summary(fixed: 1, free: 0.6).freeDescriptorSummary
            == "Centre 0, 0, radius 3. Both axes run from -4 to 4. The plot is 0.6 to 1, width to height, so the circle is drawn 1.67 times as tall as it is wide.")
    }

    @Test("Given the circle's samples, when the halves are computed, then they meet the axis at both ends and reach the radius in the middle")
    func halves() {
        #expect(PlotAspectRatioDescriptor.sampleXs.first == -3)
        #expect(PlotAspectRatioDescriptor.sampleXs.last == 3)
        #expect(PlotAspectRatioDescriptor.upperY(atX: -3) == 0)
        #expect(PlotAspectRatioDescriptor.upperY(atX: 0) == 3)
    }

    // MARK: Snippets

    @Test("Given the app bundle, when its snippets are read, then the circle, free and fixed snippets exist and show their concept")
    func snippetsExist() throws {
        let store = try SnippetStore()

        let circle = try #require(store["plot-aspect-ratio-circle"])
        let free = try #require(store["plot-aspect-ratio-free"])
        let fixed = try #require(store["plot-aspect-ratio-fixed"])
        #expect(circle.code.contains("LinePlot"))
        #expect(free.code.contains("chartXScale"))
        #expect(!free.code.contains("aspectRatio"))
        #expect(fixed.code.contains("aspectRatio(ratio, contentMode: .fit)"))
    }
}

struct PlotAspectRatioAxisTests {
    @Test("Given the text size, when the axis values are chosen, then they thin to the ends and centre only at accessibility sizes")
    func axisValues() {
        #expect(PlotAspectRatioAxis.values(for: .large) == [-4, -2, 0, 2, 4])
        #expect(PlotAspectRatioAxis.values(for: .xxxLarge) == [-4, -2, 0, 2, 4])
        #expect(PlotAspectRatioAxis.values(for: .accessibility1) == [-4, 0, 4])
        #expect(PlotAspectRatioAxis.values(for: .accessibility5) == [-4, 0, 4])
    }
}
