import Accessibility
import Charts
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct SurfacePlot3DTests {
    private let english = Locale(identifier: "en_US")
    private let tolerance = 1e-12

    // MARK: Function values at known points

    @Test("Given the ripple, when it is evaluated at known points, then it gives sin(2x) times cos(2z)")
    func rippleValues() {
        let ripple = SurfacePlot3DFunction.ripple
        #expect(abs(ripple.value(x: 0, z: 0)) < tolerance)
        #expect(abs(ripple.value(x: .pi / 4, z: 0) - 1) < tolerance)
        #expect(abs(ripple.value(x: -.pi / 4, z: 0) + 1) < tolerance)
        #expect(abs(ripple.value(x: .pi / 4, z: .pi / 2) + 1) < tolerance)
        #expect(abs(ripple.value(x: -.pi / 4, z: .pi / 2) - 1) < tolerance)
    }

    @Test("Given the saddle, when it is evaluated at known points, then it gives (x² − z²) ÷ 4")
    func saddleValues() {
        let saddle = SurfacePlot3DFunction.saddle
        #expect(saddle.value(x: 0, z: 0) == 0)
        #expect(saddle.value(x: 2, z: 0) == 1)
        #expect(saddle.value(x: -2, z: 0) == 1)
        #expect(saddle.value(x: 0, z: 2) == -1)
        #expect(saddle.value(x: 2, z: 2) == 0)
        #expect(saddle.value(x: 1, z: 0) == 0.25)
    }

    @Test("Given the hill, when it is evaluated at known points, then it gives e to the minus (x² + z²)")
    func hillValues() {
        let hill = SurfacePlot3DFunction.hill
        #expect(hill.value(x: 0, z: 0) == 1)
        #expect(abs(hill.value(x: 1, z: 0) - exp(-1)) < tolerance)
        #expect(abs(hill.value(x: 0, z: 2) - exp(-4)) < tolerance)
        #expect(hill.value(x: 2, z: 2) > 0)
    }

    @Test("Given every function, when it is sampled over the plotted region, then every value is finite and inside -1 to 1")
    func valuesStayInsideTheHeightDomain() {
        let steps = stride(from: -2.0, through: 2.0, by: 0.1)
        for function in SurfacePlot3DFunction.allCases {
            for x in steps {
                for z in steps {
                    let y = function.value(x: x, z: z)
                    #expect(y.isFinite)
                    #expect(SurfacePlot3DWording.valueRange.contains(y), "\(function) at \(x), \(z) gave \(y)")
                }
            }
        }
    }

    @Test("Given the ripple, when it is evaluated at x ±π/4 and z −π/2, 0 and π/2, then it has three peaks of 1 and three troughs of −1, as the headline says")
    func rippleHasThreePeaksAndThreeTroughs() {
        let candidates = [-Double.pi / 4, Double.pi / 4].flatMap { x in
            [-Double.pi / 2, 0, Double.pi / 2].map { z in SurfacePlot3DFunction.ripple.value(x: x, z: z) }
        }
        #expect(candidates.count(where: { abs($0 - 1) < tolerance }) == 3)
        #expect(candidates.count(where: { abs($0 + 1) < tolerance }) == 3)
    }

    @Test("Given the ripple, when its x edges are evaluated, then their ridges stay lower than the peaks, as the headline says")
    func rippleEdgesAreLower() {
        let ripple = SurfacePlot3DFunction.ripple
        let edge = stride(from: -2.0, through: 2.0, by: 0.05).flatMap { z in
            [ripple.value(x: -2, z: z), ripple.value(x: 2, z: z)]
        }
        let highest = edge.map(abs).max() ?? 0
        #expect(highest < 0.8)
        #expect(highest > 0.75)
    }

    @Test("Given every function, when its Audio Graph rows are made, then their highest and lowest points are the figures the headline names")
    func rowsReachTheHeadlinesFigures() throws {
        for function in SurfacePlot3DFunction.allCases {
            // The descriptor's points are these rows' values (its point values are not readable from Swift).
            let rows = SurfacePlot3DWording.rowZValues(for: function)
            let xs = SurfacePlot3DWording.rowXValues(for: function)
            let values = rows.flatMap { z in xs.map { x in function.value(x: x, z: z) } }
            let descriptor = SurfacePlot3DChartDescriptor(function: function, locale: english).makeChartDescriptor()
            #expect(descriptor.series.count == rows.count)
            #expect(descriptor.series.allSatisfy { $0.dataPoints.count == xs.count })
            let highest = try #require(values.max())
            let lowest = try #require(values.min())
            let named = SurfacePlot3DWording.headlineExtremes(for: function)
            let headline = SurfacePlot3DWording.headline(for: function, locale: english)
            // As the axes and the Audio Graph write them.
            let write = { SurfacePlot3DWording.number($0, locale: english) }
            #expect(write(highest) == write(named.highest), "\(function)")
            #expect(write(lowest) == write(named.lowest), "\(function)")
            #expect(headline.contains(write(named.highest)) && headline.contains(write(named.lowest)), "\(function)")
            if function != .hill {
                #expect(highest == named.highest, "\(function)")
                #expect(lowest == named.lowest, "\(function)")
            }
        }
    }

    // MARK: View model states

    @Test("Given a new view model, when nothing is chosen, then it shows the ripple in the height-based style")
    func defaults() {
        let viewModel = SurfacePlot3DViewModel()
        #expect(viewModel.function == .ripple)
        #expect(viewModel.style == .heightBased)
    }

    @Test("Given each style, when the snippets are listed, then they are the chart, the check, that style's line and the functions")
    func snippetsFollowTheStyle() {
        let viewModel = SurfacePlot3DViewModel()
        let expected: [SurfacePlot3DStyle: String] = [
            .heightBased: "surface-plot-height-based",
            .normalBased: "surface-plot-normal-based",
            .gradient: "surface-plot-gradient",
        ]
        for style in SurfacePlot3DStyle.allCases {
            viewModel.style = style
            #expect(viewModel.snippets.map(\.name) == [
                "surface-plot-chart", "surface-plot-gate", expected[style] ?? "", "surface-plot-functions",
            ])
        }
    }

    @Test("Given the app's bundle, when every snippet the screen can show is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for snippet in SurfacePlot3DViewModel.allSnippets {
            #expect(store[snippet.name] != nil, "missing \(snippet.name)")
        }
        #expect(SurfacePlot3DViewModel.allSnippets.count == 6)
    }

    @Test("Given each style, when the explanation is written, then it ends on that style's sentence")
    func explanationFollowsTheStyle() {
        let viewModel = SurfacePlot3DViewModel()
        for style in SurfacePlot3DStyle.allCases {
            viewModel.style = style
            #expect(viewModel.explanation.contains(style.explanation))
        }
    }

    // MARK: Words

    @Test("Given each function, when the headline is written, then it states the figures on its axes")
    func headlines() {
        #expect(SurfacePlot3DWording.headline(for: .ripple, locale: english)
            == "Three peaks of 1 and three troughs of -1 alternate across the middle, with lower ridges along both x edges.")
        #expect(SurfacePlot3DWording.headline(for: .saddle, locale: english)
            == "A saddle: it rises to 1 towards both ends of x and falls to -1 towards both ends of z, passing 0 in the middle.")
        #expect(SurfacePlot3DWording.headline(for: .hill, locale: english)
            == "One peak of 1 in the middle, where x and z are 0, flattening towards 0 at every edge.")
    }

    @Test("Given the function changes, when the headline and announcement are written, then both follow it")
    func headlineAndAnnouncementFollowTheFunction() {
        let viewModel = SurfacePlot3DViewModel()
        viewModel.function = .saddle
        let headline = viewModel.headline(locale: english, isChartAvailable: true)
        #expect(headline.hasPrefix("A saddle"))
        #expect(viewModel.functionChangeAnnouncement(locale: english) == "Showing the saddle. " + headline)
    }

    @Test("Given the chart cannot be drawn, when the headline is written, then it says so instead of describing a surface")
    func unavailableHeadline() {
        let viewModel = SurfacePlot3DViewModel()
        #expect(viewModel.headline(locale: english, isChartAvailable: false) == "Surface plots need iOS 26 or later.")
    }

    @Test("Given a German locale, when the headline is written, then its numbers take that locale")
    func headlineTakesLocale() {
        let german = Locale(identifier: "de_DE")
        #expect(SurfacePlot3DWording.number(0.25, locale: german) == "0,25")
        #expect(SurfacePlot3DWording.headline(for: .ripple, locale: german).contains("1"))
    }

    @Test("Given each function, when its element text is written, then the label names the formula in words and the value says where the extremes are, not the headline again")
    func elementText() {
        #expect(SurfacePlot3DWording.elementLabel(for: .ripple, locale: english)
            == "Surface plot, y equals sine of 2x times cosine of 2z, for x and z from -2 to 2")
        #expect(SurfacePlot3DWording.elementValue(for: .ripple, locale: english)
            == "Highest, 1, at x 0.79 and z 0, and at x -0.79 and z -1.57 or 1.57. "
            + "Lowest, -1, at the same places with the sign of x changed. "
            + "The ridges along the x edges reach only 0.76 and -0.76.")
        #expect(SurfacePlot3DWording.elementValue(for: .hill, locale: english)
            == "Highest, 1, at x 0 and z 0. 0.37 at a distance of 1 from the middle, and 0 to two decimals at the edges.")
        for function in SurfacePlot3DFunction.allCases {
            #expect(SurfacePlot3DWording.elementValue(for: function, locale: english)
                != SurfacePlot3DWording.headline(for: function, locale: english))
        }
    }

    // MARK: Viewpoint

    @Test("Given a new view model, when the chart is turned by hand and then a view is chosen, then the control follows")
    func viewpointFollowsThePose() {
        let viewModel = SurfacePlot3DViewModel()
        #expect(viewModel.viewpoint == .angle)
        viewModel.poseChanged(toMatch: nil)
        #expect(viewModel.viewpoint == nil)
        viewModel.viewpoint = .above
        viewModel.poseChanged(toMatch: .above)
        #expect(viewModel.viewpoint == .above)
    }

    @Test("Given each view, when its pose is made, then the four are different poses")
    func viewpointPoses() {
        guard #available(iOS 26, *) else { return }
        let poses = SurfacePlot3DViewpoint.allCases.map(\.pose)
        #expect(poses[1] == .front && poses[2] == .left && poses[3] == .top)
        #expect(poses[0] != .front && poses[0] != .left && poses[0] != .top)
    }

    // MARK: Chart descriptor

    @Test("Given the saddle, when its chart descriptor is made, then it has a title, the headline as summary and one row per z")
    func descriptor() throws {
        let descriptor = SurfacePlot3DChartDescriptor(function: .saddle, locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Surface plot of y equals x squared minus z squared, divided by 4")
        #expect(descriptor.summary == SurfacePlot3DWording.headline(for: .saddle, locale: english))
        #expect(descriptor.series.map(\.name) == ["Row at z -2", "Row at z -1", "Row at z 0", "Row at z 1", "Row at z 2"])
        let allContinuous = descriptor.series.allSatisfy(\.isContinuous)
        #expect(allContinuous)
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 17 })
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == -1.25 ... 1.25)
        #expect(yAxis.valueDescriptionProvider(0.25) == "y 0.25")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given any function, when the descriptor is made, then it has a z axis")
    func descriptorHasZAxis() throws {
        let descriptor = SurfacePlot3DChartDescriptor(function: .saddle, locale: english).makeChartDescriptor()
        let zAxis = try #require(descriptor.additionalAxes.first as? AXNumericDataAxisDescriptor)
        #expect(descriptor.additionalAxes.count == 1)
        #expect(zAxis.title == "z")
        #expect(zAxis.range == SurfacePlot3DWording.planeDomain)
        #expect(zAxis.valueDescriptionProvider(-1.5) == "z -1.5")
    }
}
