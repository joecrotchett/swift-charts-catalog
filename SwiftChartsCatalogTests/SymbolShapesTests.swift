import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct SymbolShapesTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")
    private let orders = [
        OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 60),
        OrderWait(id: 1, store: "Station", queueLength: 5, waitSeconds: 180),
        OrderWait(id: 2, store: "Harbour", queueLength: 2, waitSeconds: 95),
        OrderWait(id: 3, store: "Station", queueLength: 11, waitSeconds: 320),
        OrderWait(id: 4, store: "Station", queueLength: 6, waitSeconds: 210),
    ]

    // MARK: State

    @Test("Given a new screen, when nothing is changed, then Station's points are filled squares and the slider is off")
    func startingState() {
        let viewModel = SymbolShapesViewModel(orders: orders)

        #expect(viewModel.shape == .square)
        #expect(!viewModel.isOutlined)
        #expect(viewModel.unitScale == 0.75)
        #expect(viewModel.pickedCafe == "Station")
        #expect(!viewModel.isUnitScaleEditable)
    }

    @Test("Given the picker, when its choices are listed, then they are the eight built-in shapes and the custom one")
    func choicesAreEightAndCustom() {
        #expect(SymbolChoice.allCases.count == 9)
        #expect(SymbolChoice.allCases.count(where: { $0.builtInShape != nil }) == 8)
        #expect(SymbolChoice.custom.builtInShape == nil)
        #expect(Set(SymbolChoice.allCases.map(\.title)).count == 9)
    }

    @Test("Given any shape but the circle, when the cafés' shapes are asked for, then the last café has it and the other a circle")
    func otherCafeKeepsTheCircle() {
        let viewModel = SymbolShapesViewModel(orders: orders)

        for choice in SymbolChoice.allCases where choice != .circle {
            viewModel.shape = choice
            #expect(viewModel.choice(for: "Station") == choice)
            #expect(viewModel.choice(for: "Harbour") == .circle)
        }
    }

    @Test("Given the circle is picked, when the cafés' shapes are asked for, then the other café takes a square so the two still differ")
    func circleMovesTheReference() {
        let viewModel = SymbolShapesViewModel(orders: orders)
        viewModel.shape = .circle

        #expect(viewModel.choice(for: "Station") == .circle)
        #expect(viewModel.choice(for: "Harbour") == .square)
    }

    @Test("Given every shape, when the scale maps the cafés, then no two cafés are given the same shape")
    func cafesNeverShareAShape() {
        let viewModel = SymbolShapesViewModel(orders: orders)

        for choice in SymbolChoice.allCases {
            viewModel.shape = choice
            #expect(viewModel.choice(for: "Station") != viewModel.choice(for: "Harbour"))
        }
    }

    @Test("Given the custom shape, when it is picked, then the slider can be used and its note says where the cup is drawn")
    func customTurnsTheSliderOn() {
        let viewModel = SymbolShapesViewModel(orders: orders)
        #expect(viewModel.unitScaleNote == "No cups are drawn. Pick Custom to use the slider.")

        viewModel.shape = .custom
        viewModel.unitScale = 0.6

        #expect(viewModel.isUnitScaleEditable)
        #expect(viewModel.unitScaleText == 0.6.formatted(.number.precision(.fractionLength(2))))
        #expect(viewModel.unitScaleNote.contains(viewModel.unitScaleText))
    }

    @Test("Given no orders and the custom shape picked, when the slider is read, then it is off and its note says there is nothing to draw")
    func noOrdersTurnTheSliderOff() {
        let viewModel = SymbolShapesViewModel(orders: [])
        #expect(viewModel.unitScaleNote == "There are no orders to draw.")

        viewModel.shape = .custom

        #expect(!viewModel.isUnitScaleEditable)
        #expect(viewModel.unitScaleNote == "There are no orders to draw.")
    }

    @Test("Given orders that all met a queue of zero, when the queue axis is made, then it still has a width")
    func queueDomainNeverCollapses() {
        let zeros = [
            OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 40),
            OrderWait(id: 1, store: "Station", queueLength: 0, waitSeconds: 70),
        ]

        #expect(SymbolShapesChart.queueDomain(for: CafeOrders.grouping(zeros)) == 0 ... 1)
        #expect(SymbolShapesChart.queueDomain(for: CafeOrders.grouping(orders)) == 0 ... 11)
    }

    @Test("Given the slider's range, when it is read, then it stays inside the unit square and holds the starting value")
    func sliderRangeIsInsideTheUnitSquare() {
        #expect(SymbolShapesViewModel.unitScaleRange.lowerBound > 0)
        #expect(SymbolShapesViewModel.unitScaleRange.upperBound <= 1)
        #expect(SymbolShapesViewModel.unitScaleRange.contains(SymbolShapesViewModel.startingUnitScale))
    }

    @Test("Given a unit scale, when the cup's unit rect is asked for, then it is a centred square of that side")
    func cupUnitRectIsCentred() {
        let rect = CupSymbol(unitScale: 0.5).perceptualUnitRect

        #expect(rect == CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
    }

    @Test("Given a cup, when it is inset, then its path is smaller by that amount on every side")
    func cupInsets() {
        let box = CGRect(x: 0, y: 0, width: 20, height: 20)

        #expect(CupSymbol(unitScale: 1).path(in: box).boundingRect == box)
        #expect(CupSymbol(unitScale: 1).inset(by: 2).path(in: box).boundingRect == box.insetBy(dx: 2, dy: 2))
    }

    // MARK: Derived text

    @Test("Given filled squares, when the symbols are described, then each café is named with its shape")
    func describesFilledSymbols() {
        let viewModel = SymbolShapesViewModel(orders: orders)

        #expect(viewModel.symbolDescription == "Harbour café: filled circles. Station café: filled squares.")
    }

    @Test("Given the outlined custom shape, when the symbols are described, then the description follows both controls")
    func describesOutlinedCups() {
        let viewModel = SymbolShapesViewModel(orders: orders)
        viewModel.shape = .custom
        viewModel.isOutlined = true

        #expect(viewModel.symbolDescription == "Harbour café: outlined circles. Station café: outlined cups.")
    }

    @Test("Given orders, when the headline is written, then it gives the longest wait, its café and its queue")
    func headlineNamesTheLongestWait() {
        #expect(
            OrderWaitSummary(orders: orders, locale: english).headline
                == "The longest wait was 320 seconds, at the Station café with 11 people queuing."
        )
    }

    @Test("Given the café's sample data, when the headline is written, then its figure is the largest wait in that data")
    func headlineFollowsSampleData() throws {
        let longest = try #require(CafeData.orderWaits.map(\.waitSeconds).max())

        #expect(SymbolShapesViewModel().summary(locale: english).headline.contains(CafeWording.seconds(longest, locale: english)))
    }

    @Test("Given two orders tied for the longest wait, when the headline is written, then it counts them and names no single café")
    func tieCountsTheOrders() {
        let tied = [
            OrderWait(id: 0, store: "Harbour", queueLength: 3, waitSeconds: 200),
            OrderWait(id: 1, store: "Station", queueLength: 9, waitSeconds: 200),
            OrderWait(id: 2, store: "Station", queueLength: 1, waitSeconds: 80),
        ]

        #expect(OrderWaitSummary(orders: tied, locale: english).headline == "The longest wait was 200 seconds, on 2 orders.")
    }

    @Test("Given no orders, when the chart's words are written, then they say there are none")
    func emptyOrdersSaySo() {
        let viewModel = SymbolShapesViewModel(orders: [])

        #expect(viewModel.summary(locale: english).headline == "No orders yet.")
        #expect(viewModel.summary(locale: english).audioGraphSummary == "No orders yet.")
        #expect(!viewModel.hasOrders)
        #expect(viewModel.symbolDescription == "No orders to draw.")
    }

    @Test("Given orders that all waited zero seconds, when the headline is written, then it does not name a longest wait")
    func zeroWaitsSaySo() {
        let zeros = [
            OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 0),
            OrderWait(id: 1, store: "Station", queueLength: 0, waitSeconds: 0),
        ]

        #expect(OrderWaitSummary(orders: zeros, locale: english).headline == "No order had to wait.")
    }

    @Test("Given counts of one, when they are written, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(CafeWording.seconds(1, locale: english) == "1 second")
        #expect(CafeWording.seconds(95, locale: english) == "95 seconds")
        #expect(CafeWording.people(1, locale: english) == "1 person")
        #expect(CafeWording.people(0, locale: english) == "0 people")
        #expect(CafeWording.cafes(1, locale: english) == "1 café")
        #expect(CafeWording.cafes(2, locale: english) == "2 cafés")
        #expect(OrderWaitSummary.queueText(0, locale: english) == "nobody queuing")
        #expect(OrderWaitSummary.queueText(1, locale: english) == "1 person queuing")
        #expect(CafeWording.orders(1, locale: english) == "1 order")
    }

    @Test("Given a German locale, when the chart's words are written, then numbers are grouped its way and the words stay English")
    func numbersTakeTheLocale() throws {
        let slow = [
            OrderWait(id: 0, store: "Harbour", queueLength: 1, waitSeconds: 1100),
            OrderWait(id: 1, store: "Harbour", queueLength: 2, waitSeconds: 2400),
        ]
        let portion = try #require(CafeOrders.grouping(slow).first?.portions.first)

        #expect(OrderWaitSummary(orders: slow, locale: german).headline
            == "The longest wait was 2.400 seconds, at the Harbour café with 2 people queuing.")
        #expect(OrderWaitSummary(orders: slow, locale: german).audioGraphSummary.hasPrefix("2 orders at 1 café. "))
        #expect(portion.accessibilityValue(locale: german) == "2 orders, waits from 1.100 to 2.400 seconds")
    }

    // MARK: Accessibility

    @Test("Given orders, when they are grouped, then each café has a portion per band of four queue lengths, in data order")
    func groupsIntoPortions() {
        let cafes = CafeOrders.grouping(orders)

        #expect(cafes.map(\.name) == ["Harbour", "Station"])
        #expect(cafes[0].portions.map(\.id) == ["Harbour-0"])
        #expect(cafes[1].portions.map(\.id) == ["Station-4", "Station-8"])
        #expect(cafes.flatMap(\.orders).count == orders.count)
    }

    @Test("Given a portion, when its label and value are written, then they give the café and queue first, then the waits with their unit")
    func portionWords() throws {
        let station = try #require(CafeOrders.grouping(orders).last)

        #expect(station.portions[0].accessibilityLabel(locale: english) == "Station, 4 to 7 people queuing")
        #expect(station.portions[0].accessibilityValue(locale: english) == "2 orders, waits from 180 to 210 seconds")
        #expect(station.portions[1].accessibilityValue(locale: english) == "1 order, wait 320 seconds")
    }

    @Test("Given orders, when the Audio Graph summary is written, then it gives the counts and ranges in actual values")
    func summaryGivesActualValues() {
        #expect(
            OrderWaitSummary(orders: orders, locale: english).audioGraphSummary
                == "5 orders at 2 cafés. Queues from 0 to 11 people. Waits from 60 to 320 seconds. "
                + "Harbour: 2 orders, waits from 60 to 95 seconds. Station: 3 orders, waits from 180 to 320 seconds."
        )
    }

    @Test("Given orders, when the chart descriptor is made, then it has a title, the summary, and a named series of separate points per café")
    func descriptorDescribesTheChart() {
        let summary = OrderWaitSummary(orders: orders, locale: english)
        let descriptor = OrderWaitChartDescriptor(cafes: CafeOrders.grouping(orders), summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Wait for an order against the queue when it was placed, by café")
        #expect(descriptor.summary == summary.audioGraphSummary)
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.dataPoints.count) == [2, 3])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
    }

    @Test("Given orders, when the chart descriptor is made, then both axes are numbers from zero and say their unit")
    func descriptorAxes() throws {
        let descriptor = OrderWaitChartDescriptor(
            cafes: CafeOrders.grouping(orders), summary: OrderWaitSummary(orders: orders, locale: english)
        ).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "People queuing")
        #expect(xAxis.range == 0 ... 11)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person")
        #expect(yAxis.title == "Wait (seconds)")
        // The longest wait is 320; the axis is drawn to 400, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 400)
        #expect(yAxis.valueDescriptionProvider(95) == "95 seconds")
    }

    // MARK: Snippets

    @Test("Given a filled built-in shape, when the snippets are listed, then they are the chart and the built-in shapes")
    func snippetsForFilledBuiltIn() {
        let viewModel = SymbolShapesViewModel(orders: orders)

        #expect(viewModel.snippets.map(\.name) == ["symbol-shapes-chart", "symbol-shapes-built-in"])
    }

    @Test("Given an outlined built-in shape, when the snippets are listed, then strokeBorder is added")
    func snippetsForOutlinedBuiltIn() {
        let viewModel = SymbolShapesViewModel(orders: orders)
        viewModel.isOutlined = true

        #expect(viewModel.snippets.map(\.name) == ["symbol-shapes-chart", "symbol-shapes-built-in", "symbol-shapes-outlined"])
    }

    @Test("Given the filled custom shape, when the snippets are listed, then the custom shape is added")
    func snippetsForFilledCustom() {
        let viewModel = SymbolShapesViewModel(orders: orders)
        viewModel.shape = .custom

        #expect(viewModel.snippets.map(\.name) == ["symbol-shapes-chart", "symbol-shapes-built-in", "symbol-shapes-custom"])
    }

    @Test("Given the outlined custom shape, when the snippets are listed, then both outlines and the custom shape are shown")
    func snippetsForOutlinedCustom() {
        let viewModel = SymbolShapesViewModel(orders: orders)
        viewModel.shape = .custom
        viewModel.isOutlined = true

        #expect(viewModel.snippets.map(\.name) == [
            "symbol-shapes-chart", "symbol-shapes-built-in", "symbol-shapes-outlined",
            "symbol-shapes-custom", "symbol-shapes-custom-outlined",
        ])
    }

    @Test("Given every setting of the controls, when its snippets are looked up, then each exists in the app and has a title")
    func everySnippetExists() throws {
        let store = try SnippetStore()
        let viewModel = SymbolShapesViewModel(orders: orders)

        for choice in SymbolChoice.allCases {
            for isOutlined in [false, true] {
                viewModel.shape = choice
                viewModel.isOutlined = isOutlined
                for snippet in viewModel.snippets {
                    #expect(store[snippet.name] != nil, "\(snippet.name) is missing")
                    #expect(!snippet.title.isEmpty)
                }
            }
        }
    }
}
