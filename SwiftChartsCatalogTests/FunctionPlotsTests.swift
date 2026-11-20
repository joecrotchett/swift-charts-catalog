import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct FunctionPlotsTests {
    private let english = Locale(identifier: "en_US")

    private func summary(_ example: FunctionPlotsExample, width: Double? = nil, height: Double? = nil) -> FunctionPlotsSummary {
        FunctionPlotsSummary(
            example: example, halfWidth: width ?? example.defaultHalfWidth,
            halfHeight: height ?? example.defaultHalfHeight, locale: english
        )
    }

    // MARK: The functions

    @Test("Given each example, when its function is evaluated, then it gives the value of its formula")
    func formulas() {
        #expect(FunctionPlotsExample.sine.y(at: .pi / 2) == 1)
        #expect(FunctionPlotsExample.cubic.y(at: 2) == 2)
        #expect(FunctionPlotsExample.lowerBound(at: 3) == 3)
        #expect(FunctionPlotsExample.upperBound(at: 3) == 8)
        let rose = FunctionPlotsExample.rose.point(at: 0)
        #expect(rose.x == 4 && rose.y == 0)
        let circle = FunctionPlotsExample.circle.point(at: .pi / 2)
        #expect(abs(circle.x) < 0.000_001 && circle.y == 3)
        #expect(FunctionPlotsExample.rose.tDomain == 0 ... .pi)
        #expect(FunctionPlotsExample.circle.tDomain == 0 ... 2 * .pi)
    }

    // MARK: State

    @Test("Given a new screen, when it opens, then it shows the sine wave in its starting window")
    func startsOnSine() {
        let viewModel = FunctionPlotsViewModel()

        #expect(viewModel.example == .sine)
        #expect(viewModel.halfWidth == 6)
        #expect(viewModel.halfHeight == 1.5)
        #expect(viewModel.summary(locale: english).plotAspectRatio == nil)
    }

    @Test("Given a changed window, when another example is picked, then its own window returns and the change is announced")
    func selectResetsWindow() {
        let viewModel = FunctionPlotsViewModel()
        viewModel.halfWidth = 12

        let message = viewModel.select(.circle, locale: english)

        #expect(viewModel.halfWidth == 4)
        #expect(viewModel.halfHeight == 4)
        #expect(message == "Showing Circle, x = 3 cos t, y = 3 sin t. A circle of radius 3, round because one unit is as long on both axes.")
    }

    @Test("Given a parametric example, when its window is wider than tall, then the plot keeps one unit the same length on both axes")
    func trueProportions() throws {
        let wide = summary(.rose, width: 8, height: 4)

        // The same margin, in units, on both axes: 8% of the larger half, 8.
        #expect(wide.margin.x == wide.margin.y)
        #expect(abs(wide.margin.x - 0.64) < 0.000_001)
        #expect(abs(wide.xScaleDomain.upperBound - 8.64) < 0.000_001)
        #expect(abs(wide.yScaleDomain.lowerBound + 4.64) < 0.000_001)
        // Width over height of the plot equals the x span over the y span, so a unit is as long on both.
        let ratio = try #require(wide.plotAspectRatio)
        #expect(abs(ratio - 17.28 / 9.28) < 0.000_001)
        #expect(summary(.betweenTwo).plotAspectRatio == nil)
    }

    @Test("Given an example drawn in any shape, when its scales are made, then each gets a margin of its own half's share")
    func marginsPerAxis() {
        let sine = summary(.sine)

        #expect(abs(sine.margin.x - 0.48) < 0.000_001)
        #expect(abs(sine.margin.y - 0.12) < 0.000_001)
        #expect(sine.xDomain == -6 ... 6)
        #expect(abs(sine.xScaleDomain.upperBound - 6.48) < 0.000_001)
    }

    @Test("Given the window changes, when the chart's identity is read, then it changes too, so VoiceOver gets the new words")
    func identityFollowsWindow() {
        let viewModel = FunctionPlotsViewModel()
        let before = viewModel.chartIdentity
        viewModel.halfHeight = 1

        #expect(viewModel.chartIdentity != before)
    }

    // MARK: Snippets

    @Test("Given each kind of example, when its snippets are listed, then they show the code that draws it")
    func snippetsFollowExample() {
        #expect(FunctionPlotsViewModel(example: .sine).snippets.map(\.name) == [
            "function-plots-line", "function-plots-formulas", "function-plots-domain", "function-plots-origin-axes",
            "function-plots-margin",
        ])
        #expect(FunctionPlotsViewModel(example: .betweenTwo).snippets.map(\.name).first == "function-plots-area")
        #expect(FunctionPlotsViewModel(example: .rose).snippets.map(\.name) == [
            "function-plots-parametric", "function-plots-formulas", "function-plots-domain",
            "function-plots-origin-axes", "function-plots-margin", "function-plots-proportions",
        ])
    }

    @Test("Given the built app, when every snippet the screen can show is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let names = Set(FunctionPlotsExample.allCases.flatMap { FunctionPlotsViewModel(example: $0).snippets.map(\.name) })

        #expect(names.count == 8)
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    // MARK: Headlines

    @Test("Given the sine wave in its starting window, when the headline is written, then it gives the range the curve covers")
    func sineHeadline() {
        #expect(summary(.sine).headline == "From x = -6 to 6, y = sin x runs from -1 to 1.")
    }

    @Test("Given a window narrower than the curve, when the headline is written, then it says where the curve leaves the window")
    func clippedLineHeadlines() {
        #expect(summary(.sine, height: 0.5).headline
            == "From x = -6 to 6, y = sin x runs past both edges of the window, y = -0.5 and 0.5.")
        #expect(summary(.sine, width: 1).headline == "From x = -1 to 1, y = sin x runs from -0.84 to 0.84.")
        #expect(summary(.cubic, height: 4).headline
            == "From x = -2.25 to 2.25, y = x³ − 3x runs past both edges of the window, y = -4 and 4.")
        #expect(summary(.cubic).headline == "From x = -2.25 to 2.25, y = x³ − 3x runs from -4.64 to 4.64.")
    }

    @Test("Given a window cut at one edge, when the range is written, then only that edge is named")
    func oneEdgePhrases() {
        let window = summary(.cubic, height: 4)

        #expect(window.rangePhrase(low: -2, high: 6) == "from -2 up past the top of the window, y = 4")
        #expect(window.rangePhrase(low: -6, high: 2) == "from below the bottom of the window, y = -4, up to 2")
    }

    @Test("Given the area between two functions, when the window holds both crossings, then the headline names both")
    func areaHeadline() {
        #expect(summary(.betweenTwo).headline
            == "The shaded region between y = x and y = x² − 1 closes where they cross: x = -0.62 and x = 1.62.")
        #expect(summary(.betweenTwo, width: 1).headline
            == "The shaded region between y = x and y = x² − 1 closes where they cross: x = -0.62.")
    }

    @Test("Given a window too small to hold a crossing, when the headline is written, then it says the curves do not cross there")
    func areaWithoutCrossing() {
        #expect(summary(.betweenTwo, width: 0.5, height: 1.5).headline
            == "Inside this window y = x and y = x² − 1 do not cross, so the shaded region between them never closes.")
    }

    @Test("Given a parametric curve, when the window is smaller than the curve, then the headline names the edges it is cut at")
    func parametricHeadlines() {
        #expect(summary(.rose).headline == "A rose of five petals, each reaching 4 from the origin.")
        #expect(summary(.rose, width: 3).headline == "A rose of five petals, cut off where it reaches past x = ±3.")
        #expect(summary(.circle, width: 2, height: 2).headline
            == "A circle centred on the origin, cut off where it reaches past x = ±2 and y = ±2.")
    }

    @Test("Given another locale, when the headline is written, then its numbers are written that locale's way")
    func localeNumbers() {
        let german = FunctionPlotsSummary(example: .betweenTwo, halfWidth: 2.5, halfHeight: 4, locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("x = -0,62 and x = 1,62"))
    }

    // MARK: VoiceOver and the sliders

    @Test("Given each example, when its curves' element text is made, then each curve is named and given its values")
    func spokenCurves() throws {
        let sine = try #require(summary(.sine).spokenCurves.first)
        #expect(sine.label == "y equals sine x")
        #expect(sine.value == "x from -6 to 6, y runs from -1 to 1")

        let area = summary(.betweenTwo).spokenCurves
        #expect(area.map(\.label) == ["y equals x", "y equals x squared minus 1"])
        #expect(area.first?.value == "x from -2.5 to 2.5, y runs from -2.5 to 2.5; meets the other at x = -0.62 and x = 1.62")
        #expect(area.last?.value
            == "x from -2.5 to 2.5, y runs from -1 up past the top of the window, y = 4; meets the other at x = -0.62 and x = 1.62")

        let circle = try #require(summary(.circle).spokenCurves.first)
        #expect(circle.label == "A circle centred on the origin")
        #expect(circle.value == "x equals 3 cosine t, y equals 3 sine t; x from -3 to 3, y from -3 to 3")
    }

    @Test("Given a slider moved, when its value is spoken, then it gives the setting and then the headline")
    func sliderSpokenValues() {
        let viewModel = FunctionPlotsViewModel()
        viewModel.halfWidth = 1

        #expect(viewModel.xSliderText(locale: english) == "-1 to 1")
        #expect(viewModel.xSliderSpokenValue(locale: english) == "x from -1 to 1. From x = -1 to 1, y = sin x runs from -0.84 to 0.84.")
        #expect(viewModel.ySliderSpokenValue(locale: english).hasPrefix("y from -1.5 to 1.5. From x = -1 to 1"))
    }

    // MARK: The Audio Graph

    @Test("Given the sine wave, when the chart descriptor is made, then it has numeric x and y axes over the window and one continuous series")
    func lineDescriptor() throws {
        let descriptor = FunctionPlotsChartDescriptor(summary: summary(.sine)).makeChartDescriptor()

        #expect(descriptor.title == "Function plot: Sine wave, y = sin x")
        #expect(descriptor.summary == "Window x from -6 to 6, y from -1.5 to 1.5. From x = -6 to 6, y = sin x runs from -1 to 1.")
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.title == "x")
        #expect(xAxis.range == -6 ... 6)
        #expect(xAxis.valueDescriptionProvider(2.5) == "x = 2.5")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "y")
        #expect(yAxis.range == -1.5 ... 1.5)
        #expect(yAxis.valueDescriptionProvider(-1) == "y = -1")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["y = sin x"])
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == FunctionPlotsSummary.describedPointCount)
    }

    @Test("Given a window that cuts the curve, when the descriptor is made, then only the points drawn inside it are given")
    func descriptorDropsHiddenPoints() {
        let descriptor = FunctionPlotsChartDescriptor(summary: summary(.sine, height: 0.5)).makeChartDescriptor()

        let count = descriptor.series.first?.dataPoints.count ?? 0
        #expect(count > 0 && count < FunctionPlotsSummary.describedPointCount)
    }

    @Test("Given the area and a parametric curve, when their descriptors are made, then the area has a series per function and the curve is not continuous")
    func otherDescriptors() {
        let area = FunctionPlotsChartDescriptor(summary: summary(.betweenTwo)).makeChartDescriptor()
        #expect(area.series.map(\.name) == ["y = x", "y = x² − 1"])

        let rose = FunctionPlotsChartDescriptor(summary: summary(.rose)).makeChartDescriptor()
        #expect(rose.series.map(\.name) == ["x = 4 cos 5t cos t, y = 4 cos 5t sin t"])
        #expect(rose.series.first?.isContinuous == false)
        #expect(rose.series.first?.dataPoints.count == FunctionPlotsSummary.describedPointCount)
    }
}
