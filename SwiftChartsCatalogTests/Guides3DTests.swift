import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct Guides3DTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the screen opens, when nothing is changed, then acidity has a range and the mark is a rule")
    func opensOnRule() {
        let model = Guides3DViewModel()
        #expect(model.orderedRanges == [.acidity])
        #expect(model.markKind == .rule)
        #expect(model.headline(locale: english) == "One range makes a rule: a line along acidity, at body 5 and sweetness 5.")
    }

    @Test("Given one range, when it is removed, then the mark is a point and the change is announced")
    func noRangeMakesPoint() {
        let model = Guides3DViewModel()
        let message = model.setRange(.acidity, false, locale: english)
        #expect(model.markKind == .point)
        #expect(model.headline(locale: english) == "No range makes a point: one mark at acidity 5, body 5, and sweetness 5.")
        #expect(message == "Range on acidity removed. No range makes a point: one mark at acidity 5, body 5, and sweetness 5.")
    }

    @Test("Given a range on acidity, when sweetness gets one, then the mark is a plane at body 5")
    func twoRangesMakeRectangle() {
        let model = Guides3DViewModel()
        let message = model.setRange(.sweetness, true, locale: english)
        #expect(model.markKind == .rectangle)
        #expect(model.headline(locale: english) == "Two ranges make a rectangle: a plane across acidity and sweetness, at body 5.")
        #expect(message?.hasPrefix("Range on sweetness added. Two ranges make a rectangle") == true)
    }

    @Test("Given two ranges, when a third is asked for, then nothing changes and the third switch is disabled")
    func noThirdRange() {
        let model = Guides3DViewModel()
        model.setRange(.body, true, locale: english)
        #expect(model.canToggle(.sweetness) == false)
        #expect(model.canToggle(.acidity))
        let message = model.setRange(.sweetness, true, locale: english)
        #expect(message == nil)
        #expect(model.orderedRanges == [.acidity, .body])
    }

    @Test("Given the same setting again, when it is set, then nothing is announced")
    func unchangedSettingIsSilent() {
        let model = Guides3DViewModel()
        #expect(model.setRange(.acidity, true, locale: english) == nil)
    }

    @Test("Given each of the seven choices, when the ranges change, then the chart identity changes with them")
    func identityFollowsRanges() {
        let model = Guides3DViewModel()
        var identities: Set<String> = []
        let choices: [[Guides3DAxis]] = [[], [.acidity], [.body], [.sweetness], [.acidity, .body], [.acidity, .sweetness], [.body, .sweetness]]
        for choice in choices {
            for axis in Guides3DAxis.allCases {
                model.setRange(axis, false, locale: english)
            }
            for axis in choice {
                model.setRange(axis, true, locale: english)
            }
            #expect(model.orderedRanges == choice)
            identities.insert(model.chartIdentity)
        }
        #expect(identities.count == choices.count)
    }

    @Test("Given a rectangle across body and sweetness, when the guide is described, then x comes first and the ranges are written out")
    func guideText() {
        let model = Guides3DViewModel()
        model.setRange(.acidity, false, locale: english)
        model.setRange(.body, true, locale: english)
        model.setRange(.sweetness, true, locale: english)
        #expect(model.guideLabel == "Reference plane across body and sweetness")
        #expect(model.guideValue(locale: english) == "Acidity 5, Body 2.5 to 7.5, Sweetness 2.5 to 7.5, as drawn from ranges of 0 to 10")
        #expect(model.audioGraphTitle == "Bean tasting scores with a reference rectangle")
    }

    @Test("Given the bean samples, when they are described, then the count and each score's span are given")
    func samplesText() {
        let model = Guides3DViewModel()
        let value = model.samplesValue(locale: english)
        #expect(value.hasPrefix("60 samples: acidity "))
        #expect(value.contains("body "))
        #expect(value.contains("sweetness "))
    }

    @Test("Given one sample or none, when they are described, then the count agrees in number")
    func samplesAgreeInNumber() throws {
        let one = try #require(CafeData.beanTastings.first)
        #expect(Guides3DViewModel(beans: [one]).samplesValue(locale: english).hasPrefix("1 sample:"))
        #expect(Guides3DViewModel(beans: []).samplesValue(locale: english) == "No samples.")
    }

    @Test("Given a German locale, when the headline is written, then its numbers take that locale")
    func headlineTakesLocale() {
        let model = Guides3DViewModel()
        model.setRange(.acidity, false, locale: english)
        #expect(model.guideValue(locale: Locale(identifier: "de_DE")) == "Acidity 5, Body 5, Sweetness 5")
        #expect(Guides3DViewModel.number(2.5, locale: Locale(identifier: "de_DE")) == "2,5")
    }

    @Test("Given the descriptor, when it is made, then it has three numeric axes from 0 to 10 and one series of every sample")
    func descriptor() throws {
        let model = Guides3DViewModel()
        let descriptor = Guides3DChartDescriptor(
            beans: model.beans, title: model.audioGraphTitle,
            summary: model.audioGraphSummary(locale: english), locale: english
        ).makeChartDescriptor()
        #expect(descriptor.title == "Bean tasting scores with a reference rule")
        #expect(descriptor.summary?.hasPrefix("One range makes a rule") == true)
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.title == "Acidity")
        #expect(xAxis.range == 0 ... 10)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Body")
        #expect(yAxis.valueDescriptionProvider(5.5) == "5.5 out of 10")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.additionalAxes.count == 1)
        #expect(descriptor.additionalAxes.first?.title == "Sweetness")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == "Bean samples")
        #expect(descriptor.series.first?.dataPoints.count == 60)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    @Test("Given each mark kind, when the snippets are listed, then every one exists and the mark's own is shown")
    func snippets() throws {
        let store = try SnippetStore()
        let expected: [Guides3DMarkKind: String] = [
            .point: "rules-and-rectangles-in-3d-point",
            .rule: "rules-and-rectangles-in-3d-rule",
            .rectangle: "rules-and-rectangles-in-3d-rectangle",
        ]
        for (kind, name) in expected {
            let references = Guides3DSnippets.references(for: kind)
            #expect(references.map(\.name).contains(name))
            for reference in references {
                #expect(store[reference.name] != nil, "missing \(reference.name)")
            }
        }
    }

    @Test("Given a rule along acidity, when it is described, then it spans the whole scale")
    func ruleValue() {
        let model = Guides3DViewModel()
        #expect(model.guideLabel == "Reference rule along acidity")
        #expect(model.guideValue(locale: english) == "Acidity 0 to 10, Body 5, Sweetness 5")
    }

    @Test("Given a rule along sweetness, when the front preset is chosen, then the headline says it draws nothing and it is announced")
    func ruleEndOnFromFront() {
        let model = Guides3DViewModel()
        model.setRange(.acidity, false, locale: english)
        model.setRange(.sweetness, true, locale: english)
        let message = model.setViewAngle(.front, locale: english)
        #expect(model.isGuideHidden)
        #expect(model.headline(locale: english) == "One range makes a rule: a line along sweetness, at acidity 5 and body 5. Seen end-on from the front, it draws nothing.")
        #expect(message == "Viewed from the front. " + model.headline(locale: english))
    }

    @Test("Given a rectangle across acidity and body, when the side and top presets are chosen, then it is edge-on from both")
    func rectangleEdgeOn() {
        let model = Guides3DViewModel()
        model.setRange(.body, true, locale: english)
        model.setViewAngle(.side, locale: english)
        #expect(model.isGuideHidden)
        #expect(model.headline(locale: english).hasSuffix("Seen edge-on from the side, it draws nothing."))
        model.setViewAngle(.top, locale: english)
        #expect(model.isGuideHidden)
        model.setViewAngle(.front, locale: english)
        #expect(model.isGuideHidden == false)
    }

    @Test("Given a preset that leaves the headline as it was, when it is chosen, then nothing is announced")
    func quietAngleChange() {
        let model = Guides3DViewModel()
        #expect(model.setViewAngle(.front, locale: english) == nil)
        #expect(model.viewAngle == .front)
    }

    @Test("Given a hidden guide, when a drag turns the chart off the preset, then no angle is named and the guide counts as shown")
    func dragClearsPreset() {
        let model = Guides3DViewModel()
        model.setViewAngle(.side, locale: english)
        #expect(model.isGuideHidden)
        let hiddenIdentity = model.chartIdentity
        model.turn(azimuth: 70, inclination: 10)
        #expect(model.viewAngle == nil)
        #expect(model.isGuideHidden == false)
        #expect(model.chartIdentity != hiddenIdentity)
        // The dragged angle is kept, so the chart's new identity does not turn it back.
        #expect(model.azimuthDegrees == 70)
        #expect(model.inclinationDegrees == 10)
    }

    @Test("Given a preset, when the chart writes back an angle within a degree of it, then the preset is kept")
    func roundingIsNotADrag() {
        let model = Guides3DViewModel()
        model.setViewAngle(.top, locale: english)
        #expect(model.azimuthDegrees == 0)
        #expect(model.inclinationDegrees == 89.9)
        model.turn(azimuth: 0.2, inclination: 89.6)
        #expect(model.viewAngle == .top)
    }

    @Test("Given a drag, when a preset is chosen, then the chart takes the preset's angles")
    func presetAfterDrag() {
        let model = Guides3DViewModel()
        model.turn(azimuth: 12, inclination: 40)
        model.setViewAngle(.side, locale: english)
        #expect(model.viewAngle == .side)
        #expect(model.azimuthDegrees == 90)
        #expect(model.inclinationDegrees == 0)
    }

    @Test("Given a point, when any preset is chosen, then it is never hidden")
    func pointAlwaysShown() {
        let model = Guides3DViewModel()
        model.setRange(.acidity, false, locale: english)
        for angle in Guides3DViewAngle.allCases {
            model.setViewAngle(angle, locale: english)
            #expect(model.isGuideHidden == false)
        }
    }

    @Test("Given a rectangle, when the explanation is written, then it says how much of its ranges is drawn")
    func explanationFollowsMark() {
        let model = Guides3DViewModel()
        #expect(model.explanation.contains("2.5 to 7.5") == false)
        #expect(model.explanation.contains("hairline"))
        model.setRange(.sweetness, true, locale: english)
        #expect(model.explanation.contains("given 0 to 10 it covers 2.5 to 7.5 on each axis"))
        #expect(model.explanation.contains("hairline") == false)
    }
}
