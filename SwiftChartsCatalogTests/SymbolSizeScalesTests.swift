import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct SymbolSizeScalesTests {
    private let english = Locale(identifier: "en_US")

    // MARK: Data and categories

    @Test("Given the sample weekdays, when each gets its part of the week, then only Saturday and Sunday are the weekend")
    func dayTypes() {
        let weekend = CafeData.weekdays.filter { SymbolSizeScalesDayType(weekday: $0) == .weekend }
        #expect(weekend == ["Sat", "Sun"])
        #expect(SymbolSizeScalesDayType(weekday: "Mon") == .weekday)
    }

    // MARK: Headline

    @Test("Given the sample data, where 80 and 79 orders are drawn the same size, when the headline is written, then it names both slots and claims no one largest")
    func headlineForSampleData() {
        let summary = SymbolSizeScalesSummary(slots: CafeData.hourlyOrders, locale: english)

        #expect(summary.mostOrders == 80)
        #expect(summary.headline
            == "Tuesday at 8 am and Thursday at 8 am took the most orders, within a few of each other: 79 to 80 orders.")
    }

    @Test("Given one slot clearly ahead, when the headline is written, then it names it as drawn largest")
    func headlineForClearLeader() {
        let slots = [
            HourlyOrders(weekday: "Mon", slot: "8 am", orders: 80),
            HourlyOrders(weekday: "Tue", slot: "8 am", orders: 70),
        ]
        #expect(SymbolSizeScalesSummary(slots: slots, locale: english).headline == "Most orders: 80 orders, Monday at 8 am, drawn largest.")
    }

    @Test("Given two slots tied for the most orders, when the headline is written, then it names both")
    func headlineOnTie() {
        let slots = [
            HourlyOrders(weekday: "Mon", slot: "8 am", orders: 40),
            HourlyOrders(weekday: "Sat", slot: "12 pm", orders: 40),
            HourlyOrders(weekday: "Sun", slot: "6 am", orders: 1),
        ]
        let summary = SymbolSizeScalesSummary(slots: slots, locale: english)

        #expect(summary.headline == "Most orders: 40 orders, Monday at 8 am and Saturday at 12 pm, drawn largest.")
    }

    @Test("Given one order at most, when the headline is written, then the count agrees in number")
    func headlineAgreesInNumber() {
        let slots = [HourlyOrders(weekday: "Mon", slot: "6 am", orders: 1)]

        #expect(SymbolSizeScalesSummary(slots: slots, locale: english).headline == "Most orders: 1 order, Monday at 6 am, drawn largest.")
    }

    @Test("Given no data, when the headline is written, then it says no orders were taken")
    func headlineWithNoData() {
        #expect(SymbolSizeScalesSummary(slots: [], locale: english).headline == "No orders taken yet.")
    }

    @Test("Given every slot at zero, when the headline is written, then it names no busiest slot")
    func headlineWithZeros() {
        let slots = [
            HourlyOrders(weekday: "Mon", slot: "6 am", orders: 0),
            HourlyOrders(weekday: "Tue", slot: "6 am", orders: 0),
        ]
        let summary = SymbolSizeScalesSummary(slots: slots, locale: english)

        #expect(summary.busiest.isEmpty)
        #expect(summary.headline == "No orders in any slot, so every symbol is the same size.")
    }

    @Test("Given a German locale, when the headline is written, then the count is written in it")
    func headlineTakesLocale() {
        let slots = [HourlyOrders(weekday: "Mon", slot: "6 am", orders: 1200)]

        #expect(SymbolSizeScalesSummary(slots: slots, locale: Locale(identifier: "de_DE")).headline.contains("1.200 orders"))
    }

    // MARK: View model

    @Test("Given a new screen, when it opens, then it shows a diamond weekend and a set range of 16 to 300")
    func defaults() {
        let model = SymbolSizeScalesViewModel()

        #expect(model.weekendShape == .diamond)
        #expect(model.sizeRange == 16 ... 300)
    }

    @Test("Given the mistake, when it is on, then no range is passed and the default-range snippet is shown")
    func defaultRangeMistake() {
        let model = SymbolSizeScalesViewModel()
        model.usesDefaultRange = true

        #expect(model.sizeRange == nil)
        #expect(model.snippets.map(\.name) == [
            "symbol-size-scales-marks", "symbol-size-scales-default-range", "symbol-size-scales-shapes",
        ])
    }

    @Test("Given a set range, when the snippets are listed, then they show the marks, both scales and the shapes")
    func setRangeSnippets() {
        let model = SymbolSizeScalesViewModel()

        #expect(model.snippets.map(\.name) == [
            "symbol-size-scales-marks", "symbol-size-scales-scales", "symbol-size-scales-shapes",
        ])
    }

    @Test("Given moved sliders, when the range is read, then it runs from the smallest to the largest area")
    func slidersSetRange() {
        let model = SymbolSizeScalesViewModel()
        model.smallestArea = 40
        model.largestArea = 800

        #expect(model.sizeRange == 40 ... 800)
        #expect(model.smallestAreaText(locale: english) == "40 pt²")
        #expect(model.largestAreaSpoken(locale: english) == "800 square points")
    }

    @Test("Given the slider bounds, when they are compared, then the smallest area can never pass the largest")
    func sliderBoundsDoNotCross() {
        #expect(SymbolSizeScalesViewModel.smallestAreaRange.upperBound < SymbolSizeScalesViewModel.largestAreaRange.lowerBound)
    }

    @Test("Given every snippet the screen can show, when the bundle is read, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let model = SymbolSizeScalesViewModel()
        var names = model.snippets.map(\.name)
        model.usesDefaultRange = true
        names += model.snippets.map(\.name)

        for name in Set(names) {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    // MARK: Announcements

    @Test("Given a new weekend shape, when it is announced, then the message names the shape, then the headline")
    func shapeAnnouncement() {
        let model = SymbolSizeScalesViewModel()
        model.weekendShape = .outline

        #expect(model.shapeAnnouncement(headline: "Headline.") == "Weekend now drawn as outlined circles. Headline.")
    }

    @Test("Given the range switched, when it is announced, then the message says which range, then the headline")
    func rangeAnnouncement() {
        let model = SymbolSizeScalesViewModel()
        #expect(model.rangeAnnouncement(headline: "Headline.", locale: english)
            == "Symbol areas from 16 square points to 300 square points. Headline.")

        model.usesDefaultRange = true
        #expect(model.rangeAnnouncement(headline: "Headline.", locale: english) == "Size range left at the default. Headline.")
    }

    // MARK: Chart descriptor

    @Test("Given the sample data, when the descriptor is made, then it has one series per weekday over six times of day")
    func descriptorShape() throws {
        let descriptor = SymbolSizeScalesDescriptor(
            slots: CafeData.hourlyOrders, weekendShape: .diamond, sizeRange: 16 ... 300, locale: english
        ).makeChartDescriptor()

        #expect(descriptor.title == "Orders by weekday and time of day")
        #expect(descriptor.series.map(\.name) == ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 6 && !$0.isContinuous })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == CafeData.slots)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 80)
        #expect(yAxis.valueDescriptionProvider(1) == "1 order")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given each range setting, when the descriptor's summary is read, then it describes what is drawn")
    func descriptorSummary() {
        let set = SymbolSizeScalesDescriptor(
            slots: CafeData.hourlyOrders, weekendShape: .triangle, sizeRange: 16 ... 300, locale: english
        ).makeChartDescriptor()
        let mistake = SymbolSizeScalesDescriptor(
            slots: CafeData.hourlyOrders, weekendShape: .triangle, sizeRange: nil, locale: english
        ).makeChartDescriptor()

        #expect(set.summary?.contains("Most orders: 80 orders, Tuesday at 8 am.") == true)
        #expect(set.summary?.contains("the weekend as triangles") == true)
        #expect(set.summary?.contains("from 16 square points for zero orders to 300 square points for the most.") == true)
        #expect(mistake.summary?.contains("default range") == true)
    }

    @Test("Given one slot, when the Audio Graph summary is written, then the slot count agrees in number")
    func oneSlotAgrees() {
        let summary = SymbolSizeScalesSummary(slots: [HourlyOrders(weekday: "Mon", slot: "6 am", orders: 3)], locale: english)

        #expect(summary.audioGraphSummary(weekendShape: .square, sizeRange: 16 ... 300).hasPrefix("1 slot. Most orders: 3 orders"))
        #expect(SymbolSizeScalesWording.slots(42, locale: english) == "42 slots")
    }

    @Test("Given no data, when the descriptor's summary is read, then it says no orders were taken")
    func descriptorWithNoData() {
        let descriptor = SymbolSizeScalesDescriptor(slots: [], weekendShape: .square, sizeRange: 16 ... 300, locale: english)
            .makeChartDescriptor()

        #expect(descriptor.summary == "No orders taken yet.")
        #expect(descriptor.series.isEmpty)
    }
}
