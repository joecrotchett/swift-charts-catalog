import Accessibility
import Charts
import Foundation
import Spatial
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct PoseProjectionTests {
    private let english = Locale(identifier: "en_US")

    private func tasting(_ id: Int, _ origin: String, _ acidity: Double, _ body: Double, _ sweetness: Double) -> BeanTasting {
        BeanTasting(id: id, origin: origin, acidity: acidity, body: body, sweetness: sweetness)
    }

    // MARK: Presets

    @Test("Given each preset, when its pose is made, then it is the framework's preset for that view")
    func presetsMapToPoses() {
        guard #available(iOS 26.0, *) else { return }
        #expect(PoseProjectionPreset.clusters.pose == .front)
        #expect(PoseProjectionPreset.trend.pose == .left)
        #expect(PoseProjectionPreset.standard.pose == .default)
    }

    @Test("Given each preset, when its pose's angles are read back, then they are the angles the sliders show")
    func presetAnglesMatchPoses() {
        guard #available(iOS 26.0, *) else { return }
        for preset in PoseProjectionPreset.allCases {
            let pose = preset.pose
            let read = PoseProjectionAngles(azimuth: pose.azimuth.degrees, inclination: pose.inclination.degrees)
            #expect(read.isClose(to: preset.angles), "\(preset)")
        }
    }

    @Test("Given a preset's angles, when a pose is made from them, then it equals the framework's preset")
    func anglesMakeThePresetPose() {
        guard #available(iOS 26.0, *) else { return }
        for preset in [PoseProjectionPreset.clusters, .trend] {
            let made = Chart3DPose(azimuth: .degrees(preset.angles.azimuth), inclination: .degrees(preset.angles.inclination))
            #expect(made == preset.pose, "\(preset)")
        }
    }

    @Test("Given a new screen, when nothing is chosen, then it opens on the clusters, orthographic")
    func opensOnClusters() {
        let viewModel = PoseProjectionViewModel()

        #expect(viewModel.activePreset == .clusters)
        #expect(viewModel.projection == .orthographic)
        #expect(viewModel.view == .front(fromBehind: false))
        #expect(viewModel.tastings == CafeData.beanTastings)
    }

    @Test("Given the clusters, when Trend is chosen, then the angles move to the side and the change is announced with the headline")
    func choosingAPreset() {
        let viewModel = PoseProjectionViewModel()

        let announcement = viewModel.choose(.trend, locale: english)

        #expect(viewModel.angles == PoseProjectionAngles(azimuth: 90, inclination: 0))
        #expect(viewModel.activePreset == .trend)
        #expect(announcement == "From the left. From the left, sweetness against body: all 60 samples rise in one narrow band.")
    }

    @Test("Given a preset, when a slider moves off it, then no preset is marked")
    func sliderLeavesPreset() {
        let viewModel = PoseProjectionViewModel()

        viewModel.azimuth = 35

        #expect(viewModel.activePreset == nil)
    }

    // MARK: Keeping the chart and the sliders together

    @Test("Given the sliders, when the chart reports a pose rotated by hand, then the sliders take its angles, normalized")
    func rotationMovesSliders() {
        let viewModel = PoseProjectionViewModel()

        viewModel.chartReported(PoseProjectionAngles(azimuth: 200, inclination: 32.5))

        #expect(viewModel.azimuth == -160)
        #expect(viewModel.inclination == 32.5)
        #expect(viewModel.view == .angled)
    }

    @Test("Given the sliders set a pose, when the chart reports the same pose back, then nothing changes")
    func ownPoseIsNotWrittenBack() {
        let viewModel = PoseProjectionViewModel(preset: .standard)

        viewModel.chartReported(PoseProjectionAngles(azimuth: -29.999999999999996, inclination: 14.999999999999998))

        #expect(viewModel.azimuth == -30)
        #expect(viewModel.inclination == 15)
        #expect(viewModel.activePreset == .standard)
    }

    @Test("Given the inclination slider at 90, when the chart shows the 89.9 it allows, then the pose is not set again")
    func clampedInclinationIsTheSame() {
        let viewModel = PoseProjectionViewModel()
        viewModel.inclination = 90

        #expect(!viewModel.chartNeedsPose(currently: PoseProjectionAngles(azimuth: 0, inclination: 89.9)))
        #expect(viewModel.chartNeedsPose(currently: PoseProjectionAngles(azimuth: 0, inclination: 0)))
    }

    @Test("Given angles a full turn apart, when they are compared, then they are the same pose")
    func fullTurnIsClose() {
        #expect(PoseProjectionAngles(azimuth: 180, inclination: 0).isClose(to: PoseProjectionAngles(azimuth: -180, inclination: 0)))
        #expect(PoseProjectionAngles(azimuth: 370, inclination: 0).normalized.azimuth == 10)
        #expect(!PoseProjectionAngles(azimuth: 0, inclination: 0).isClose(to: PoseProjectionAngles(azimuth: 1, inclination: 0)))
    }

    // MARK: What a pose shows

    @Test("Given poses near each axis, when classified, then each names the scores it lines up", arguments: [
        (0.0, 0.0, PoseProjectionView.front(fromBehind: false)), (9.0, -9.0, .front(fromBehind: false)),
        (175.0, 0.0, .front(fromBehind: true)), (90.0, 5.0, .side(fromRight: false)), (-95.0, 0.0, .side(fromRight: true)),
        (30.0, 85.0, .top(fromBelow: false)), (0.0, -89.9, .top(fromBelow: true)),
        (-30.0, 15.0, .angled), (45.0, 0.0, .angled),
    ])
    func viewsByPose(azimuth: Double, inclination: Double, expected: PoseProjectionView) {
        #expect(PoseProjectionView(PoseProjectionAngles(azimuth: azimuth, inclination: inclination)) == expected)
    }

    @Test("Given each kind of pose, when the headline is written, then it says what that view of the tastings shows")
    func headlines() {
        let viewModel = PoseProjectionViewModel()
        #expect(viewModel.headline(locale: english) == "From the front, acidity against body: the 3 origins sit in separate clusters.")

        viewModel.azimuth = 180
        #expect(viewModel.headline(locale: english) == "From behind, acidity against body: the 3 origins sit in separate clusters.")

        viewModel.choose(.trend, locale: english)
        #expect(viewModel.headline(locale: english) == "From the left, sweetness against body: all 60 samples rise in one narrow band.")

        viewModel.azimuth = -90
        #expect(viewModel.headline(locale: english)
            == "From the right, mirrored, sweetness running right to left against body: all 60 samples rise in one narrow band.")

        viewModel.azimuth = 90
        viewModel.inclination = 90
        #expect(viewModel.headline(locale: english) == "From above, acidity against sweetness: the clusters separate, and body is hidden.")

        viewModel.choose(.standard, locale: english)
        #expect(viewModel.headline(locale: english) == "At azimuth -30°, inclination 15°: depth mixes all three scores, so no two can be read off the axes.")
    }

    @Test("Given no tastings, when the headline is written, then it says there is nothing to show")
    func emptyHeadline() {
        #expect(PoseProjectionViewModel(tastings: []).headline(locale: english) == "No tastings to show.")
    }

    @Test("Given origins that overlap and scores that do not rise together, when the headline is written, then it claims neither clusters nor a band")
    func headlineFollowsTheData() {
        let mixed = [
            tasting(0, "Ethiopia", 5, 5, 5), tasting(1, "Ethiopia", 6, 6, 2), tasting(2, "Colombia", 5.5, 5.5, 7),
            tasting(3, "Colombia", 6.5, 4, 3),
        ]
        let viewModel = PoseProjectionViewModel(tastings: mixed)
        #expect(viewModel.headline(locale: english) == "From the front, acidity against body: the origins overlap.")

        viewModel.choose(.trend, locale: english)
        #expect(viewModel.headline(locale: english) == "From the left, sweetness against body: the samples make no single band.")
    }

    @Test("Given every headline the screen can show, when compared with the reserved one, then none is longer")
    func reservedHeadlineIsLongest() {
        let viewModel = PoseProjectionViewModel()
        let reserved = viewModel.reservedHeadline(locale: english)
        for (azimuth, inclination) in [
            (0.0, 0.0), (180.0, 0.0), (90.0, 0.0), (-90.0, 0.0), (0.0, 85.0), (0.0, -85.0), (-175.0, -75.0),
        ] {
            viewModel.azimuth = azimuth
            viewModel.inclination = inclination
            #expect(viewModel.headline(locale: english).count <= reserved.count)
        }
    }

    @Test("Given an Egyptian Arabic locale, when the reserved headline is written, then it is the longest headline as written in that locale")
    func reservedHeadlineTakesLocale() {
        let viewModel = PoseProjectionViewModel()
        let arabic = Locale(identifier: "ar_EG")
        let reserved = viewModel.reservedHeadline(locale: arabic)
        #expect(reserved.contains("٦٠"))
        #expect(!reserved.contains("60"))
        for (azimuth, inclination) in [(-90.0, 0.0), (-175.0, -75.0), (0.0, 85.0)] {
            viewModel.azimuth = azimuth
            viewModel.inclination = inclination
            #expect(viewModel.headline(locale: arabic).count <= reserved.count)
        }
    }

    // MARK: The data behind the headline

    @Test("Given the bean tastings, when their facts are worked out, then three origins sit apart and sweetness follows body")
    func tastingFacts() throws {
        let facts = PoseProjectionFacts(tastings: CafeData.beanTastings)

        #expect(facts.clusters.map(\.origin) == CafeData.beanOrigins)
        #expect(facts.clusters.map(\.count) == [20, 20, 20])
        #expect(facts.clustersSeparateFromFront)
        #expect(facts.clustersSeparateFromAbove)
        #expect(try #require(facts.bodySweetnessCorrelation) >= 0.9)
    }

    // MARK: Controls and code

    @Test("Given a slider, when it speaks, then it says its angle in degrees and then the headline")
    func sliderSpokenValues() {
        let viewModel = PoseProjectionViewModel(preset: .standard)

        #expect(viewModel.azimuthText(locale: english) == "-30°")
        #expect(viewModel.azimuthSpokenValue(locale: english).hasPrefix("-30 degrees. At azimuth -30°"))
        viewModel.inclination = 1
        #expect(viewModel.inclinationSpokenValue(locale: english).hasPrefix("1 degree. "))
    }

    @Test("Given each projection, when the code is shown, then it shows that projection's modifier beside the pose code")
    func snippetsFollowProjection() {
        let viewModel = PoseProjectionViewModel()
        let shared = ["pose-and-projection-chart", "pose-and-projection-gate", "pose-and-projection-sync", "pose-and-projection-presets"]

        #expect(viewModel.snippets.map(\.name) == shared + ["pose-and-projection-orthographic"])
        viewModel.projection = .perspective
        #expect(viewModel.snippets.map(\.name) == shared + ["pose-and-projection-perspective"])
    }

    @Test("Given the app's snippets, when the screen's are looked up, then every one exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let viewModel = PoseProjectionViewModel()
        var names = Set(viewModel.snippets.map(\.name))
        viewModel.projection = .perspective
        names.formUnion(viewModel.snippets.map(\.name))

        for name in names {
            #expect(store[name] != nil, "\(name)")
        }
    }

    // MARK: Accessibility

    @Test("Given an origin, when its element is described, then it gives the name and count, then each score's extent")
    func elementText() throws {
        let viewModel = PoseProjectionViewModel(tastings: [
            tasting(0, "Ethiopia", 7, 3, 3.5), tasting(1, "Ethiopia", 8.5, 4.2, 4),
        ])
        let cluster = try #require(viewModel.facts.clusters.first)

        #expect(viewModel.elementLabel(for: cluster, locale: english) == "Ethiopia, 2 samples")
        #expect(viewModel.elementValue(for: cluster, locale: english) == "Acidity 7.0 to 8.5, body 3.0 to 4.2, sweetness 3.5 to 4.0")
    }

    @Test("Given the tastings, when the chart descriptor is made, then it plays body against sweetness with acidity as a third axis, one series per origin")
    func descriptor() throws {
        let descriptor = PoseProjectionDescriptor(tastings: CafeData.beanTastings, locale: english).makeChartDescriptor()

        // The chart opens from the front: acidity across, body up, sweetness the depth.
        #expect(descriptor.title == "Bean tastings: body against acidity, with sweetness, by origin")
        #expect(descriptor.summary?.hasPrefix("60 samples from 3 origins, scored 0 to 10. Ethiopia averages acidity") == true)
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.title == "Acidity")
        #expect(xAxis.range == 0 ... 10)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Body")
        #expect(yAxis.range == 0 ... 10)
        #expect(yAxis.valueDescriptionProvider(6.26) == "6.3 out of 10")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        let sweetness = try #require(descriptor.additionalAxes.first as? AXNumericDataAxisDescriptor)
        #expect(descriptor.additionalAxes.count == 1)
        #expect(sweetness.title == "Sweetness")
        #expect(sweetness.range == 0 ... 10)
        #expect(sweetness.valueDescriptionProvider(7.84) == "7.8 out of 10")
        #expect(descriptor.series.map(\.name) == CafeData.beanOrigins)
        #expect(descriptor.series.map(\.dataPoints.count) == [20, 20, 20])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
    }

    @Test("Given no tastings, when the descriptor's summary is written, then it says so")
    func emptyDescriptor() {
        #expect(PoseProjectionDescriptor(tastings: [], locale: english).summary == "No tastings.")
    }
}
