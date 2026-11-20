import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct FittedSurfaceTests {
    private let english = Locale(identifier: "en_US")

    private func tasting(_ id: Int, _ acidity: Double, _ body: Double, _ sweetness: Double, origin: String = "Ethiopia") -> BeanTasting {
        BeanTasting(id: id, origin: origin, acidity: acidity, body: body, sweetness: sweetness)
    }

    /// Points lying exactly on sweetness = 2 + 0.5 × acidity − 0.25 × body.
    private var onAKnownPlane: [BeanTasting] {
        [(1.0, 2.0), (4.0, 1.0), (6.0, 7.0), (3.0, 5.0), (8.0, 3.0)].enumerated().map { index, pair in
            tasting(index, pair.0, pair.1, 2 + 0.5 * pair.0 - 0.25 * pair.1)
        }
    }

    // MARK: The fit

    @Test("Given points exactly on a known plane, when fitted, then the coefficients are that plane's")
    func fitRecoversKnownPlane() throws {
        let plane = try #require(FittedSurfacePlane.fit(onAKnownPlane))

        #expect(abs(plane.intercept - 2) < 1e-9)
        #expect(abs(plane.acidityWeight - 0.5) < 1e-9)
        #expect(abs(plane.bodyWeight + 0.25) < 1e-9)
    }

    @Test("Given the bean tastings, when fitted, then the coefficients match the least-squares fit worked out separately")
    func fitMatchesBeanTastings() throws {
        // Worked out outside the app (normal equations in Python on the same sixty samples):
        // intercept 1.21341, acidity -0.00055, body 0.74794. The data was made as 1.2 + 0.75 × body plus noise.
        let plane = try #require(FittedSurfacePlane.fit(CafeData.beanTastings))

        #expect(abs(plane.intercept - 1.21341) < 1e-4)
        #expect(abs(plane.acidityWeight + 0.00055) < 1e-4)
        #expect(abs(plane.bodyWeight - 0.74794) < 1e-4)
    }

    @Test("Given fewer than three samples, when fitted, then there is no plane")
    func fitNeedsThreeSamples() {
        #expect(FittedSurfacePlane.fit(Array(onAKnownPlane.prefix(2))) == nil)
        #expect(FittedSurfacePlane.fit([]) == nil)
    }

    @Test("Given samples whose acidity and body lie on one line, when fitted, then there is no plane")
    func fitRefusesALine() {
        let inALine = (0 ..< 5).map { tasting($0, Double($0), 2 * Double($0), 3) }
        #expect(FittedSurfacePlane.fit(inALine) == nil)
    }

    @Test("Given a plane, when it leaves the 0 to 10 range, then the drawn height is not a number there")
    func drawnSweetnessStopsAtTheScoreRange() {
        let plane = FittedSurfacePlane(intercept: 1, acidityWeight: 0, bodyWeight: 2)

        #expect(FittedSurfaceViewModel.drawnSweetness(plane, acidity: 5, body: 3) == 7)
        #expect(FittedSurfaceViewModel.drawnSweetness(plane, acidity: 5, body: 6).isNaN)
    }

    // MARK: Domains and presets

    @Test("Given the bean tastings, when the domains are read, then acidity and body span the data in whole points and sweetness 0 to 10")
    func domains() {
        let viewModel = FittedSurfaceViewModel()

        #expect(viewModel.acidityDomain == 2 ... 9)
        #expect(viewModel.bodyDomain == 2 ... 9)
        #expect(viewModel.sweetnessDomain == 0 ... 10)
    }

    @Test("Given a drag after a preset, when the same preset is chosen again, then the chart turns back to it")
    func choosingAPreset() {
        let viewModel = FittedSurfaceViewModel()
        #expect(viewModel.azimuthDegrees == 55)
        #expect(viewModel.inclinationDegrees == 12)

        viewModel.choose(.nearlyEdgeOn)
        // A drag writes its angles back into the view model.
        viewModel.azimuthDegrees = 10
        viewModel.inclinationDegrees = 30
        viewModel.choose(.nearlyEdgeOn)

        #expect(viewModel.azimuthDegrees == 84)
        #expect(viewModel.inclinationDegrees == 4)
    }

    @Test("Given a dragged angle, when the plane is toggled, then the angle is kept")
    func toggleKeepsPose() {
        let viewModel = FittedSurfaceViewModel()
        viewModel.azimuthDegrees = 70
        viewModel.inclinationDegrees = 20
        viewModel.showsSurface = false
        viewModel.showsSurface = true
        #expect(viewModel.azimuthDegrees == 70)
        #expect(viewModel.inclinationDegrees == 20)
    }

    @Test("Given a domain, when its labels are chosen, then they are whole scores inside it, the odd ones when there are many")
    func labelledValues() {
        #expect(FittedSurfaceViewModel.labelledValues(in: 2 ... 9) == [3, 5, 7])
        #expect(FittedSurfaceViewModel.labelledValues(in: 1 ... 7) == [3, 5])
        #expect(FittedSurfaceViewModel.labelledValues(in: 4 ... 7) == [5, 6])
        #expect(FittedSurfaceViewModel.labelledValues(in: 4 ... 5).isEmpty)
        let viewModel = FittedSurfaceViewModel()
        #expect(viewModel.acidityMarks == [3, 5, 7])
        #expect(viewModel.bodyMarks == [3, 5, 7])
    }

    @Test("Given the bean tastings, when the origins are listed, then they come in the order VoiceOver reads them, left to right")
    func readOrder() {
        #expect(FittedSurfaceViewModel().originsInReadOrder == ["Sumatra", "Colombia", "Ethiopia"])
        // The key and the Audio Graph list the origins in the app's one order.
        #expect(FittedSurfaceViewModel().originsInOriginOrder == ["Ethiopia", "Colombia", "Sumatra"])
    }

    // MARK: Words

    @Test("Given the plane is shown, when the headline is read, then it names the plane's height at labelled scores")
    func headlineWithPlane() {
        let viewModel = FittedSurfaceViewModel()
        // 1.2134 − 0.00055 × 5 + 0.74794 × 3 = 3.45; × 7 = 6.45.
        #expect(viewModel.headline(locale: english) == "Fitted plane, at acidity 5: sweetness 3.5 at body 3, sweetness 6.4 at body 7.")
        let labelled = viewModel.labelledHeights
        #expect(labelled?.acidity == 5)
        #expect(labelled?.heights.map(\.body) == [3, 7])
    }

    @Test("Given a plane that leaves the score range at some labels, when the headline is read, then it names only heights that are drawn")
    func headlineSkipsUndrawnHeights() {
        // On the known plane, acidity 1 to 8 labels 3, 5, 7 and body 1 to 7 labels 3, 5: 3.75 and 3.25 at acidity 5.
        let viewModel = FittedSurfaceViewModel(tastings: onAKnownPlane)
        #expect(viewModel.headline(locale: english) == "Fitted plane, at acidity 5: sweetness 3.8 at body 3, sweetness 3.2 at body 5.")
    }

    @Test("Given the plane, when its equation is written, then it has no minus on a weight that rounds to zero and a minus on a negative one")
    func equation() {
        #expect(FittedSurfaceViewModel().equation(locale: english) == "sweetness = 1.21 + 0.00 × acidity + 0.75 × body")
        #expect(FittedSurfaceViewModel(tastings: onAKnownPlane).equation(locale: english)
            == "sweetness = 2.00 + 0.50 × acidity − 0.25 × body")
        #expect(FittedSurfaceViewModel().explanation(locale: english).hasSuffix("The fit is sweetness = 1.21 + 0.00 × acidity + 0.75 × body."))
        #expect(FittedSurfaceViewModel(tastings: []).equation(locale: english) == nil)
    }

    @Test("Given the plane is hidden, when the headline is read, then it describes the samples")
    func headlineWithoutPlane() {
        let viewModel = FittedSurfaceViewModel()
        viewModel.showsSurface = false
        #expect(viewModel.headline(locale: english) == "60 bean samples, each scored for acidity, body and sweetness.")
    }

    @Test("Given no samples or too few, when the headline is read, then it says so")
    func headlineWithoutAFit() {
        #expect(FittedSurfaceViewModel(tastings: []).headline(locale: english) == "No bean samples to fit a plane to.")
        let one = FittedSurfaceViewModel(tastings: Array(onAKnownPlane.prefix(1)))
        #expect(one.headline(locale: english) == "1 bean sample: too few, or in a line, to fit a plane.")
        #expect(!one.drawsPlane)
    }

    @Test("Given the plane is toggled, when the announcement is read, then it says what changed and then the headline")
    func announcement() {
        let viewModel = FittedSurfaceViewModel()
        #expect(viewModel.changeAnnouncement(locale: english).hasPrefix("Fitted plane shown. Fitted plane, at acidity 5"))
        viewModel.showsSurface = false
        #expect(viewModel.changeAnnouncement(locale: english) == "Fitted plane hidden. 60 bean samples, each scored for acidity, body and sweetness.")
    }

    @Test("Given a German locale, when the headline is read, then its numbers use a decimal comma")
    func headlineLocale() {
        let viewModel = FittedSurfaceViewModel()
        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")) == "Fitted plane, at acidity 5: sweetness 3,5 at body 3, sweetness 6,4 at body 7.")
    }

    @Test("Given the bean tastings, when the spoken text is read, then each origin and the plane are described in values")
    func spokenText() {
        let spoken = FittedSurfaceViewModel().spokenText(locale: english)

        #expect(spoken.originLabel("Ethiopia") == "Ethiopia")
        #expect(spoken.originValue("Ethiopia").hasPrefix("20 bean samples. Acidity "))
        #expect(spoken.planeLabel == "Fitted plane")
        #expect(spoken.planeValue == "Fitted to 60 bean samples: sweetness is 1.21, plus 0.00 for each point of acidity, plus 0.75 for each point of body")
        #expect(spoken.summary == "60 bean samples from 3 origins, each scored from 0 to 10. Sweetness from 2.9 to 7.9. "
            + "Fitted plane: sweetness is 1.21, plus 0.00 for each point of acidity, plus 0.75 for each point of body.")
    }

    // MARK: The descriptor

    private func descriptor(showsSurface: Bool) -> AXChartDescriptor {
        let viewModel = FittedSurfaceViewModel()
        viewModel.showsSurface = showsSurface
        return FittedSurfaceDescriptor(
            spoken: viewModel.spokenText(locale: english),
            acidityDomain: viewModel.acidityDomain,
            bodyDomain: viewModel.bodyDomain,
            sweetnessDomain: viewModel.sweetnessDomain
        ).makeChartDescriptor()
    }

    @Test("Given the plane is shown, when the descriptor is made, then it has the three origins and the plane, and body as a third axis")
    func descriptorWithPlane() throws {
        let made = descriptor(showsSurface: true)

        #expect(made.title == "Bean tastings with a plane fitted to them")
        // In the order VoiceOver reads the elements: the plane, then the origins left to right.
        #expect(made.series.map(\.name) == ["Fitted plane", "Ethiopia", "Colombia", "Sumatra"])
        #expect(made.series.dropFirst().map(\.dataPoints.count) == [20, 20, 20])
        // Acidity 2...9 and body 2...9 in whole points: 8 × 8 samples of the plane, all inside 0 to 10.
        #expect(made.series.first?.dataPoints.count == 64)
        #expect(made.additionalAxes.count == 1)
        #expect(made.additionalAxes.first?.title == "Body")
        let yAxis = try #require(made.yAxis)
        #expect(yAxis.title == "Sweetness")
        #expect(yAxis.range == 0 ... 10)
        #expect(yAxis.valueDescriptionProvider(6.54) == "6.5 out of 10")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given the plane is hidden, when the descriptor is made, then only the origins remain")
    func descriptorWithoutPlane() {
        let made = descriptor(showsSurface: false)

        #expect(made.title == "Bean tastings")
        #expect(made.series.map(\.name) == ["Ethiopia", "Colombia", "Sumatra"])
        #expect(!(made.summary ?? "").contains("Fitted plane"))
    }

    @Test("Given a plane that leaves the score range, when the descriptor samples it, then only drawn heights are described")
    func descriptorSamplesDrawnHeights() throws {
        // sweetness = 1 + 2 × body leaves 0 to 10 above body 4.5.
        let plane = FittedSurfacePlane(intercept: 1, acidityWeight: 0, bodyWeight: 2)
        let spoken = FittedSurfaceSpokenText(tastings: [], plane: plane, showsSurface: true, locale: english)
        let made = FittedSurfaceDescriptor(spoken: spoken, acidityDomain: 0 ... 1, bodyDomain: 0 ... 9, sweetnessDomain: 0 ... 10)
            .makeChartDescriptor()
        let planeSeries = try #require(made.series.first)
        // Acidity 0 and 1, body 0 to 4: ten points.
        #expect(planeSeries.dataPoints.count == 10)
        #expect(planeSeries.dataPoints.allSatisfy { ($0.yValue?.__number ?? .nan) <= 10 })
    }

    @Test("Given the built app, when its snippets are read, then every one this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [
            "a-surface-through-the-points-gate", "a-surface-through-the-points-chart",
            "a-surface-through-the-points-fit", "a-surface-through-the-points-accessibility",
        ]
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }
}
