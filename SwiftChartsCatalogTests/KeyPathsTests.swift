import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct KeyPathsTests {
    private let english = Locale(identifier: "en_US")

    private func order(_ id: Int, drink: String = "Tea", hour: Double, cups: Int, wait: Double) -> CafeOrder {
        CafeOrder(id: id, drink: drink, hour: hour, cups: cups, waitMinutes: wait)
    }

    // MARK: Points

    @Test("Given orders, when they become points, then each opacity runs from the faintest to 1 across the collection")
    func opacityScaledAcrossCollection() {
        let points = KeyPathsOrder.make(
            from: [order(0, hour: 8, cups: 1, wait: 2), order(1, hour: 9, cups: 3, wait: 6), order(2, hour: 10, cups: 2, wait: 10)]
        )

        let closeEnough = { (values: [CGFloat], expected: [CGFloat]) in
            values.count == expected.count && zip(values, expected).allSatisfy { abs($0 - $1) < 0.000_001 }
        }
        #expect(closeEnough(points.map(\.waitOpacity), [KeyPathsOrderOpacity.lowest, 0.6, 1]))
        #expect(closeEnough(points.map(\.cupsOpacity), [KeyPathsOrderOpacity.lowest, 1, 0.6]))
    }

    @Test("Given orders that all wait the same, when they become points, then every point is drawn at full opacity")
    func equalValuesFullOpacity() {
        let points = KeyPathsOrder.make(from: [order(0, hour: 8, cups: 2, wait: 4), order(1, hour: 9, cups: 2, wait: 4)])

        #expect(points.allSatisfy { $0.waitOpacity == 1 && $0.cupsOpacity == 1 })
    }

    @Test("Given an order, when it becomes a point, then it keeps its hour and its order size as a category")
    func pointFields() throws {
        let point = try #require(KeyPathsOrder.make(from: [order(0, drink: "Mocha", hour: 8.5, cups: 1, wait: 1)]).first)

        #expect(point.hour == 8.5)
        #expect(point.time == CafeData.time(8, 30))
        #expect(point.orderSize == "1 cup")
    }

    @Test("Given orders coloured by drink, when VoiceOver's stretches are made, then each gives clock times, minutes and counts by drink")
    func spokenOrders() throws {
        let orders = KeyPathsOrder.make(from: [
            order(0, drink: "Latte", hour: 6.5, cups: 1, wait: 2), order(1, drink: "Tea", hour: 7.75, cups: 2, wait: 1),
            order(2, drink: "Latte", hour: 17.9, cups: 1, wait: 4),
        ])
        let portions = KeyPathsOrdersSummary(orders: orders, locale: english).portions(colour: .drink)
        let first = try #require(portions.first)

        #expect(portions.count == 6)
        #expect(first.label(locale: english) == "6:00\u{202F}AM to 8:00\u{202F}AM")
        #expect(first.value(locale: english)
            == "2 orders, waits from 1 minute to 2 minutes, median 1.5 minutes; Latte 1, Tea 1, Mocha 0, and Espresso 0")
        #expect(portions.last?.label(locale: english) == "4:00\u{202F}PM to 6:00\u{202F}PM")
        #expect(portions[2].value(locale: english) == "No orders.")
    }

    @Test("Given a German locale, when the view's locale reaches the view model, then the spoken shifts are written in it")
    func localeReachesSpokenText() throws {
        let shifts = [Shift(id: 0, barista: "Ana", start: CafeData.time(6), end: CafeData.time(13, 30))]
        let viewModel = KeyPathsViewModel(orders: [], shifts: shifts, locale: english)
        viewModel.update(locale: Locale(identifier: "de_DE"))

        let shift = try #require(viewModel.shifts.first)
        #expect(shift.spokenValue.contains("7,5"))
        #expect(!shift.spokenValue.contains("AM"))
    }

    @Test("Given a shift, when VoiceOver's words are written, then the label is the name and the value gives start, end and length")
    func spokenShift() throws {
        let shift = try #require(KeyPathsViewModel(locale: english).shifts.first)

        #expect(shift.spokenLabel == "Ana")
        #expect(shift.spokenValue == "6:00\u{202F}AM to 12:00\u{202F}PM, 6 hours")
        #expect(shift.startHour == 6)
        #expect(shift.endHour == 12)
    }

    @Test("Given each colour choice, when the points are plotted, then they are grouped in the colour's legend order")
    func groupedByColour() {
        let viewModel = KeyPathsViewModel(orders: CafeData.manyOrders(count: 200), shifts: [], locale: english)

        for colour in KeyPathsColour.allCases {
            viewModel.colour = colour
            let indices = viewModel.orders.compactMap { colour.domain.firstIndex(of: $0[keyPath: colour.keyPath]) }
            #expect(indices.count == 200)
            #expect(indices == indices.sorted())
        }
    }

    @Test("Given the colour choices, when their domains are read, then they list the drinks and the four order sizes")
    func colourDomains() {
        #expect(KeyPathsColour.drink.domain == CafeData.manyOrderDrinks)
        #expect(KeyPathsColour.orderSize.domain == ["1 cup", "2 cups", "3 cups", "4 cups"])
    }

    // MARK: Orders headline

    @Test("Given the sample orders, when the headline is written, then it gives the longest wait as drawn and its order")
    func ordersHeadlineForSampleData() throws {
        let viewModel = KeyPathsViewModel(locale: english)
        let longest = try #require(viewModel.orders.max { $0.waitMinutes < $1.waitMinutes })
        let expectedWait = KeyPathsWording.minutes(longest.waitMinutes, locale: english)

        #expect(viewModel.orders.count == KeyPathsViewModel.orderCount)
        #expect(viewModel.headline.hasPrefix("Of 400 orders, the longest wait was \(expectedWait): "))
        #expect(viewModel.headline.contains(" of \(longest.drink) at "))
    }

    @Test("Given two orders tied for the longest wait, when the headline is written, then it says the wait is shared")
    func ordersHeadlineOnTie() {
        let summary = KeyPathsOrdersSummary(
            orders: KeyPathsOrder.make(from: [order(0, hour: 8, cups: 2, wait: 7), order(1, hour: 9, cups: 3, wait: 7)]),
            locale: english
        )

        #expect(summary.headline == "Of 2 orders, the longest wait was 7 minutes, shared by 2 orders.")
    }

    @Test("Given one order of one cup, when the headline is written, then every count agrees in number")
    func ordersHeadlineAgreesInNumber() {
        let summary = KeyPathsOrdersSummary(
            orders: KeyPathsOrder.make(from: [order(0, drink: "Tea", hour: 8, cups: 1, wait: 1)]),
            locale: english
        )

        #expect(summary.headline.hasPrefix("Of 1 order, the longest wait was 1 minute: 1 cup of Tea at 8:00"))
    }

    @Test("Given no orders, when the chart's words are written, then they say there are none and a placeholder shows")
    func noOrders() {
        let viewModel = KeyPathsViewModel(orders: [], locale: english)

        #expect(viewModel.isEmpty)
        #expect(viewModel.headline == "No orders yet today.")
        #expect(viewModel.ordersSummary.audioGraphSummary(colour: .drink) == "No orders yet today.")
    }

    // MARK: Shifts headline

    @Test("Given the sample shifts, when the headline is written, then it names Tom's seven-hour shift")
    func shiftsHeadlineForSampleData() {
        let viewModel = KeyPathsViewModel(locale: english)
        viewModel.example = .shifts

        #expect(viewModel.headline.hasPrefix("Of 5 shifts, the longest is Tom’s: 7 hours, 11:00"))
    }

    @Test("Given two shifts of the same longest length, when the headline is written, then it names both")
    func shiftsHeadlineOnTie() {
        let shifts = [
            Shift(id: 0, barista: "Ana", start: CafeData.time(6), end: CafeData.time(12)),
            Shift(id: 1, barista: "Ben", start: CafeData.time(9), end: CafeData.time(15)),
            Shift(id: 2, barista: "Tom", start: CafeData.time(15), end: CafeData.time(16)),
        ]
        let summary = KeyPathsShiftsSummary(shifts: KeyPathsShift.make(from: shifts, locale: english), locale: english)

        #expect(summary.headline == "Of 3 shifts, the longest are Ana’s and Ben’s: 6 hours each.")
    }

    @Test("Given one shift of one hour, when the headline is written, then the counts agree in number")
    func shiftsHeadlineAgreesInNumber() {
        let shifts = [Shift(id: 0, barista: "Ana", start: CafeData.time(6), end: CafeData.time(7))]
        let summary = KeyPathsShiftsSummary(shifts: KeyPathsShift.make(from: shifts, locale: english), locale: english)

        #expect(summary.headline.hasPrefix("Of 1 shift, the longest is Ana’s: 1 hour, 6:00"))
    }

    @Test("Given no shifts, when the shifts example is shown, then the headline says so and a placeholder shows")
    func noShifts() {
        let viewModel = KeyPathsViewModel(shifts: [], locale: english)
        viewModel.example = .shifts

        #expect(viewModel.isEmpty)
        #expect(viewModel.headline == "No shifts on the rota today.")
    }

    @Test("Given Mia's split shift, when the shifts are described, then her two shifts are told apart")
    func shiftCategories() {
        let summary = KeyPathsShiftsSummary(shifts: KeyPathsShift.make(from: CafeData.shifts, locale: english), locale: english)

        #expect(summary.categories == ["Ana", "Ben", "Mia, shift 1", "Mia, shift 2", "Tom"])
    }

    // MARK: Controls, announcements and snippets

    @Test("Given each example, when the controls are laid out, then colour, size and opacity apply only to the orders")
    func encodingControlsForOrdersOnly() {
        let viewModel = KeyPathsViewModel(locale: english)
        #expect(viewModel.showsEncodingControls)

        viewModel.example = .shifts
        #expect(!viewModel.showsEncodingControls)
    }

    @Test("Given a change of property, when it is announced, then the message says what changed and then the headline")
    func announcements() {
        let viewModel = KeyPathsViewModel(locale: english)
        let headline = viewModel.headline

        viewModel.colour = .orderSize
        #expect(viewModel.colourAnnouncement() == "Colour and shape now show order size. \(headline)")
        viewModel.size = .minutesPerCup
        #expect(viewModel.sizeAnnouncement() == "Size now shows minutes a cup. \(headline)")
        viewModel.opacity = .cups
        #expect(viewModel.opacityAnnouncement() == "Opacity now shows cups. \(headline)")
        viewModel.example = .shifts
        #expect(viewModel.exampleAnnouncement() == "Now showing each shift as a bar from its start to its end. \(viewModel.headline)")
    }

    @Test("Given the orders with the size scale, when the snippets are listed, then they show the plot, the range and the key paths")
    func snippetsForOrders() {
        let viewModel = KeyPathsViewModel(locale: english)

        #expect(viewModel.snippets.map(\.name) == [
            "key-paths-point-plot", "key-paths-size-scale",
            "key-paths-colour-choices", "key-paths-size-choices", "key-paths-opacity-choices", "key-paths-spoken-orders",
        ])
    }

    @Test("Given the size scale left out, when the snippets are listed, then the range is replaced by the version without it")
    func snippetsForMistake() {
        let viewModel = KeyPathsViewModel(locale: english)
        viewModel.leavesOutSizeScale = true

        #expect(viewModel.snippets.map(\.name).contains("key-paths-no-size-scale"))
        #expect(!viewModel.snippets.map(\.name).contains("key-paths-size-scale"))
    }

    @Test("Given the shifts, when the snippets are listed, then they show the interval")
    func snippetsForShifts() {
        let viewModel = KeyPathsViewModel(locale: english)
        viewModel.example = .shifts

        #expect(viewModel.snippets.map(\.name) == ["key-paths-interval", "key-paths-spoken-shifts"])
    }

    @Test("Given each example, when the spoken note is read, then it says VoiceOver reads a representation, and why")
    func spokenNote() {
        let viewModel = KeyPathsViewModel(locale: english)

        #expect(viewModel.spokenNote.hasPrefix("VoiceOver reads the orders two hours at a time"))
        viewModel.example = .shifts
        #expect(viewModel.spokenNote.contains("never its start and end"))
    }

    @Test("Given the default styles, when the encoding note is read, then it names what the size legend and opacity show")
    func encodingNoteDefault() {
        let viewModel = KeyPathsViewModel(locale: english)

        #expect(viewModel.encodingNote
            == "The size legend's numbers are cups. Opacity shows wait, faintest for the lowest; it has no legend.")
    }

    @Test("Given colour by order size and size by cups, when the encoding note is read, then it says one field is encoded twice")
    func encodingNoteDuplicate() {
        let viewModel = KeyPathsViewModel(locale: english)
        viewModel.colour = .orderSize

        #expect(viewModel.encodingNote.hasSuffix(" Colour and size both show cups: one field, encoded twice."))
        viewModel.opacity = .cups
        #expect(viewModel.encodingNote.hasSuffix(" Colour, size, and opacity all show cups: one field, encoded three times."))
        viewModel.colour = .drink
        viewModel.size = .minutesPerCup
        viewModel.opacity = .minutesPerCup
        #expect(viewModel.encodingNote.hasSuffix(" Size and opacity both show minutes a cup: one field, encoded twice."))
    }

    @Test("Given the app's snippets, when every name this screen can show is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [
            "key-paths-point-plot", "key-paths-size-scale", "key-paths-no-size-scale", "key-paths-colour-choices",
            "key-paths-size-choices", "key-paths-opacity-choices", "key-paths-interval",
            "key-paths-spoken-orders", "key-paths-spoken-shifts",
        ]

        for name in names {
            #expect(store[name] != nil, "\(name) is missing")
        }
    }

    // MARK: Audio Graph

    @Test("Given the orders coloured by drink, when the descriptor is made, then it has a series per drink and waits in minutes")
    func ordersDescriptor() throws {
        let viewModel = KeyPathsViewModel(locale: english)
        let descriptor = KeyPathsOrdersDescriptor(orders: viewModel.orders, colour: .drink, locale: english).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Wait for each order by time of day, by drink")
        #expect(descriptor.series.map(\.name) == CafeData.manyOrderDrinks)
        #expect(descriptor.series.map(\.dataPoints.count).reduce(0, +) == KeyPathsViewModel.orderCount)
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        // The drawn wait axis: the longest wait (9.0 minutes) rounded up to 10, the domain the chart is given.
        #expect(yAxis.range == 0 ... 10)
        #expect(yAxis.valueDescriptionProvider(1) == "1 minute")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.summary?.hasPrefix("400 orders from 6:") == true)
    }

    @Test("Given the shifts, when the descriptor is made, then each shift is a category with its start and end as series")
    func shiftsDescriptor() throws {
        let viewModel = KeyPathsViewModel(locale: english)
        let descriptor = KeyPathsShiftsDescriptor(shifts: viewModel.shifts, locale: english).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.series.map(\.name) == [CafeWording.shiftStart, CafeWording.shiftEnd])
        #expect(descriptor.series.map(\.dataPoints.count) == [5, 5])
        #expect(yAxis.range == 6 ... 18)
        #expect(yAxis.valueDescriptionProvider(.infinity) == "")
        #expect(descriptor.summary?.hasPrefix("5 shifts from 6:") == true)
    }
}
