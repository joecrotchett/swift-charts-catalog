import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct ColourRampsTests {
    private let english = Locale(identifier: "en_US")

    private func summary(_ ramp: ColourRampsRamp, _ changes: [DrinkChange] = CafeData.drinkChanges) -> ColourRampsSummary {
        ColourRampsSummary(changes: changes, ramp: ramp, locale: english)
    }

    @Test("Given a new view model, when it is created, then it shows the default ramp over the café's changes")
    func startsOnDefault() {
        let viewModel = ColourRampsViewModel()

        #expect(viewModel.ramp == .automatic)
        #expect(viewModel.changes == CafeData.drinkChanges)
    }

    @Test("Given each ramp, when the snippets are listed, then the encoding comes first and the ramp's scale follows")
    func snippetsFollowRamp() {
        #expect(ColourRampsViewModel.snippets(for: .automatic).map(\.name) == ["colour-ramps-encode"])
        #expect(ColourRampsViewModel.snippets(for: .custom).map(\.name)
            == ["colour-ramps-encode", "colour-ramps-custom-gradient"])
        #expect(ColourRampsViewModel.snippets(for: .diverging).map(\.name)
            == ["colour-ramps-encode", "colour-ramps-diverging"])
    }

    @Test("Given the built app, when its snippets are read, then every snippet the screen can show exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = ColourRampsRamp.allCases.flatMap { ColourRampsViewModel.snippets(for: $0) }.map(\.name)

        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
        #expect(store["colour-ramps-diverging"]?.code.contains("domain: -limit ... limit") == true)
    }

    @Test("Given the café's changes and the default ramp, when the headline is written, then it names the deepest and the palest bar")
    func defaultHeadline() {
        #expect(summary(.automatic).headline
            == "The higher the change, the deeper the blue: Latte, up 212 cups, is the deepest, and Cocoa, down 305 cups, the palest.")
    }

    @Test("Given the custom ramp, when the headline is written, then it says which drink is yellow and which red")
    func customHeadline() {
        #expect(summary(.custom).headline == "Cocoa, down 305 cups, is the most yellow; Latte, up 212 cups, the most red.")
    }

    @Test("Given the diverging ramp, when the headline is written, then it counts the drinks on each side of zero")
    func divergingHeadline() {
        #expect(summary(.diverging).headline
            == "3 drinks sold more than last month, on the blue side, and 3 drinks sold fewer, on the orange side.")
    }

    @Test("Given only rises, when the diverging headline is written, then it does not mention orange bars")
    func divergingOnlyRises() {
        let changes = [DrinkChange(drink: "Tea", change: 1), DrinkChange(drink: "Mocha", change: 0)]

        #expect(summary(.diverging, changes).headline
            == "1 drink sold more than last month, on the blue side; zero is the gray middle of the ramp.")
    }

    @Test("Given only falls, when the diverging headline is written, then it does not mention blue bars")
    func divergingOnlyFalls() {
        let changes = [DrinkChange(drink: "Tea", change: -4), DrinkChange(drink: "Mocha", change: -9)]

        #expect(summary(.diverging, changes).headline
            == "2 drinks sold fewer than last month, on the orange side; zero is the gray middle of the ramp.")
    }

    @Test("Given a change of zero, when the headline is written, then that drink is left out: it draws no bar")
    func zeroBarIsNotNamed() {
        let changes = [
            DrinkChange(drink: "Tea", change: 0), DrinkChange(drink: "Mocha", change: 40), DrinkChange(drink: "Chai", change: 10),
        ]
        let words = summary(.automatic, changes)

        #expect(words.drawn.map(\.drink) == ["Mocha", "Chai"])
        #expect(words.headline
            == "The higher the change, the deeper the blue: Mocha, up 40 cups, is the deepest, and Chai, up 10 cups, the palest.")
    }

    @Test("Given two drinks tied for the highest change, when the headline is written, then it names both")
    func tieNamesBoth() {
        let changes = [
            DrinkChange(drink: "Tea", change: 50), DrinkChange(drink: "Mocha", change: 50), DrinkChange(drink: "Chai", change: -1),
        ]

        #expect(summary(.custom, changes).headline == "Chai, down 1 cup, is the most yellow; Tea and Mocha, up 50 cups, the most red.")
    }

    @Test("Given every drawn change equal, when the headline is written, then it says the bars share one colour")
    func equalChangesShareColour() {
        let changes = [DrinkChange(drink: "Tea", change: 1), DrinkChange(drink: "Mocha", change: 1)]

        #expect(summary(.automatic, changes).headline == "Every bar is the same colour: Tea and Mocha up 1 cup.")
    }

    @Test("Given no changes or only zeros, when the words are written, then they say so and the chart is empty")
    func emptyAndAllZero() {
        let empty = summary(.automatic, [])
        let zeros = summary(.diverging, [DrinkChange(drink: "Tea", change: 0)])

        #expect(empty.isEmpty)
        #expect(empty.headline == "No changes against last month to show.")
        #expect(empty.audioGraphSummary == empty.headline)
        #expect(zeros.isEmpty)
        #expect(zeros.headline == "Every drink sold the same as last month.")
        #expect(zeros.audioGraphSummary == zeros.headline)
        #expect(zeros.divergingLimit == 1)
    }

    @Test("Given the café's changes, when the diverging domain is worked out, then it is the largest change either way")
    func divergingLimit() {
        #expect(summary(.diverging).divergingLimit == 305)
    }

    @Test("Given changes, when they are said in words, then they give direction and agree in number")
    func movementWords() {
        #expect(ColourRampsSummary.movement(212, locale: english) == "up 212 cups")
        #expect(ColourRampsSummary.movement(-1, locale: english) == "down 1 cup")
        #expect(ColourRampsSummary.movement(0, locale: english) == "no change")
        #expect(ColourRampsSummary.movement(1200, locale: english) == "up 1,200 cups")
        #expect(ColourRampsSummary.movement(1200, locale: Locale(identifier: "de_DE")) == "up 1.200 cups")
    }

    @Test("Given a ramp change, when the announcement is written, then it names the ramp and then the headline")
    func announcement() {
        let viewModel = ColourRampsViewModel()
        viewModel.ramp = .diverging

        #expect(viewModel.announcement(locale: english)
            == "Colour ramp: Diverging. 3 drinks sold more than last month, on the blue side, and 3 drinks sold fewer, on the orange side.")
    }

    @Test("Given each ramp, when the Audio Graph summary is written, then it gives the values and the ramp drawn")
    func audioGraphSummary() {
        let expected = "6 drinks: 3 sold more than last month, 3 fewer. Highest Latte, up 212 cups; "
            + "lowest Cocoa, down 305 cups. Colour repeats each change, on "

        #expect(summary(.automatic).audioGraphSummary == expected + "the default ramp, shades of one blue.")
        #expect(summary(.diverging).audioGraphSummary.hasSuffix("orange for fewer cups, gray at no change, blue for more."))
        #expect(summary(.custom).audioGraphSummary == expected + "a ramp from yellow to red: the lower the change, the more yellow.")
        #expect(summary(.automatic, [DrinkChange(drink: "Tea", change: 1200), DrinkChange(drink: "Chai", change: -3)])
            .audioGraphSummary.hasPrefix("2 drinks: 1 sold more than last month, 1 fewer."))
    }

    @Test("Given the café's changes, when the descriptor is made, then its axes, series and values match the bars")
    func descriptor() throws {
        let descriptor = ColourRampsChartDescriptor(summary: summary(.custom)).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Change in cups against last month, by drink")
        #expect(descriptor.summary == summary(.custom).audioGraphSummary)
        #expect((descriptor.xAxis as? AXCategoricalDataAxisDescriptor)?.categoryOrder
            == ["Latte", "Tea", "Mocha", "Cocoa", "Americano", "Chai"])
        #expect(yAxis.title == "Change in cups")
        // From the fall of 305 to the rise of 212, on an axis drawn from -400 to 400.
        #expect(yAxis.range == -400 ... 400)
        #expect(yAxis.valueDescriptionProvider(-305) == "down 305 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Change in cups"])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 6)
    }

    @Test("Given only rises, when the descriptor's range is worked out, then it still starts at zero, as the bars do")
    func rangeIncludesZero() {
        #expect(summary(.automatic, [DrinkChange(drink: "Tea", change: 30)]).valueRange == 0 ... 30)
    }

    @Test("Given Dark Mode and the default ramp, when the headline is written, then the highest change is the brightest bar and the lowest the darkest")
    func darkHeadline() {
        let words = ColourRampsViewModel().summary(locale: Locale(identifier: "en_US"), isDark: true)
        #expect(words.headline
            == "The higher the change, the brighter the blue: Latte, up 212 cups, is the brightest, and Cocoa, down 305 cups, the darkest.")
    }

    @Test("Given Dark Mode, when the other ramps' headlines are written, then they are the same as in light")
    func darkLeavesOtherRampsAlone() {
        for ramp in [ColourRampsRamp.custom, .diverging] {
            let model = ColourRampsViewModel()
            model.ramp = ramp
            #expect(model.summary(locale: Locale(identifier: "en_US"), isDark: true).headline
                == model.summary(locale: Locale(identifier: "en_US")).headline)
        }
    }
}
