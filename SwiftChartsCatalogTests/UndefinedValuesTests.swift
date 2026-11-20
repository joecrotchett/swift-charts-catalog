import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct UndefinedValuesTests {
    private let english = Locale(identifier: "en_US")

    private func summary(_ function: UndefinedValuesFunction, clipped: Bool = true) -> UndefinedValuesSummary {
        UndefinedValuesSummary(function: function, isClipped: clipped, locale: english)
    }

    // MARK: The functions

    @Test("Given the fit, when y is asked for outside its range, then .nan replaces a finite formula value that would be drawn inside the plot")
    func fitReturnsNanWhereFormulaIsFinite() {
        let removed = stride(from: -4.0, to: 0, by: 0.1)
        for x in removed {
            #expect(UndefinedValuesFunction.fit.y(at: x).isNaN, "x = \(x)")
            #expect(UndefinedValuesFunction.fitFormula(x).isFinite, "x = \(x)")
        }
        // Without the .nan, the formula would draw from x = -2.8 to -0.1 inside the y domain, where the plot shows it.
        let drawnWithoutNan = removed.filter { UndefinedValuesWindow.yDomain.contains(UndefinedValuesFunction.fitFormula($0)) }
        #expect(drawnWithoutNan.count == 28)
        #expect(UndefinedValuesFunction.fit.y(at: 3.5).isNaN)
        #expect(UndefinedValuesFunction.fit.y(at: 0) == -1)
        #expect(UndefinedValuesFunction.fit.y(at: 2) == 1)
    }

    @Test("Given the fit, when its branches are made, then the Audio Graph gets points only from 0 to 3")
    func fitBranchStopsWhereTheFitDoes() throws {
        let unclipped = summary(.fit, clipped: false).branches
        #expect(unclipped.map(\.name) == ["Fit, x from 0 to 3"])
        let points = try #require(unclipped.first?.points)
        #expect(points.first?.x == 0)
        #expect(points.last?.x == 3)
        #expect(summary(.fit).branches.first?.points.last?.x == 2.8)
    }

    @Test("Given 1/x and ln x, when y is asked for where they are undefined, then the plain formulas already give no finite value")
    func otherFunctionsNeedNoGuard() {
        #expect(UndefinedValuesFunction.reciprocal.y(at: 0) == .infinity)
        #expect(UndefinedValuesFunction.reciprocal.y(at: 2) == 0.5)
        #expect(UndefinedValuesFunction.logarithm.y(at: -1).isNaN)
        #expect(UndefinedValuesFunction.logarithm.y(at: 0) == -.infinity)
        #expect(UndefinedValuesFunction.logarithm.y(at: 1) == 0)
    }

    @Test("Given every function, when it is sampled across the x domain, then each runs past the y domain, so unclipped is a mistake for all")
    func everyFunctionLeavesTheScale() {
        for function in UndefinedValuesFunction.allCases {
            let ys = stride(from: -4.0, through: 4.0, by: 0.01).map(function.y(at:)).filter(\.isFinite)
            #expect(ys.contains { !UndefinedValuesWindow.yDomain.contains($0) }, "\(function)")
            #expect(function.leavesTop == ys.contains { $0 > UndefinedValuesWindow.yDomain.upperBound }, "\(function)")
            #expect(function.leavesBottom == ys.contains { $0 < UndefinedValuesWindow.yDomain.lowerBound }, "\(function)")
        }
    }

    // MARK: The headline

    @Test("Given the fit clipped, when the headline is written, then it says nothing is drawn outside the fit's range")
    func fitHeadline() {
        #expect(
            summary(.fit).headline
                == "The fit holds only from x = 0 to 3: outside it, nothing is drawn. Clipped, it stops at the edge of the plot, y = 3."
        )
    }

    @Test("Given 1/x clipped, when the headline is written, then it says the line breaks at the pole")
    func reciprocalClippedHeadline() {
        #expect(
            summary(.reciprocal).headline
                == "1/x has a pole at x = 0, where the line breaks. Clipped, it stops at the edge of the plot, y = 3 and y = -3."
        )
    }

    @Test("Given 1/x unclipped, when the headline is written, then it says the curve runs past both edges")
    func reciprocalUnclippedHeadline() {
        #expect(
            summary(.reciprocal, clipped: false).headline
                == "1/x has a pole at x = 0, where the line breaks. Unclipped, it runs on past y = 3 and y = -3, out of the plot area."
        )
    }

    @Test("Given ln x, when the headline is written, then it says where it is undefined, and only the bottom edge is reached")
    func logarithmHeadline() {
        #expect(
            summary(.logarithm).headline
                == "ln x is undefined at x = 0 and below, so no curve is drawn there. "
                + "Clipped, it stops at the edge of the plot, y = -3."
        )
    }

    @Test("Given tan x, when the headline is written, then it names both poles to two decimal places")
    func tangentHeadline() {
        #expect(
            summary(.tangent, clipped: false).headline
                == "tan x has poles at x = -1.57 and x = 1.57, where the line breaks. "
                + "Unclipped, it runs on past y = 3 and y = -3, out of the plot area."
        )
    }

    @Test("Given a German locale, when the headline is written, then the numbers are written the German way")
    func headlineTakesLocale() {
        let german = UndefinedValuesSummary(function: .tangent, isClipped: true, locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("x = 1,57"))
    }

    // MARK: The view model

    @Test("Given a new screen, when it opens, then it shows the fit, the one function .nan changes, clipped")
    func startsClipped() {
        let viewModel = UndefinedValuesViewModel()

        #expect(viewModel.function == .fit)
        #expect(viewModel.isClipped)
        #expect(viewModel.summary(locale: english).headline == summary(.fit).headline)
    }

    @Test("Given the mistake toggle on, when the state is read, then the plot is unclipped and the chart has a new identity")
    func mistakeUnclips() {
        let viewModel = UndefinedValuesViewModel()
        let before = viewModel.chartIdentity

        viewModel.isShowingUnclipped = true

        #expect(!viewModel.isClipped)
        #expect(viewModel.chartIdentity != before)
    }

    @Test("Given a new function, when the change is announced, then it says which function, then the headline")
    func functionAnnouncement() {
        let viewModel = UndefinedValuesViewModel()
        viewModel.function = .logarithm

        #expect(viewModel.functionAnnouncement(locale: english) == "Showing Natural log of x. \(summary(.logarithm).headline)")
    }

    @Test("Given clipping turned off, when the change is announced, then it says so, then the headline")
    func clippingAnnouncement() {
        let viewModel = UndefinedValuesViewModel()
        viewModel.isShowingUnclipped = true

        #expect(
            viewModel.clippingAnnouncement(locale: english)
                == "Plot area unclipped. \(summary(.fit, clipped: false).headline)"
        )
    }

    @Test("Given any state, when the snippets are listed, then they are the two the build extracted from this screen")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let viewModel = UndefinedValuesViewModel()

        for clipped in [true, false] {
            viewModel.isShowingUnclipped = !clipped
            #expect(viewModel.snippets.map(\.name) == ["undefined-values-functions", "undefined-values-chart"])
        }
        let functions = try #require(store["undefined-values-functions"])
        let chart = try #require(store["undefined-values-chart"])
        #expect(functions.code.contains(".nan"))
        #expect(chart.code.contains("plotArea.clipped()"))
    }

    // MARK: The element and the Audio Graph

    @Test("Given 1/x and the fit, when the element's value is written, then it gives where the curve is not drawn and actual values")
    func elementValueGivesValues() {
        #expect(
            summary(.reciprocal).elementValue
                == "Breaks at x = 0. x = -2, y = -0.5; x = -1, y = -1; x = 1, y = 1; x = 2, y = 0.5. "
                + "Clipped, it stops at the edge of the plot, y = 3 and y = -3."
        )
        #expect(
            summary(.fit).elementValue
                == "Drawn only from x = 0 to 3. x = 0, y = -1; x = 1, y = -0.5; x = 2, y = 1. Clipped, it stops at the edge of the plot, y = 3."
        )
    }

    @Test("Given 1/x clipped, when the branches are made, then there are two, with no point at zero or beyond the y domain")
    func reciprocalBranchesClipped() throws {
        let branches = summary(.reciprocal).branches

        #expect(branches.map(\.name) == ["1/x, x from -4 to 0", "1/x, x from 0 to 4"])
        let all = branches.flatMap(\.points)
        #expect(!all.contains { $0.x == 0 })
        #expect(all.allSatisfy { UndefinedValuesWindow.yDomain.contains($0.y) })
        let first = try #require(branches.first?.points.first)
        #expect(first.x == -4)
    }

    @Test("Given 1/x unclipped, when the branches are made, then points beyond the y domain are kept, and the described range holds them")
    func reciprocalBranchesUnclipped() {
        let unclipped = summary(.reciprocal, clipped: false)
        let points = unclipped.branches.flatMap(\.points)

        #expect(points.contains { $0.y == 10 })
        #expect(!points.contains { !$0.y.isFinite })
        #expect(unclipped.describedYRange == -10 ... 10)
        #expect(summary(.reciprocal).describedYRange == UndefinedValuesWindow.yDomain)
        #expect(summary(.fit, clipped: false).describedYRange == -3 ... 3.5)
    }

    @Test("Given tan x and ln x, when the branches are made, then tan has three pieces and ln one, from zero")
    func otherBranches() {
        #expect(summary(.tangent).branches.map(\.name) == [
            "tan x, x from -4 to -1.57", "tan x, x from -1.57 to 1.57", "tan x, x from 1.57 to 4",
        ])
        #expect(summary(.logarithm).branches.map(\.name) == ["ln x, x from 0 to 4"])
        #expect(summary(.tangent).branches.flatMap(\.points).allSatisfy { UndefinedValuesWindow.yDomain.contains($0.y) })
    }

    @Test("Given a function, when the descriptor is made, then it has a title, summary, numeric axes on the drawn domains and a continuous series per branch")
    func descriptorDescribesTheChart() throws {
        let described = summary(.tangent)
        let descriptor = UndefinedValuesChartDescriptor(summary: described).makeChartDescriptor()

        #expect(descriptor.title == "Graph of tan x")
        #expect(descriptor.summary == described.audioGraphSummary)
        #expect(descriptor.series.count == 3)
        #expect(!descriptor.series.contains { !$0.isContinuous })
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.range == -4 ... 4)
        #expect(xAxis.valueDescriptionProvider(1.5) == "x = 1.5")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "y")
        #expect(yAxis.range == -3 ... 3)
        #expect(yAxis.valueDescriptionProvider(-0.25) == "y = -0.25")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given ln x, when the Audio Graph summary is written, then it gives the window and where it is undefined, in actual values")
    func audioGraphSummary() {
        #expect(
            summary(.logarithm).audioGraphSummary
                == "ln x, window x from -4 to 4, y from -3 to 3. ln x is undefined at x = 0 and below: "
                + "the log of a negative is already NaN, so no curve is drawn there. Clipped, it stops at the edge of the plot, y = -3."
        )
    }
}
