import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ColourMeaningTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the chain's cafés, when the model loads them, then every café has a case and keeps its data order")
    func everyCafeMaps() {
        let model = ColourMeaningViewModel(cafeCount: 10)

        #expect(model.allRows.map(\.cafe.rawValue) == CafeData.chainCafes.map(\.name))
        #expect(model.allRows.map(\.yearlyCups) == CafeData.chainCafes.map(\.yearlyCups))
        #expect(model.countRange == 2 ... 10)
    }

    @Test("Given a count, when the model draws, then it shows that many cafés from the first")
    func countPicksFirstCafes() {
        let model = ColourMeaningViewModel(cafeCount: 3)

        #expect(model.rows.map(\.cafe) == [.kiosk, .pier, .market])
    }

    @Test("Given a count outside the range, when the model is made, then the count is kept within it")
    func countIsClampedAtInit() {
        #expect(ColourMeaningViewModel(cafeCount: 40).cafeCount == 10)
        #expect(ColourMeaningViewModel(cafeCount: 0).cafeCount == 2)
    }

    @Test("Given seven cafés and automatic colours, when the headline is read, then each has a colour of its own")
    func sevenAutomaticDoNotRepeat() {
        let model = ColourMeaningViewModel(cafeCount: 7)
        let summary = model.summary(locale: english)

        #expect(summary.colourCount == 7)
        #expect(summary.repeats.isEmpty)
        #expect(summary.headline == "7 cafés, 7 colours: one each, in the order the cafés appear.")
    }

    @Test("Given eight cafés and automatic colours, when the headline is read, then it names the café that repeats a colour")
    func eighthRepeatsTheFirst() {
        let summary = ColourMeaningViewModel(cafeCount: 8).summary(locale: english)

        #expect(summary.colourCount == 7)
        #expect(summary.repeats.map(\.cafe) == [.harbour])
        #expect(summary.repeats.map(\.sharesWith) == [.kiosk])
        #expect(summary.headline == "8 cafés but only 7 colours, so they repeat: Harbour has Kiosk’s.")
    }

    @Test("Given ten cafés and automatic colours, when the headline is read, then all three repeats are named")
    func tenAutomaticRepeatThree() {
        let summary = ColourMeaningViewModel(cafeCount: 10).summary(locale: english)

        #expect(summary.headline
            == "10 cafés but only 7 colours, so they repeat: Harbour has Kiosk’s, Airport has Pier’s, and Central has Market’s.")
    }

    @Test("Given ten cafés and explicit colours, when the headline is read, then there are ten colours and no repeats")
    func tenExplicitAllDifferent() {
        let model = ColourMeaningViewModel(cafeCount: 10)
        model.colours = .explicit
        let summary = model.summary(locale: english)

        #expect(summary.colourCount == 10)
        #expect(summary.repeats.isEmpty)
        #expect(summary.headline == "10 cafés, 10 colours: each café keeps its own.")
    }

    @Test("Given every café, when the explicit colours are read, then no two cafés share one")
    func explicitColoursAreDistinct() {
        #expect(Set(ColourMeaningCafe.allCases.map(\.colour)).count == ColourMeaningCafe.allCases.count)
    }

    @Test("Given no cafés, when the headline is read, then it says there is nothing to colour")
    func emptyHeadline() {
        let model = ColourMeaningViewModel(cafes: [])

        #expect(model.rows.isEmpty)
        #expect(model.summary(locale: english).headline == "No cafés to colour.")
        #expect(model.summary(locale: english).audioGraphSummary == "No cafés to colour.")
    }

    @Test("Given one café, when the headline is read, then its counts agree in number")
    func oneCafeAgrees() {
        let model = ColourMeaningViewModel(cafes: [ChainCafe(name: "Kiosk", yearlyCups: 1, change: 0)])
        let summary = model.summary(locale: english)

        #expect(summary.headline == "1 café, 1 colour: one each, in the order the cafés appear.")
        #expect(summary.audioGraphSummary == "Kiosk, 1 cup a year. 1 café, 1 colour: one each, in the order the cafés appear.")
    }

    @Test("Given a German locale, when the headline is read, then its numbers are written the German way")
    func headlineTakesLocale() {
        let summary = ColourMeaningSummary(
            rows: [ColourMeaningRow(cafe: .central, yearlyCups: 480_000)], colours: .automatic,
            locale: Locale(identifier: "de_DE")
        )

        #expect(summary.audioGraphSummary.hasPrefix("Central, 480.000 cups a year."))
    }

    @Test("Given each setting, when the snippets are read, then they follow the colours and exist in the bundle")
    func snippetsFollowColours() throws {
        let store = try SnippetStore(bundle: .main)
        let model = ColourMeaningViewModel()

        #expect(model.snippets.map(\.name) == ["colour-meaning-automatic"])
        model.colours = .explicit
        #expect(model.snippets.map(\.name) == ["colour-meaning-automatic", "colour-meaning-explicit", "colour-meaning-colours"])
        for reference in model.snippets {
            #expect(store[reference.name] != nil)
        }
        #expect(try #require(store["colour-meaning-explicit"]).code.contains("chartForegroundStyleScale"))
        #expect(try #require(store["colour-meaning-automatic"]).code.contains("foregroundStyle(by:"))
    }

    @Test("Given a change to the cafés or the colours, when it is announced, then it says what changed and then the headline")
    func announcements() {
        let model = ColourMeaningViewModel(cafeCount: 8)

        #expect(model.countAnnouncement(locale: english)
            == "8 cafés shown. 8 cafés but only 7 colours, so they repeat: Harbour has Kiosk’s.")
        model.colours = .explicit
        #expect(model.coloursAnnouncement(locale: english) == "Explicit colours. 8 cafés, 8 colours: each café keeps its own.")
    }

    @Test("Given ten cafés, when the chart descriptor is made, then it names the axes, the cafés and the drawn log axis's decades")
    func descriptor() throws {
        let rows = ColourMeaningViewModel(cafeCount: 10).rows
        let descriptor = ColourMeaningChartDescriptor(rows: rows, colours: .automatic, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Cups a year at the chain’s cafés, coloured by café")
        #expect(descriptor.summary?.hasPrefix("From Kiosk, 120 cups a year, to Central, 480,000 cups a year.") == true)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ColourMeaningCafe.allCases.map(\.rawValue))
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.yearlyCupsAxisTitle)
        // The log axis is drawn over its decades, 100 to a million, not the data's 120 to 480,000.
        #expect(ColourMeaningAxis.decades(rows) == [100, 1000, 10000, 100_000, 1_000_000])
        #expect(yAxis.range == 100 ... 1_000_000)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.dataPoints.count == 10)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    @Test("Given a café with no cups, when the chart descriptor is made, then its range starts at zero like the linear scale")
    func descriptorRangeFromZero() throws {
        let rows = [ColourMeaningRow(cafe: .kiosk, yearlyCups: 0), ColourMeaningRow(cafe: .pier, yearlyCups: 640)]
        let descriptor = ColourMeaningChartDescriptor(rows: rows, colours: .automatic, locale: english).makeChartDescriptor()

        #expect(try #require(descriptor.yAxis).range == 0 ... 640)
    }
}
