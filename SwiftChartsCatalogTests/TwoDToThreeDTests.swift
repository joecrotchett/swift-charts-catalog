import Accessibility
import Charts
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct TwoDToThreeDTests {
    let english = Locale(identifier: "en_US")
    let german = Locale(identifier: "de_DE")

    private func bean(_ id: Int, _ origin: String, _ acidity: Double, _ body: Double, _ sweetness: Double) -> BeanTasting {
        BeanTasting(id: id, origin: origin, acidity: acidity, body: body, sweetness: sweetness)
    }

    // MARK: View model state

    @Test("Given a new screen, when it opens, then it shows acidity against body and the 3D chart's opening angle")
    func initialState() {
        let model = TwoDToThreeDViewModel()
        #expect(model.chart == .acidityBody)
        #expect(model.viewpoint == .angle)
        #expect(model.beans.count == 60)
        #expect(!model.isEmpty)
    }

    @Test("Given each 2D chart, when it is shown, then See Code shows the 2D scatter and its elements")
    func twoDSnippets() {
        let model = TwoDToThreeDViewModel()
        for chart in [TwoDToThreeDChart.acidityBody, .sweetnessBody, .aciditySweetness] {
            model.chart = chart
            #expect(model.snippets.map(\.name) == ["from-2d-to-3d-scatter", "from-2d-to-3d-elements"])
        }
    }

    @Test("Given the 3D chart, when it is shown, then See Code opens on the 3D chart, with the availability check after it")
    func threeDSnippets() {
        let model = TwoDToThreeDViewModel()
        model.chart = .threeD
        #expect(model.snippets.map(\.name) == [
            "from-2d-to-3d-chart3d", "from-2d-to-3d-gate", "from-2d-to-3d-pose", "from-2d-to-3d-elements",
        ])
    }

    @Test("Given the app's snippets, when they are loaded, then every snippet the screen names exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = Set((TwoDToThreeDViewModel.twoDSnippets + TwoDToThreeDViewModel.threeDSnippets).map(\.name))
        for name in names {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
        #expect(store["from-2d-to-3d-gate"]?.code.contains("#available(iOS 26") == true)
        #expect(store["from-2d-to-3d-chart3d"]?.code.contains("z: .value") == true)
    }

    @Test("Given the 3D chart turned by hand, when the pose matches no face, then no viewpoint is selected")
    func turnedByHand() {
        let model = TwoDToThreeDViewModel()
        model.poseChanged(toMatch: nil)
        #expect(model.viewpoint == nil)
        model.poseChanged(toMatch: .side)
        #expect(model.viewpoint == .side)
    }

    @Test("Given the 3D chart turned to a face, when a 2D chart is shown and the 3D chart again, then it opens on that face")
    func viewpointSurvivesARoundTrip() {
        let model = TwoDToThreeDViewModel()
        model.chart = .threeD
        model.viewpoint = .below

        model.chart = .sweetnessBody
        model.chart = .threeD

        #expect(model.viewpoint == .below)
        #expect(model.openingViewpoint == .below)
    }

    @Test("Given the 3D chart turned by hand, when a 2D chart is shown and the 3D chart again, then it and the control both go back to the opening angle")
    func handTurnResetsOnReturn() {
        let model = TwoDToThreeDViewModel()
        model.chart = .threeD
        model.poseChanged(toMatch: nil)

        model.chart = .acidityBody
        model.chart = .threeD

        #expect(model.viewpoint == .angle)
        #expect(model.openingViewpoint == .angle)
    }

    @Test("Given each opening viewpoint, when the 3D view is made, then its pose is that viewpoint's")
    func openingPoseFollowsViewpoint() {
        guard #available(iOS 26, *) else { return }
        for viewpoint in TwoDToThreeDViewpoint.allCases {
            #expect(TwoDToThreeDChart3DView.openingPose(for: viewpoint) == viewpoint.pose)
        }
    }

    @Test("Given an origin outside the three, when its look is taken, then it is neutral and shared with none of them")
    func unknownOriginIsNeutral() {
        let known = CafeData.beanOrigins
        #expect(!BeanOriginStyle.isKnown("Kenya"))
        #expect(BeanOriginStyle.colour(for: "Kenya") == .gray)
        #expect(!known.map(BeanOriginStyle.colour(for:)).contains(.gray))
        #expect(!known.map(BeanOriginStyle.symbolName(for:)).contains(BeanOriginStyle.symbolName(for: "Kenya")))
        #expect(!known.map(BeanOriginStyle.solid(for:)).contains(BeanOriginStyle.solid(for: "Kenya")))
    }

    @Test("Given each face of the cube, when it is chosen, then it matches the 2D chart of the same two scores")
    func facesMatchCharts() {
        #expect(TwoDToThreeDViewpoint.front.matchingChart == .acidityBody)
        #expect(TwoDToThreeDViewpoint.side.matchingChart == .sweetnessBody)
        #expect(TwoDToThreeDViewpoint.below.matchingChart == .aciditySweetness)
        #expect(TwoDToThreeDViewpoint.angle.matchingChart == nil)
        #expect(TwoDToThreeDChart.sweetnessBody.xScore == .sweetness)
        #expect(TwoDToThreeDChart.sweetnessBody.yScore == .body)
        #expect(TwoDToThreeDChart.threeD.hiddenScore == nil)
    }

    @Test("Given each chart, when it is shown, then the explanation says what it shows")
    func explanations() {
        let model = TwoDToThreeDViewModel()
        model.chart = .acidityBody
        #expect(model.explanation.contains("leaves sweetness out"))
        model.chart = .threeD
        #expect(model.explanation.contains("Chart becomes Chart3D"))
        #expect(model.explanation.contains("from the front it is the first chart"))
    }

    // MARK: Headlines

    @Test("Given the tastings, when each chart is shown, then the headline gives whole-number spans that are on the grid")
    func headlines() {
        let summary = TwoDToThreeDSummary(beans: CafeData.beanTastings, locale: english)
        #expect(summary.headline(for: .acidityBody)
            == "Ethiopia scores highest for acidity, about 7 to 9; Sumatra scores highest for body, about 7 to 9.")
        #expect(summary.headline(for: .aciditySweetness)
            == "Ethiopia scores highest for acidity, about 7 to 9; Sumatra scores highest for sweetness, about 6 to 8.")
        #expect(summary.headline(for: .sweetnessBody)
            == "Sweetness rises with body: about 3 for the lightest sample (body 3) and 8 for the fullest (body 9).")
        #expect(summary.headline(for: .threeD).hasPrefix("All three scores in one chart"))
    }

    @Test("Given no tastings, when any chart is chosen, then the headline and summary say there is no data")
    func emptyData() {
        let model = TwoDToThreeDViewModel(beans: [])
        #expect(model.isEmpty)
        let summary = model.summary(locale: english)
        for chart in TwoDToThreeDChart.allCases {
            #expect(summary.headline(for: chart) == "No tastings recorded yet.")
            #expect(summary.audioGraphSummary(for: chart) == "No tastings recorded yet.")
        }
        #expect(summary.clusters.isEmpty)
    }

    @Test("Given every score zero, when the headline is written, then it claims no leader and no trend")
    func allZero() {
        let beans = CafeData.beanOrigins.enumerated().map { bean($0.offset, $0.element, 0, 0, 0) }
        let summary = TwoDToThreeDSummary(beans: beans, locale: english)
        #expect(summary.headline(for: .acidityBody)
            == "Every origin scores about 0 for acidity; every origin scores about 0 for body.")
        #expect(summary.headline(for: .sweetnessBody) == "Every sample has a body of about 0, so this view shows no trend.")
    }

    @Test("Given sweetness that falls with body, when the side chart is shown, then the headline says it falls")
    func fallingTrend() {
        let beans = [bean(0, "Ethiopia", 5, 2, 8), bean(1, "Sumatra", 5, 8, 3)]
        let summary = TwoDToThreeDSummary(beans: beans, locale: english)
        #expect(summary.headline(for: .sweetnessBody).hasPrefix("Sweetness falls as body rises"))
    }

    @Test("Given two origins tied for the highest acidity, when the headline is written, then it names both")
    func tiedLeaders() {
        let beans = [bean(0, "Ethiopia", 8, 3, 4), bean(1, "Colombia", 8, 5, 5), bean(2, "Sumatra", 3, 8, 7)]
        let summary = TwoDToThreeDSummary(beans: beans, locale: english)
        #expect(summary.headline(for: .acidityBody).hasPrefix("Ethiopia and Colombia score highest for acidity, about 8"))
    }

    // MARK: What assistive technologies get

    @Test("Given each origin, when its element is written, then it says the origin, the count and each drawn score's span")
    func elementText() throws {
        let summary = TwoDToThreeDSummary(beans: CafeData.beanTastings, locale: english)
        let ethiopia = try #require(summary.clusters.first)
        #expect(summary.clusters.map(\.origin) == CafeData.beanOrigins)
        #expect(summary.elementLabel(for: ethiopia) == "Ethiopia, 20 samples")
        #expect(summary.elementValue(for: ethiopia, chart: .acidityBody)
            == "Acidity 6.9 to 8.7 out of 10, Body 2.5 to 4.3 out of 10")
        #expect(summary.elementValue(for: ethiopia, chart: .sweetnessBody)
            == "Sweetness 2.9 to 4.6 out of 10, Body 2.5 to 4.3 out of 10")
        #expect(summary.elementValue(for: ethiopia, chart: .threeD)
            == "Acidity 6.9 to 8.7 out of 10, Body 2.5 to 4.3 out of 10, Sweetness 2.9 to 4.6 out of 10")
    }

    @Test("Given one sample, when its element is written, then the count agrees in number")
    func singularSample() throws {
        let summary = TwoDToThreeDSummary(beans: [bean(0, "Ethiopia", 7, 3, 4)], locale: english)
        let cluster = try #require(summary.clusters.first)
        #expect(summary.elementLabel(for: cluster) == "Ethiopia, 1 sample")
        #expect(summary.elementValue(for: cluster, chart: .acidityBody) == "Acidity 7 out of 10, Body 3 out of 10")
    }

    @Test("Given a German locale, when scores are written, then they take its decimal comma")
    func germanLocale() throws {
        let summary = TwoDToThreeDSummary(beans: CafeData.beanTastings, locale: german)
        let ethiopia = try #require(summary.clusters.first)
        #expect(summary.elementValue(for: ethiopia, chart: .acidityBody).hasPrefix("Acidity 6,9 to 8,7"))
    }

    @Test("Given a change of chart or viewpoint, when it is announced, then it says what changed, then what is shown")
    func announcements() {
        let summary = TwoDToThreeDSummary(beans: CafeData.beanTastings, locale: english)
        #expect(summary.announcement(for: TwoDToThreeDChart.sweetnessBody)
            == "Showing sweetness against body. \(summary.headline(for: .sweetnessBody))")
        #expect(summary.announcement(for: TwoDToThreeDChart.threeD).hasPrefix("Showing the 3D chart of all three scores. All three"))
        #expect(summary.announcement(for: TwoDToThreeDViewpoint.below)
            == "Seen from below: acidity across, sweetness up, the same as the 2D chart of those two scores.")
    }

    // MARK: Audio Graph

    @Test("Given a 2D chart, when its descriptor is made, then it has two score axes and one series per origin")
    func twoDDescriptor() throws {
        let descriptor = TwoDToThreeDDescriptor(beans: CafeData.beanTastings, chart: .sweetnessBody, locale: english)
            .makeChartDescriptor()
        #expect(descriptor.title == "Bean tastings: sweetness against body, by origin")
        #expect(descriptor.xAxis.title == "Sweetness")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Body")
        #expect(yAxis.range == 0 ... 10)
        #expect(yAxis.valueDescriptionProvider(7.5) == "7.5 out of 10")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.additionalAxes.isEmpty)
        #expect(descriptor.series.map(\.name) == CafeData.beanOrigins)
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 20 && !$0.isContinuous })
        #expect(descriptor.summary?.hasPrefix("60 samples from Ethiopia, Colombia, and Sumatra.") == true)
    }

    @Test("Given the 3D chart, when its descriptor is made, then sweetness is a third axis and each point carries it")
    func threeDDescriptor() {
        let descriptor = TwoDToThreeDDescriptor(beans: CafeData.beanTastings, chart: .threeD, locale: english)
            .makeChartDescriptor()
        #expect(descriptor.title == "Bean tastings: acidity, body and sweetness, by origin")
        #expect(descriptor.xAxis.title == "Acidity")
        #expect(descriptor.additionalAxes.map(\.title) == ["Sweetness"])
        #expect(descriptor.series.map(\.dataPoints.count) == [20, 20, 20])
    }
}
