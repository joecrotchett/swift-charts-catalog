import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ColourWeightTests {
    private let english = Locale(identifier: "en_US")

    private func store(_ name: String, _ cups: [Int]) -> StoreSales {
        StoreSales(store: name, days: cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) })
    }

    @Test("Given the screen opens, when nothing is changed, then the colours are of equal weight")
    func startsEqual() {
        let model = ColourWeightViewModel()
        #expect(model.isShowingUnequalWeight == false)
        #expect(model.palette == .equal)
        #expect(model.palette.colourName(for: CafeWording.harbour) == "blue")
        #expect(model.palette.colourName(for: CafeWording.station) == "orange")
    }

    @Test("Given the mistake toggle, when it is turned on, then navy and bright orange are drawn")
    func mistakePalette() {
        let model = ColourWeightViewModel()
        model.isShowingUnequalWeight = true
        #expect(model.palette == .unequal)
        #expect(model.palette.colourName(for: CafeWording.harbour) == "navy")
        #expect(model.palette.colourName(for: CafeWording.station) == "bright orange")
    }

    @Test("Given the sample data, when the headline is written, then it names the last day's figures")
    func headline() {
        let model = ColourWeightViewModel()
        #expect(model.headline(locale: english) == "On Saturday, March 28, Harbour sold more: 282 cups to Station’s 193.")
    }

    @Test("Given either toggle setting, when the headline is written, then it is the same")
    func headlineIgnoresColour() {
        let model = ColourWeightViewModel()
        let equal = model.headline(locale: english)
        model.isShowingUnequalWeight = true
        #expect(model.headline(locale: english) == equal)
    }

    @Test("Given a tie on the last day, when the headline is written, then both cafés sold the same")
    func headlineTie() {
        let model = ColourWeightViewModel(stores: [store(CafeWording.harbour, [5, 1]), store(CafeWording.station, [4, 1])])
        #expect(model.headline(locale: english) == "On Monday, March 2, Harbour and Station each sold 1 cup.")
    }

    @Test("Given no days, when the screen draws, then there is no data and the headline says so")
    func empty() {
        let model = ColourWeightViewModel(stores: [])
        #expect(model.hasData == false)
        #expect(model.headline(locale: english) == "No cups sold yet.")
    }

    @Test("Given only zeros, when the screen draws, then the lines are a chart and the headline is true")
    func zeros() {
        let model = ColourWeightViewModel(stores: [store(CafeWording.harbour, [0, 0]), store(CafeWording.station, [0, 0])])
        #expect(model.hasData)
        #expect(model.cupsAxis == 0 ... 50)
        #expect(model.headline(locale: english) == "On Monday, March 2, Harbour and Station each sold 0 cups.")
    }

    @Test("Given the sample data, when the axis is worked out, then it runs from 150 to 300 cups")
    func axis() {
        #expect(ColourWeightViewModel().cupsAxis == 150 ... 300)
    }

    @Test("Given the sample data, when the date axis is labelled, then it marks 1, 8, 15 and 22 March")
    func labelledDays() {
        #expect(ColourWeightViewModel().labelledDays == [0, 7, 14, 21].map(CafeData.day))
    }

    @Test("Given the sample data, when the days are built, then each holds both cafés and only the last is marked")
    func days() throws {
        let days = ColourWeightViewModel().days
        #expect(days.count == 28)
        #expect(days.filter(\.isLast).count == 1)
        let first = try #require(days.first)
        #expect(first.readings.map(\.store) == [CafeWording.harbour, CafeWording.station])
        #expect(first.readings.map(\.cups) == [190, 155])
    }

    @Test("Given the first day, when its element is written, then it gives the day and each café's cups")
    func element() throws {
        let model = ColourWeightViewModel()
        let first = try #require(model.days.first)
        #expect(model.dayName(first.date, locale: english) == "Sunday, March 1")
        #expect(model.dayValue(first, locale: english) == "Harbour, 190 cups; Station, 155 cups")
    }

    @Test("Given each setting, when the legend is read, then it names the colour and symbol drawn")
    func legend() {
        let model = ColourWeightViewModel()
        #expect(model.legendLabel(for: CafeWording.harbour) == "Harbour: blue line with circles")
        model.isShowingUnequalWeight = true
        #expect(model.legendLabel(for: CafeWording.station) == "Station: bright orange line with squares")
    }

    @Test("Given the shared café styles, when the symbols are named, then the names follow CafeSeriesStyle's shapes")
    func symbolNames() {
        #expect(ColourWeightSymbolName.plural(for: CafeWording.harbour) == "circles")
        #expect(ColourWeightSymbolName.plural(for: CafeWording.station) == "squares")
    }

    @Test("Given the last day, when its labels are placed, then only the lower café's goes below its point")
    func labelPlacement() throws {
        let last = try #require(ColourWeightViewModel().days.last)
        let harbour = try #require(last.readings.first { $0.store == CafeWording.harbour })
        let station = try #require(last.readings.first { $0.store == CafeWording.station })
        #expect(!last.isLowest(harbour))
        #expect(last.isLowest(station))
        let tie = ColourWeightDay(date: last.date, end: last.end, readings: [harbour, ColourWeightReading(store: CafeWording.station, cups: harbour.cups)], isLast: true)
        #expect(tie.readings.allSatisfy { !tie.isLowest($0) })
    }

    @Test("Given the toggle changes, when it is announced, then it says what changed and then the headline")
    func announcement() {
        let model = ColourWeightViewModel()
        model.isShowingUnequalWeight = true
        #expect(model.changeAnnouncement(locale: english)
            == "Colours of unequal weight: Harbour navy and Station bright orange. "
            + "On Saturday, March 28, Harbour sold more: 282 cups to Station’s 193.")
        model.isShowingUnequalWeight = false
        #expect(model.changeAnnouncement(locale: english).hasPrefix("Colours of equal weight: Harbour blue and Station orange."))
    }

    @Test("Given each setting, when See Code opens, then it shows the chart and the palette drawn")
    func snippetNames() {
        let model = ColourWeightViewModel()
        #expect(model.snippets.map(\.name) == ["colour-weight-and-meaning-chart", "colour-weight-and-meaning-equal"])
        model.isShowingUnequalWeight = true
        #expect(model.snippets.map(\.name) == ["colour-weight-and-meaning-chart", "colour-weight-and-meaning-unequal"])
    }

    @Test("Given the built app, when its snippets are read, then every one the screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for name in ["colour-weight-and-meaning-chart", "colour-weight-and-meaning-equal", "colour-weight-and-meaning-unequal"] {
            #expect(store[name] != nil)
        }
    }

    @Test("Given the sample data, when the descriptor is made, then it names both series over 28 written-out days")
    func descriptor() throws {
        let model = ColourWeightViewModel()
        let descriptor = ColourWeightDescriptor(
            stores: model.stores, days: model.days, cupsAxis: model.cupsAxis,
            dayNames: model.days.map { model.dayName($0.date, locale: english) }, locale: english
        ).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold each day at Harbour and Station")
        #expect(descriptor.summary == "28 days, Sunday, March 1 to Saturday, March 28. "
            + "Harbour: first day 190 cups, last day 282 cups, highest 282 cups. "
            + "Station: first day 155 cups, last day 193 cups, highest 223 cups.")
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour, CafeWording.station])
        #expect(descriptor.series.allSatisfy { $0.isContinuous && $0.dataPoints.count == 28 })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 150 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(200) == "200 cups")
    }

    @Test("Given both cafés' days, when the caption is written, then it gives the period month first, as other screens do")
    func captionMonthFirst() {
        let caption = ColourWeightViewModel().caption(locale: english)
        #expect(caption == "Cups sold each day, " + CafeWording.dayRange(CafeData.day(0), CafeData.day(27), locale: english))
        #expect(caption.contains("March 1"))
        #expect(ColourWeightViewModel(stores: []).caption(locale: english) == "Cups sold each day")
    }
}
