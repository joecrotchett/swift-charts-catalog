import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct HalfRingGaugeTests {
    private let english = Locale(identifier: "en_US")

    // MARK: Angles

    @Test("Given 0%, when the angles are worked out, then there is no filled part and the track takes the whole half ring")
    func anglesAtZero() {
        let angles = HalfRingGaugeAngles(progress: 0)

        #expect(angles.filled == nil)
        #expect(angles.track == 0 ..< 1)
        #expect(angles.clear == 1 ..< 2)
        #expect(angles.filledSweepDegrees == 0)
        #expect(angles.filledEndDegrees == -90)
    }

    @Test("Given 50%, when the angles are worked out, then the filled part sweeps 90 degrees and ends at 12 o'clock")
    func anglesAtHalf() {
        let angles = HalfRingGaugeAngles(progress: 0.5)

        #expect(angles.filled == 0 ..< 0.5)
        #expect(angles.track == 0.5 ..< 1)
        #expect(angles.clear == 1 ..< 2)
        #expect(angles.filledSweepDegrees == 90)
        #expect(angles.filledEndDegrees == 0)
    }

    @Test("Given 100%, when the angles are worked out, then the filled part sweeps 180 degrees and there is no track")
    func anglesAtFull() {
        let angles = HalfRingGaugeAngles(progress: 1)

        #expect(angles.filled == 0 ..< 1)
        #expect(angles.track == nil)
        #expect(angles.clear == 1 ..< 2)
        #expect(angles.filledSweepDegrees == 180)
        #expect(angles.filledEndDegrees == 90)
    }

    @Test(
        "Given a value outside 0 to 1 or not a number, when the angles are worked out, then it is clamped",
        arguments: [(-0.25, 0.0), (1.5, 1.0), (Double.nan, 0.0), (Double.infinity, 1.0), (-Double.infinity, 0.0)]
    )
    func anglesClamp(value: Double, expected: Double) {
        let angles = HalfRingGaugeAngles(progress: value)

        #expect(angles.progress == expected)
        #expect(angles.filledSweepDegrees == expected * 180)
    }

    @Test("Given a value between whole percents, when the angles are worked out, then it is rounded to a whole percent")
    func anglesRoundToWholePercent() {
        #expect(HalfRingGaugeAngles(progress: 0.004).filled == nil)
        #expect(HalfRingGaugeAngles(progress: 0.996).track == nil)
        #expect(HalfRingGaugeAngles(progress: 0.724).percent == 72)
    }

    // MARK: Headline and spoken text

    @Test("Given the starting state, when the headline is written, then it gives the percentage under the arch")
    func headlineStartingState() {
        let model = HalfRingGaugeViewModel()

        #expect(model.wording(locale: english).headline == "72% of today's cup goal is reached.")
        #expect(model.wording(locale: english).elementValue == "72%")
    }

    @Test("Given 0% and 100%, when the headline is written, then it says so in words and figures")
    func headlineAtEnds() {
        #expect(HalfRingGaugeWording(percent: 0, locale: english).headline == "None of today's cup goal is reached yet: 0%.")
        #expect(HalfRingGaugeWording(percent: 100, locale: english).headline == "Today's cup goal is reached: 100%.")
    }

    @Test("Given a value past the end, when the model writes the headline, then it uses the clamped value")
    func headlineClamped() {
        let model = HalfRingGaugeViewModel()
        model.progress = 1.3

        #expect(model.wording(locale: english).headline == "Today's cup goal is reached: 100%.")
    }

    @Test("Given a French locale, when the percentage is written, then it is written the French way")
    func percentFollowsLocale() {
        let text = HalfRingGaugeWording(percent: 72, locale: Locale(identifier: "fr_FR")).percentText

        #expect(text.hasPrefix("72"))
        #expect(text != "72%")
    }

    @Test("Given any state, when the slider speaks, then it speaks the headline")
    func sliderSpeaksHeadline() {
        let wording = HalfRingGaugeWording(percent: 40, locale: english)

        #expect(wording.sliderSpokenValue == "40% of today's cup goal is reached.")
    }

    // MARK: Chart identity

    @Test("Given a change to the progress or the toggle, when the identity is read, then it changes")
    func identityFollowsState() {
        let model = HalfRingGaugeViewModel()
        let first = model.chartIdentity
        model.progress = 0.3
        let second = model.chartIdentity
        model.showsClearSector = true

        #expect(first != second)
        #expect(second != model.chartIdentity)
    }

    // MARK: Descriptor

    @Test("Given 72%, when the descriptor is made, then it is one category with one point from 0 to 100 percent")
    func descriptorSingleValue() throws {
        let descriptor = HalfRingGaugeChartDescriptor(wording: HalfRingGaugeWording(percent: 72, locale: english))
            .makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(descriptor.title == "Progress toward today's cup goal")
        #expect(descriptor.summary == "72 percent of the goal.")
        #expect(xAxis.categoryOrder == ["Progress toward today's cup goal"])
        #expect(yAxis.range == 0 ... 100)
        #expect(yAxis.valueDescriptionProvider(72) == "72 percent")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.dataPoints.count == 1)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    // MARK: Snippets

    @Test("Given the built app, when the snippets are read, then every one the screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for snippet in HalfRingGaugeViewModel.snippets {
            #expect(store[snippet.name] != nil, "\(snippet.name)")
        }
    }
}
