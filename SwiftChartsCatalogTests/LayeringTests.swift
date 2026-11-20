import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct LayeringTests {
    private let english = Locale(identifier: "en_US")

    private func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    @Test("Given the sample week, when the screen opens, then both zIndexes are 0 and Harbour is in front")
    func defaultOrder() {
        let model = LayeringViewModel()
        let summary = model.summary(locale: english)
        #expect(model.stationLayer == 0)
        #expect(model.harbour.count == 7)
        #expect(model.station.count == 7)
        #expect(!summary.stationIsInFront)
        #expect(summary.hiddenDays.isEmpty)
        #expect(summary.headline == "Both at zIndex 0, so the written order puts Harbour in front on all 7 days.")
    }

    @Test("Given the sample week, when Station's zIndex is 1, then Harbour is hidden on the five weekdays")
    func stationInFront() {
        let model = LayeringViewModel()
        model.stationLayer = 1
        let summary = model.summary(locale: english)
        #expect(summary.stationIsInFront)
        #expect(summary.hiddenDays.count == 5)
        #expect(summary.headline == "Station is in front: Harbour's bar is hidden on 5 of 7 days.")
        #expect(summary.layerText == "1")
    }

    @Test("Given the sample week, when Station's zIndex is -1, then Harbour stays in front")
    func stationBehind() {
        let model = LayeringViewModel()
        model.stationLayer = -1
        let summary = model.summary(locale: english)
        #expect(!summary.stationIsInFront)
        #expect(summary.headline == "Station's lower zIndex keeps Harbour in front on all 7 days.")
        #expect(summary.layerText == "-1")
    }

    @Test("Given Harbour taller every day, when Station is in front, then the headline says none are hidden")
    func noneHidden() {
        let summary = LayeringSummary(harbour: days([200, 210]), station: days([100, 110]), stationLayer: 1, locale: english)
        #expect(summary.hiddenDays.isEmpty)
        #expect(summary.headline == "Station is in front, and Harbour rises above it on all 2 days.")
    }

    @Test("Given equal cups, when Station is in front, then Harbour's bar counts as hidden")
    func equalHeightIsHidden() {
        let summary = LayeringSummary(harbour: days([120]), station: days([120]), stationLayer: 1, locale: english)
        #expect(summary.hiddenDays.count == 1)
        #expect(summary.headline == "Station is in front: Harbour's bar is hidden on 1 of 1 day.")
    }

    @Test("Given no cups, when the summary is read, then it is empty and says so")
    func emptyAndZero() {
        let empty = LayeringSummary(harbour: [], station: [], stationLayer: 1, locale: english)
        let zeros = LayeringSummary(harbour: days([0, 0]), station: days([0, 0]), stationLayer: 1, locale: english)
        #expect(empty.isEmpty)
        #expect(zeros.isEmpty)
        #expect(zeros.hiddenDays.isEmpty)
        #expect(empty.headline == "No cups sold in the first week.")
        #expect(zeros.audioGraphSummary == "No cups sold in the first week.")
    }

    @Test("Given each order, when Harbour's element is read, then its value says what is drawn")
    func elementText() {
        let harbour = days([100, 300])
        let station = days([200, 200])
        let front = LayeringSummary(harbour: harbour, station: station, stationLayer: 1, locale: english)
        let back = LayeringSummary(harbour: harbour, station: station, stationLayer: 0, locale: english)
        #expect(front.label(harbour[0], store: CafeWording.harbour) == "Sunday, March 1, Harbour")
        #expect(front.harbourValue(harbour[0]) == "100 cups, hidden behind Station's bar")
        #expect(front.harbourValue(harbour[1]) == "300 cups, shows above Station's bar")
        #expect(back.harbourValue(harbour[0]) == "100 cups")
        #expect(back.stationValue(station[0]) == "200 cups")
    }

    @Test("Given Station in front, when the slider is spoken, then it gives the setting and then the headline")
    func spokenSlider() {
        let model = LayeringViewModel()
        model.stationLayer = 1
        #expect(model.summary(locale: english).spokenSliderValue
            == "1. Station is in front: Harbour's bar is hidden on 5 of 7 days.")
    }

    @Test("Given a German locale, when the element label is written, then the day is in German")
    func localeIsPassed() {
        let summary = LayeringSummary(harbour: days([1]), station: days([1]), stationLayer: 0, locale: Locale(identifier: "de_DE"))
        #expect(summary.dayName(CafeData.day(0)) == "Sonntag, 1. März")
    }

    @Test("Given the sample week, when the descriptor is made, then it has both cafés, the days and cups")
    func descriptor() throws {
        let model = LayeringViewModel()
        model.stationLayer = 1
        let descriptor = LayeringChartDescriptor(summary: model.summary(locale: english)).makeChartDescriptor()
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 7 && !$0.isContinuous })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range.lowerBound == 0)
        // The drawn axis: the busiest day rounded up to the axis step, 219 to 300.
        #expect(yAxis.range.upperBound == 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        let summary = try #require(descriptor.summary)
        #expect(summary.contains("Station's zIndex is 1, Harbour's is 0. Station is in front:"))
        #expect(!summary.contains("drawn in front of"))
        #expect(summary.contains("hidden on 5 of 7 days"))
    }

    @Test("Given the built app, when snippets are read, then the screen's snippet exists")
    func snippetExists() throws {
        let store = try SnippetStore()
        let snippet = try #require(store["layering-zindex"])
        #expect(snippet.code.contains(".zIndex(stationLayer)"))
    }
}
